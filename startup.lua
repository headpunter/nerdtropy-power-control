-- ============================================================
-- NERDTROPY POWER CONTROL — v3.1
-- ============================================================
-- Single file for all nodes. Role is auto-detected on boot:
--   • Monitor on right side  →  Display mode (renders dashboard)
--   • Any other peripheral   →  Slave mode   (reports telemetry)
-- OTA updates pulled from Gitea on every boot.
-- ============================================================

local VERSION          = "3.8"
local API_HOST         = "http://10.10.0.10:8000"
local GITEA_RAW        = "http://10.10.0.10:30008/headpunter/nerdtropy-minecraft-project/raw/branch/main"
local MONITOR_SIDE     = "right"
local POLL_INTERVAL    = 1      -- display refresh seconds
local HEARTBEAT        = 2      -- slave report interval seconds
local STATE_DIR        = "/pwr_slave"
local STATE_FILE       = STATE_DIR .. "/state.dat"

-- ============================================================
-- SHARED HELPERS
-- ============================================================
local function log(msg)
    print(string.format("[%s] %s", textutils.formatTime(os.time(), true), msg))
end

local function apiPost(path, payload)
    local ok, response = pcall(
        http.post,
        API_HOST .. path,
        textutils.serialiseJSON(payload),
        {["Content-Type"] = "application/json"}
    )
    if not ok or not response or type(response) ~= "table" then return nil end
    local ok2, body = pcall(textutils.unserialiseJSON, response.readAll())
    response.close()
    return ok2 and body or nil
end

local function apiGet(path)
    local ok, response = pcall(http.get, API_HOST .. path)
    if not ok or not response or type(response) ~= "table" then return nil end
    local ok2, body = pcall(textutils.unserialiseJSON, response.readAll())
    response.close()
    return ok2 and body or nil
end

-- Mekanism: J → FE (÷2.5)
local function formatFE(j)
    if j == nil then return "?" end
    local fe = math.abs(j) / 2.5
    if fe >= 1e12 then return string.format("%.2f TFE", fe/1e12) end
    if fe >= 1e9  then return string.format("%.2f GFE", fe/1e9)  end
    if fe >= 1e6  then return string.format("%.2f MFE", fe/1e6)  end
    if fe >= 1e3  then return string.format("%.2f kFE", fe/1e3)  end
    return string.format("%.0f FE", fe)
end

-- BigReactors / turbine output: already FE, no conversion
local function formatRawFE(fe)
    if fe == nil then return "?" end
    fe = math.abs(fe)
    if fe >= 1e12 then return string.format("%.2f TFE", fe/1e12) end
    if fe >= 1e9  then return string.format("%.2f GFE", fe/1e9)  end
    if fe >= 1e6  then return string.format("%.2f MFE", fe/1e6)  end
    if fe >= 1e3  then return string.format("%.2f kFE", fe/1e3)  end
    return string.format("%.0f FE", fe)
end

local function formatTime(s)
    if s == nil or s <= 0 or s == math.huge then return "--" end
    local d = math.floor(s/86400)
    local h = math.floor((s%86400)/3600)
    local m = math.floor((s%3600)/60)
    if d > 0 then return string.format("%dd %02dh", d, h)
    elseif h > 0 then return string.format("%dh %02dm", h, m)
    else return string.format("%dm", m) end
end

local function formatUptime(s)
    local d = math.floor(s/86400)
    local h = math.floor((s%86400)/3600)
    local m = math.floor((s%3600)/60)
    if d > 0 then return string.format("%dd %02dh %02dm", d, h, m) end
    return string.format("%02dh %02dm", h, m)
end

-- ============================================================
-- OTA UPDATE
-- ============================================================
local function checkUpdate()
    print("Checking for updates...")
    local ok, r = pcall(http.get, GITEA_RAW .. "/version.txt")
    if not ok or not r then print("Update check failed (Gitea unreachable)"); return end
    local remote = r.readAll():match("^%s*(.-)%s*$")  -- trim whitespace
    r.close()

    if remote == VERSION then
        print("Up to date (" .. VERSION .. ")")
        return
    end

    print(string.format("Update available: %s → %s. Downloading...", VERSION, remote))
    local ok2, r2 = pcall(http.get, GITEA_RAW .. "/startup.lua")
    if not ok2 or not r2 then print("Download failed"); return end
    local content = r2.readAll()
    r2.close()

    -- Validate syntax before writing
    local fn, err = load(content, "startup.lua")
    if not fn then
        print("Update rejected (syntax error): " .. tostring(err))
        return
    end

    local h = fs.open("/startup", "w")
    h.write(content)
    h.close()
    print("Updated to " .. remote .. ". Rebooting...")
    sleep(1)
    os.reboot()
end

-- ============================================================
-- SLAVE MODE
-- ============================================================
local ROLE_MAP = {
    ["inductionPort"]="battery",          ["mekanism:induction_port"]="battery",
    ["fissionReactorLogicAdapter"]="reactor",
    ["mekanism:fission_reactor_logic_adapter"]="reactor",
    ["fusionReactorLogicAdapter"]="reactor",
    ["BigReactors-Reactor"]="reactor",    ["BiggerReactors_Reactor"]="reactor",
    ["bigger_reactors_reactor"]="reactor",
    ["BigReactors-Turbine"]="turbine",    ["BiggerReactors_Turbine"]="turbine",
    ["bigger_reactors_turbine"]="turbine",
    ["energyDetector"]="energy_detector", ["energy_detector"]="energy_detector",
}
local ROLE_PRIORITY = {"battery","reactor","turbine","energy_detector","unknown"}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if not ok then return nil end
    return r
