local PeltTracker = {}

function PeltTracker.init()
    print("[PeltTracker] v1.18 starting...")

    -- CONFIG
    local whiteThreshold       = 240
    local WARNING_INTERVAL     = 0.1
    local TRACE_SMOOTH_FACTOR  = 0.2    
    local ALERT_SOUND_INTERVAL = 1.0
    local TELEPORT_DOWN_DIST   = -10000

    -- SERVICES
    local Players       = game:GetService("Players")
    local TweenService  = game:GetService("TweenService")
    local UserInput     = game:GetService("UserInputService")
    local Workspace     = game:GetService("Workspace")
    local RunService    = game:GetService("RunService")

    -- LOCAL PLAYER & GUI
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then warn("[PeltTracker] No LocalPlayer") return end
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- STATE
    local animalData = {}      -- [folder] = { torso, color, isExotic }
    local tracerData = {}      -- [folder] = { box, line, conn }
    local buttonMap  = {}      -- [folder] = TextButton
    local listFrame, trackerGui
    local lastAlertSound = 0

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    -- classifyColor now includes Polar & White as exotic, plus new common pelts
    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg = (r+g+b)/3
        -- Exotic pelts
        if r>=whiteThreshold and g>=whiteThreshold and b>=whiteThreshold then
            return "White", true
        end
        if math.abs(r-168)<=5 and math.abs(g-179)<=5 and math.abs(b-211)<=5 then
            return "Polar", true
        end
        if r>=70 and g<=50 and b<=50 then
            return "Crimson", true
        end
        if (b>=200 and r<=80 and g<=80) or (b>r and b>g and avg<100) then
            return "Azure", true
        end
        -- New common pelts
        if math.abs(r-63)<=5  and math.abs(g-62)<=5  and math.abs(b-51)<=5  then return "Glade",    false end
        if math.abs(r-71)<=5  and math.abs(g-51)<=5  and math.abs(b-51)<=5  then return "Hazel",    false end
        if math.abs(r-99)<=5  and math.abs(g-89)<=5  and math.abs(b-70)<=5  then return "Kermode",  false end
        if math.abs(r-105)<=5 and math.abs(g-115)<=5 and math.abs(b-125)<=5 then return "Silver",   false end
        if math.abs(r-138)<=5 and math.abs(g-83)<=5  and math.abs(b-60)<=5  then return "Cinnamon", false end
        if math.abs(r-168)<=5 and math.abs(g-130)<=5 and math.abs(b-103)<=5 then return "Blonde",   false end
        if math.abs(r-124)<=5 and math.abs(g-80)<=5  and math.abs(b-48)<=5  then return "Beige",    false end
        -- Other common/non-exotic
        if r>=150 and g>=80 and g<=110 and b<=80 then return "Orange", false end
        if r<=50 and g<=50 and b<=50 then return "Black", false end
        if math.abs(r-g)<=20 and math.abs(r-b)<=20 and math.abs(g-b)<=20 then
            if avg>=140 then return "Grey", false else return "Dark Grey", false end
        end
        if r>=60 and g>=40 and b>=30 then
            if avg>=80 then return "Brown", false else return "Dark Brown", false end
        end
        return "Unknown", false
    end

    -- SCAN ANIMALS
    local function scanAll()
        animalData = {}
        -- find Workspace.NPCs.Animals root
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then warn("[PeltTracker] Animals folder not found") return end
        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local _, isExotic = classifyColor(torso.Color)
                    animalData[f] = { torso = torso, isExotic = isExotic }
                end
            end
        end
    end

    -- TOGGLE ESP & SMOOTH TRACER
    local function toggleESP(folder)
        local info = animalData[folder]
        if not info then return end
        local t = info.torso
        -- REMOVE if exists
        local existing = t:FindFirstChild("__PeltESP")
        if existing then
            existing:Destroy()
            if tracerData[folder] then
                tracerData[folder].conn:Disconnect()
                tracerData[folder].line:Remove()
                tracerData[folder].box:Destroy()
                tracerData[folder] = nil
            end
            return
        end
        -- CREATE BOX
        local box = Instance.new("BoxHandleAdornment", t)
        box.Name        = "__PeltESP"
        box.Adornee     = t
        box.AlwaysOnTop = true
        box.ZIndex      = 10
        box.Size        = t.Size * 5
        box.Color3      = Color3.fromRGB(57,255,20)
        box.Transparency= 0.7
        -- CREATE SMOOTH TRACER
        local cam = Workspace.CurrentCamera
        local line = Drawing.new("Line")
        line.Visible   = true
        line.Thickness = 2
        line.Color     = box.Color3
        -- initial endpoints at center
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        line.From = center
        line.To   = center
        -- update each frame
        local conn = RunService.RenderStepped:Connect(function()
            if not line.Visible then return end
            local cam2 = Workspace.CurrentCamera
            local screenPos, onScreen = cam2:WorldToViewportPoint(t.Position)
            if onScreen then
                local target = Vector2.new(screenPos.X, screenPos.Y)
                -- lerp smoothly
                line.To = line.To:Lerp(target, TRACE_SMOOTH_FACTOR)
                line.From = Vector2.new(cam2.ViewportSize.X/2, cam2.ViewportSize.Y/2)
                line.Visible = true
            else
                line.Visible = false
            end
        end)
        tracerData[folder] = { box = box, line = line, conn = conn }
    end

    -- BUILD & REFRESH LIST with ACCURATE EMOJI
    local function updateList()
        if not listFrame then return end
        -- clear old
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
        end
        buttonMap = {}
        -- iterate animalData
        local order = 1
        for folder, info in pairs(animalData) do
            local btn = Instance.new("TextButton", listFrame)
            btn.LayoutOrder = order; order += 1
            btn.Size        = UDim2.new(1,0,0,28)
            btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
            btn.BorderSizePixel  = 0
            btn.Font       = Enum.Font.SourceSansSemibold
            btn.TextSize   = 16
            btn.TextColor3 = Color3.new(1,1,1)
            btn.RichText   = true

            -- distance in studs (= feet)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and (hrp.Position - info.torso.Position).Magnitude or math.huge

            -- emoji logic
            local emoji = ""
            if dist <= 150 then emoji = " 🚨"  
            elseif dist <= 500 then emoji = " ⚠" end

            btn.Text = string.format("%s — %.1f ft%s", folder.Name, dist, emoji)

            btn.MouseButton1Click:Connect(function() toggleESP(folder) end)
            buttonMap[folder] = btn
        end
    end

    -- INITIALIZE GUI & HEARTBEAT
    local function createGui()
        if trackerGui then trackerGui:Destroy() end
        trackerGui = Instance.new("ScreenGui", PlayerGui)
        trackerGui.Name = "PeltTrackerGUI"
            -- List frame
    listFrame = Instance.new("ScrollingFrame", main)
    listFrame.Name = "List"
    listFrame.Size = UDim2.new(1,-16,1,-40)
    listFrame.Position = UDim2.new(0,8,0,32)
    listFrame.BackgroundTransparency = 1
    listFrame.ScrollBarThickness = 6
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0,6)
    local layout=Instance.new("UIListLayout", listFrame)
    layout.Padding = UDim.new(0,4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
    end)

    updateList()
    end

    scanAll()
    createGui()
    RunService.Heartbeat:Connect(function()
        scanAll()
        updateList()
    end)
end

return PeltTracker
