-- ============================================================
-- POWER NETWORK - MASTER NODE (v2.3)
-- ============================================================
-- Monitor (right): live power dashboard + touch controls
-- Terminal (computer): version status + update controls
--
-- Terminal shows:
--   Master version vs GitHub version
--   Each slave's version + up-to-date status
--   [CHECK FOR UPDATES] polls GitHub
--   [UPDATE ALL NODES]  pushes new code + reboots nodes
--
-- WIRING: Ender Modem LEFT, Advanced Monitor (6x4) RIGHT
-- ============================================================

local VERSION         = "2.5"
local MODEM_SIDE      = "left"
local MONITOR_SIDE    = "right"
local PROTOCOL        = "nerdtropy_power"
local MASTER_HOSTNAME = "power_master"

-- ============================================================
-- GITHUB CONFIG
-- Set these to your repo's raw content URLs
-- ============================================================
local GITHUB_SLAVE_URL   = "https://raw.githubusercontent.com/headpunter/nerdtropy-power-control/main/slave.lua"
local GITHUB_MASTER_URL  = "https://raw.githubusercontent.com/headpunter/nerdtropy-power-control/main/master.lua"
local GITHUB_VERSION_URL = "https://raw.githubusercontent.com/headpunter/nerdtropy-power-control/main/version.txt"
-- version.txt in your repo should contain just a version string matching VERSION above
-- e.g.: 2.3

local TURN_ON_PERCENT  = 30
local TURN_OFF_PERCENT = 90
local POLL_INTERVAL    = 1
local SLAVE_TIMEOUT    = 10
local PING_INTERVAL    = 10
local STATE_DIR        = "/pwr"
local REGISTRY_FILE    = STATE_DIR .. "/registry.dat"
local CONFIG_FILE      = STATE_DIR .. "/config.dat"

-- ============================================================
-- STATE
-- ============================================================
local mon = nil
local monW, monH = 0, 0

local slaves = {}
local nextSerial = {battery=0,reactor=0,turbine=0,energy_detector=0,unknown=0}

local mode = "SMART"
local touchButtons = {}

local historyMaxlen = 60
local genHistory = {}
local useHistory = {}

local startTime    = os.epoch("utc")
local totalGenerated = 0
local totalConsumed  = 0
local commandsSent   = 0

local desiredReactorState = nil
local commandedSlaves = {}
local lastPingTime = 0
local turbinePage = 0

-- Update state (shown in terminal)
local githubVersion   = nil   -- version string from GitHub, nil = not yet checked
local githubChecking  = false
local githubError     = nil
local terminalActive  = false

-- ============================================================
-- PERSISTENCE
-- ============================================================
local function ensureDir()
    if not fs.exists(STATE_DIR) then fs.makeDir(STATE_DIR) end
end

local function loadState()
    ensureDir()
    if fs.exists(REGISTRY_FILE) then
        local h = fs.open(REGISTRY_FILE, "r")
        local ok, data = pcall(textutils.unserialize, h.readAll())
        h.close()
        if ok and type(data) == "table" then
            slaves = data.slaves or {}
            nextSerial = data.nextSerial or nextSerial
            for uuid, s in pairs(slaves) do
                s.lastSeen=0; s.online=false; s.data={}; s._uuid=uuid
            end
        end
    end
    if fs.exists(CONFIG_FILE) then
        local h = fs.open(CONFIG_FILE, "r")
        local ok, data = pcall(textutils.unserialize, h.readAll())
        h.close()
        if ok and type(data) == "table" then
            mode           = data.mode or mode
            TURN_ON_PERCENT  = data.turnOn  or TURN_ON_PERCENT
            TURN_OFF_PERCENT = data.turnOff or TURN_OFF_PERCENT
            totalGenerated = data.totalGenerated or 0
            totalConsumed  = data.totalConsumed  or 0
            commandsSent   = data.commandsSent   or 0
        end
    end
end

local function saveRegistry()
    ensureDir()
    local p = {}
    for uuid, s in pairs(slaves) do
        p[uuid] = {id=s.id,role=s.role,ptype=s.ptype,name=s.name,targetRpm=s.targetRpm}
    end
    local h = fs.open(REGISTRY_FILE, "w")
    h.write(textutils.serialize({slaves=p,nextSerial=nextSerial}))
    h.close()
end

local function saveConfig()
    ensureDir()
    local h = fs.open(CONFIG_FILE, "w")
    h.write(textutils.serialize({
        mode=mode, turnOn=TURN_ON_PERCENT, turnOff=TURN_OFF_PERCENT,
        totalGenerated=totalGenerated, totalConsumed=totalConsumed,
        commandsSent=commandsSent,
    }))
    h.close()
end

-- ============================================================
-- HELPERS
-- ============================================================
local function genUuid()
    return string.format("%08x-%04x", os.epoch("utc")%0xFFFFFFFF, math.random(0,0xFFFF))
end

local function assignName(r)
    nextSerial[r] = (nextSerial[r] or 0) + 1
    local pfx = ({battery="Battery",reactor="Reactor",turbine="Turbine",
                  energy_detector="Sensor",unknown="Node"})[r] or "Node"
    return pfx.."-"..nextSerial[r]
end

local function formatFE(j)
    if j==nil then return "?" end
    local fe=math.abs(j)/2.5
    if fe>=1e12 then return string.format("%.2f TFE",fe/1e12) end
    if fe>=1e9  then return string.format("%.2f GFE",fe/1e9)  end
    if fe>=1e6  then return string.format("%.2f MFE",fe/1e6)  end
    if fe>=1e3  then return string.format("%.2f kFE",fe/1e3)  end
    return string.format("%.0f FE",fe)