end

local function discoverPeripherals()
    local found = {}
    for _, side in ipairs({"top","bottom","left","right","front","back"}) do
        if peripheral.isPresent(side) then
            found[side] = {
                type    = peripheral.getType(side),
                methods = peripheral.getMethods(side) or {},
            }
        end
    end
    return found
end

local function pickPrimary(peripherals)
    local byRole = {}
    for side, info in pairs(peripherals) do
        local role = ROLE_MAP[info.type] or "unknown"
        if not byRole[role] then byRole[role] = {side=side, ptype=info.type} end
    end
    for _, r in ipairs(ROLE_PRIORITY) do
        if byRole[r] then return r, byRole[r].side, byRole[r].ptype end
    end
    local side, info = next(peripherals)
    if side then return "unknown", side, info.type end
    return "unknown", nil, "unknown"
end

local function collectData(role, p)
    if not p then return {} end
    local d = {}
    if role == "battery" then
        d.energy       = safeCall(p.getEnergy)
        d.maxEnergy    = safeCall(p.getMaxEnergy)
        local pct      = safeCall(p.getEnergyFilledPercentage)
        if pct then d.fillPercent = pct * 100 end
        d.lastInput    = safeCall(p.getLastInput)
        d.lastOutput   = safeCall(p.getLastOutput)
        d.transferCap  = safeCall(p.getTransferCap)
        d.cells        = safeCall(p.getInstalledCells)

    elseif role == "reactor" then
        d.active          = safeCall(p.getActive)
        d.assembled       = safeCall(p.mbIsAssembled)
        d.activelyCooled  = safeCall(p.isActivelyCooled)
        d.casingTemp      = safeCall(p.getCasingTemperature)
        d.fuelTemp        = safeCall(p.getFuelTemperature)
        d.fuel            = safeCall(p.getFuelAmount)
        d.fuelMax         = safeCall(p.getFuelAmountMax)
        d.fuelBurnRate    = safeCall(p.getFuelConsumedLastTick)
        d.waste           = safeCall(p.getWasteAmount)
        d.energy          = safeCall(p.getEnergyStored)
        d.energyMax       = safeCall(p.getEnergyCapacity)
        d.output          = safeCall(p.getEnergyProducedLastTick)
        if d.activelyCooled then
            d.coolant     = safeCall(p.getCoolantAmount)
            d.coolantMax  = safeCall(p.getCoolantAmountMax)
            d.hotFluid    = safeCall(p.getHotFluidAmount)
            d.hotFluidMax = safeCall(p.getHotFluidAmountMax)
            d.steamOutput = safeCall(p.getHotFluidProducedLastTick)
        end
        d.numRods = safeCall(p.getNumberOfControlRods)
        if d.numRods and d.numRods > 0 then
            d.rodLevel = safeCall(p.getControlRodLevel, 0)
        end

    elseif role == "turbine" then
        d.active          = safeCall(p.getActive)
        d.assembled       = safeCall(p.mbIsAssembled)
        d.rpm             = safeCall(p.getRotorSpeed)
        d.steamIn         = safeCall(p.getFluidFlowRate)
        d.steamMax        = safeCall(p.getFluidFlowRateMax)
        d.steamMaxMax     = safeCall(p.getFluidFlowRateMaxMax)
        d.bladeEfficiency = safeCall(p.getBladeEfficiency)
        d.numBlades       = safeCall(p.getNumberOfBlades)
        d.rotorMass       = safeCall(p.getRotorMass)
        d.inductorEngaged = safeCall(p.getInductorEngaged)
        d.energy          = safeCall(p.getEnergyStored)
        d.energyMax       = safeCall(p.getEnergyCapacity)
        d.output          = safeCall(p.getEnergyProducedLastTick)
        d.inputAmount     = safeCall(p.getInputAmount)
        d.outputAmount    = safeCall(p.getOutputAmount)
        d.fluidAmountMax  = safeCall(p.getFluidAmountMax)

    elseif role == "energy_detector" then
        d.transferRate    = safeCall(p.getTransferRate)
        d.transferLimit   = safeCall(p.getTransferRateLimit)
    end
    return d
end

