-- PeltTracker with new exotic and common pelts v1.17.0
local PeltTracker = {}
function PeltTracker.init()
    --// ANIMAL PELT TRACKER with Supercharged Extras v1.17.0 //--
    print("[PeltTracker] Supercharged v1.17.0 starting...")

    -- CONFIG
    local whiteThreshold       = 240
    local WARNING_INTERVAL     = 0.1
    local TRACE_INTERVAL       = 0.1
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
    if not LocalPlayer then
        warn("[PeltTracker] No LocalPlayer")
        return
    end
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- EXTRA STATE
    local soundEnabled    = false
    local lastAlertSound  = 0
    local alertSound      = Instance.new("Sound", PlayerGui)
    alertSound.SoundId   = "rbxassetid://472069894"
    alertSound.Volume    = 1

    -- SETTINGS
    local Settings = {
        maxTrackDist     = 1000,
        markerColor      = Color3.fromRGB(0,0,0),
        markerBeamColor  = ColorSequence.new(Color3.fromRGB(0,0,0)),
    }

    -- CORE STATE
    local animalData     = {}  -- folder → { torso, color, isExotic, markers }
    local buttonMap      = {}  -- folder → TextButton
    local isConfirming   = {}  -- button → bool
    local tracerData     = {}  -- folder → { box, line, btn }
    local trackerGui, trackerOpen, listFrame
    local rebuildPending = false
    local minimized      = false

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

    -- Notification UI
    local function createNotification(title, message, bg)
        local gui = Instance.new("ScreenGui", PlayerGui); gui.ResetOnSpawn = false
        local f = Instance.new("Frame", gui)
        f.Size = UDim2.new(0,400,0,100)
        f.Position = UDim2.new(1.05,0,0.75,0)
        f.AnchorPoint = Vector2.new(1,0)
        f.BackgroundColor3 = bg
        f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
        local t = Instance.new("TextLabel", f)
        t.Size = UDim2.new(1,-20,0,28); t.Position = UDim2.new(0,10,0,8)
        t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold
        t.TextSize = 20; t.TextColor3 = Color3.new(1,1,1)
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = title
        local b = Instance.new("TextLabel", f)
        b.Size = UDim2.new(1,-20,0,40); b.Position = UDim2.new(0,10,0,36)
        b.BackgroundTransparency = 1; b.Font = Enum.Font.Gotham; b.TextSize = 16
        b.TextColor3 = Color3.new(1,1,1); b.TextWrapped = true
        b.TextXAlignment = Enum.TextXAlignment.Left; b.TextYAlignment = Enum.TextYAlignment.Top
        b.Text = message
        local ok = Instance.new("TextButton", f)
        ok.Size = UDim2.new(0,70,0,28); ok.Position = UDim2.new(1,-80,1,-40)
        ok.Font = Enum.Font.GothamBold; ok.TextSize = 18; ok.Text = "OK"
        ok.BackgroundColor3 = Color3.fromRGB(70,70,70); ok.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", ok).CornerRadius = UDim.new(0,6)
        TweenService:Create(f, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.95,0,0.75,0)
        }):Play()
        ok.MouseButton1Click:Connect(function()
            TweenService:Create(f, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1.05,0,0.75,0)
            }):Play()
            delay(0.6, function() gui:Destroy() end)
        end)
    end

    -- SCAN ANIMALS
    local function scanAll()
        animalData = {}
        local azureList, crimsonList, whiteList, polarList = {}, {}, {}, {}
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then 
            warn("[PeltTracker] Animals folder not found")
            return azureList, crimsonList, whiteList, polarList 
        end
        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local name, ex = classifyColor(torso.Color)
                    animalData[f] = { torso = torso, color = name, isExotic = ex, markers = nil }
                    if ex then
                        if name == "Azure"  then table.insert(azureList, f.Name)
                        elseif name == "Crimson" then table.insert(crimsonList, f.Name)
                        elseif name == "White"   then table.insert(whiteList, f.Name)
                        elseif name == "Polar"   then table.insert(polarList, f.Name)
                        end
                    end
                end
            end
        end
        return azureList, crimsonList, whiteList, polarList
    end