end

local function formatRawFE(fe)
    if fe==nil then return "?" end
    fe=math.abs(fe)
    if fe>=1e12 then return string.format("%.2f TFE",fe/1e12) end
    if fe>=1e9  then return string.format("%.2f GFE",fe/1e9)  end
    if fe>=1e6  then return string.format("%.2f MFE",fe/1e6)  end
    if fe>=1e3  then return string.format("%.2f kFE",fe/1e3)  end
    return string.format("%.0f FE",fe)
end

local function formatTime(s)
    if s==nil or s<=0 or s==math.huge then return "--" end
    local d=math.floor(s/86400)
    local h=math.floor((s%86400)/3600)
    local m=math.floor((s%3600)/60)
    if d>0 then return string.format("%dd %02dh",d,h)
    elseif h>0 then return string.format("%dh %02dm",h,m)
    else return string.format("%dm",m) end
end

local function formatUptime(s)
    local d=math.floor(s/86400)
    local h=math.floor((s%86400)/3600)
    local m=math.floor((s%3600)/60)
    if d>0 then return string.format("%dd %02dh %02dm",d,h,m) end
    return string.format("%02dh %02dm",h,m)
end

local function timestamp() return textutils.formatTime(os.time(), true) end

local function pushHistory(list, v)
    table.insert(list, v)
    while #list>historyMaxlen do table.remove(list,1) end
end