local function verifyPeripheral(p, role, reportFn)
    local results = {}
    local pass, fail = 0, 0

    local function check(name, fn)
        local ok, err = pcall(fn)
        if ok then
            print("  [OK] " .. name)
            pass = pass + 1
        else
            print("  [FAIL] " .. name .. ": " .. tostring(err))
            fail = fail + 1
        end
        table.insert(results, {test=name, ok=ok, err=ok and nil or tostring(err)})
    end

    local function readback(getter, setter, testVal, restoreVal, label)
        -- write testVal, read back, restore
        local ok1 = pcall(setter, testVal)
        if not ok1 then
            print("  [FAIL] " .. label .. ": setter threw error")
            fail = fail + 1
            table.insert(results, {test=label, ok=false, err="setter error"})
            return
        end
        sleep(0.5)
        local ok2, got = pcall(getter)
        local matched = ok2 and (got == testVal)
        pcall(setter, restoreVal)  -- always restore
        if matched then
            print("  [OK] " .. label .. " (set=" .. tostring(testVal) .. " read=" .. tostring(got) .. ")")
            pass = pass + 1
        else
            print("  [FAIL] " .. label .. " (set=" .. tostring(testVal) .. " read=" .. tostring(got) .. ")")
            fail = fail + 1
        end
        table.insert(results, {test=label, ok=matched, set=testVal, got=got})
    end

    print("--- Peripheral verification: " .. role .. " ---")

    if role == "turbine" then
        -- Verify all getters respond
        check("getActive",              function() assert(p.getActive() ~= nil) end)
        check("getRotorSpeed",          function() assert(p.getRotorSpeed() ~= nil) end)
        check("getInductorEngaged",     function() assert(p.getInductorEngaged() ~= nil) end)
        check("getFluidFlowRateMax",    function() assert(p.getFluidFlowRateMax() ~= nil) end)
        check("getFluidFlowRateMaxMax", function() assert(p.getFluidFlowRateMaxMax() ~= nil) end)
        check("mbIsAssembled",          function() assert(p.mbIsAssembled() ~= nil) end)

        -- setActive: toggle off then restore
        local curActive = p.getActive()
        readback(p.getActive, p.setActive, not curActive, curActive, "setActive")

        -- setFluidFlowRateMax: ±1 from current, then restore
        local curFlow = p.getFluidFlowRateMax() or 0
        local maxFlow = p.getFluidFlowRateMaxMax() or 2000
        local testFlow = (curFlow > 10) and (curFlow - 1) or (curFlow + 1)
        testFlow = math.max(0, math.min(maxFlow, testFlow))
        readback(p.getFluidFlowRateMax, p.setFluidFlowRateMax,
                 testFlow, curFlow, "setFluidFlowRateMax")

        -- setInductorEngaged: toggle and restore
        local curCoil = p.getInductorEngaged()
        readback(p.getInductorEngaged, p.setInductorEngaged,
                 not curCoil, curCoil, "setInductorEngaged")

    elseif role == "reactor" then
        -- Verify all getters respond
        check("getActive",            function() assert(p.getActive() ~= nil) end)
        check("getCasingTemperature", function() assert(p.getCasingTemperature() ~= nil) end)
        check("getFuelAmount",        function() assert(p.getFuelAmount() ~= nil) end)
        check("isActivelyCooled",     function() assert(p.isActivelyCooled() ~= nil) end)
        check("mbIsAssembled",        function() assert(p.mbIsAssembled() ~= nil) end)

        -- setActive: toggle off then restore
        local curActive = p.getActive()
        readback(p.getActive, p.setActive, not curActive, curActive, "setActive")

        -- setControlRodLevel: ±1 from current, then restore
        local numRods = p.getNumberOfControlRods() or 0
        if numRods > 0 then
            local curLevel = p.getControlRodLevel(0) or 0
            local testLevel = (curLevel < 99) and (curLevel + 1) or (curLevel - 1)
            readback(
                function() return p.getControlRodLevel(0) end,
                function(v) p.setControlRodLevel(0, v) end,
                testLevel, curLevel, "setControlRodLevel"
            )
        end

    elseif role == "battery" then
        check("getEnergy",    function() assert(p.getEnergy() ~= nil) end)
        check("getMaxEnergy", function() assert(p.getMaxEnergy() ~= nil) end)
        check("getLastInput", function() assert(p.getLastInput() ~= nil) end)
    end

    local summary = string.format("Verification: %d passed, %d failed", pass, fail)
    print(summary)
    if reportFn then
        reportFn({
            event   = "verify",
            role    = role,
            passed  = pass,
            failed  = fail,
            results = results,
        })
    end
    return fail == 0
end

local function executeCommand(action, params, periph, myRole, cachedCmd)
    params = params or {}
    if action == "set_reactor" then
        if type(periph.setActive) == "function" then
            pcall(periph.setActive, params.state == true)
        end
        redstone.setOutput("right", params.state == true)
        log("Reactor -> " .. tostring(params.state))

    elseif action == "set_turbine" then
        if type(periph.setActive) == "function" then
            pcall(periph.setActive, params.state == true)
        end
        if params.inductor ~= nil and type(periph.setInductorEngaged) == "function" then
            pcall(periph.setInductorEngaged, params.inductor == true)
        end
        redstone.setOutput("right", params.state == true)
        log("Turbine -> " .. tostring(params.state))

    elseif action == "set_inductor" then
        if type(periph.setInductorEngaged) == "function" then
            pcall(periph.setInductorEngaged, params.state == true)
        end
        log("Inductor -> " .. tostring(params.state))

    elseif action == "set_flow_rate" then
        if type(periph.setFluidFlowRateMax) == "function" then
            pcall(periph.setFluidFlowRateMax, params.rate)
        end
        log("Flow rate -> " .. tostring(params.rate) .. " mB/t")

    elseif action == "reboot" then
        log("Remote reboot command received — rebooting...")
        sleep(1)
        os.reboot()

    elseif action == "scram" then
        if myRole == "reactor" and type(periph.setActive) == "function" then
            pcall(periph.setActive, false)
        end
        if myRole == "turbine" then
            if type(periph.setActive) == "function" then pcall(periph.setActive, false) end
            if type(periph.setInductorEngaged) == "function" then
                pcall(periph.setInductorEngaged, false)
            end
        end
        redstone.setOutput("right", false)
        log("!!! SCRAM !!!")
    end

    cachedCmd.action = action
    cachedCmd.params = params
