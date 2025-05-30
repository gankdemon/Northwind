local PeltTracker = {}
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
    if not LocalPlayer then warn("[PeltTracker] No LocalPlayer"); return end
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
    local trackerGui, trackerOpen, listFrame, rebuildPending, minimized
    rebuildPending, minimized = false, false

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg   = (r+g+b)/3

        if r>=whiteThreshold and g>=whiteThreshold and b>=whiteThreshold then
            return "White", true
        end
        if r>=70 and g<=50 and b<=50 then
            return "Crimson", true
        end
        if (b>=200 and r<=80 and g<=80) or (b>r and b>g and avg<100) then
            return "Azure", true
        end

        -- new exact matches
        if r==63  and g==62  and b==51  then return "Glade",    false end
        if r==71  and g==51  and b==51  then return "Hazel",    false end
        if r==99  and g==89  and b==70  then return "Kermode",  false end
        if r==105 and g==115 and b==125 then return "Silver",   false end
        if r==138 and g==83  and b==60  then return "Cinnamon", false end
        if r==168 and g==130 and b==103 then return "Blonde",   false end
        if r==124 and g==80  and b==48  then return "Beige",    false end
        if r==168 and g==179 and b==211 then return "Polar",    true  end

        if r>=150 and g>=80 and g<=110 and b<=80 then
            return "Orange", false
        end
        if r<=50 and g<=50 and b<=50 then
            return "Black", false
        end
        if math.abs(r-g)<=20 and math.abs(r-b)<=20 and math.abs(g-b)<=20 then
            if avg>=140 then return "Grey", false else return "Dark Grey", false end
        end
        if r>=60 and g>=40 and b>=30 then
            if avg>=80 then return "Brown", false else return "Dark Brown", false end
        end
        return "Unknown", false
    end

    local function scanAll()
        animalData = {}
        local categories = { Azure={}, Crimson={}, Polar={}, White={} }
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then warn("[PeltTracker] Animals folder not found"); return categories end

        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local name, ex = classifyColor(torso.Color)
                    animalData[f] = { torso=torso, color=name, isExotic=ex, markers=nil }
                    if ex and categories[name] then
                        table.insert(categories[name], f.Name)
                    end
                end
            end
        end

        return categories
    end

    local function createNotification(title,message,bg)
        local gui = Instance.new("ScreenGui", PlayerGui); gui.ResetOnSpawn=false
        local f   = Instance.new("Frame", gui)
        f.Size       = UDim2.new(0,400,0,100)
        f.Position   = UDim2.new(1.05,0,0.75,0)
        f.AnchorPoint= Vector2.new(1,0)
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

    local function addMapMarker(folder)
        local info = animalData[folder]
        if info.markers then return end

        local part = Instance.new("Part", Workspace)
        part.Size         = Vector3.new(1,1,1)
        part.Anchored     = true
        part.CanCollide   = false
        part.Transparency = 0.7
        part.Color        = Settings.markerColor
        part.CFrame       = CFrame.new(info.torso.Position)

        local a0 = Instance.new("Attachment", part)
        local a1 = Instance.new("Attachment", Workspace.Terrain)
        a1.WorldPosition  = part.Position + Vector3.new(0,500,0)

        local beam = Instance.new("Beam", part)
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.FaceCamera  = true
        beam.Width0, beam.Width1 = 0.5, 0.5
        beam.Color      = Settings.markerBeamColor

        info.markers = { part=part, beam=beam, a0=a0, a1=a1 }
    end

    local function removeMapMarker(folder)
        local info = animalData[folder]
        if not info.markers then return end
        info.markers.beam:Destroy()
        info.markers.a0:Destroy()
        info.markers.a1:Destroy()
        info.markers.part:Destroy()
        info.markers = nil
    end

    local function toggleESP(folder)
        local info = animalData[folder]
        if not info then return false end

        local t = info.torso
        local existing = t:FindFirstChild("__PeltESP")
        if existing then
            existing:Destroy()
            tracerData[folder].line:Remove()
            tracerData[folder].box:Destroy()
            tracerData[folder] = nil
            return false
        end

        local box = Instance.new("BoxHandleAdornment", t)
        box.Name       = "__PeltESP"
        box.Adornee    = t
        box.AlwaysOnTop= true
        box.ZIndex     = 10
        box.Size       = t.Size * 5
        box.Color3     = Color3.fromRGB(57,255,20)
        box.Transparency = 0.7

        local cam    = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line   = Drawing.new("Line")
        line.Visible   = true
        line.Thickness = 2
        line.Color     = box.Color3
        line.From      = center
        line.To        = center

        tracerData[folder] = { box=box, line=line }
        return true
    end

    local function updateList()
        if not listFrame then return end
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                c:Destroy()
            end
        end
        table.clear(buttonMap)

        -- group by species prefix
        local groups = {}
        for f, info in pairs(animalData) do
            local sp = f.Name:match("([^_]+)_") or f.Name
            groups[sp] = groups[sp] or {}
            table.insert(groups[sp], f)
        end

        local species = {}
        for sp in pairs(groups) do
            table.insert(species, sp)
        end
        table.sort(species)

        local order = 1
        for _, sp in ipairs(species) do
            local hdr = Instance.new("TextLabel", listFrame)
            hdr.LayoutOrder         = order; order += 1
            hdr.Size                = UDim2.new(1,0,0,20)
            hdr.BackgroundTransparency = 1
            hdr.Font                = Enum.Font.GothamBold
            hdr.TextSize            = 16
            hdr.TextColor3          = Color3.new(1,1,1)
            hdr.TextXAlignment      = Enum.TextXAlignment.Center
            hdr.Text                = "─── " .. sp .. " ───"

            for _, folder in ipairs(groups[sp]) do
                local info = animalData[folder]
                local btn = Instance.new("TextButton", listFrame)
                btn.LayoutOrder        = order; order += 1
                btn.Size               = UDim2.new(1,0,0,28)
                btn.BackgroundColor3   = Color3.fromRGB(45,45,45)
                btn.BorderSizePixel    = 0
                btn.Font               = Enum.Font.SourceSansSemibold
                btn.TextSize           = 16
                btn.RichText           = true

                local r,g,b = toRGB(info.torso.Color)
                local hex   = string.format("%02X%02X%02X", r, g, b)
                local prefix= string.format("<font color=\"#%s\">●</font> ", hex)
                local baseText = prefix .. folder.Name .. " — " .. info.color

                btn:SetAttribute("BaseText", baseText)
                btn:SetAttribute("WarningIcon", "")

                btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                    and info.torso.Color
                    or (info.isExotic and exoticTextColor or Color3.new(1,1,1))

                btn.Text = baseText
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

                buttonMap[folder] = btn

                -- LEFT CLICK: ESP toggle
                btn.MouseButton1Click:Connect(function()
                    isConfirming[btn] = true
                    local added = toggleESP(folder)
                    btn.Text = baseText .. "  " .. (added and "✅ ESP Enabled!" or "❌ ESP Disabled!")
                    btn.TextColor3 = Color3.fromRGB(50,255,50)
                    delay(1.5, function()
                        isConfirming[btn] = nil
                        btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                            and info.torso.Color
                            or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                        btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                    end)
                end)

                -- RIGHT CLICK: teleport
                btn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton2 then
                        isConfirming[btn] = true
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = info.torso.CFrame + Vector3.new(0,3,0) end
                        btn.Text = baseText .. "  📍 Teleported!"
                        btn.TextColor3 = Color3.new(1,1,0)
                        delay(1.5, function()
                            isConfirming[btn] = nil
                            btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                                and info.torso.Color
                                or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                            btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                        end)
                    end
                end)

                -- MIDDLE CLICK: map marker
                btn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton3 then
                        isConfirming[btn] = true
                        if info.markers then
                            removeMapMarker(folder)
                            btn.Text = baseText .. "  ➖ Marker Removed!"
                        else
                            addMapMarker(folder)
                            btn.Text = baseText .. "  ➕ Marker Placed!"
                        end
                        btn.TextColor3 = Color3.fromRGB(255,50,50)
                        delay(2.5, function()
                            isConfirming[btn] = nil
                            btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                                and info.torso.Color
                                or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                            btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                        end)
                    end
                end)
            end
        end
    end

    local function createTrackerGui()
        if trackerGui and trackerOpen then
            trackerGui:Destroy()
            trackerGui, trackerOpen = nil, false
            return
        end

        trackerGui = Instance.new("ScreenGui", PlayerGui)
        trackerOpen = true

        local main = Instance.new("Frame", trackerGui)
        main.Name               = "MainFrame"
        main.Size               = UDim2.new(0,360,0,500)
        main.Position           = UDim2.new(0.65,0,0,100)
        main.BackgroundColor3   = Color3.fromRGB(25,25,25)
        main.BorderSizePixel    = 0
        main.Active, main.Draggable = true, true
        Instance.new("UICorner", main).CornerRadius = UDim.new(0,8)

        local count = 0
        for _ in pairs(animalData) do count += 1 end

        local hdr = Instance.new("TextLabel", main)
        hdr.Size              = UDim2.new(0.75,-10,0,28)
        hdr.Position          = UDim2.new(0,10,0,0)
        hdr.BackgroundTransparency = 1
        hdr.Font              = Enum.Font.GothamBold
        hdr.TextSize          = 18
        hdr.TextColor3        = Color3.new(1,1,1)
        hdr.TextXAlignment    = Enum.TextXAlignment.Left
        hdr.Text              = string.format("Tracker - %d found", count)

        local minBtn = Instance.new("TextButton", main)
        minBtn.Size            = UDim2.new(0,28,0,28)
        minBtn.Position        = UDim2.new(1,-32,0,0)
        minBtn.BackgroundTransparency = 1
        minBtn.Font            = Enum.Font.GothamBold
        minBtn.TextSize        = 18
        minBtn.TextColor3      = Color3.new(1,1,1)
        minBtn.Text            = "➖"
        minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            listFrame.Visible = not minimized
            minBtn.Text = minimized and "➕" or "➖"
            local newSize = minimized and UDim2.new(0,360,0,30) or UDim2.new(0,360,0,500)
            TweenService:Create(main, TweenInfo.new(0.3,Enum.EasingStyle.Quad), { Size=newSize }):Play()
        end)

        local btnConfigs = {
            { icon="🔊", onClick=function(b)
                soundEnabled = not soundEnabled
                b.TextColor3  = soundEnabled and Color3.fromRGB(0,255,0) or Color3.new(1,1,1)
            end },
            { icon="⚙️", onClick=function()
                createNotification("Settings","(coming soon)", Color3.fromRGB(70,70,70))
            end },
            { icon="⏬", onClick=function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, TELEPORT_DOWN_DIST, 0) end
            end },
            { icon="🔄", onClick=function()
                if not rebuildPending then
                    rebuildPending = true
                    scanAll()
                    updateList()
                    delay(0.5, function() rebuildPending = false end)
                end
            end },
        }

        for i, conf in ipairs(btnConfigs) do
            local b = Instance.new("TextButton", main)
            b.Size              = UDim2.new(0,28,0,28)
            b.Position          = UDim2.new(1, -32*(i+1), 0, 0)
            b.BackgroundTransparency = 1
            b.Font              = Enum.Font.GothamBold
            b.TextSize          = 18
            b.TextColor3        = Color3.new(1,1,1)
            b.Text              = conf.icon
            b.MouseButton1Click:Connect(function() conf.onClick(b) end)
        end

        listFrame = Instance.new("ScrollingFrame", main)
        listFrame.Name               = "List"
        listFrame.Size               = UDim2.new(1,-16,1,-40)
        listFrame.Position           = UDim2.new(0,8,0,32)
        listFrame.BackgroundTransparency = 1
        listFrame.ScrollBarThickness = 6
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0,6)

        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding    = UDim.new(0,4)
        layout.SortOrder  = Enum.SortOrder.LayoutOrder
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listFrame.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
        end)

        updateList()
    end

    -- INITIAL SETUP: BIG EXOTIC NOTIFICATION
    local cats = scanAll()
    local msg  = ""
    for _, col in ipairs({"Azure","Crimson","Polar","White"}) do
        local list = cats[col]
        if #list > 0 then
            msg = msg .. string.format("• %s (%d): %s\n", col, #list, table.concat(list, ", "))
        end
    end
    if msg == "" then
        createNotification("Exotic Pelts Detected", "No Exotic Pelts Detected.", Color3.fromRGB(80,80,80))
    else
        createNotification("Exotic Pelts Detected", msg, Color3.fromRGB(218,165,32))
    end

    createTrackerGui()

    -- LIVE WATCH + WARNINGS + TRACERS + SOUND
    local lw, lt = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        lw, lt, lastAlertSound = lw + dt, lt + dt, lastAlertSound + dt

        if lw >= WARNING_INTERVAL then
            lw = 0
            local parts = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then table.insert(parts, hrp.Position) end
                end
            end
            for folder, info in pairs(animalData) do
                local btn = buttonMap[folder]
                if not btn or isConfirming[btn] then continue end
                local icon = ""
                for _, p in ipairs(parts) do
                    local d = (p - info.torso.Position).Magnitude
                    if d <= Settings.maxTrackDist then
                        icon = " 🚨"
                        if soundEnabled and lastAlertSound >= ALERT_SOUND_INTERVAL then
                            alertSound:Play()
                            lastAlertSound = 0
                        end
                        break
                    elseif d <= Settings.maxTrackDist * 1.5 then
                        icon = " ⚠️"
                    end
                end
                btn:SetAttribute("WarningIcon", icon)
                btn.Text = btn:GetAttribute("BaseText") .. icon
            end
        end

        if lt >= TRACE_INTERVAL then
            lt = 0
            local cam    = Workspace.CurrentCamera
            local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
            for folder, data in pairs(tracerData) do
                data.line.Visible = Workspace:FindFirstChild("__PeltESP", true) and true or false
                if data.line.Visible then
                    local pos, vis = cam:WorldToViewportPoint(
                        animalData[folder].torso.Position + Vector3.new(0, animalData[folder].torso.Size.Y/2, 0)
                    )
                    if vis then
                        data.line.From = center
                        data.line.To   = Vector2.new(pos.X, pos.Y)
                    end
                end
            end
        end
    end)

    -- TOGGLE GUI WITH F7
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F7 then
            createTrackerGui()
        end
    end)
