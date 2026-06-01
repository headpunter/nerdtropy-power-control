-- ============================================================
-- POWER NETWORK - SLAVE NODE (v2.3)
-- ============================================================
-- Passive worker. No watchdog. Cached command on reboot.
-- Accepts single-message file update from master, reboots.
-- ============================================================

local VERSION            = "2.4"
local MODEM_SIDE         = "left"
local PERIPHERAL_SIDE    = "back"
local REDSTONE_SIDE      = "right"
local HEARTBEAT_INTERVAL = 2
local PROTOCOL           = "nerdtropy_power"
local MASTER_HOSTNAME    = "power_master"
local STATE_DIR          = "/pwr_slave"
local STATE_FILE         = STATE_DIR .. "/state.dat"

local periph   = nil
local role     = nil
local ptype    = nil
local myUuid   = nil
local myName   = nil
local masterId = nil
local cachedCommand = nil

local function log(msg)
    print(string.format("[%s] %s", textutils.formatTime(os.time(), true), msg))
end
local function divider() print(string.rep("-", 40)) end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

-- ============================================================
-- PERSISTENCE
-- ============================================================
local function ensureDir()
    if not fs.exists(STATE_DIR) then fs.makeDir(STATE_DIR) end
end

local function loadState()
    ensureDir()
    if not fs.exists(STATE_FILE) then return end
    local h = fs.open(STATE_FILE, "r")
    local ok, data = pcall(textutils.unserialize, h.readAll())
    h.close()
    if ok and type(data) == "table" then
        myUuid = data.uuid
        myName = data.name
        cachedCommand = data.cachedCommand
    end
end

local function saveState()
    ensureDir()
    local h = fs.open(STATE_FILE, "w")
    h.write(textutils.serialize({
        uuid=myUuid, name=myName, cachedCommand=cachedCommand,
    }))
    h.close()
end

-- ============================================================
-- ROLE
-- ============================================================
local function identifyRole()
    periph = peripheral.wrap(PERIPHERAL_SIDE)
    if not periph then return nil, nil, "No peripheral on "..PERIPHERAL_SIDE end
    ptype = peripheral.getType(PERIPHERAL_SIDE)
    local roleMap = {
        ["inductionPort"]="battery", ["mekanism:induction_port"]="battery",
        ["fissionReactorLogicAdapter"]="reactor",
        ["mekanism:fission_reactor_logic_adapter"]="reactor",
        ["fusionReactorLogicAdapter"]="reactor",
        ["BigReactors-Reactor"]="reactor", ["BiggerReactors_Reactor"]="reactor",
        ["bigger_reactors_reactor"]="reactor",
        ["BigReactors-Turbine"]="turbine", ["BiggerReactors_Turbine"]="turbine",
        ["bigger_reactors_turbine"]="turbine",
        ["energyDetector"]="energy_detector", ["energy_detector"]="energy_detector",
    }
    return (roleMap[ptype] or "unknown"), ptype, nil
end