end

local function runSlave()
    local myUuid, myName, myRole, primarySide, periph
    local cachedCommand = {}

    local function saveState()
        if not fs.exists(STATE_DIR) then fs.makeDir(STATE_DIR) end
        local h = fs.open(STATE_FILE, "w")
        h.write(textutils.serialize({
            uuid=myUuid, name=myName, role=myRole,
            cachedCommand=cachedCommand
        }))
        h.close()
    end

    local function loadState()
        if not fs.exists(STATE_FILE) then return end
        local h = fs.open(STATE_FILE, "r")
        local ok, data = pcall(textutils.unserialize, h.readAll())
        h.close()
        if ok and type(data) == "table" then
            myUuid        = data.uuid
            myName        = data.name
            myRole        = data.role
            cachedCommand = data.cachedCommand or {}
        end
    end

    loadState()

    local allPeripherals = discoverPeripherals()
    -- Remove monitor from peripheral map so it doesn't influence role
    for side, info in pairs(allPeripherals) do
        if info.type == "monitor" then allPeripherals[side] = nil end
    end

    if not next(allPeripherals) then
        print("ERROR: No peripherals found (monitor doesn't count)")
        return
    end

    local localRole, localSide, localPtype = pickPrimary(allPeripherals)
    myRole      = myRole or localRole
    primarySide = localSide
    periph      = peripheral.wrap(primarySide)

    print("Primary: " .. localRole .. " (" .. localPtype .. ") on " .. (localSide or "?"))
    if myUuid then print("Saved UUID: " .. myUuid) end

    if cachedCommand and cachedCommand.action then
        print("Replaying: " .. cachedCommand.action)
        executeCommand(cachedCommand.action, cachedCommand.params, periph, myRole, cachedCommand)
    end

    print("Connecting to " .. API_HOST .. " ...")
    local registered = false
    while not registered do
        local body = apiPost("/api/report", {
            uuid        = myUuid,
            computer_id = os.getComputerID(),
            version     = VERSION,
            peripherals = allPeripherals,
        })
        if body and body.uuid then
            myUuid = body.uuid
            myName = body.name
            myRole = body.role
            saveState()
            registered = true
            print("Registered as: " .. myName .. " (" .. myRole .. ")")
        else
            print("API unreachable, retrying in 5s...")
            sleep(5)
        end
    end

    print("Running peripheral verification...")
    local verifyOk = verifyPeripheral(periph, myRole, function(vdata)
        apiPost("/api/report", {
            uuid    = myUuid,
            version = VERSION,
            data    = { verify = vdata },
        })
    end)
    if not verifyOk then
        print("WARNING: Some peripheral checks failed — check wiring")
    end

    print("Online. Heartbeat every " .. HEARTBEAT .. "s.")
    print("(Ctrl+T to stop)")

    while true do
        local data = collectData(myRole, periph)
        local body = apiPost("/api/report", {
            uuid    = myUuid,
            version = VERSION,
            data    = data,
        })
        if body then
            if body.uuid and body.uuid ~= myUuid then
                myUuid = body.uuid
                myName = body.name
                myRole = body.role
                saveState()
                log("Re-registered as " .. myName)
            end
            if body.command then
                local cmd = body.command
                log("CMD: " .. cmd.action .. " — " .. (cmd.reason or ""))
                executeCommand(cmd.action, cmd.params, periph, myRole, cachedCommand)
                saveState()
            end
        else
            log("API unreachable")
        end
        sleep(HEARTBEAT)
    end
end