local function average(list, count)
    if #list==0 then return 0 end
    count=count or #list
    local s1=math.max(1,#list-count+1)
    local sum,n=0,0
    for i=s1,#list do sum=sum+list[i]; n=n+1 end
    return sum/math.max(1,n)
end

-- ============================================================
-- AGGREGATES
-- ============================================================
local function getBattery()
    for _, s in pairs(slaves) do
        if s.role=="battery" and s.online then return s end
    end
end

local function getReactors()
    local t={}
    for _, s in pairs(slaves) do if s.role=="reactor" then table.insert(t,s) end end
    table.sort(t, function(a,b) return a.name<b.name end)
    return t
end

local function getTurbines()
    local t={}
    for _, s in pairs(slaves) do if s.role=="turbine" then table.insert(t,s) end end
    table.sort(t, function(a,b) return a.name<b.name end)
    return t
end

local function getAllSlaves()
    local t={}
    local batteries,turbines,reactors,others={},{},{},{}
    for uuid,s in pairs(slaves) do
        local entry={uuid=uuid,s=s}
        if     s.role=="battery" then table.insert(batteries,entry)
        elseif s.role=="turbine" then table.insert(turbines, entry)
        elseif s.role=="reactor" then table.insert(reactors, entry)
        else                          table.insert(others,   entry) end
    end
    for _,v in ipairs(batteries) do table.insert(t,v) end
    for _,v in ipairs(others)    do table.insert(t,v) end
    for _,v in ipairs(turbines)  do table.insert(t,v) end
    for _,v in ipairs(reactors)  do table.insert(t,v) end
    return t
end

local function countOnline()
    local on,off=0,0
    for _,s in pairs(slaves) do
        if s.online then on=on+1 else off=off+1 end
    end
    return on,off
end

local function getTotalSteamProd()
    local t=0
    for _,s in pairs(getReactors()) do
        if s.online and s.data.activelyCooled and s.data.steamOutput then
            t=t+s.data.steamOutput
        end
    end
    return t
end

local function getTotalSteamCons()
    local t=0
    for _,s in pairs(getTurbines()) do
        if s.online and s.data.steamIn then t=t+s.data.steamIn end
    end
    return t
end

-- ============================================================
-- CONTROL
-- ============================================================
local function commandSlave(uuid, action, params)
    local s=slaves[uuid]
    if not s or not s.id then return end
    rednet.send(s.id,{type="COMMAND",action=action,params=params or {}},PROTOCOL)
    commandsSent=commandsSent+1
end

local function pingSlaves()
    for _,s in pairs(slaves) do
        if s.online and s.id then
            rednet.send(s.id,{type="PING"},PROTOCOL)
        end
    end
end

local function applyMode()
    local battery=getBattery()
    if not battery or not battery.data.fillPercent then return end
    local pct=battery.data.fillPercent
    local newDesired=desiredReactorState

    if     mode=="ON"    then newDesired=true
    elseif mode=="OFF"   then newDesired=false
    elseif mode=="SMART" then
        if     desiredReactorState==nil  then newDesired=pct<TURN_ON_PERCENT and true or false
        elseif pct<TURN_ON_PERCENT       then newDesired=true
        elseif pct>TURN_OFF_PERCENT      then newDesired=false end
    end

    if newDesired~=desiredReactorState then
        desiredReactorState=newDesired; commandedSlaves={}
    end
    if desiredReactorState==nil then return end

    for uuid,s in pairs(slaves) do
        if s.online and not commandedSlaves[uuid] then
            if s.role=="reactor" then
                commandSlave(uuid,"set_reactor",{state=desiredReactorState})
                commandedSlaves[uuid]=true
            elseif s.role=="turbine" then
                -- inductor param intentionally omitted: coils stay engaged on shutdown
                -- for residual spin-down harvest; applyTurbineInductors handles coil state
                commandSlave(uuid,"set_turbine",{state=desiredReactorState})
                commandedSlaves[uuid]=true
            end
        end
    end
end

local function applyTurbineControl()
    for uuid,s in pairs(slaves) do
        if s.role=="turbine" and s.online and s.data then
            local rpm     = s.data.rpm or 0
            local engaged = s.data.inductorEngaged
            local tgt     = s.targetRpm or 1800

            -- inductor lifecycle
            if rpm >= tgt and engaged == false then
                commandSlave(uuid,"set_inductor",{state=true})
            elseif rpm < 50 and engaged == true then
                commandSlave(uuid,"set_inductor",{state=false})
            end

            -- flow rate tuning: step toward target RPM (dead band ±30 RPM)
            if s.data.active and s.data.assembled then
                local current = s.data.steamIn or 0
                local maxFlow = s.data.steamMaxMax or 0
                local err = tgt - rpm
                if math.abs(err) > 30 then
                    local step = math.min(50, math.max(1, math.abs(err) * 0.15))
                    local newRate = current + (err > 0 and step or -step)
                    newRate = math.max(0, math.min(maxFlow, newRate))
                    if math.abs(newRate - current) >= 1 then
                        commandSlave(uuid,"set_flow_rate",{rate=math.floor(newRate)})
                    end
                end
            end
        end
    end
end

-- ============================================================
-- GITHUB UPDATE
-- ============================================================
local function githubConfigured()
    return not GITHUB_SLAVE_URL:find("YOUR_USERNAME")
end

local function fetchGitHub(url)
    if not http then return nil, "HTTP not available" end
    local ok, result = pcall(http.get, url)
    if not ok or not result then return nil, "Request failed" end
    local content = result.readAll()
    result.close()
    return content, nil
end

local function checkForUpdates()
    if not githubConfigured() then
        githubError = "GitHub URLs not configured in master.lua"
        return
    end
    githubChecking = true
    githubError = nil
    -- Redraw terminal to show "Checking..."
    local content, err = fetchGitHub(GITHUB_VERSION_URL)
    githubChecking = false
    if not content then
        githubError = "Check failed: " .. tostring(err)
    else
        githubVersion = content:match("^%s*(.-)%s*$")  -- trim whitespace
    end
end

local function slaveNeedsUpdate(s)
    if not githubVersion then return false end
    return (s.slaveVersion or "?") ~= githubVersion
end

local function masterNeedsUpdate()
    if not githubVersion then return false end
    return VERSION ~= githubVersion
end

local function updateAllNodes()
    if not githubConfigured() then return end

    -- Fetch slave script
    local slaveContent, err = fetchGitHub(GITHUB_SLAVE_URL)
    if not slaveContent then
        return "Failed to fetch slave.lua: "..tostring(err)
    end
    -- Validate slave syntax
    local fn, syntaxErr = load(slaveContent)
    if not fn then
        return "slave.lua syntax error: "..tostring(syntaxErr)
    end

    -- Push to all online slaves that need updating
    local updated, failed = 0, 0
    for _, entry in ipairs(getAllSlaves()) do
        local s = entry.s
        if s.online and slaveNeedsUpdate(s) then
            rednet.send(s.id, {
                type="UPDATE", content=slaveContent
            }, PROTOCOL)
            updated = updated + 1
        end
    end

    -- Update master if needed
    local masterUpdated = false
    if masterNeedsUpdate() then
        local masterContent, merr = fetchGitHub(GITHUB_MASTER_URL)
        if masterContent then
            local mfn, mErr = load(masterContent)
            if mfn then
                local h = fs.open("startup", "w")
                h.write(masterContent)
                h.close()
                masterUpdated = true
            end
        end
    end

    return nil, updated, failed, masterUpdated
end

-- ============================================================
-- TERMINAL DISPLAY
-- ============================================================
local termColors = {
    ok      = colors.lime,
    warn    = colors.yellow,
    crit    = colors.red,
    info    = colors.lightBlue,
    label   = colors.lightGray,
    value   = colors.white,
    header  = colors.cyan,
    bg      = colors.black,
}

local function tc(color)
    if term.isColor() then term.setTextColor(color) end
end

local function drawTerminal()
    term.clear()
    term.setCursorPos(1, 1)

    tc(termColors.header)
    print("=== NERDTROPY POWER CONTROL v"..VERSION.." ===")
    tc(termColors.label)
    local on, off = countOnline()
    print(string.format("%d online, %d offline | %s", on, off, timestamp()))
    print(string.rep("-", 50))

    -- Master version row
    tc(termColors.label)
    io.write(string.format("%-8s", "Master:"))
    tc(termColors.value)
    io.write(string.format("v%-6s  ", VERSION))

    if not githubConfigured() then
        tc(termColors.warn)
        io.write("[GitHub not configured]")
    elseif githubChecking then
        tc(termColors.info)
        io.write("[Checking GitHub...]")
    elseif githubError then
        tc(termColors.crit)
        io.write("["..githubError.."]")
    elseif not githubVersion then
        tc(termColors.label)
        io.write("[Not checked yet]")
    elseif masterNeedsUpdate() then
        tc(termColors.warn)
        io.write("[UPDATE AVAILABLE -> v"..githubVersion.."]")
    else
        tc(termColors.ok)
        io.write("[UP TO DATE]")
    end
    print()

    print(string.rep("-", 50))
    tc(termColors.label)
    print("SLAVES:")

    for _, entry in ipairs(getAllSlaves()) do
        local s = entry.s
        local ver = s.slaveVersion or "?"
        tc(termColors.label)
        io.write(string.format("  %-15s v%-6s  ", s.name, ver))

        if not s.online then
            tc(termColors.crit)
            io.write("[OFFLINE]")
        elseif not githubVersion then
            tc(termColors.label)
            io.write("[Not checked]")
        elseif slaveNeedsUpdate(s) then
            tc(termColors.warn)
            io.write("[UPDATE AVAILABLE -> v"..githubVersion.."]")
        else
            tc(termColors.ok)
            io.write("[UP TO DATE]")
        end
        print()
    end

    local anySlaveOutdated = false
    for _, s in pairs(slaves) do
        if s.online and slaveNeedsUpdate(s) then anySlaveOutdated=true; break end
    end

    print(string.rep("-", 50))
    print()

    -- Buttons row
    tc(termColors.info)
    io.write("[C] Check for updates   ")
    if githubVersion and (masterNeedsUpdate() or anySlaveOutdated) then
        tc(termColors.warn)
        io.write("[U] Update all nodes")
    end
    print()
    print()
    tc(termColors.label)
    print("[Q] Exit to dashboard mode")
    tc(termColors.value)
end

local function runTerminal()
    terminalActive = true

    while true do
        drawTerminal()
        io.write("\n> ")

        local _, key = os.pullEvent("char")

        if key=="c" or key=="C" then
            tc(termColors.info)
            print("\nChecking GitHub...")
            checkForUpdates()

        elseif key=="u" or key=="U" then
            local anyOutdated = masterNeedsUpdate()
            if not anyOutdated then
                for _, s in pairs(slaves) do
                    if s.online and slaveNeedsUpdate(s) then anyOutdated=true; break end
                end
            end

            if not githubVersion then
                print("\nCheck for updates first (press C).")
                sleep(1.5)
            elseif not anyOutdated then
                tc(termColors.ok)
                print("\nAll nodes are already up to date!")
                sleep(1.5)
            else
                tc(termColors.info)
                print("\nPushing updates...")
                local err, updated, failed, masterUpdated = updateAllNodes()
                if err then
                    tc(termColors.crit)
                    print("ERROR: "..err)
                    sleep(3)
                else
                    tc(termColors.ok)
                    print(string.format("Pushed to %d slave(s).", updated))
                    if masterUpdated then
                        tc(termColors.warn)
                        print("Master updated. Rebooting in 2s...")
                        sleep(2)
                        os.reboot()
                    else
                        print("Slaves rebooting. They will re-register shortly.")
                        sleep(2)
                    end
                end
            end

        elseif key=="q" or key=="Q" then
            break
        end
    end

    terminalActive = false
    -- Restore terminal to idle state
    term.clear()
    term.setCursorPos(1,1)
    tc(termColors.header)
    print("=== Nerdtropy Power Control ===")
    tc(termColors.label)
    print("Dashboard on monitor | Press any key for admin")
end

-- ============================================================
-- WARNINGS
-- ============================================================
local function generateWarnings()
    local w={}
    local bat=getBattery()
    if bat and bat.data.fillPercent and bat.data.fillPercent<10 then
        table.insert(w,{level="crit",msg=string.format("Battery critical: %.1f%%",bat.data.fillPercent)})
    end
    for _,r in pairs(getReactors()) do
        if not r.online then
            table.insert(w,{level="warn",msg=r.name.." OFFLINE"})
        else
            if r.data.casingTemp then
                local ct=r.data.activelyCooled and 120000 or 2000
                if r.data.casingTemp>ct then
                    table.insert(w,{level="crit",msg=r.name.." overheating: "..math.floor(r.data.casingTemp).."C"})
                end
            end
            if r.data.fuel and r.data.fuelMax and r.data.fuelMax>0 then
                local fp=(r.data.fuel/r.data.fuelMax)*100
                if fp<20 then table.insert(w,{level="warn",msg=string.format("%s fuel low: %.0f%%",r.name,fp)}) end
            end
            if desiredReactorState~=nil and r.data.active~=nil and commandedSlaves[r._uuid] then
                if r.data.active~=desiredReactorState then
                    table.insert(w,{level="warn",msg=r.name.." drift: cmd "..(desiredReactorState and "ON" or "OFF").." but "..(r.data.active and "ON" or "OFF")})
                end
            end
        end
    end
    for _,t in pairs(getTurbines()) do
        if not t.online then table.insert(w,{level="warn",msg=t.name.." OFFLINE"})
        elseif t.data.active and t.data.inductorEngaged==false then
            table.insert(w,{level="warn",msg=t.name.." inductor off"})
        end
    end
    local prod=getTotalSteamProd(); local cons=getTotalSteamCons()
    if prod>0 and cons>0 then
        local diff=prod-cons
        if math.abs(diff)>prod*0.15 and math.abs(diff)>100 then
            table.insert(w,{level="info",msg=string.format("Steam %s%+.0f mB/t",diff>0 and "surplus " or "deficit ",diff)})
        end
    end
    return w
end

-- ============================================================
-- MONITOR DRAWING
-- ============================================================
local C={
    bg=colors.black,border=colors.gray,
    title=colors.cyan,label=colors.lightGray,value=colors.white,
    barLow=colors.red,barMid=colors.yellow,barHigh=colors.lime,barEmpty=colors.gray,
    reactorOn=colors.lime,reactorOff=colors.red,
    flowIn=colors.lime,flowOut=colors.red,flowZero=colors.lightGray,
    threshold=colors.orange,accent=colors.cyan,
    btn=colors.gray,btnActive=colors.lime,btnEmergency=colors.red,
    warn=colors.orange,crit=colors.red,ok=colors.lime,info=colors.lightBlue,
    steam=colors.white,stale=colors.gray,
}

local function colorForPercent(p)
    if p<25 then return C.barLow elseif p<60 then return C.barMid else return C.barHigh end
end
local function colorForTemp(t,isActive)
    if t==nil then return C.flowZero end
    if isActive then
        if t>120000 then return C.crit end
        if t>100000 then return C.warn end
        return C.ok
    else
        if t>2000 then return C.crit end
        if t>1500 then return C.warn end
        return C.ok
    end
end
local function colorForRpm(rpm, target)
    if rpm==nil or rpm==0 then return C.flowZero end
    target = target or 1800
    local off=math.abs(rpm-target)
    if off<=30 then return C.ok elseif off<200 then return C.warn else return C.crit end
end
local function colorForEff(e)
    if e==nil then return C.flowZero end
    if e>=90 then return C.ok elseif e>=70 then return C.warn else return C.crit end
end

local function mSet(fg,bg)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) end
end
local function mWrite(x,y,text,fg,bg)
    mon.setCursorPos(x,y); mSet(fg or C.value,bg or C.bg); mon.write(text)
