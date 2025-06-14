-- PeltTracker with new exotic and common pelts v1.17 + Tree & Gem Tracker v1.0
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
    local treeData       = {}  -- list of tree Models
    local gemData        = {}  -- list of ore Instances
    local buttonMap      = {}  -- folder → TextButton
    local tracerData     = {}  -- folder → { box, line }
    local trackerGui, trackerOpen
    local currentTab     = "Animals"
    local animalListFrame, treeListFrame, gemListFrame

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
        f.BackgroundColor3 = bg; f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
        -- header
        local t = Instance.new("TextLabel", f)
        t.Size = UDim2.new(1,-20,0,28); t.Position = UDim2.new(0,10,0,8)
        t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 20
        t.TextColor3 = Color3.new(1,1,1); t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = title
        -- body
        local b = Instance.new("TextLabel", f)
        b.Size = UDim2.new(1,-20,0,40); b.Position = UDim2.new(0,10,0,36)
        b.BackgroundTransparency = 1; b.Font = Enum.Font.Gotham; b.TextSize = 16
        b.TextColor3 = Color3.new(1,1,1); b.TextWrapped = true
        b.TextXAlignment = Enum.TextXAlignment.Left; b.TextYAlignment = Enum.TextYAlignment.Top
        b.Text = message
        -- OK button
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
                        if name == "Azure"   then table.insert(azureList,   f.Name)
                        elseif name == "Crimson" then table.insert(crimsonList, f.Name)
                        elseif name == "White"   then table.insert(whiteList,   f.Name)
                        elseif name == "Polar"   then table.insert(polarList,   f.Name)
                        end
                    end
                end
            end
        end
        return azureList, crimsonList, whiteList, polarList
    end

    -- ESP & TRACER
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
        local box = Instance.new("BoxHandleAdornment", t)
        box.Name = "__PeltESP"; box.Adornee = t; box.AlwaysOnTop = true
        box.ZIndex = 10; box.Size = t.Size * 5; box.Color3 = Color3.fromRGB(57,255,20)
        box.Transparency = 0.7
        local cam = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line = Drawing.new("Line")
        line.Visible = true; line.Thickness = 2; line.Color = box.Color3
        line.From = center; line.To = center
        tracerData[folder] = { box = box, line = line }
        return true
    end

    -- BUILD & REFRESH ANIMAL LIST
    local function updateAnimalList()
        if not animalListFrame then return end
        for _, c in ipairs(animalListFrame:GetChildren()) do
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
            local hdr = Instance.new("TextLabel", animalListFrame)
            hdr.LayoutOrder = order; order += 1
            hdr.Size = UDim2.new(1,0,0,20)
            hdr.BackgroundTransparency = 1
            hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 16; hdr.TextColor3 = Color3.new(1,1,1)
            hdr.TextXAlignment = Enum.TextXAlignment.Center
            hdr.Text = "─── " .. sp .. " ───"

            for _, folder in ipairs(groups[sp]) do
                local info = animalData[folder]
                local btn = Instance.new("TextButton", animalListFrame)
                btn.LayoutOrder = order; order += 1
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.SourceSansSemibold; btn.TextSize = 16; btn.RichText = true

                local r,g,b = toRGB(info.torso.Color)
                local hex = string.format("%02X%02X%02X", r,g,b)
                local prefix = string.format("<font color=\"#%s\">●</font> ", hex)
                local base = prefix .. folder.Name .. " — " .. info.color
                btn.Text = base
                btn.TextColor3 = info.isExotic and Color3.fromRGB(255,215,0) or Color3.new(1,1,1)

                buttonMap[folder] = btn
                btn.MouseButton1Click:Connect(function()
                    local ok = toggleESP(folder)
                    btn.Text = base .. (ok and "  ✅ ESP" or "  ❌ ESP")
                end)
                btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = info.torso.CFrame + Vector3.new(0,3,0) end
                    end
                end)
            end
        end
    end

    -- TREE SCAN
    local function scanTrees()
        treeData = {}
        local roots = {
            Workspace:FindFirstChild("StaticProps") and Workspace.StaticProps.Resources,
            Workspace:FindFirstChild("TargetFilter") and Workspace.TargetFilter.Resources,
        }
        for _, folder in ipairs(roots) do
            if folder and folder:IsA("Folder") then
                for _, m in ipairs(folder:GetChildren()) do
                    if m:IsA("Model") and m.Name:lower():match("tree") then
                        table.insert(treeData, m)
                    end
                end
            end
        end
        return treeData
    end

    -- GEM SCAN
    local function scanGems()
        gemData = {}
        local roots = {
            Workspace:FindFirstChild("StaticProps") and Workspace.StaticProps.Resources,
            Workspace:FindFirstChild("TargetFilter") and Workspace.TargetFilter.Resources,
        }
        for _, folder in ipairs(roots) do
            if folder and folder:IsA("Folder") then
                for _, m in ipairs(folder:GetChildren()) do
                    if m:IsA("Model") and m.Name:lower():match("deposit") then
                        local ores = m:FindFirstChild("Ores")
                        if ores and ores:IsA("Folder") then
                            for _, ore in ipairs(ores:GetChildren()) do
                                if ore.Name:match("^Uncut") then
                                    table.insert(gemData, ore)
                                end
                            end
                        end
                    end
                end
            end
        end
        return gemData
    end

    -- LIST BUILDERS FOR TREES & GEMS
    local function clearFrame(frame)
        for _, c in ipairs(frame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                c:Destroy()
            end
        end
    end

    local function updateTreeList()
        if not treeListFrame then return end
        clearFrame(treeListFrame)
        if #scanTrees() == 0 then
            local lbl = Instance.new("TextLabel", treeListFrame)
            lbl.Size = UDim2.new(1,0,0,28)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 16; lbl.TextColor3 = Color3.new(1,1,1)
            lbl.Text = "No trees found in this server."
        else
            for _, m in ipairs(treeData) do
                local btn = Instance.new("TextLabel", treeListFrame)
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundTransparency = 1
                btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 16; btn.TextColor3 = Color3.new(1,1,1)
                btn.Text = m.Name
            end
        end
    end

    local function updateGemList()
        if not gemListFrame then return end
        clearFrame(gemListFrame)
        if #scanGems() == 0 then
            local lbl = Instance.new("TextLabel", gemListFrame)
            lbl.Size = UDim2.new(1,0,0,28)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 16; lbl.TextColor3 = Color3.new(1,1,1)
            lbl.Text = "No gems found in this server."
        else
            for _, ore in ipairs(gemData) do
                local btn = Instance.new("TextLabel", gemListFrame)
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundTransparency = 1
                btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 16; btn.TextColor3 = Color3.new(1,1,1)
                btn.Text = ore.Name
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
        main.Position = UDim2.new(0.35,0,0.4,-52)
        main.BackgroundColor3 = Color3.fromRGB(25,25,25)
        main.Active, main.Draggable = true, true
        Instance.new("UICorner", main).CornerRadius = UDim.new(0,8)

        -- Header & Minimize & Buttons (unchanged)
        -- … <your existing header/minimize/control code> …

        -- Tab Buttons (added)
        local tabs = {"Animals","Trees","Gems"}
        local tabButtons = {}
        for i,name in ipairs(tabs) do
            local tbtn = Instance.new("TextButton", main)
            tbtn.Size = UDim2.new(0,100,0,24)
            tbtn.Position = UDim2.new(0,10 + (i-1)*105,0,30)
            tbtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
            tbtn.Font, tbtn.TextSize, tbtn.TextColor3 = Enum.Font.GothamBold,14,Color3.new(1,1,1)
            tbtn.Text = name
            tabButtons[name] = tbtn
            tbtn.MouseButton1Click:Connect(function()
                currentTab = name
                animalListFrame.Visible = (name=="Animals")
                treeListFrame.Visible   = (name=="Trees")
                gemListFrame.Visible    = (name=="Gems")
                hdr.Text = name .. " Tracker"
                for _, b in pairs(tabButtons) do
                    b.BackgroundColor3 = (b==tbtn) and Color3.fromRGB(70,70,70) or Color3.fromRGB(45,45,45)
                end
            end)
        end

        -- Three list frames
        local function makeList()
            local f = Instance.new("ScrollingFrame", main)
            f.Size = UDim2.new(1,-16,1,-60)
            f.Position = UDim2.new(0,8,0,60)
            f.BackgroundTransparency = 1
            f.ScrollBarThickness = 6
            Instance.new("UICorner", f).CornerRadius = UDim.new(0,6)
            local layout = Instance.new("UIListLayout", f)
            layout.Padding = UDim.new(0,4)
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                f.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 8)
            end)
            return f
        end

        animalListFrame = makeList()
        treeListFrame   = makeList()
        gemListFrame    = makeList()
        treeListFrame.Visible = false
        gemListFrame.Visible  = false

        -- Initial population
        local a,z,w,p = scanAll()
        updateAnimalList()
        updateTreeList()
        updateGemList()
    end

    -- INITIAL SETUP + Notifications + GUI creation
    local azure, crimson, white, polar = scanAll()
    -- <your existing notification calls>
    createTrackerGui()

    -- LIVE WATCH + WARNINGS + TRACERS + SOUND
    -- <your existing RunService.Heartbeat code>

    -- F7 toggle
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Keyboard
          and inp.KeyCode == Enum.KeyCode.F7 then
            createTrackerGui()
        end
    end)
end

return PeltTracker
