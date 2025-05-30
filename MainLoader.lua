-- MainLoader.lua
local function fetchModule(url)
  local src = game:HttpGet(url)
  local fn = assert(loadstring(src))
  return fn()
end

local staffUrl = "https://raw.githubusercontent.com/gankdemon/Northwind/main/StaffTracker.lua"
local peltUrl  = "https://raw.githubusercontent.com/gankdemon/Northwind/main/PeltTracker.lua"
local teleporterUrl = "https://raw.githubusercontent.com/gankdemon/Northwind/main/teleporter.lua"

local Staff = fetchModule(staffUrl)
local Pelt  = fetchModule(peltUrl)
local Teleporter = fetchModule(teleporterUrl)

Staff.init()
Pelt.init()
Teleporter.init()