-- ESP & TRACER: now restores both box + line every time
local function toggleESP(folder)
    local info = animalData[folder]; if not info then return false end
    local t = info.torso
    local existing = t:FindFirstChild("__PeltESP")
    if existing then
        existing:Destroy()
        if tracerData[folder] then
            tracerData[folder].line:Remove()
            tracerData[folder].box:Destroy()
            tracerData[folder] = nil
        end
        return false
    end
    -- box
    local box = Instance.new("BoxHandleAdornment", t)
    box.Name = "__PeltESP"
    box.Adornee = t
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = t.Size * 5
    box.Color3 = Color3.fromRGB(57,255,20)
    box.Transparency = 0.7
    -- tracer
    local cam = Workspace.CurrentCamera
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local line = Drawing.new("Line")
    line.Visible = true
    line.Thickness = 2
    line.Color = box.Color3
    line.From = center
    line.To = center
    tracerData[folder] = { box = box, line = line }
    return true
end

    -- BUILD & REFRESH LIST
    local function updateList()
        if not listFrame then return end
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
        end
        table.clear(buttonMap)

        local groups = {}
        for f, info in pairs(animalData) do
            local sp = f.Name:match("([^_]+)_") or f.Name
            groups[sp] = groups[sp] or {}
            table.insert(groups[sp], f)
        end
        local species = {}
        for sp in pairs(groups) do table.insert(species, sp) end
        table.sort(species)

        local order = 1
        for _, sp in ipairs(species) do
            local hdr = Instance.new("TextLabel", listFrame)
            hdr.LayoutOrder = order; order += 1
            hdr.Size = UDim2.new(1,0,0,20)
            hdr.BackgroundTransparency = 1
            hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 16; hdr.TextColor3 = Color3.new(1,1,1)
            hdr.TextXAlignment = Enum.TextXAlignment.Center
            hdr.Text = "─── " .. sp .. " ───"

            for _, folder in ipairs(groups[sp]) do
                local info = animalData[folder]
                local btn = Instance.new("TextButton", listFrame)
                btn.LayoutOrder = order; order += 1
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.SourceSansSemibold; btn.TextSize = 16
                btn.RichText = true

                local r,g,b = toRGB(info.torso.Color)
                local hex = string.format("%02X%02X%02X", r,g,b)
                local prefix = string.format("<font color=\"#%s\">●</font> ", hex)
                local baseText = prefix .. folder.Name .. " — " .. info.color
                btn:SetAttribute("BaseText", baseText)
                btn:SetAttribute("WarningIcon", "")
                btn.Text = baseText

                -- Golden text for exotics, white otherwise
                local defaultColor = info.isExotic and Color3.fromRGB(255,215,0) or Color3.new(1,1,1)
                btn.TextColor3 = defaultColor

                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
                buttonMap[folder] = btn

            -- ESP toggle (left‑click) with GREEN confirmation
            btn.MouseButton1Click:Connect(function()
                isConfirming[btn] = true
                local added = toggleESP(folder)
                if added then
                    btn.Text = baseText.."  ✅ ESP Enabled!"
                else
                    btn.Text = baseText.."  ❌ ESP Disabled!"
                end
                btn.TextColor3 = Color3.fromRGB(50,255,50)
                delay(1.5, function()
                    isConfirming[btn] = nil
                    btn.TextColor3 = info.torso:FindFirstChild("__PeltESP") and info.torso.Color or Color3.new(1,1,1)
                    btn.Text = btn:GetAttribute("BaseText")..btn:GetAttribute("WarningIcon")
                end)
            end)

            -- Teleport (right‑click)
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    isConfirming[btn] = true
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = info.torso.CFrame + Vector3.new(0,3,0) end
                    btn.Text = baseText.."  📍 Teleported!"
                    btn.TextColor3 = Color3.new(1,1,0)
                    delay(1.5, function()
                        isConfirming[btn] = nil
                        btn.TextColor3 = info.torso:FindFirstChild("__PeltESP") and info.torso.Color or Color3.new(1,1,1)
                        btn.Text = btn:GetAttribute("BaseText")..btn:GetAttribute("WarningIcon")
                    end)
                end
            end)

            -- Marker toggle (middle‑click) with RED confirmation
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton3 then
                    isConfirming[btn] = true
                    if info.markers then
                        removeMapMarker(folder)
                        btn.Text = baseText.."  ➖ Marker Removed!"
                    else
                        addMapMarker(folder)
                        btn.Text = baseText.."  ➕ Marker Placed!"
                    end
                    btn.TextColor3 = Color3.fromRGB(255,50,50)
                    delay(2.5, function()
                        isConfirming[btn] = nil
                        btn.TextColor3 = info.torso:FindFirstChild("__PeltESP") and info.torso.Color or Color3.new(1,1,1)
                        btn.Text = btn:GetAttribute("BaseText")..btn:GetAttribute("WarningIcon")
                    end)
                end
            end)
        end
    end
