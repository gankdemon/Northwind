-- PeltTracker with smooth tracer & accurate alarm logic v1.18
local PeltTracker = {}
function PeltTracker.init()
    print("[PeltTracker] v1.18 starting...")

    -- CONFIG
    local whiteThreshold       = 240
    local WARNING_INTERVAL     = 0.1
    local TRACE_SMOOTH_FACTOR  = 0.2  -- smoother tracer
    local ALERT_SOUND_INTERVAL = 1.0
    local TELEPORT_DOWN_DIST   = -10000

    -- SERVICES
    local Players          = game:GetService("Players")
    local TweenService     = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace        = game:GetService("Workspace")
    local RunService       = game:GetService("RunService")

    -- LOCALPLAYER & GUI
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then warn("[PeltTracker] No LocalPlayer") return end
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- SOUND
    local soundEnabled = false
    local lastAlertSound = 0
    local alertSound = Instance.new("Sound", PlayerGui)
    alertSound.SoundId = "rbxassetid://472069894"
    alertSound.Volume = 1

    -- STATE
    local animalData = {}     -- [folder] = { torso, colorName, isExotic }
    local tracerData = {}     -- [folder] = { box, line, conn }
    local buttonMap  = {}     -- [folder] = TextButton
    local isConfirming = {}
    local trackerGui, trackerOpen, listFrame
    local minimized = false

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg = (r+g+b)/3
        if r>=whiteThreshold and g>=whiteThreshold and b>=whiteThreshold then return "White", true end
        if math.abs(r-168)<=5 and math.abs(g-179)<=5 and math.abs(b-211)<=5 then return "Polar", true end
        if r>=70 and g<=50 and b<=50 then return "Crimson", true end
        if (b>=200 and r<=80 and g<=80) or (b>r and b>g and avg<100) then return "Azure", true end
        if math.abs(r-63)<=5  and math.abs(g-62)<=5  and math.abs(b-51)<=5  then return "Glade", false end
        if math.abs(r-71)<=5  and math.abs(g-51)<=5  and math.abs(b-51)<=5  then return "Hazel", false end
        if math.abs(r-99)<=5  and math.abs(g-89)<=5  and math.abs(b-70)<=5  then return "Kermode", false end
        if math.abs(r-105)<=5 and math.abs(g-115)<=5 and math.abs(b-125)<=5 then return "Silver", false end
        if math.abs(r-138)<=5 and math.abs(g-83)<=5  and math.abs(b-60)<=5  then return "Cinnamon", false end
        if math.abs(r-168)<=5 and math.abs(g-130)<=5 and math.abs(b-103)<=5 then return "Blonde", false end
        if math.abs(r-124)<=5 and math.abs(g-80)<=5  and math.abs(b-48)<=5  then return "Beige", false end
        if r>=150 and g>=80 and g<=110 and b<=80 then return "Orange", false end
        if r<=50 and g<=50 and b<=50 then return "Black", false end
        if math.abs(r-g)<=20 and math.abs(r-b)<=20 and math.abs(g-b)<=20 then
            return avg>=140 and "Grey" or "Dark Grey", false
        end
        if r>=60 and g>=40 and b>=30 then
            return avg>=80 and "Brown" or "Dark Brown", false
        end
        return "Unknown", false
    end

    -- SCAN ANIMALS
    local function scanAll()
        animalData = {}
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then warn("[PeltTracker] Animals folder not found") return end
        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local colorName, isExotic = classifyColor(torso.Color)
                    animalData[f] = { torso = torso, color = colorName, isExotic = isExotic }
                end
            end
        end
    end

    -- ESP toggle with smooth tracer
    local function toggleESP(folder)
        local info = animalData[folder]; if not info then return false end
        local t = info.torso
        if t:FindFirstChild("__PeltESP") then
            t:FindFirstChild("__PeltESP"):Destroy()
            if tracerData[folder] then
                tracerData[folder].conn:Disconnect()
                tracerData[folder].line:Remove()
                tracerData[folder].box:Destroy()
                tracerData[folder] = nil
            end
            return false
        end

        local box = Instance.new("BoxHandleAdornment", t)
        box.Name = "__PeltESP"
        box.Adornee = t
        box.AlwaysOnTop = true
        box.ZIndex = 10
        box.Size = t.Size * 5
        box.Color3 = Color3.fromRGB(57,255,20)
        box.Transparency = 0.7

        local cam = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line = Drawing.new("Line")
        line.Color = box.Color3
        line.Thickness = 2
        line.Visible = true
        line.From = center
        line.To = center

        local conn = RunService.RenderStepped:Connect(function()
            local pos3, onScreen = cam:WorldToViewportPoint(t.Position)
            if onScreen then
                local target = Vector2.new(pos3.X, pos3.Y)
                line.To = line.To:Lerp(target, TRACE_SMOOTH_FACTOR)
                line.From = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
                line.Visible = true
            else
                line.Visible = false
            end
        end)

        tracerData[folder] = { box = box, line = line, conn = conn }
        return true
    end

    -- BUILD GUI
    local function updateList()
        if not listFrame then return end
        for _,c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        buttonMap = {}

        local order = 1
        for folder, info in pairs(animalData) do
            local btn = Instance.new("TextButton", listFrame)
            btn.LayoutOrder = order; order += 1
            btn.Size = UDim2.new(1,0,0,28)
            btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.SourceSansSemibold; btn.TextSize = 16
            btn.RichText = true

            local r,g,b = toRGB(info.torso.Color)
            local hex = string.format("%02X%02X%02X", r,g,b)
            local baseText = string.format("<font color=\"#%s\">●</font> %s — %s", hex, folder.Name, info.color)
            btn:SetAttribute("BaseText", baseText)
            btn:SetAttribute("WarningIcon", "")
            btn.Text = baseText
            btn.TextColor3 = info.isExotic and Color3.fromRGB(255,215,0) or Color3.new(1,1,1)
            instance = btn

            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
            buttonMap[folder] = btn

            btn.MouseButton1Click:Connect(function()
                isConfirming[btn] = true
                local added = toggleESP(folder)
                btn.TextColor3 = added and Color3.fromRGB(50,255,50) or Color3.fromRGB(255,50,50)
                btn.Text = baseText .. (added and " ✅ ESP Enabled!" or " ❌ ESP Disabled!")
                delay(1.5, function()
                    isConfirming[btn] = nil
                    btn.TextColor3 = btn.TextColor3
                    btn.Text = baseText .. btn:GetAttribute("WarningIcon")
                end)
            end)

            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = info.torso.CFrame + Vector3.new(0,3,0) end
                end
            end)
        end
    end

    local function createTrackerGui()
        if trackerGui then trackerGui:Destroy() end
        trackerGui = Instance.new("ScreenGui", PlayerGui)
        trackerGui.Name = "PeltTrackerGUI"
        listFrame = Instance.new("ScrollingFrame", trackerGui)
        listFrame.Size = UDim2.new(0,360,0,500)
        listFrame.Position = UDim2.new(0.35, -354, 0.40, -52)
        listFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
        listFrame.BorderSizePixel = 0
        listFrame.Active = true; listFrame.Draggable = true
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0,8)
        local layout=Instance.new("UIListLayout", listFrame)
        layout.Padding = UDim.new(0,4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listFrame.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
        end)

        updateList()
    end

    scanAll()
    createTrackerGui()

    -- LIVE Updates, emoji alarm logic + sound
    local lw, lt = 0,0
    RunService.Heartbeat:Connect(function(dt)
        lw += dt; lt += dt; lastAlertSound += dt

        if lw >= WARNING_INTERVAL then
            lw = 0
            local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            for folder, info in pairs(animalData) do
                local btn = buttonMap[folder]
                if btn and not isConfirming[btn] then
                    local icon = ""
                    if myHRP then
                        local d = (myHRP.Position - info.torso.Position).Magnitude
                        if d <= 150 then
                            icon = " 🚨"
                            if soundEnabled and lastAlertSound >= ALERT_SOUND_INTERVAL then
                                alertSound:Play()
                                lastAlertSound = 0
                            end
                        elseif d <= 500 then
                            icon = " ⚠"
                        end
                    end
                    btn:SetAttribute("WarningIcon", icon)
                    btn.Text = btn:GetAttribute("BaseText") .. icon
                end
            end
        end
    end)

    -- F7 to toggle GUI
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F7 then
            createTrackerGui()
        end
    end)
end

return PeltTracker
