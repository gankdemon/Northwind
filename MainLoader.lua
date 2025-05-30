-- MainLoader.lua

--[[
    Feature: keepiy (always enabled using Infinite Yield's detection logic)
    This loader will persist across server teleports if the executor supports it.
]]

-- 1. Wait for the game to fully load before any logic runs
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 2. Helper to detect available functions
local function missing(typeName, func, fallback)
    if type(func) == typeName then
        return func
    end
    return fallback or nil
end

-- 3. Determine the exploit's queue_on_teleport function (fallback for various executors)
local queueteleport = missing(
    "function",
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
)

-- 4. Always queue this loader across teleports if supported
if queueteleport then
    queueteleport(("loadstring(game:HttpGet('%s', true))()"):format(
        "https://raw.githubusercontent.com/gankdemon/Northwind/main/MainLoader.lua"
    ))
end

-- 5. Module fetch utility
local function fetchModule(url)
    local src = game:HttpGet(url, true)
    local fn = assert(loadstring(src))
    return fn()
end

-- 6. URLs for modules (raw)
local staffUrl = "https://raw.githubusercontent.com/gankdemon/Northwind/main/StaffTracker.lua"
local peltUrl  = "https://raw.githubusercontent.com/gankdemon/Northwind/main/PeltTracker.lua"
local teleporterUrl = "https://raw.githubusercontent.com/gankdemon/Northwind/main/teleporter.lua"

-- 7. Load and initialize modules
local Staff = fetchModule(staffUrl)
local Pelt  = fetchModule(peltUrl)
local Teleporter = fetchModule(teleporterUrl)

Staff.init()
Pelt.init()
Teleporter.init()

loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