-- ============================================================
-- DATA COLLECTION
-- ============================================================
local function collectData()
    local d = { role=role, ptype=ptype, version=VERSION }
    if role == "battery" then
        d.energy=safeCall(periph.getEnergy)
        d.maxEnergy=safeCall(periph.getMaxEnergy)
        local p=safeCall(periph.getEnergyFilledPercentage)
        if p then d.fillPercent=p*100 end
        d.lastInput=safeCall(periph.getLastInput)
        d.lastOutput=safeCall(periph.getLastOutput)
        d.transferCap=safeCall(periph.getTransferCap)
        d.cells=safeCall(periph.getInstalledCells)
    elseif role == "reactor" then
        d.active=safeCall(periph.getActive)
        d.assembled=safeCall(periph.mbIsAssembled)
        d.activelyCooled=safeCall(periph.isActivelyCooled)
        d.casingTemp=safeCall(periph.getCasingTemperature)
        d.fuelTemp=safeCall(periph.getFuelTemperature)
        d.fuel=safeCall(periph.getFuelAmount)
        d.fuelMax=safeCall(periph.getFuelAmountMax)
        d.fuelReactivity=safeCall(periph.getFuelReactivity)
        d.fuelBurnRate=safeCall(periph.getFuelConsumedLastTick)
        d.waste=safeCall(periph.getWasteAmount)
        d.energy=safeCall(periph.getEnergyStored)
        d.energyMax=safeCall(periph.getEnergyCapacity)
        d.output=safeCall(periph.getEnergyProducedLastTick)
        if d.activelyCooled then
            d.coolant=safeCall(periph.getCoolantAmount)
            d.coolantMax=safeCall(periph.getCoolantAmountMax)
            d.hotFluid=safeCall(periph.getHotFluidAmount)
            d.hotFluidMax=safeCall(periph.getHotFluidAmountMax)
            d.steamOutput=safeCall(periph.getHotFluidProducedLastTick)
        end
        d.numRods=safeCall(periph.getNumberOfControlRods)
        if d.numRods and d.numRods>0 then
            d.rodLevel=safeCall(periph.getControlRodLevel, 0)
        end
    elseif role == "turbine" then
        d.active=safeCall(periph.getActive)
        d.assembled=safeCall(periph.mbIsAssembled)
        d.rpm=safeCall(periph.getRotorSpeed)
        d.steamIn=safeCall(periph.getFluidFlowRate)
        d.steamMax=safeCall(periph.getFluidFlowRateMax)
        d.steamMaxMax=safeCall(periph.getFluidFlowRateMaxMax)
        d.bladeEfficiency=safeCall(periph.getBladeEfficiency)
        d.numBlades=safeCall(periph.getNumberOfBlades)
        d.rotorMass=safeCall(periph.getRotorMass)
        d.inductorEngaged=safeCall(periph.getInductorEngaged)
        d.energy=safeCall(periph.getEnergyStored)
        d.energyMax=safeCall(periph.getEnergyCapacity)
        d.output=safeCall(periph.getEnergyProducedLastTick)
        d.inputAmount=safeCall(periph.getInputAmount)
        d.outputAmount=safeCall(periph.getOutputAmount)
        d.fluidAmountMax=safeCall(periph.getFluidAmountMax)
    elseif role == "energy_detector" then
        d.transferRate=safeCall(periph.getTransferRate)
        d.transferLimit=safeCall(periph.getTransferRateLimit)
    end
    d.lastCommandAction = cachedCommand and cachedCommand.action or nil
    d.lastCommandState  = cachedCommand and cachedCommand.params
                          and cachedCommand.params.state or nil
    return d
end

-- ============================================================
-- COMMANDS
-- ============================================================
local function executeCommand(action, params)
    params = params or {}
    if action == "set_reactor" then
        if type(periph.setActive)=="function" then pcall(periph.setActive, params.state==true) end
        redstone.setOutput(REDSTONE_SIDE, params.state==true)
        log("Reactor -> "..tostring(params.state))
        return true
    elseif action == "set_turbine" then
        if type(periph.setActive)=="function" then pcall(periph.setActive, params.state==true) end
        if params.inductor ~= nil and type(periph.setInductorEngaged)=="function" then
            pcall(periph.setInductorEngaged, params.inductor==true)
        end
        redstone.setOutput(REDSTONE_SIDE, params.state==true)
        log("Turbine -> "..tostring(params.state).." inductor="..(params.inductor==nil and "unchanged" or tostring(params.inductor)))
        return true
    elseif action == "set_inductor" then
        if type(periph.setInductorEngaged)=="function" then
            pcall(periph.setInductorEngaged, params.state==true)
        end
        log("Inductor -> "..tostring(params.state))
        return true
    elseif action == "scram" then
        if role=="reactor" and type(periph.setActive)=="function" then
            pcall(periph.setActive, false)
        end
        if role=="turbine" then
            if type(periph.setActive)=="function" then pcall(periph.setActive, false) end
            if type(periph.setInductorEngaged)=="function" then
                pcall(periph.setInductorEngaged, false)
            end
        end
        redstone.setOutput(REDSTONE_SIDE, false)
        log("!!! SCRAM !!!")
        return true
    end
    return false
end

local function handleCommand(action, params)
    cachedCommand = { action=action, params=params, timestamp=os.epoch("utc") }
    saveState()
    return executeCommand(action, params)
end

