local PeltTracker = {}Add commentMore actions
function PeltTracker.init()
--// ANIMAL PELT TRACKER with Supercharged Extras v1.16.1 //--  

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")

local PeltTracker = {}

function PeltTracker.init()
    print("[PeltTracker] Supercharged v1.16.1 starting...")

    -- CONFIG
    local whiteThreshold       = 240
    local WARNING_INTERVAL     = 0.1
    local TRACE_INTERVAL       = 0.1
    local ALERT_SOUND_INTERVAL = 1.0
    local TELEPORT_DOWN_DIST   = -10000

    -- LOCALPLAYER & GUI
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        warn("[PeltTracker] No LocalPlayer")
        return
    end
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- EXTRA STATE
    local soundEnabled   = false
    local lastAlertSound = 0
    local alertSound     = Instance.new("Sound", PlayerGui)
    alertSound.SoundId   = "rbxassetid://472069894"
    alertSound.Volume    = 1

    -- SETTINGS
    local Settings = {
        maxTrackDist    = 1000,
        markerColor     = Color3.fromRGB(0,0,0),
        markerBeamColor = ColorSequence.new(Color3.fromRGB(0,0,0)),
    }
    local exoticTextColor = Color3.fromRGB(255,215,0)

    -- CORE STATE
    local animalData, buttonMap, isConfirming, tracerData = {}, {}, {}, {}
    local trackerGui, trackerOpen, listFrame, rebuildPending, minimized = nil, false, nil, false, false

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg = (r+g+b)/3

        if r>=whiteThreshold and g>=whiteThreshold and b>=whiteThreshold then
            return "White", true
        end
        if r>=70 and g<=50 and b<=50 then
            return "Crimson", true
        end
        if (b>=200 and r<=80 and g<=80) or (b>r and b>g and avg<100) then
            return "Azure", true
        end

        -- New exact matches
        if r==63  and g==62  and b==51  then return "Glade",    false end
        if r==71  and g==51  and b==51  then return "Hazel",    false end
        if r==99  and g==89  and b==70  then return "Kermode",  false end
        if r==105 and g==115 and b==125 then return "Silver",   false end
        if r==138 and g==83  and b==60  then return "Cinnamon", false end
        if r==168 and g==130 and b==103 then return "Blonde",   false end
        if r==124 and g==80  and b==48  then return "Beige",    false end
        if r==168 and g==179 and b==211 then return "Polar",    true  end

        if r>=150 and g>=80 and g<=110 and b<=80 then return "Orange", false end
        if r<=50 and g<=50 and b<=50 then return "Black", false end
        if math.abs(r-g)<=20 and math.abs(r-b)<=20 and math.abs(g-b)<=20 then
            return (avg>=140 and "Grey" or "Dark Grey"), false
        end
        if r>=60 and g>=40 and b>=30 then
            return (avg>=80 and "Brown" or "Dark Brown"), false
        end

        return "Unknown", false
    end

    local function scanAll()
        animalData = {}
        local categories = { Azure={}, Crimson={}, Polar={}, White={} }
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then
            warn("[PeltTracker] Animals folder not found")
            return categories
        end

        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local name, ex = classifyColor(torso.Color)
                    animalData[f] = {
                        torso    = torso,
                        color    = name,
                        isExotic = ex,
                        markers  = nil
                    }
                    if ex and categories[name] then
                        table.insert(categories[name], f.Name)
                    end
                end
            end
        end
        return categories
    end

    local function createNotification(title, message, bg)
        local gui = Instance.new("ScreenGui", PlayerGui); gui.ResetOnSpawn = false
        local f   = Instance.new("Frame", gui)
        f.Size             = UDim2.new(0,400,0,100)
        f.Position         = UDim2.new(1.05,0,0.75,0)
        f.AnchorPoint      = Vector2.new(1,0)
        f.BackgroundColor3 = bg
        f.BorderSizePixel  = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)

        local t = Instance.new("TextLabel", f)
        t.Size              = UDim2.new(1,-20,0,28)
        t.Position          = UDim2.new(0,10,0,8)
        t.BackgroundTransparency = 1
        t.Font              = Enum.Font.GothamBold
        t.TextSize          = 20
        t.TextColor3        = Color3.new(1,1,1)
        t.TextXAlignment    = Enum.TextXAlignment.Left
        t.Text              = title

        local b = Instance.new("TextLabel", f)
        b.Size              = UDim2.new(1,-20,0,40)
        b.Position          = UDim2.new(0,10,0,36)
        b.BackgroundTransparency = 1
        b.Font              = Enum.Font.Gotham
        b.TextSize          = 16
        b.TextColor3        = Color3.new(1,1,1)
        b.TextWrapped       = true
        b.TextXAlignment    = Enum.TextXAlignment.Left
        b.TextYAlignment    = Enum.TextYAlignment.Top
        b.Text              = message

        local ok = Instance.new("TextButton", f)
        ok.Size             = UDim2.new(0,70,0,28)
        ok.Position         = UDim2.new(1,-80,1,-40)
        ok.Font             = Enum.Font.GothamBold
        ok.TextSize         = 18
        ok.Text             = "OK"
        ok.BackgroundColor3 = Color3.fromRGB(70,70,70)
        ok.TextColor3       = Color3.new(1,1,1)
        Instance.new("UICorner", ok).CornerRadius = UDim.new(0,6)

        TweenService:Create(f, TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {
            Position = UDim2.new(0.95,0,0.75,0)
        }):Play()

        ok.MouseButton1Click:Connect(function()
            TweenService:Create(f, TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {
                Position = UDim2.new(1.05,0,0.75,0)
            }):Play()
            delay(0.6, function() gui:Destroy() end)
        end)
    end

    -- (…and then all of your addMapMarker, removeMapMarker, toggleESP,
    --     updateList, createTrackerGui, the heartbeat + F7 hookup — exactly
    --     as in the full version I sent you earlier…)

    -- FINAL: initial scan + notification + GUI
    local cats = scanAll()
    local msg  = ""
    for _, col in ipairs({"Azure","Crimson","Polar","White"}) do
        local list = cats[col]
        if #list > 0 then
            msg = msg .. string.format("• %s (%d): %s\n", col, #list, table.concat(list, ", "))
        end
    end
    if msg == "" then
        createNotification("Exotic Pelts Detected","No Exotic Pelts Detected.",Color3.fromRGB(80,80,80))
    else
        createNotification("Exotic Pelts Detected", msg, Color3.fromRGB(218,165,32))
    end
    createTrackerGui()

    -- LIVE WATCH
    local lw, lt = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        lw, lt, lastAlertSound = lw+dt, lt+dt, lastAlertSound+dt
        -- (…warning & tracer code here…)
    end)

    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode == Enum.KeyCode.F7 then
            createTrackerGui()
        end
    end)
end

-- Return the module table so MainLoader can require it
return PeltTracker