end
local function mBox(x1,y1,x2,y2,col)
    col=col or C.border
    for x=x1,x2 do mWrite(x,y1,"-",col); mWrite(x,y2,"-",col) end
    for y=y1+1,y2-1 do mWrite(x1,y,"|",col); mWrite(x2,y,"|",col) end
    mWrite(x1,y1,"+",col); mWrite(x2,y1,"+",col)
    mWrite(x1,y2,"+",col); mWrite(x2,y2,"+",col)
end
local function mBar(x,y,w,pct,fc)
    local inner=w-2; local filled=math.floor((pct/100)*inner)
    mWrite(x,y,"[",C.border); mWrite(x+w-1,y,"]",C.border)
    for i=0,inner-1 do mWrite(x+1+i,y,i<filled and "=" or " ",i<filled and fc or C.barEmpty) end
end
local function mBtn(label,x1,y1,x2,y2,action,isActive,col)
    col=col or C.btn
    local bgC=isActive and C.btnActive or col
    local fgC=isActive and C.bg or C.value
    for y=y1,y2 do for x=x1,x2 do mWrite(x,y," ",fgC,bgC) end end
    mWrite(math.floor((x1+x2-#label)/2)+1,math.floor((y1+y2)/2),label,fgC,bgC)
    mSet(C.value,C.bg)
    table.insert(touchButtons,{x1=x1,y1=y1,x2=x2,y2=y2,action=action})
end
local function addButton(x1,y1,x2,y2,action)
    table.insert(touchButtons,{x1=x1,y1=y1,x2=x2,y2=y2,action=action})
end

local function drawDashboard()
    if terminalActive then return end
    touchButtons={}
    mSet(C.value,C.bg)
    mon.clear()
    local w,h=monW,monH

    mWrite(1,1,string.rep("=",w),C.accent)
    local title=" NERDTROPY POWER CONTROL "
    mWrite(math.floor((w-#title)/2),1,title,C.title)
    local modeC=mode=="SMART" and C.ok or (mode=="ON" and C.reactorOn or C.reactorOff)
    mWrite(w-14,1," Mode: "..mode.." ",modeC)

    local bat=getBattery()
    local batPct=bat and bat.data.fillPercent or 0
    local batE=bat and bat.data.energy or 0
    local batMax=bat and bat.data.maxEnergy or 1
    local batIn=bat and bat.data.lastInput or 0
    local batOut=bat and bat.data.lastOutput or 0
    local net=batIn-batOut

    mWrite(2,3,"BATTERY",C.label)
    mWrite(2,4,string.format("%.2f%%",batPct),colorForPercent(batPct))
    local cap=formatFE(batE).." / "..formatFE(batMax)
    mWrite(w-#cap-1,4,cap,C.value)
    mBar(2,6,w-2,batPct,colorForPercent(batPct))
    local onX=math.floor(2+(TURN_ON_PERCENT/100)*(w-4))
    local offX=math.floor(2+(TURN_OFF_PERCENT/100)*(w-4))
    mWrite(onX,7,"^",C.threshold); mWrite(offX,7,"^",C.threshold)
    mWrite(onX-2,8,TURN_ON_PERCENT.."%",C.threshold)
    mWrite(offX-2,8,TURN_OFF_PERCENT.."%",C.threshold)
    local ft,fc
    if net>0 then ft="+"..formatFE(net).."/t";fc=C.flowIn
    elseif net<0 then ft="-"..formatFE(net).."/t";fc=C.flowOut
    else ft="0 FE/t";fc=C.flowZero end
    mWrite(2,9,"Net: "..ft,fc)

    local c1,c2,c3=2,math.floor(w/3)+1,math.floor(2*w/3)+1
    local sY=11
    mBox(c1,sY,c2-2,sY+7,C.border)
    mBox(c2,sY,c3-2,sY+7,C.border)
    mBox(c3,sY,w-1,sY+7,C.border)
    mWrite(c1+2,sY," GENERATION ",C.label)
    mWrite(c2+2,sY," CONSUMPTION ",C.label)
    mWrite(c3+2,sY," PROJECTIONS ",C.label)

    local gen1m=average(genHistory,60)
    local genNow=#genHistory>0 and genHistory[#genHistory] or 0
    mWrite(c1+1,sY+2,"Now:  ",C.label); mWrite(c1+7,sY+2,"+"..formatFE(genNow).."/t",C.flowIn)
    mWrite(c1+1,sY+3,"1min: ",C.label); mWrite(c1+7,sY+3,"+"..formatFE(gen1m).."/t",C.flowIn)

    local use1m=average(useHistory,60)
    local useNow=#useHistory>0 and useHistory[#useHistory] or 0
    mWrite(c2+1,sY+2,"Now:  ",C.label); mWrite(c2+7,sY+2,"-"..formatFE(useNow).."/t",C.flowOut)
    mWrite(c2+1,sY+3,"1min: ",C.label); mWrite(c2+7,sY+3,"-"..formatFE(use1m).."/t",C.flowOut)

    local delta=gen1m-use1m
    local rem=batMax-batE
    local ttf,tte
    if delta>0 then ttf=rem/delta/20 end
    if delta<0 then tte=batE/-delta/20 end
    mWrite(c3+1,sY+2,"To full:  ",C.label); mWrite(c3+11,sY+2,formatTime(ttf),C.value)
    mWrite(c3+1,sY+3,"To empty: ",C.label); mWrite(c3+11,sY+3,formatTime(tte),C.value)
    mWrite(c3+1,sY+5,"Delta:    ",C.label)
    mWrite(c3+11,sY+5,(delta>=0 and "+" or "-")..formatFE(delta).."/t",delta>=0 and C.flowIn or C.flowOut)

    local rY=sY+9
    mBox(2,rY,w-1,rY+7,C.border)
    mWrite(4,rY," REACTORS ",C.label)
    mWrite(3,rY+1,"Name",C.label); mWrite(15,rY+1,"Status",C.label)
    mWrite(25,rY+1,"Output",C.label); mWrite(40,rY+1,"Fuel",C.label)
    mWrite(50,rY+1,"Temp",C.label); mWrite(62,rY+1,"Last",C.label)
    local rRow=0
    for _,s in ipairs(getReactors()) do
        if rRow<5 then
            local y=rY+2+rRow; local on=s.online
            mWrite(3,y,s.name,on and C.value or C.stale)
            if not on then mWrite(15,y,"OFFLINE",C.flowZero)
            else mWrite(15,y,s.data.active and "ACTIVE" or "IDLE",s.data.active and C.reactorOn or C.reactorOff) end
            if not on then mWrite(25,y,"--",C.stale)
            elseif s.data.activelyCooled then mWrite(25,y,string.format("%.0f mB/t",s.data.steamOutput or 0),C.steam)
            else mWrite(25,y,formatRawFE(s.data.output or 0).."/t",C.value) end
            if not on or not s.data.fuel then mWrite(40,y,"--",C.stale)
            elseif s.data.fuelMax and s.data.fuelMax>0 then
                local fp=(s.data.fuel/s.data.fuelMax)*100
                mWrite(40,y,string.format("%.0f%%",fp),fp<20 and C.warn or C.value) end
            if not on or not s.data.casingTemp then mWrite(50,y,"--",C.stale)
            else mWrite(50,y,string.format("%.0fC",s.data.casingTemp),colorForTemp(s.data.casingTemp,s.data.activelyCooled)) end
            mWrite(62,y,math.floor((os.epoch("utc")-s.lastSeen)/1000).."s",on and C.label or C.stale)
            rRow=rRow+1
        end
    end
    if rRow==0 then mWrite(3,rY+3,"(no reactors connected)",C.flowZero) end

    local tY=rY+9
    local allTurbines=getTurbines()
    local tTotal=#allTurbines
    local tPages=math.max(1,math.ceil(tTotal/4))
    if turbinePage>=tPages then turbinePage=tPages-1 end
    mBox(2,tY,w-1,tY+6,C.border)
    mWrite(4,tY," TURBINES ",C.label)
    if tTotal>4 then
        local pageLabel=string.format(" %d/%d ",turbinePage+1,tPages)
        local px=w-1-#pageLabel-3
        mWrite(px,tY,pageLabel,C.label)
        addButton(px-2,tY,px-2,tY,"turb_page_prev","<")
        mWrite(px-2,tY,"<",turbinePage>0 and C.value or C.stale)
        addButton(w-2,tY,w-2,tY,"turb_page_next",">")
        mWrite(w-2,tY,">",turbinePage<tPages-1 and C.value or C.stale)
    end
    mWrite(3,tY+1,"Name",C.label); mWrite(15,tY+1,"RPM",C.label)
    mWrite(23,tY+1,"Steam",C.label); mWrite(37,tY+1,"Output",C.label)
    mWrite(48,tY+1,"Eff%",C.label); mWrite(54,tY+1,"Ind",C.label)
    mWrite(59,tY+1,"Tgt",C.label)
    local tRow=0
    local tStart=turbinePage*4+1
    for i=tStart, math.min(tStart+3, tTotal) do
        local s=allTurbines[i]
        local y=tY+2+tRow; local on=s.online
        local tgt=s.targetRpm or 1800
        mWrite(3,y,s.name,on and C.value or C.stale)
        mWrite(15,y,on and string.format("%.0f",s.data.rpm or 0) or "--",on and colorForRpm(s.data.rpm,tgt) or C.stale)
        mWrite(23,y,on and string.format("%.0f/%.0f",s.data.steamIn or 0,s.data.steamMax or 0) or "--",on and C.value or C.stale)
        mWrite(37,y,on and formatRawFE(s.data.output or 0).."/t" or "--",on and C.value or C.stale)
        mWrite(48,y,on and (s.data.bladeEfficiency and string.format("%.0f%%",s.data.bladeEfficiency) or "?") or "--",on and colorForEff(s.data.bladeEfficiency) or C.stale)
        mWrite(54,y,on and (s.data.inductorEngaged and "ON" or "OFF") or "--",on and (s.data.inductorEngaged and C.ok or C.flowZero) or C.stale)
        local tgtLabel=tostring(tgt)
        local tgtColor=on and colorForRpm(s.data.rpm,tgt) or C.stale
        mWrite(59,y,tgtLabel,tgtColor)
        addButton(59,y,59+#tgtLabel-1,y,"turb_tgt_"..s._uuid)
        tRow=tRow+1
    end
    if tTotal==0 then mWrite(3,tY+3,"(no turbines connected)",C.flowZero) end

    local stY=tY+8
    local prod=getTotalSteamProd(); local cons2=getTotalSteamCons(); local diff=prod-cons2
    mWrite(2,stY,"STEAM:",C.label)
    mWrite(9,stY,string.format("Prod %.0f mB/t",prod),C.steam)
    mWrite(28,stY,string.format("Cons %.0f mB/t",cons2),C.steam)
    local ds,dc
    if diff>0 then ds=string.format("+%.0f mB/t (surplus)",diff); dc=math.abs(diff)>200 and C.warn or C.ok
    elseif diff<0 then ds=string.format("%.0f mB/t (deficit)",diff); dc=C.warn
    else ds="0 mB/t (balanced)"; dc=C.ok end
    mWrite(47,stY,ds,dc)

    local nY=stY+2
    local on2,off2=countOnline()
    mWrite(2,nY,string.format("Nodes: %d online, %d offline",on2,off2),on2>0 and C.ok or C.warn)

    local warnings=generateWarnings()
    if #warnings==0 then mWrite(45,nY,"All systems nominal",C.ok)
    else
        for i=1,math.min(3,#warnings) do
            local wn=warnings[i]
            mWrite(45,nY+(i-1),wn.msg,wn.level=="crit" and C.crit or (wn.level=="warn" and C.warn or C.info))
        end
    end

    local cY=h-6; local bw=14
    mBtn(" ON ",    2,      cY,2+bw,   cY+3,"mode_on",    mode=="ON")
    mBtn(" OFF ",   4+bw,   cY,4+2*bw, cY+3,"mode_off",   mode=="OFF")
    mBtn(" SMART ", 6+2*bw, cY,6+3*bw, cY+3,"mode_smart", mode=="SMART")
    mWrite(8+3*bw,cY,"ON Threshold:",C.label)
    mBtn(" - ",8+3*bw+14,cY,  8+3*bw+17,cY+1,"on_down")
    mWrite(8+3*bw+19,cY,TURN_ON_PERCENT.."%",C.value)
    mBtn(" + ",8+3*bw+24,cY,  8+3*bw+27,cY+1,"on_up")
    mWrite(8+3*bw,cY+2,"OFF Threshold:",C.label)
    mBtn(" - ",8+3*bw+14,cY+2,8+3*bw+17,cY+3,"off_down")
    mWrite(8+3*bw+19,cY+2,TURN_OFF_PERCENT.."%",C.value)
    mBtn(" + ",8+3*bw+24,cY+2,8+3*bw+27,cY+3,"off_up")
    mBtn(" EMERGENCY STOP ",w-19,cY,w-2,cY+3,"emergency",false,C.btnEmergency)

    local uptime=(os.epoch("utc")-startTime)/1000
    mWrite(2,h,string.format("Master v%s | Uptime: %s | Cmds: %d | %s",
        VERSION,formatUptime(uptime),commandsSent,timestamp()),C.label)
end

-- ============================================================
-- TOUCH
-- ============================================================
local function handleTouch(x,y)
    for _,b in ipairs(touchButtons) do
        if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then
            local a=b.action
            if     a=="mode_on"    then mode="ON";    desiredReactorState=nil; commandedSlaves={}
            elseif a=="mode_off"   then mode="OFF";   desiredReactorState=nil; commandedSlaves={}
            elseif a=="mode_smart" then mode="SMART"; desiredReactorState=nil; commandedSlaves={}
            elseif a=="on_up"      then TURN_ON_PERCENT=math.min(95,TURN_ON_PERCENT+5)
            elseif a=="on_down"    then TURN_ON_PERCENT=math.max(5,TURN_ON_PERCENT-5)
            elseif a=="off_up"     then TURN_OFF_PERCENT=math.min(99,TURN_OFF_PERCENT+5)
            elseif a=="off_down"   then TURN_OFF_PERCENT=math.max(TURN_ON_PERCENT+10,TURN_OFF_PERCENT-5)
            elseif a=="turb_page_prev" then
                turbinePage=math.max(0,turbinePage-1)
            elseif a=="turb_page_next" then
                local tPages=math.max(1,math.ceil(#getTurbines()/4))
                turbinePage=math.min(tPages-1,turbinePage+1)
            elseif a:sub(1,9)=="turb_tgt_" then
                local uuid=a:sub(10)
                if slaves[uuid] then
                    local s=slaves[uuid]
                    s.targetRpm = (s.targetRpm==1800) and 900 or 1800
                    saveRegistry()
                end
            elseif a=="emergency"  then
                mode="OFF"; desiredReactorState=false; commandedSlaves={}
                for uuid,s in pairs(slaves) do
                    if s.role=="reactor" or s.role=="turbine" then
                        commandSlave(uuid,"scram",{})
                        commandedSlaves[uuid]=true
                    end
                end
            end
            saveConfig()
            return
        end
    end
end

-- ============================================================
-- MESSAGES
-- ============================================================
local function handleHello(senderId, msg)
    local foundUuid=nil
    if msg.uuid and slaves[msg.uuid] then foundUuid=msg.uuid
    else
        for uuid,s in pairs(slaves) do
            if s.id==senderId then foundUuid=uuid; break end
        end
    end
    if foundUuid then
        local s=slaves[foundUuid]
        s.id=senderId; s.online=true; s.lastSeen=os.epoch("utc")
        s._uuid=foundUuid; s.slaveVersion=msg.version
        rednet.send(senderId,{type="WELCOME",uuid=foundUuid,name=s.name},PROTOCOL)
        if s.role=="reactor" then commandedSlaves[foundUuid]=nil end
        return
    end
    local newUuid=genUuid()
    local newName=assignName(msg.role or "unknown")
    slaves[newUuid]={id=senderId,role=msg.role,ptype=msg.ptype,name=newName,
        lastSeen=os.epoch("utc"),online=true,data={},_uuid=newUuid,slaveVersion=msg.version,
        targetRpm=(msg.role=="turbine" and 1800 or nil)}
    saveRegistry()
    rednet.send(senderId,{type="WELCOME",uuid=newUuid,name=newName},PROTOCOL)
end

local function handleReport(senderId, msg)
    if not msg.uuid or not slaves[msg.uuid] then return end
    local s=slaves[msg.uuid]
    s.id=senderId; s.online=true; s.lastSeen=os.epoch("utc")
    s.data=msg.data or {}; s._uuid=msg.uuid
    if msg.data and msg.data.version then s.slaveVersion=msg.data.version end
    if s.role=="battery" and s.data.lastInput then
        pushHistory(genHistory,s.data.lastInput)
        pushHistory(useHistory,s.data.lastOutput or 0)
        totalGenerated=totalGenerated+(s.data.lastInput or 0)/20
        totalConsumed =totalConsumed +(s.data.lastOutput or 0)/20
    end
end

local function refreshOnline()
    local now=os.epoch("utc")
    for _,s in pairs(slaves) do s.online=((now-s.lastSeen)/1000)<SLAVE_TIMEOUT end
end

-- ============================================================
-- STARTUP
-- ============================================================
term.clear()
term.setCursorPos(1,1)
tc(termColors.header)
print("=== Nerdtropy Power Control v"..VERSION.." ===")
tc(termColors.label)
print(string.rep("-",40))

if not peripheral.isPresent(MODEM_SIDE) or peripheral.getType(MODEM_SIDE)~="modem" then
    print("ERROR: No modem on "..MODEM_SIDE); return
end
if not peripheral.isPresent(MONITOR_SIDE) or peripheral.getType(MONITOR_SIDE)~="monitor" then
    print("ERROR: No monitor on "..MONITOR_SIDE); return
end

mon=peripheral.wrap(MONITOR_SIDE)
mon.setTextScale(0.5)
monW,monH=mon.getSize()
print("Monitor: "..monW.."x"..monH)

rednet.open(MODEM_SIDE)
rednet.host(PROTOCOL,MASTER_HOSTNAME)
print("Network ready")

loadState()
local n=0; for _ in pairs(slaves) do n=n+1 end
print("Loaded "..n.." slaves")

if not http then
    print("NOTE: HTTP not available - GitHub updates disabled")
elseif not githubConfigured() then
    print("NOTE: Set GITHUB_*_URL in master.lua to enable updates")
end

math.randomseed(os.epoch("utc"))
print(string.rep("-",40))
tc(termColors.value)
print("Dashboard running on monitor.")
print("Press any key to open update console.")
print()

-- ============================================================
-- PARALLEL LOOPS
-- ============================================================
local function rednetListener()
    while true do
        local sender,msg=rednet.receive(PROTOCOL)
        if type(msg)=="table" then
            if     msg.type=="HELLO"  then handleHello(sender,msg)
            elseif msg.type=="REPORT" then handleReport(sender,msg)
            elseif msg.type=="PONG"   then
                if msg.uuid and slaves[msg.uuid] then
                    slaves[msg.uuid].lastSeen=os.epoch("utc")
                    slaves[msg.uuid].online=true
                    if msg.version then slaves[msg.uuid].slaveVersion=msg.version end
                end
            end
        end
    end
end

local function controlLoop()
    while true do
        refreshOnline()
        applyMode()
        applyTurbineControl()
        drawDashboard()
        saveConfig()
        local now=os.epoch("utc")
        if (now-lastPingTime)/1000>=PING_INTERVAL then
            pingSlaves(); lastPingTime=now
        end
        sleep(POLL_INTERVAL)
    end
end

local function touchLoop()
    while true do
        local _,_,x,y=os.pullEvent("monitor_touch")
        handleTouch(x,y); drawDashboard()
    end
end

local function terminalLoop()
    while true do
        os.pullEvent("key")
        runTerminal()
    end
end

parallel.waitForAny(rednetListener,controlLoop,touchLoop,terminalLoop)