-- ============================================================
-- UPDATE HANDLER - receives full file content in one message
-- ============================================================
local function handleUpdate(msg)
    if not msg.content then
        log("UPDATE ERROR: no content")
        return
    end
    -- Validate syntax
    local fn, err = load(msg.content)
    if not fn then
        log("UPDATE ERROR: " .. tostring(err))
        if masterId then
            rednet.send(masterId, {
                type="UPDATE_RESULT", uuid=myUuid,
                ok=false, err=tostring(err)
            }, PROTOCOL)
        end
        return
    end
    -- Write to startup
    local h = fs.open("startup", "w")
    h.write(msg.content)
    h.close()
    log("Update written OK. Rebooting...")
    if masterId then
        rednet.send(masterId, {
            type="UPDATE_RESULT", uuid=myUuid, ok=true
        }, PROTOCOL)
    end
    sleep(0.5)
    os.reboot()
end

-- ============================================================
-- NETWORK
-- ============================================================
local function setupNetwork()
    if not peripheral.isPresent(MODEM_SIDE) then
        return false, "No modem on "..MODEM_SIDE
    end
    if peripheral.getType(MODEM_SIDE) ~= "modem" then
        return false, "Not a modem on "..MODEM_SIDE
    end
    rednet.open(MODEM_SIDE)
    return true
end

local function findMaster()
    log("Searching for master...")
    masterId = rednet.lookup(PROTOCOL, MASTER_HOSTNAME)
    if masterId then log("Master found at ID "..masterId); return true end
    return false
end

local function sendHello()
    if not masterId then return false end
    rednet.send(masterId, {
        type="HELLO", role=role, ptype=ptype,
        uuid=myUuid, version=VERSION, cachedCommand=cachedCommand,
    }, PROTOCOL)
    return true
end

local function sendReport()
    if not masterId then return false end
    rednet.send(masterId, { type="REPORT", uuid=myUuid, data=collectData() }, PROTOCOL)
    return true
end

-- ============================================================
-- STARTUP
-- ============================================================
term.clear()
term.setCursorPos(1, 1)
print("=== Power Network Slave v"..VERSION.." ===")
print("(Passive - no watchdog)")
divider()

loadState()

local r, p, err = identifyRole()
if not r then print("ERROR: "..err); return end
role=r
print("Role: "..role.."  Peripheral: "..p)
if myUuid then print("Name: "..(myName or "?").."  UUID: "..myUuid) end
divider()

local ok, netErr = setupNetwork()
if not ok then print("ERROR: "..netErr); return end
print("Modem ready")
divider()

if cachedCommand and cachedCommand.action then
    print("Cached: "..cachedCommand.action.." state="..
          tostring(cachedCommand.params and cachedCommand.params.state))
    log("Replaying cached command")
    executeCommand(cachedCommand.action, cachedCommand.params)
else
    print("No cached command - peripheral unchanged")
end
divider()

while not findMaster() do print("No master - retry 5s..."); sleep(5) end
divider()

sendHello()
print("HELLO sent...")

local timeout=10; local welcomed=false
while timeout>0 and not welcomed do
    local sender, msg = rednet.receive(PROTOCOL, 1)
    if sender==masterId and type(msg)=="table" and msg.type=="WELCOME" then
        myUuid=msg.uuid; myName=msg.name; welcomed=true; saveState()
    end
    timeout=timeout-1
end

if welcomed then print("Registered: "..(myName or "?"))
else print("No WELCOME - will retry...") end
divider()
print("Online. Heartbeat every "..HEARTBEAT_INTERVAL.."s.")
print("(Ctrl+T to stop)\n")

-- ============================================================
-- MAIN LOOP
-- ============================================================
local lastReport = 0
while true do
    local sender, msg = rednet.receive(PROTOCOL, 0.5)

    if sender==masterId and type(msg)=="table" then
        if     msg.type=="COMMAND" then
            handleCommand(msg.action, msg.params)
            rednet.send(masterId,{type="ACK",uuid=myUuid,command=msg.action},PROTOCOL)
        elseif msg.type=="PING" then
            rednet.send(masterId,{type="PONG",uuid=myUuid,version=VERSION},PROTOCOL)
        elseif msg.type=="UPDATE" then
            handleUpdate(msg)
        elseif msg.type=="WELCOME" then
            myUuid=msg.uuid; myName=msg.name; saveState()
            log("Re-registered as "..myName)
        end
    end

    local now=os.epoch("utc")
    if (now-lastReport)/1000 >= HEARTBEAT_INTERVAL then
        if myUuid then sendReport() else sendHello() end
        lastReport=now
    end
end