-- ============================================================
-- DISPLAY MODE
-- ============================================================
local function runDisplay()
    local mon = peripheral.wrap(MONITOR_SIDE)
    mon.setTextScale(0.5)
    local monW, monH = mon.getSize()
    print("Monitor: " .. monW .. "x" .. monH)

    local startTime    = os.epoch("utc")
    local genHistory   = {}
    local useHistory   = {}
    local histMaxLen   = 60
    local turbinePage  = 0
    local touchButtons = {}
    local latestVersion = nil

    local state = {
        slaves = {},
        config = {mode="SMART", turn_on_percent=30, turn_off_percent=90},
        api_uptime = 0,
        commands_sent = 0,
    }

    local function pushHistory(list, v)
        table.insert(list, v)
        while #list > histMaxLen do table.remove(list, 1) end
    end

    local function average(list, count)
        if #list == 0 then return 0 end
        count = count or #list
        local s1 = math.max(1, #list - count + 1)
        local sum, n = 0, 0
        for i = s1, #list do sum = sum + list[i]; n = n + 1 end
        return sum / math.max(1, n)
    end

    local function fetchState()
        local body = apiGet("/api/state")
        if body and type(body) == "table" then
            state = body
            local bat = nil
            for _, s in pairs(state.slaves) do
                if s.role == "battery" and s.online then bat = s; break end
            end
            if bat and bat.data.lastInput then
                pushHistory(genHistory, bat.data.lastInput / 2.5)
                pushHistory(useHistory, (bat.data.lastOutput or 0) / 2.5)
            end
            return true
        end
        return false
    end

    local function getBattery()
        for _, s in pairs(state.slaves) do
            if s.role == "battery" and s.online then return s end
        end
    end

    local function getByRole(role)
        local t = {}
        for _, s in pairs(state.slaves) do
            if s.role == role then table.insert(t, s) end
        end
        table.sort(t, function(a, b) return a.name < b.name end)
        return t
    end

    local function countOnline()
        local on, off = 0, 0
        for _, s in pairs(state.slaves) do
            if s.online then on = on + 1 else off = off + 1 end
        end
        return on, off
    end

    local function getTotalSteamProd()
        local t = 0
        for _, s in ipairs(getByRole("reactor")) do
            if s.online and s.data.activelyCooled and s.data.steamOutput then
                t = t + s.data.steamOutput
            end
        end
        return t
    end

    local function getTotalSteamCons()
        local t = 0
        for _, s in ipairs(getByRole("turbine")) do
            if s.online and s.data.steamIn then t = t + s.data.steamIn end
        end
        return t
    end

    -- Colour palette
    local C = {
        bg=colors.black, border=colors.gray,
        title=colors.cyan, label=colors.lightGray, value=colors.white,
        barLow=colors.red, barMid=colors.yellow, barHigh=colors.lime, barEmpty=colors.gray,
        reactorOn=colors.lime, reactorOff=colors.red,
        flowIn=colors.lime, flowOut=colors.red, flowZero=colors.lightGray,
        threshold=colors.orange, accent=colors.cyan,
        btn=colors.gray, btnActive=colors.lime, btnEmergency=colors.red,
        warn=colors.orange, crit=colors.red, ok=colors.lime,
        steam=colors.white, stale=colors.gray,
    }

    local function colorForPercent(p)
        if p < 25 then return C.barLow elseif p < 60 then return C.barMid else return C.barHigh end
    end
    local function colorForTemp(t, isActive)
        if t == nil then return C.flowZero end
        if isActive then
            if t > 120000 then return C.crit end
            if t > 100000 then return C.warn end
        else
            if t > 2000 then return C.crit end
            if t > 1500 then return C.warn end
        end
        return C.ok
    end
    local function colorForRpm(rpm, target)
        if rpm == nil or rpm == 0 then return C.flowZero end
        target = target or 1800
        local off = math.abs(rpm - target)
        if off <= 30 then return C.ok elseif off < 200 then return C.warn else return C.crit end
    end
    local function colorForEff(e)
        if e == nil then return C.flowZero end
        if e >= 90 then return C.ok elseif e >= 70 then return C.warn else return C.crit end
    end

    local function mSet(fg, bg)
        if fg then mon.setTextColor(fg) end
        if bg then mon.setBackgroundColor(bg) end
    end
    local function mWrite(x, y, text, fg, bg)
        mon.setCursorPos(x, y); mSet(fg or C.value, bg or C.bg); mon.write(text)
    end
    local function mBar(x, y, w, pct, fc)
        local inner = w - 2; local filled = math.floor((pct/100)*inner)
        mWrite(x, y, "[", C.border); mWrite(x+w-1, y, "]", C.border)
        for i = 0, inner-1 do
            mWrite(x+1+i, y, i < filled and "=" or " ", i < filled and fc or C.barEmpty)
        end
    end
    local function mBtn(label, x1, y1, x2, y2, action, isActive, col)
        col = col or C.btn
        local bgC = isActive and C.btnActive or col
        local fgC = isActive and C.bg or C.value
        for y = y1, y2 do for x = x1, x2 do mWrite(x, y, " ", fgC, bgC) end end
        mWrite(math.floor((x1+x2-#label)/2)+1, math.floor((y1+y2)/2), label, fgC, bgC)
        mSet(C.value, C.bg)
        table.insert(touchButtons, {x1=x1, y1=y1, x2=x2, y2=y2, action=action})
    end
    local function addButton(x1, y1, x2, y2, action)
        table.insert(touchButtons, {x1=x1, y1=y1, x2=x2, y2=y2, action=action})
    end

    local function drawDashboard()
        touchButtons = {}
        mSet(C.value, C.bg)
        mon.clear()
        local w, h = monW, monH
        local cfg = state.config

        mWrite(1, 1, string.rep("=", w), C.accent)
        local title = " NERDTROPY POWER CONTROL "
        mWrite(math.floor((w-#title)/2), 1, title, C.title)
        local modeC = cfg.mode == "SMART" and C.ok or (cfg.mode == "ON" and C.reactorOn or C.reactorOff)
        mWrite(w-14, 1, " Mode: " .. cfg.mode .. " ", modeC)

        local bat    = getBattery()
        local batPct = bat and bat.data.fillPercent or 0
        local batE   = bat and bat.data.energy or 0
        local batMax = bat and bat.data.maxEnergy or 1
        local batIn  = bat and bat.data.lastInput or 0
        local batOut = bat and bat.data.lastOutput or 0
        local net    = (batIn - batOut) / 2.5

        mWrite(2, 3, "BATTERY", C.label)
        mWrite(2, 4, string.format("%.2f%%", batPct), colorForPercent(batPct))
        local cap = formatFE(batE) .. " / " .. formatFE(batMax)
        mWrite(w-#cap-1, 4, cap, C.value)
        mBar(2, 6, w-2, batPct, colorForPercent(batPct))
        local onX  = math.floor(2 + (cfg.turn_on_percent/100)*(w-4))
        local offX = math.floor(2 + (cfg.turn_off_percent/100)*(w-4))
        mWrite(onX, 7, "^", C.threshold); mWrite(offX, 7, "^", C.threshold)
        mWrite(onX-2, 8, cfg.turn_on_percent .. "%", C.threshold)
        mWrite(offX-2, 8, cfg.turn_off_percent .. "%", C.threshold)
        local ft, fc
        if net > 0 then ft = "+" .. formatRawFE(net) .. "/t"; fc = C.flowIn
        elseif net < 0 then ft = formatRawFE(net) .. "/t"; fc = C.flowOut
        else ft = "0 FE/t"; fc = C.flowZero end
        mWrite(2, 9, "Net: " .. ft, fc)

        local c1, c2, c3 = 2, math.floor(w/3)+1, math.floor(2*w/3)+1
        local sY = 11
        for _, box in ipairs({
            {c1, c2-2, " GENERATION "},
            {c2, c3-2, " CONSUMPTION "},
            {c3, w-1,  " PROJECTIONS "},
        }) do
            local bx1, bx2, lbl = box[1], box[2], box[3]
            mWrite(bx1, sY, "+", C.border); mWrite(bx2, sY, "+", C.border)
            mWrite(bx1, sY+7, "+", C.border); mWrite(bx2, sY+7, "+", C.border)
            for x = bx1+1, bx2-1 do
                mWrite(x, sY, "-", C.border); mWrite(x, sY+7, "-", C.border)
            end
            for y = sY+1, sY+6 do mWrite(bx1, y, "|", C.border); mWrite(bx2, y, "|", C.border) end
            mWrite(bx1+2, sY, lbl, C.label)
        end

        local gen1m  = average(genHistory, 60)
        local genNow = #genHistory > 0 and genHistory[#genHistory] or 0
        mWrite(c1+1, sY+2, "Now:  ", C.label)
        mWrite(c1+7, sY+2, "+" .. formatRawFE(genNow) .. "/t", C.flowIn)
        mWrite(c1+1, sY+3, "1min: ", C.label)
        mWrite(c1+7, sY+3, "+" .. formatRawFE(gen1m) .. "/t", C.flowIn)

        local use1m  = average(useHistory, 60)
        local useNow = #useHistory > 0 and useHistory[#useHistory] or 0
        mWrite(c2+1, sY+2, "Now:  ", C.label)
        mWrite(c2+7, sY+2, "-" .. formatRawFE(useNow) .. "/t", C.flowOut)
        mWrite(c2+1, sY+3, "1min: ", C.label)
        mWrite(c2+7, sY+3, "-" .. formatRawFE(use1m) .. "/t", C.flowOut)

        local delta = gen1m - use1m
        local rem   = (batMax - batE) / 2.5
        local ttf   = delta > 0 and rem / delta / 20 or nil
        local tte   = delta < 0 and batE / 2.5 / -delta / 20 or nil
        mWrite(c3+1, sY+2, "To full:  ", C.label)
        mWrite(c3+11, sY+2, formatTime(ttf), C.value)
        mWrite(c3+1, sY+3, "To empty: ", C.label)
        mWrite(c3+11, sY+3, formatTime(tte), C.value)
        mWrite(c3+1, sY+5, "Delta:    ", C.label)
        mWrite(c3+11, sY+5,
               (delta >= 0 and "+" or "") .. formatRawFE(delta) .. "/t",
               delta >= 0 and C.flowIn or C.flowOut)

        -- Reactors
        local rY = sY + 9
        mWrite(2, rY, "+", C.border); mWrite(w-1, rY, "+", C.border)
        mWrite(2, rY+7, "+", C.border); mWrite(w-1, rY+7, "+", C.border)
        for x = 3, w-2 do mWrite(x, rY, "-", C.border); mWrite(x, rY+7, "-", C.border) end
        for y = rY+1, rY+6 do mWrite(2, y, "|", C.border); mWrite(w-1, y, "|", C.border) end
        mWrite(4, rY, " REACTORS ", C.label)
        mWrite(3, rY+1, "Name", C.label);  mWrite(15, rY+1, "Status", C.label)
        mWrite(25, rY+1, "Output", C.label); mWrite(40, rY+1, "Fuel", C.label)
        mWrite(50, rY+1, "Temp", C.label);  mWrite(62, rY+1, "Seen", C.label)
        local rRow = 0
        for _, s in ipairs(getByRole("reactor")) do
            if rRow < 5 then
                local y = rY+2+rRow; local on = s.online
                mWrite(3, y, s.name, on and C.value or C.stale)
                if not on then
                    mWrite(15, y, "OFFLINE", C.stale)
                else
                    mWrite(15, y, s.data.active and "ACTIVE" or "IDLE",
                           s.data.active and C.reactorOn or C.reactorOff)
                end
                if not on then
                    mWrite(25, y, "--", C.stale)
                elseif s.data.activelyCooled then
                    mWrite(25, y, string.format("%.0f mB/t", s.data.steamOutput or 0), C.steam)
                else
                    mWrite(25, y, formatRawFE(s.data.output or 0) .. "/t", C.value)
                end
                if not on or not s.data.fuel then
                    mWrite(40, y, "--", C.stale)
                elseif s.data.fuelMax and s.data.fuelMax > 0 then
                    local fp = (s.data.fuel/s.data.fuelMax)*100
                    mWrite(40, y, string.format("%.0f%%", fp), fp < 20 and C.warn or C.value)
                end
                if not on or not s.data.casingTemp then
                    mWrite(50, y, "--", C.stale)
                else
                    mWrite(50, y, string.format("%.0fC", s.data.casingTemp),
                           colorForTemp(s.data.casingTemp, s.data.activelyCooled))
                end
                local age = math.floor((os.epoch("utc")/1000) - (s.last_seen or 0))
                mWrite(62, y, age .. "s", on and C.label or C.stale)
                rRow = rRow + 1
            end
        end
        if rRow == 0 then mWrite(3, rY+3, "(no reactors)", C.stale) end

        -- Turbines
        local tY = rY + 9
        local allTurbines = getByRole("turbine")
        local tTotal  = #allTurbines
        local tPages  = math.max(1, math.ceil(tTotal/4))
        if turbinePage >= tPages then turbinePage = tPages-1 end
        mWrite(2, tY, "+", C.border); mWrite(w-1, tY, "+", C.border)
        mWrite(2, tY+6, "+", C.border); mWrite(w-1, tY+6, "+", C.border)
        for x = 3, w-2 do mWrite(x, tY, "-", C.border); mWrite(x, tY+6, "-", C.border) end
        for y = tY+1, tY+5 do mWrite(2, y, "|", C.border); mWrite(w-1, y, "|", C.border) end
        mWrite(4, tY, " TURBINES ", C.label)
        if tTotal > 4 then
            local pl = string.format(" %d/%d ", turbinePage+1, tPages)
            local px = w-1-#pl-3
            mWrite(px, tY, pl, C.label)
            mWrite(px-2, tY, "<", turbinePage > 0 and C.value or C.stale)
            addButton(px-2, tY, px-2, tY, "turb_page_prev")
            mWrite(w-2, tY, ">", turbinePage < tPages-1 and C.value or C.stale)
            addButton(w-2, tY, w-2, tY, "turb_page_next")
        end
        mWrite(3, tY+1, "Name", C.label);  mWrite(15, tY+1, "RPM", C.label)
        mWrite(23, tY+1, "Steam", C.label); mWrite(37, tY+1, "Output", C.label)
        mWrite(48, tY+1, "Eff%", C.label); mWrite(54, tY+1, "Ind", C.label)
        mWrite(59, tY+1, "Tgt", C.label)
        local tRow = 0
        local tStart = turbinePage*4+1
        for i = tStart, math.min(tStart+3, tTotal) do
            local s = allTurbines[i]
            local y = tY+2+tRow; local on = s.online
            local tgt = s.target_rpm or 1800
            mWrite(3, y, s.name, on and C.value or C.stale)
            mWrite(15, y, on and string.format("%.0f", s.data.rpm or 0) or "--",
                   on and colorForRpm(s.data.rpm, tgt) or C.stale)
            mWrite(23, y, on and string.format("%.0f/%.0f",
                   s.data.steamIn or 0, s.data.steamMax or 0) or "--",
                   on and C.value or C.stale)
            mWrite(37, y, on and formatRawFE(s.data.output or 0).."/t" or "--",
                   on and C.value or C.stale)
            mWrite(48, y, on and (s.data.bladeEfficiency and
                   string.format("%.0f%%", s.data.bladeEfficiency) or "?") or "--",
                   on and colorForEff(s.data.bladeEfficiency) or C.stale)
            mWrite(54, y, on and (s.data.inductorEngaged and "ON" or "OFF") or "--",
                   on and (s.data.inductorEngaged and C.ok or C.flowZero) or C.stale)
            mWrite(59, y, tostring(tgt), on and colorForRpm(s.data.rpm, tgt) or C.stale)
            tRow = tRow + 1
        end
        if tTotal == 0 then mWrite(3, tY+3, "(no turbines)", C.stale) end

        -- Steam balance
        local stY  = tY + 8
        local prod = getTotalSteamProd()
        local cons = getTotalSteamCons()
        local diff = prod - cons
        mWrite(2, stY, "STEAM:", C.label)
        mWrite(9, stY, string.format("Prod %.0f mB/t", prod), C.steam)
        mWrite(28, stY, string.format("Cons %.0f mB/t", cons), C.steam)
        local ds, dc
        if diff > 0 then
            ds = string.format("+%.0f mB/t (surplus)", diff)
            dc = math.abs(diff) > 200 and C.warn or C.ok
        elseif diff < 0 then
            ds = string.format("%.0f mB/t (deficit)", diff); dc = C.warn
        else
            ds = "0 mB/t (balanced)"; dc = C.ok
        end
        mWrite(47, stY, ds, dc)

        -- Node count
        local nY = stY + 2
        local on2, off2 = countOnline()
        mWrite(2, nY, string.format("Nodes: %d online, %d offline", on2, off2),
               on2 > 0 and C.ok or C.warn)
        mWrite(45, nY, string.format("API up %.0fs", state.api_uptime or 0), C.label)

        -- Controls
        local cY = h-6; local bw = 14
        mBtn(" ON ",    2,      cY, 2+bw,    cY+3, "mode_on",    cfg.mode=="ON")
        mBtn(" OFF ",   4+bw,   cY, 4+2*bw,  cY+3, "mode_off",   cfg.mode=="OFF")
        mBtn(" SMART ", 6+2*bw, cY, 6+3*bw,  cY+3, "mode_smart", cfg.mode=="SMART")
        mWrite(8+3*bw, cY,   "ON Threshold:",  C.label)
        mBtn(" - ", 8+3*bw+14, cY,   8+3*bw+17, cY+1, "on_down")
        mWrite(8+3*bw+19, cY, cfg.turn_on_percent .. "%", C.value)
        mBtn(" + ", 8+3*bw+24, cY,   8+3*bw+27, cY+1, "on_up")
        mWrite(8+3*bw, cY+2, "OFF Threshold:", C.label)
        mBtn(" - ", 8+3*bw+14, cY+2, 8+3*bw+17, cY+3, "off_down")
        mWrite(8+3*bw+19, cY+2, cfg.turn_off_percent .. "%", C.value)
        mBtn(" + ", 8+3*bw+24, cY+2, 8+3*bw+27, cY+3, "off_up")
        mBtn(" EMERGENCY STOP ", w-19, cY, w-2, cY+3, "emergency", false, C.btnEmergency)

        local uptime = (os.epoch("utc") - startTime) / 1000
        local vColor = latestVersion and latestVersion ~= VERSION and C.warn or C.label
        mWrite(2, h, string.format("v%s%s | Up: %s | API cmds: %d | %s",
            VERSION,
            latestVersion and latestVersion ~= VERSION and (" (update " .. latestVersion .. ")") or "",
            formatUptime(uptime), state.commands_sent or 0,
            textutils.formatTime(os.time(), true)), vColor)
    end

    local function handleTouch(x, y)
        for _, b in ipairs(touchButtons) do
            if x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
                local a = b.action
                local cfg = state.config
                if     a == "mode_on"    then apiPost("/api/config", {mode="ON"})
                elseif a == "mode_off"   then apiPost("/api/config", {mode="OFF"})
                elseif a == "mode_smart" then apiPost("/api/config", {mode="SMART"})
                elseif a == "on_up"      then
                    apiPost("/api/config", {turn_on_percent=math.min(95, cfg.turn_on_percent+5)})
                elseif a == "on_down"    then
                    apiPost("/api/config", {turn_on_percent=math.max(5, cfg.turn_on_percent-5)})
                elseif a == "off_up"     then
                    apiPost("/api/config", {turn_off_percent=math.min(99, cfg.turn_off_percent+5)})
                elseif a == "off_down"   then
                    apiPost("/api/config", {
                        turn_off_percent=math.max(cfg.turn_on_percent+10, cfg.turn_off_percent-5)
                    })
                elseif a == "turb_page_prev" then
                    turbinePage = math.max(0, turbinePage-1)
                elseif a == "turb_page_next" then
                    turbinePage = math.min(math.max(1, math.ceil(#getByRole("turbine")/4))-1,
                                           turbinePage+1)
                elseif a == "emergency" then
                    apiPost("/api/emergency", {})
                end
                return
            end
        end
    end

    -- Wait for API
    print("Waiting for API...")
    local ready = false
    while not ready do
        local ok, r = pcall(http.get, API_HOST .. "/api/health")
        if ok and r then r.close(); ready = true
        else print("API not ready, retrying..."); sleep(3) end
    end
    print("API connected. Dashboard running.")

    local function displayLoop()
        while true do
            fetchState()
            drawDashboard()
            sleep(POLL_INTERVAL)
        end
    end

    local function touchLoop()
        while true do
            local _, _, x, y = os.pullEvent("monitor_touch")
            handleTouch(x, y)
            fetchState()
            drawDashboard()
        end
    end

    local function versionCheckLoop()
        while true do
            local ok, r = pcall(http.get, GITEA_RAW .. "/version.txt")
            if ok and r and type(r) == "table" then
                local v = r.readAll():match("^%s*(.-)%s*$")
                r.close()
                latestVersion = v
            end
            sleep(300)  -- check every 5 minutes
        end
    end

    parallel.waitForAny(displayLoop, touchLoop, versionCheckLoop)
end

-- ============================================================
-- BOOT
-- ============================================================
term.clear()
term.setCursorPos(1, 1)
print("=== Nerdtropy Power Control v" .. VERSION .. " ===")
print("API: " .. API_HOST)
print(string.rep("-", 40))

checkUpdate()

-- Detect role from peripherals
local isDisplay = peripheral.isPresent(MONITOR_SIDE)
    and peripheral.getType(MONITOR_SIDE) == "monitor"

if isDisplay then
    print("Role: DISPLAY (monitor on " .. MONITOR_SIDE .. ")")
    print(string.rep("-", 40))
    runDisplay()
else
    print("Role: SLAVE (worker node)")
    print(string.rep("-", 40))
    runSlave()
end
