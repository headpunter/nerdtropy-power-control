-- periph_test.lua — peripheral inspector & method tester
-- wget http://10.10.0.10:30008/headpunter/nerdtropy-minecraft-project/raw/branch/main/periph_test.lua periph_test.lua
-- Usage: lua periph_test.lua  (or just run it)

local function center(str, w)
    local pad = math.max(0, math.floor((w - #str) / 2))
    return string.rep(" ", pad) .. str
end

local function hr(w) print(string.rep("-", w or 60)) end

-- ── Find all peripherals ───────────────────────────────────────
local sides = {"top","bottom","left","right","front","back"}
local found = {}
for _, side in ipairs(sides) do
    local t = peripheral.getType(side)
    if t then
        table.insert(found, {side=side, ptype=t, p=peripheral.wrap(side)})
    end
end

if #found == 0 then
    print("No peripherals found on any side.")
    return
end

-- ── Pick peripheral ────────────────────────────────────────────
local target
if #found == 1 then
    target = found[1]
    print("Using " .. target.ptype .. " on " .. target.side)
else
    hr()
    print("Found peripherals:")
    for i, f in ipairs(found) do
        print(string.format("  [%d] %s  (%s)", i, f.ptype, f.side))
    end
    hr()
    io.write("Select [1-" .. #found .. "]: ")
    local n = tonumber(io.read())
    target = found[n] or found[1]
end

local p     = target.p
local ptype = target.ptype
local side  = target.side

hr(60)
print(center("PERIPHERAL: " .. ptype .. " (" .. side .. ")", 60))
hr(60)

-- ── Get all methods ────────────────────────────────────────────
local methods = {}
for name, fn in pairs(p) do
    if type(fn) == "function" then
        table.insert(methods, name)
    end
end
table.sort(methods)

-- ── Auto-call all getters and show results ─────────────────────
print("\n[ GETTERS — current state ]\n")
local getters, setters, others = {}, {}, {}
for _, name in ipairs(methods) do
    if name:sub(1,3) == "get" or name:sub(1,2) == "is" then
        table.insert(getters, name)
    elseif name:sub(1,3) == "set" then
        table.insert(setters, name)
    else
        table.insert(others, name)
    end
end

for _, name in ipairs(getters) do
    local ok, result = pcall(p[name])
    local display
    if not ok then
        display = "ERROR: " .. tostring(result)
    elseif result == nil then
        display = "(nil)"
    elseif type(result) == "table" then
        display = textutils.serialise(result):gsub("\n", " ")
        if #display > 60 then display = display:sub(1,57) .. "..." end
    else
        display = tostring(result)
    end
    print(string.format("  %-35s = %s", name .. "()", display))
end

-- ── Method index ───────────────────────────────────────────────
print("\n[ ALL METHODS ]\n")
print("  GETTERS:")
for i, name in ipairs(getters) do
    io.write(string.format("  %3d. %-30s", i, name))
    if i % 2 == 0 then print() end
end
if #getters % 2 ~= 0 then print() end

print("\n  SETTERS:")
for i, name in ipairs(setters) do
    print(string.format("  %3d. %s", i + #getters, name))
end

if #others > 0 then
    print("\n  OTHER:")
    for i, name in ipairs(others) do
        print(string.format("  %3d. %s", i + #getters + #setters, name))
    end
end

-- ── Interactive call loop ──────────────────────────────────────
local allMethods = {}
for _, n in ipairs(getters) do table.insert(allMethods, n) end
for _, n in ipairs(setters) do table.insert(allMethods, n) end
for _, n in ipairs(others)  do table.insert(allMethods, n) end

print("\n" .. string.rep("=", 60))
print("  Interactive mode — call any method")
print("  Enter number or name, args separated by spaces")
print("  'r' to refresh getters  |  'q' to quit")
print(string.rep("=", 60))

local function parseArgs(argstr)
    local args = {}
    for tok in (argstr .. " "):gmatch("([^ ]+) ") do
        local n = tonumber(tok)
        if n then
            table.insert(args, n)
        elseif tok == "true" then
            table.insert(args, true)
        elseif tok == "false" then
            table.insert(args, false)
        else
            table.insert(args, tok)
        end
    end
    return args
end

while true do
    io.write("\n> ")
    local line = io.read()
    if not line or line == "q" or line == "quit" then
        print("Bye.")
        break
    end

    if line == "r" or line == "refresh" then
        print("\n[ GETTERS refresh ]\n")
        for _, name in ipairs(getters) do
            local ok, result = pcall(p[name])
            local display = ok and tostring(result) or ("ERROR: " .. tostring(result))
            print(string.format("  %-35s = %s", name .. "()", display))
        end
    else
        -- Split into method + args
        local parts = {}
        for tok in (line .. " "):gmatch("([^ ]+) ") do
            table.insert(parts, tok)
        end
        local methodKey = table.remove(parts, 1)
        local args = parseArgs(table.concat(parts, " "))

        -- Resolve by number or name
        local methodName
        local idx = tonumber(methodKey)
        if idx and allMethods[idx] then
            methodName = allMethods[idx]
        else
            -- Check exact match first, then prefix
            for _, name in ipairs(allMethods) do
                if name == methodKey then methodName = name; break end
            end
            if not methodName then
                for _, name in ipairs(allMethods) do
                    if name:lower():find(methodKey:lower(), 1, true) then
                        methodName = name; break
                    end
                end
            end
        end

        if not methodName then
            print("  Unknown method: " .. methodKey)
        elseif type(p[methodName]) ~= "function" then
            print("  Not a function: " .. methodName)
        else
            print("  Calling: " .. methodName .. "(" .. table.concat(parts, ", ") .. ")")
            local ok, r1, r2, r3 = pcall(p[methodName], table.unpack(args))
            if not ok then
                print("  ERROR: " .. tostring(r1))
            else
                local results = {}
                for _, v in ipairs({r1, r2, r3}) do
                    if v ~= nil then
                        if type(v) == "table" then
                            table.insert(results, textutils.serialise(v))
                        else
                            table.insert(results, tostring(v))
                        end
                    end
                end
                if #results == 0 then
                    print("  OK (no return value)")
                else
                    print("  => " .. table.concat(results, ", "))
                end
            end
        end
    end
end