end

-- CREATE / TOGGLE GUI
local function createTrackerGui()
    if trackerGui and trackerOpen then
        trackerGui:Destroy()
        trackerGui, trackerOpen = nil, false
        return
    end
    trackerGui = Instance.new("ScreenGui", PlayerGui)
    trackerOpen = true

    -- Main frame
    local main = Instance.new("Frame", trackerGui)
    main.Name = "MainFrame"
    main.Size = UDim2.new(0,360,0,500)
    main.AnchorPoint = Vector2.new(0, 0)
    main.Position    = UDim2.new(0.349999994, -354, 0.400000006, -52)

    main.BackgroundColor3 = Color3.fromRGB(25,25,25)
    main.BorderSizePixel = 0
    main.Active, main.Draggable = true, true
    local mainCorner = Instance.new("UICorner", main)
    mainCorner.CornerRadius = UDim.new(0,8)

    -- Header & Minimize
    local count = 0 for _ in pairs(animalData) do count += 1 end
    local hdr = Instance.new("TextLabel", main)
    hdr.Size = UDim2.new(0.75,-10,0,28)
    hdr.Position = UDim2.new(0,10,0,0)
    hdr.BackgroundTransparency = 1
    hdr.Font, hdr.TextSize, hdr.TextColor3 = Enum.Font.GothamBold, 18, Color3.new(1,1,1)
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.Text = string.format("Tracker - %d found", count)

    local minBtn = Instance.new("TextButton", main)
    minBtn.Size = UDim2.new(0,28,0,28)
    minBtn.Position = UDim2.new(1,-32,0,0)
    minBtn.BackgroundTransparency = 1
    minBtn.Font, minBtn.TextSize, minBtn.TextColor3 = Enum.Font.GothamBold, 18, Color3.new(1,1,1)
    minBtn.Text = "➖"
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        listFrame.Visible = not minimized
        minBtn.Text = minimized and "➕" or "➖"
        local newSize = minimized and UDim2.new(0,360,0,30) or UDim2.new(0,360,0,500)
        TweenService:Create(main, TweenInfo.new(0.3,Enum.EasingStyle.Quad), { Size=newSize }):Play()
        mainCorner.CornerRadius = UDim.new(0, minimized and 15 or 8)
    end)

    -- Control buttons (same icons order as before)
    local btnConfigs = {
        {
            icon="🔊",
            onClick=function(b)
                soundEnabled = not soundEnabled
                b.TextColor3 = soundEnabled and Color3.fromRGB(0,255,0) or Color3.new(1,1,1)
            end
        },
        {
            icon="⚙️",
            onClick=function()
                createNotification("Settings","(coming soon)", Color3.fromRGB(70,70,70))
            end
        },
        {
            icon="⏬",
            onClick=function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, TELEPORT_DOWN_DIST, 0) end
            end
        },
        {
            icon="🔄",
            onClick=function()
                if not rebuildPending then
                    rebuildPending = true
                    scanAll(); updateList()
                    delay(0.5, function() rebuildPending = false end)
                end
            end
        },
    }
    for i,conf in ipairs(btnConfigs) do
        local b = Instance.new("TextButton", main)
        b.Size = UDim2.new(0,28,0,28)
        b.Position = UDim2.new(1,-32*(i+1),0,0)
        b.BackgroundTransparency = 1
        b.Font, b.TextSize, b.TextColor3 = Enum.Font.GothamBold, 18, Color3.new(1,1,1)
        b.Text = conf.icon
        b.MouseButton1Click:Connect(function() conf.onClick(b) end)
    end

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

 -- INITIAL SETUP + Notifications
    local azure, crimson, white, polar = scanAll()
    if #azure   > 0 then createNotification("Azure Pelts Detected",   ("Found %d Azure: %s"):format(#azure,   table.concat(azure,",")),   Color3.fromRGB(0,0,128)) end
    if #crimson > 0 then createNotification("Crimson Pelts Detected", ("Found %d Crimson: %s"):format(#crimson, table.concat(crimson,",")), Color3.fromRGB(220,20,60)) end
    if #white   > 0 then createNotification("White Pelts Detected",   ("Found %d White: %s"):format(#white,   table.concat(white,",")),   Color3.fromRGB(200,200,200)) end
    if #polar   > 0 then createNotification("Polar Pelts Detected",   ("Found %d Polar: %s"):format(#polar,   table.concat(polar,",")),   Color3.fromRGB(180,180,220)) end
    if #azure==0 and #crimson==0 and #white==0 and #polar==0 then
        createNotification("No Exotic Pelts", "No Azure, Crimson, White, or Polar detected.", Color3.fromRGB(80,80,80))
    end
    createTrackerGui()