end

-- Run immediately on paste
PeltTracker.init()
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
    if not LocalPlayer then warn("[PeltTracker] No LocalPlayer"); return end
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
    local trackerGui, trackerOpen, listFrame, rebuildPending, minimized
    rebuildPending, minimized = false, false

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg   = (r+g+b)/3

        if r>=whiteThreshold and g>=whiteThreshold and b>=whiteThreshold then
            return "White", true
        end
        if r>=70 and g<=50 and b<=50 then
            return "Crimson", true
        end
        if (b>=200 and r<=80 and g<=80) or (b>r and b>g and avg<100) then
            return "Azure", true
        end

        -- new exact matches
        if r==63  and g==62  and b==51  then return "Glade",    false end
        if r==71  and g==51  and b==51  then return "Hazel",    false end
        if r==99  and g==89  and b==70  then return "Kermode",  false end
        if r==105 and g==115 and b==125 then return "Silver",   false end
        if r==138 and g==83  and b==60  then return "Cinnamon", false end
        if r==168 and g==130 and b==103 then return "Blonde",   false end
        if r==124 and g==80  and b==48  then return "Beige",    false end
        if r==168 and g==179 and b==211 then return "Polar",    true  end

        if r>=150 and g>=80 and g<=110 and b<=80 then
            return "Orange", false
        end
        if r<=50 and g<=50 and b<=50 then
            return "Black", false
        end
        if math.abs(r-g)<=20 and math.abs(r-b)<=20 and math.abs(g-b)<=20 then
            if avg>=140 then return "Grey", false else return "Dark Grey", false end
        end
        if r>=60 and g>=40 and b>=30 then
            if avg>=80 then return "Brown", false else return "Dark Brown", false end
        end
        return "Unknown", false
    end

    local function scanAll()
        animalData = {}
        local categories = { Azure={}, Crimson={}, Polar={}, White={} }
        local root = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs")
        root = root and root:FindFirstChild("Animals")
        if not root then warn("[PeltTracker] Animals folder not found"); return categories end

        for _, f in ipairs(root:GetChildren()) do
            if f:IsA("Folder") then
                local torso = f:FindFirstChild("Character") and f.Character:FindFirstChild("Torso")
                if torso then
                    local name, ex = classifyColor(torso.Color)
                    animalData[f] = { torso=torso, color=name, isExotic=ex, markers=nil }
                    if ex and categories[name] then
                        table.insert(categories[name], f.Name)
                    end
                end
            end
        end

        return categories
    end

    local function createNotification(title,message,bg)
        local gui = Instance.new("ScreenGui", PlayerGui); gui.ResetOnSpawn=false
        local f   = Instance.new("Frame", gui)
        f.Size       = UDim2.new(0,400,0,100)
        f.Position   = UDim2.new(1.05,0,0.75,0)
        f.AnchorPoint= Vector2.new(1,0)
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

    local function addMapMarker(folder)
        local info = animalData[folder]
        if info.markers then return end

        local part = Instance.new("Part", Workspace)
        part.Size         = Vector3.new(1,1,1)
        part.Anchored     = true
        part.CanCollide   = false
        part.Transparency = 0.7
        part.Color        = Settings.markerColor
        part.CFrame       = CFrame.new(info.torso.Position)

        local a0 = Instance.new("Attachment", part)
        local a1 = Instance.new("Attachment", Workspace.Terrain)
        a1.WorldPosition  = part.Position + Vector3.new(0,500,0)

        local beam = Instance.new("Beam", part)
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.FaceCamera  = true
        beam.Width0, beam.Width1 = 0.5, 0.5
        beam.Color      = Settings.markerBeamColor

        info.markers = { part=part, beam=beam, a0=a0, a1=a1 }
    end

    local function removeMapMarker(folder)
        local info = animalData[folder]
        if not info.markers then return end
        info.markers.beam:Destroy()
        info.markers.a0:Destroy()
        info.markers.a1:Destroy()
        info.markers.part:Destroy()
        info.markers = nil
    end

    local function toggleESP(folder)
        local info = animalData[folder]
        if not info then return false end

        local t = info.torso
        local existing = t:FindFirstChild("__PeltESP")
        if existing then
            existing:Destroy()
            tracerData[folder].line:Remove()
            tracerData[folder].box:Destroy()
            tracerData[folder] = nil
            return false
        end

        local box = Instance.new("BoxHandleAdornment", t)
        box.Name       = "__PeltESP"
        box.Adornee    = t
        box.AlwaysOnTop= true
        box.ZIndex     = 10
        box.Size       = t.Size * 5
        box.Color3     = Color3.fromRGB(57,255,20)
        box.Transparency = 0.7

        local cam    = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line   = Drawing.new("Line")
        line.Visible   = true
        line.Thickness = 2
        line.Color     = box.Color3
        line.From      = center
        line.To        = center

        tracerData[folder] = { box=box, line=line }
        return true
    end

    local function updateList()
        if not listFrame then return end
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                c:Destroy()
            end
        end
        table.clear(buttonMap)

        -- group by species prefix
        local groups = {}
        for f, info in pairs(animalData) do
            local sp = f.Name:match("([^_]+)_") or f.Name
            groups[sp] = groups[sp] or {}
            table.insert(groups[sp], f)
        end

        local species = {}
        for sp in pairs(groups) do
            table.insert(species, sp)
        end
        table.sort(species)

        local order = 1
        for _, sp in ipairs(species) do
            local hdr = Instance.new("TextLabel", listFrame)
            hdr.LayoutOrder         = order; order += 1
            hdr.Size                = UDim2.new(1,0,0,20)
            hdr.BackgroundTransparency = 1
            hdr.Font                = Enum.Font.GothamBold
            hdr.TextSize            = 16
            hdr.TextColor3          = Color3.new(1,1,1)
            hdr.TextXAlignment      = Enum.TextXAlignment.Center
            hdr.Text                = "─── " .. sp .. " ───"

            for _, folder in ipairs(groups[sp]) do
                local info = animalData[folder]
                local btn = Instance.new("TextButton", listFrame)
                btn.LayoutOrder        = order; order += 1
                btn.Size               = UDim2.new(1,0,0,28)
                btn.BackgroundColor3   = Color3.fromRGB(45,45,45)
                btn.BorderSizePixel    = 0
                btn.Font               = Enum.Font.SourceSansSemibold
                btn.TextSize           = 16
                btn.RichText           = true

                local r,g,b = toRGB(info.torso.Color)
                local hex   = string.format("%02X%02X%02X", r, g, b)
                local prefix= string.format("<font color=\"#%s\">●</font> ", hex)
                local baseText = prefix .. folder.Name .. " — " .. info.color

                btn:SetAttribute("BaseText", baseText)
                btn:SetAttribute("WarningIcon", "")

                btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                    and info.torso.Color
                    or (info.isExotic and exoticTextColor or Color3.new(1,1,1))

                btn.Text = baseText
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

                buttonMap[folder] = btn

                -- LEFT CLICK: ESP toggle
                btn.MouseButton1Click:Connect(function()
                    isConfirming[btn] = true
                    local added = toggleESP(folder)
                    btn.Text = baseText .. "  " .. (added and "✅ ESP Enabled!" or "❌ ESP Disabled!")
                    btn.TextColor3 = Color3.fromRGB(50,255,50)
                    delay(1.5, function()
                        isConfirming[btn] = nil
                        btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                            and info.torso.Color
                            or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                        btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                    end)
                end)

                -- RIGHT CLICK: teleport
                btn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton2 then
                        isConfirming[btn] = true
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = info.torso.CFrame + Vector3.new(0,3,0) end
                        btn.Text = baseText .. "  📍 Teleported!"
                        btn.TextColor3 = Color3.new(1,1,0)
                        delay(1.5, function()
                            isConfirming[btn] = nil
                            btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                                and info.torso.Color
                                or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                            btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                        end)
                    end
                end)

                -- MIDDLE CLICK: map marker
                btn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton3 then
                        isConfirming[btn] = true
                        if info.markers then
                            removeMapMarker(folder)
                            btn.Text = baseText .. "  ➖ Marker Removed!"
                        else
                            addMapMarker(folder)
                            btn.Text = baseText .. "  ➕ Marker Placed!"
                        end
                        btn.TextColor3 = Color3.fromRGB(255,50,50)
                        delay(2.5, function()
                            isConfirming[btn] = nil
                            btn.TextColor3 = info.torso:FindFirstChild("__PeltESP")
                                and info.torso.Color
                                or (info.isExotic and exoticTextColor or Color3.new(1,1,1))
                            btn.Text = btn:GetAttribute("BaseText") .. btn:GetAttribute("WarningIcon")
                        end)
                    end
                end)
            end
        end
    end

    local function createTrackerGui()
        if trackerGui and trackerOpen then
            trackerGui:Destroy()
            trackerGui, trackerOpen = nil, false
            return
        end

        trackerGui = Instance.new("ScreenGui", PlayerGui)
        trackerOpen = true

        local main = Instance.new("Frame", trackerGui)
        main.Name               = "MainFrame"
        main.Size               = UDim2.new(0,360,0,500)
        main.Position           = UDim2.new(0.65,0,0,100)
        main.BackgroundColor3   = Color3.fromRGB(25,25,25)
        main.BorderSizePixel    = 0
        main.Active, main.Draggable = true, true
        Instance.new("UICorner", main).CornerRadius = UDim.new(0,8)

        local count = 0
        for _ in pairs(animalData) do count += 1 end

        local hdr = Instance.new("TextLabel", main)
        hdr.Size              = UDim2.new(0.75,-10,0,28)
        hdr.Position          = UDim2.new(0,10,0,0)
        hdr.BackgroundTransparency = 1
        hdr.Font              = Enum.Font.GothamBold
        hdr.TextSize          = 18
        hdr.TextColor3        = Color3.new(1,1,1)
        hdr.TextXAlignment    = Enum.TextXAlignment.Left
        hdr.Text              = string.format("Tracker - %d found", count)

        local minBtn = Instance.new("TextButton", main)
        minBtn.Size            = UDim2.new(0,28,0,28)
        minBtn.Position        = UDim2.new(1,-32,0,0)
        minBtn.BackgroundTransparency = 1
        minBtn.Font            = Enum.Font.GothamBold
        minBtn.TextSize        = 18
        minBtn.TextColor3      = Color3.new(1,1,1)
        minBtn.Text            = "➖"
        minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            listFrame.Visible = not minimized
            minBtn.Text = minimized and "➕" or "➖"
            local newSize = minimized and UDim2.new(0,360,0,30) or UDim2.new(0,360,0,500)
            TweenService:Create(main, TweenInfo.new(0.3,Enum.EasingStyle.Quad), { Size=newSize }):Play()
        end)

        local btnConfigs = {
            { icon="🔊", onClick=function(b)
                soundEnabled = not soundEnabled
                b.TextColor3  = soundEnabled and Color3.fromRGB(0,255,0) or Color3.new(1,1,1)
            end },
            { icon="⚙️", onClick=function()
                createNotification("Settings","(coming soon)", Color3.fromRGB(70,70,70))
            end },
            { icon="⏬", onClick=function()
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame + Vector3.new(0, TELEPORT_DOWN_DIST, 0) end
            end },
            { icon="🔄", onClick=function()
                if not rebuildPending then
                    rebuildPending = true
                    scanAll()
                    updateList()
                    delay(0.5, function() rebuildPending = false end)
                end
            end },
        }

        for i, conf in ipairs(btnConfigs) do
            local b = Instance.new("TextButton", main)
            b.Size              = UDim2.new(0,28,0,28)
            b.Position          = UDim2.new(1, -32*(i+1), 0, 0)
            b.BackgroundTransparency = 1
            b.Font              = Enum.Font.GothamBold
            b.TextSize          = 18
            b.TextColor3        = Color3.new(1,1,1)
            b.Text              = conf.icon
            b.MouseButton1Click:Connect(function() conf.onClick(b) end)
        end

        listFrame = Instance.new("ScrollingFrame", main)
        listFrame.Name               = "List"
        listFrame.Size               = UDim2.new(1,-16,1,-40)
        listFrame.Position           = UDim2.new(0,8,0,32)
        listFrame.BackgroundTransparency = 1
        listFrame.ScrollBarThickness = 6
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0,6)

        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding    = UDim.new(0,4)
        layout.SortOrder  = Enum.SortOrder.LayoutOrder
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            listFrame.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
        end)

        updateList()
    end

    -- INITIAL SETUP: BIG EXOTIC NOTIFICATION
    local cats = scanAll()
    local msg  = ""
    for _, col in ipairs({"Azure","Crimson","Polar","White"}) do
        local list = cats[col]
        if #list > 0 then
            msg = msg .. string.format("• %s (%d): %s\n", col, #list, table.concat(list, ", "))
        end
    end
    if msg == "" then
        createNotification("Exotic Pelts Detected", "No Exotic Pelts Detected.", Color3.fromRGB(80,80,80))
    else
        createNotification("Exotic Pelts Detected", msg, Color3.fromRGB(218,165,32))
    end

    createTrackerGui()

    -- LIVE WATCH + WARNINGS + TRACERS + SOUND
    local lw, lt = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        lw, lt, lastAlertSound = lw + dt, lt + dt, lastAlertSound + dt

        if lw >= WARNING_INTERVAL then
            lw = 0
            local parts = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then table.insert(parts, hrp.Position) end
                end
            end
            for folder, info in pairs(animalData) do
                local btn = buttonMap[folder]
                if not btn or isConfirming[btn] then continue end
                local icon = ""
                for _, p in ipairs(parts) do
                    local d = (p - info.torso.Position).Magnitude
                    if d <= Settings.maxTrackDist then
                        icon = " 🚨"
                        if soundEnabled and lastAlertSound >= ALERT_SOUND_INTERVAL then
                            alertSound:Play()
                            lastAlertSound = 0
                        end
                        break
                    elseif d <= Settings.maxTrackDist * 1.5 then
                        icon = " ⚠️"
                    end
                end
                btn:SetAttribute("WarningIcon", icon)
                btn.Text = btn:GetAttribute("BaseText") .. icon
            end
        end

        if lt >= TRACE_INTERVAL then
            lt = 0
            local cam    = Workspace.CurrentCamera
            local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
            for folder, data in pairs(tracerData) do
                data.line.Visible = Workspace:FindFirstChild("__PeltESP", true) and true or false
                if data.line.Visible then
                    local pos, vis = cam:WorldToViewportPoint(
                        animalData[folder].torso.Position + Vector3.new(0, animalData[folder].torso.Size.Y/2, 0)
                    )
                    if vis then
                        data.line.From = center
                        data.line.To   = Vector2.new(pos.X, pos.Y)
                    end
                end
            end
        end
    end)

    -- TOGGLE GUI WITH F7
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F7 then
            createTrackerGui()
        end
    end)
end

-- Run immediately on paste
PeltTracker.init()
return PeltTracker