-- LIVE WATCH + WARNINGS + TRACERS + SOUND
local lw, lt = 0,0
RunService.Heartbeat:Connect(function(dt)
    lw, lt, lastAlertSound = lw+dt, lt+dt, lastAlertSound+dt

    if lw >= WARNING_INTERVAL then
        lw = 0
        local parts={}
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl~=LocalPlayer and pl.Character then
                local hrp=pl.Character:FindFirstChild("HumanoidRootPart")
                if hrp then table.insert(parts, hrp.Position) end
            end
        end
        for folder,info in pairs(animalData) do
            local btn=buttonMap[folder]
            if not btn or isConfirming[btn] then continue end
            local icon=""
            for _,p in ipairs(parts) do
                local d=(p - info.torso.Position).Magnitude
                if d<=Settings.maxTrackDist then
                    icon=" 🚨"
                    if soundEnabled and lastAlertSound>=ALERT_SOUND_INTERVAL then
                        alertSound:Play(); lastAlertSound=0
                    end
                    break
                elseif d<=Settings.maxTrackDist*1.5 then
                    icon=" ⚠️"
                end
            end
            btn:SetAttribute("WarningIcon",icon)
            btn.Text = btn:GetAttribute("BaseText")..icon
        end
    end

    if lt>=TRACE_INTERVAL then
        lt=0
        local cam=Workspace.CurrentCamera
        local center=Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        for folder,data in pairs(tracerData) do
            local box = Workspace:FindFirstChild("__PeltESP", true)
            data.line.Visible = box and true or false
            if data.line.Visible then
                data.line.From = center
                local torso = animalData[folder].torso
                local pos, vis = cam:WorldToViewportPoint(torso.Position + Vector3.new(0,torso.Size.Y/2,0))
                if vis then data.line.To = Vector2.new(pos.X, pos.Y) end
            end
        end
    end
end)

-- TOGGLE GUI with F7
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Keyboard and inp.KeyCode==Enum.KeyCode.F7 then
        createTrackerGui()
    end
end)
end
return PeltTracker
