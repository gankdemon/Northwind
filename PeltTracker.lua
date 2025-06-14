-- PeltTracker with new exotic and common pelts v1.17.2 + Tree & Gem Tracker v1.2
local PeltTracker = {}
function PeltTracker.init()
    --// ANIMAL PELT TRACKER with Supercharged Extras v1.17.2 + Trees & Gems //--
    print("[PeltTracker] Supercharged v1.17.2 starting...")

    -- CONFIG
    local whiteThreshold       = 240
    local WARNING_INTERVAL     = 0.1
    local TRACE_INTERVAL       = 0.1
    local ALERT_SOUND_INTERVAL = 1.0
    local TREE_TELEPORT_OFFSET = Vector3.new(10, 0, 0)
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
    local animalData     = {}   -- folder → { torso, color, isExotic, markers }
    local treeData       = {}   -- array of tree models
    local gemData        = {}   -- array of ore instances
    local buttonMap      = {}   -- folder/model → TextButton
    local tracerData     = {}   -- folder/model → { box, line }
    local treeTracerData = {}   -- model → { box, line }
    local trackerGui, trackerOpen
    local currentTab     = "Animals"
    local animalListFrame, treeListFrame, gemListFrame
    local tabButtons     = {}

    -- UTILITIES
    local function toRGB(c)
        return math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
    end

    local function classifyColor(c)
        local r,g,b = toRGB(c)
        local avg = (r+g+b)/3
        -- Exotic
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
        -- Common
        if math.abs(r-63)<=5  and math.abs(g-62)<=5  and math.abs(b-51)<=5  then return "Glade",    false end
        if math.abs(r-71)<=5  and math.abs(g-51)<=5  and math.abs(b-51)<=5  then return "Hazel",    false end
        if math.abs(r-99)<=5  and math.abs(g-89)<=5  and math.abs(b-70)<=5  then return "Kermode",  false end
        if math.abs(r-105)<=5 and math.abs(g-115)<=5 and math.abs(b-125)<=5 then return "Silver",   false end
        if math.abs(r-138)<=5 and math.abs(g-83)<=5  and math.abs(b-60)<=5  then return "Cinnamon", false end
        if math.abs(r-168)<=5 and math.abs(g-130)<=5 and math.abs(b-103)<=5 then return "Blonde",   false end
        if math.abs(r-124)<=5 and math.abs(g-80)<=5  and math.abs(b-48)<=5  then return "Beige",    false end
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
        local gui = Instance.new("ScreenGui", PlayerGui)
        gui.ResetOnSpawn = false
        local f = Instance.new("Frame", gui)
        f.Size = UDim2.new(0,400,0,100)
        f.Position = UDim2.new(1.05,0,0.75,0)
        f.AnchorPoint = Vector2.new(1,0)
        f.BackgroundColor3 = bg
        f.BorderSizePixel = 0
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
        local t = Instance.new("TextLabel", f)
        t.Size = UDim2.new(1,-20,0,28)
        t.Position = UDim2.new(0,10,0,8)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 20
        t.TextColor3 = Color3.new(1,1,1)
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = title
        local b = Instance.new("TextLabel", f)
        b.Size = UDim2.new(1,-20,0,40)
        b.Position = UDim2.new(0,10,0,36)
        b.BackgroundTransparency = 1
        b.Font = Enum.Font.Gotham
        b.TextSize = 16
        b.TextColor3 = Color3.new(1,1,1)
        b.TextWrapped = true
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextYAlignment = Enum.TextYAlignment.Top
        b.Text = message
        local ok = Instance.new("TextButton", f)
        ok.Size = UDim2.new(0,70,0,28)
        ok.Position = UDim2.new(1,-80,1,-40)
        ok.Font = Enum.Font.GothamBold
        ok.TextSize = 18
        ok.Text = "OK"
        ok.BackgroundColor3 = Color3.fromRGB(70,70,70)
        ok.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner", ok).CornerRadius = UDim.new(0,6)
        TweenService:Create(f, TweenInfo.new(0.6), {Position=UDim2.new(0.95,0,0.75,0)}):Play()
        ok.MouseButton1Click:Connect(function()
            TweenService:Create(f, TweenInfo.new(0.6), {Position=UDim2.new(1.05,0,0.75,0)}):Play()
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

    -- ESP & TRACER for animals
    local function toggleESP(folder)
        local info = animalData[folder]
        if not info then return false end
        local part = info.torso
        local existing = part:FindFirstChild("__PeltESP")
        if existing then
            existing:Destroy()
            if tracerData[folder] then
                tracerData[folder].line:Remove()
                tracerData[folder] = nil
            end
            return false
        end
        local box = Instance.new("BoxHandleAdornment", part)
        box.Name = "__PeltESP"; box.Adornee = part; box.AlwaysOnTop = true; box.ZIndex = 10
        box.Size = part.Size * 5; box.Color3 = Color3.fromRGB(57,255,20); box.Transparency = 0.7
        local cam = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line = Drawing.new("Line")
        line.Visible = true; line.Thickness = 2; line.Color = box.Color3
        line.From = center; line.To = center
        tracerData[folder] = {box = box, line = line}
        return true
    end

    -- UPDATE ANIMAL LIST
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
                local baseText = string.format("<font color=\"#%s\">●</font> %s — %s", hex, folder.Name, info.color)
                btn.Text = baseText
                btn.TextColor3 = info.isExotic and Color3.fromRGB(255,215,0) or Color3.new(1,1,1)
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
                buttonMap[folder] = btn
                btn.MouseButton1Click:Connect(function()
                    local ok = toggleESP(folder)
                    btn.Text = baseText .. (ok and "  ✅ ESP" or "  ❌ ESP")
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

    -- SCAN TREES (ignore Pine, Maple, Cedar, Alder)
    local function scanTrees()
        treeData = {}
        for _, rootName in ipairs({"StaticProps","TargetFilter"}) do
            local root = Workspace:FindFirstChild(rootName)
            local folder = root and root:FindFirstChild("Resources")
            if folder and folder:IsA("Folder") then
                for _, m in ipairs(folder:GetChildren()) do
                    local lname = m.Name:lower()
                    if m:IsA("Model")
                       and lname:match("tree")
                       and not lname:match("pine tree")
                       and not lname:match("maple")
                       and not lname:match("cedar")
                       and not lname:match("alder") then
                        table.insert(treeData, m)
                    end
                end
            end
        end
        return treeData
    end

    -- ESP & TRACER for trees
    local function toggleTreeESP(model)
        local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not part then return false end
        local existing = part:FindFirstChild("__TreeESP")
        if existing then
            existing:Destroy()
            if treeTracerData[model] then
                treeTracerData[model].line:Remove()
                treeTracerData[model] = nil
            end
            return false
        end
        local box = Instance.new("BoxHandleAdornment", part)
        box.Name = "__TreeESP"; box.Adornee = part; box.AlwaysOnTop = true; box.ZIndex = 10
        box.Size = part.Size * 1.2; box.Color3 = Color3.fromRGB(0,200,255); box.Transparency = 0.5
        local cam = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local line = Drawing.new("Line")
        line.Visible = true; line.Thickness = 2; line.Color = box.Color3
        line.From = center; line.To = center
        treeTracerData[model] = {box = box, line = line}
        return true
    end

    -- UPDATE TREE LIST
    local function updateTreeList()
        if not treeListFrame then return end
        for _, c in ipairs(treeListFrame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
        end
        local list = scanTrees()
        if #list == 0 then
            local lbl = Instance.new("TextLabel", treeListFrame)
            lbl.Size = UDim2.new(1,0,0,28); lbl.BackgroundTransparency = 1
            lbl.Font, lbl.TextSize, lbl.TextColor3 = Enum.Font.Gotham,16,Color3.new(1,1,1)
            lbl.Text = "No trees found in this server."
        else
            for _, m in ipairs(list) do
                local btn = Instance.new("TextButton", treeListFrame)
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundColor3, btn.BorderSizePixel = Color3.fromRGB(45,45,45),0
                btn.Font, btn.TextSize, btn.TextColor3 = Enum.Font.SourceSansSemibold,16,Color3.new(1,1,1)
                btn.Text = m.Name
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
                btn.MouseButton1Click:Connect(function()
                    if toggleTreeESP(m) then
                        btn.Text = m.Name.."  ✅ ESP"
                    else
                        btn.Text = m.Name.."  ❌ ESP"
                    end
                    delay(1.5, function() btn.Text = m.Name end)
                end)
                btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                            if part then
                                hrp.CFrame = part.CFrame * CFrame.new(TREE_TELEPORT_OFFSET)
                            end
                        end
                        btn.Text = m.Name.."  📍 TP"
                        delay(1.5, function() btn.Text = m.Name end)
                    end
                end)
            end
        end
    end

    -- Robust, logged gem scanner
local function scanGems()
    gemData = {}

    for _, rootName in ipairs({"StaticProps", "TargetFilter"}) do
        -- wait up to 5 seconds for the root + Resources folder to exist
        local root = Workspace:FindFirstChild(rootName) 
                  or Workspace:WaitForChild(rootName, 5)
        if not root then
            warn(("[PeltTracker]  ✖ couldn’t find Workspace.%s"):format(rootName))
            continue
        end

        local resources = root:FindFirstChild("Resources")
                       or root:WaitForChild("Resources", 5)
        if not resources then
            warn(("[PeltTracker]  ✖ %s.Resources missing"):format(rootName))
            continue
        end

        -- dump what deposits we see
        for _, deposit in ipairs(resources:GetChildren()) do
            if deposit:IsA("Model") and deposit.Name:lower():match("deposit") then
                print(("[PeltTracker] → Scanning deposit: %s"):format(deposit:GetFullName()))
                
                -- now scan every descendant under this deposit
                for _, node in ipairs(deposit:GetDescendants()) do
                    if node:IsA("BasePart") and node.Name:lower():match("uncut") then
                        table.insert(gemData, node)
                        print(("[PeltTracker]     • Found gem node: %s"):format(node:GetFullName()))
                    end
                end
            else
                -- uncomment if you want to see everything that *isn’t* a deposit
                -- print(("Skipping %s (%s)"):format(deposit.Name, deposit.ClassName))
            end
        end
    end

    print(("[PeltTracker] ◦ scanGems total found: %d"):format(#gemData))
    return gemData
end

    -- UPDATE GEM LIST (with ESP + teleport)
    local function updateGemList()
        if not gemListFrame then return end
        for _, c in ipairs(gemListFrame:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
        end
        local list = scanGems()
        if #list == 0 then
            local lbl = Instance.new("TextLabel", gemListFrame)
            lbl.Size = UDim2.new(1,0,0,28); lbl.BackgroundTransparency = 1
            lbl.Font, lbl.TextSize, lbl.TextColor3 = Enum.Font.Gotham,16,Color3.new(1,1,1)
            lbl.Text = "No gems found in this server."
        else
            for _, ore in ipairs(list) do
                local btn = Instance.new("TextButton", gemListFrame)
                btn.Size = UDim2.new(1,0,0,28)
                btn.BackgroundColor3, btn.BorderSizePixel = Color3.fromRGB(45,45,45),0
                btn.Font, btn.TextSize, btn.TextColor3 = Enum.Font.SourceSansSemibold,16,Color3.new(1,1,1)
                btn.Text = ore.Name
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

                local function toggleGemESP(model)
                    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                    if not part then return false end
                    local existing = part:FindFirstChild("__GemESP")
                    if existing then
                        existing:Destroy()
                        if tracerData[model] then
                            tracerData[model].line:Remove()
                            tracerData[model] = nil
                        end
                        return false
                    end
                    local box = Instance.new("BoxHandleAdornment", part)
                    box.Name = "__GemESP"; box.Adornee = part; box.AlwaysOnTop = true; box.ZIndex = 10
                    box.Size = part.Size * 1.2; box.Color3 = Color3.fromRGB(255,255,100); box.Transparency = 0.5
                    local cam = Workspace.CurrentCamera
                    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
                    local line = Drawing.new("Line")
                    line.Visible = true; line.Thickness = 2; line.Color = box.Color3
                    line.From = center; line.To = center
                    tracerData[model] = {box = box, line = line}
                    return true
                end

                btn.MouseButton1Click:Connect(function()
                    if toggleGemESP(ore) then
                        btn.Text = ore.Name .. "  ✅ ESP"
                    else
                        btn.Text = ore.Name .. "  ❌ ESP"
                    end
                    delay(1.5, function() btn.Text = ore.Name end)
                end)

                btn.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local part = ore.PrimaryPart or ore:FindFirstChildWhichIsA("BasePart")
                            if part then
                                hrp.CFrame = part.CFrame + Vector3.new(0,3,0)
                            end
                        end
                        btn.Text = ore.Name.."  📍 TP"
                        delay(1.5, function() btn.Text = ore.Name end)
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
        main.Position = UDim2.new(0.35,0,0.4,-52)
        main.BackgroundColor3 = Color3.fromRGB(25,25,25)
        main.Active, main.Draggable = true, true
        Instance.new("UICorner", main).CornerRadius = UDim.new(0,8)

        -- Header
        local hdr = Instance.new("TextLabel", main)
        hdr.Size = UDim2.new(0.75,-10,0,28)
        hdr.Position = UDim2.new(0,10,0,0)
        hdr.BackgroundTransparency = 1
        hdr.Font, hdr.TextSize, hdr.TextColor3 = Enum.Font.GothamBold,18,Color3.new(1,1,1)
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        hdr.Text = "Pelt tracker"

        -- Minimize button
        local minimized = false
        local listRef = nil
        local minBtn = Instance.new("TextButton", main)
        minBtn.Size = UDim2.new(0,28,0,28)
        minBtn.Position = UDim2.new(1,-32,0,0)
        minBtn.BackgroundTransparency = 1
        minBtn.Font, minBtn.TextSize, minBtn.TextColor3 = Enum.Font.GothamBold,18,Color3.new(1,1,1)
        minBtn.Text = "➖"
        minBtn.MouseButton1Click:Connect(function()
            minimized = not minimized
            -- hide/show the tab buttons and the current list frame, keep header and controls
            for _, b in pairs(tabButtons) do
                b.Visible = not minimized
            end
            if listRef then
                listRef.Visible = not minimized
            end
            minBtn.Text = minimized and "➕" or "➖"
            local newSize = minimized and UDim2.new(0,360,0,30) or UDim2.new(0,360,0,500)
            TweenService:Create(main, TweenInfo.new(0.3,Enum.EasingStyle.Quad), {Size=newSize}):Play()
        end)

        -- Control buttons 🔊 ⚙️ ⏬ 🔄
        local ctrlIcons = {"🔊","⚙️","⏬","🔄"}
        local ctrlFuncs = {
            function(b) soundEnabled = not soundEnabled; b.TextColor3 = soundEnabled and Color3.fromRGB(0,255,0) or Color3.new(1,1,1) end,
            function() createNotification("Settings","Coming soon",Color3.fromRGB(70,70,70)) end,
            function() local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then hrp.CFrame=hrp.CFrame*CFrame.new(0,TELEPORT_DOWN_DIST,0) end end,
            function()
                scanAll(); updateAnimalList()
                updateTreeList()
                updateGemList()
            end,
        }
        for i,icon in ipairs(ctrlIcons) do
            local b=Instance.new("TextButton", main)
            b.Size=UDim2.new(0,28,0,28); b.Position=UDim2.new(1,-32*(i+1),0,0)
            b.BackgroundTransparency=1; b.Font, b.TextSize, b.TextColor3=Enum.Font.GothamBold,18,Color3.new(1,1,1)
            b.Text=icon; b.MouseButton1Click:Connect(function() ctrlFuncs[i](b) end)
        end

        -- Tabs (rounded, no border)
        local tabs = {"Animals","Trees","Gems"}
        for i,name in ipairs(tabs) do
            local tbtn=Instance.new("TextButton", main)
            tbtn.Size=UDim2.new(0,100,0,24); tbtn.Position=UDim2.new(0,10+(i-1)*105,0,30)
            tbtn.BackgroundColor3=Color3.fromRGB(45,45,45); tbtn.BorderSizePixel=0; tbtn.AutoButtonColor=false
            tbtn.Font, tbtn.TextSize, tbtn.TextColor3=Enum.Font.GothamBold,14,Color3.new(1,1,1)
            tbtn.Text=name; Instance.new("UICorner", tbtn).CornerRadius=UDim.new(0,6)
            tabButtons[name]=tbtn
            tbtn.MouseButton1Click:Connect(function()
                currentTab=name
                animalListFrame.Visible=(name=="Animals")
                treeListFrame.Visible=(name=="Trees")
                gemListFrame.Visible=(name=="Gems")
                hdr.Text=name.." Tracker"
                for _,b in pairs(tabButtons) do
                    b.BackgroundColor3=(b==tbtn) and Color3.fromRGB(70,70,70) or Color3.fromRGB(45,45,45)
                end
                listRef = ({Animals=animalListFrame, Trees=treeListFrame, Gems=gemListFrame})[name]
            end)
        end

        -- List frames factory
        local function makeList()
            local f=Instance.new("ScrollingFrame", main)
            f.Size=UDim2.new(1,-16,1,-60); f.Position=UDim2.new(0,8,0,60)
            f.BackgroundTransparency=1; f.ScrollBarThickness=6
            Instance.new("UICorner", f).CornerRadius=UDim.new(0,6)
            local layout=Instance.new("UIListLayout", f)
            layout.Padding=UDim.new(0,4); layout.SortOrder=Enum.SortOrder.LayoutOrder
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                f.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
            end)
            return f
        end

        animalListFrame=makeList()
        treeListFrame=makeList()
        gemListFrame=makeList()
        treeListFrame.Visible=false
        gemListFrame.Visible=false
        listRef=animalListFrame

        -- Initial population
        scanAll(); updateAnimalList(); updateTreeList(); updateGemList()
    end

    -- INITIAL SETUP + NOTIFICATIONS
    local azure, crimson, white, polar = scanAll()
    if #azure   > 0 then createNotification("Azure Pelts Detected",   ("Found %d Azure: %s"):format(#azure,   table.concat(azure,",")),   Color3.fromRGB(0,0,128)) end
    if #crimson > 0 then createNotification("Crimson Pelts Detected", ("Found %d Crimson: %s"):format(#crimson, table.concat(crimson,",")), Color3.fromRGB(220,20,60)) end
    if #white   > 0 then createNotification("White Pelts Detected",   ("Found %d White: %s"):format(#white,   table.concat(white,",")),   Color3.fromRGB(200,200,200)) end
    if #polar   > 0 then createNotification("Polar Pelts Detected",   ("Found %d Polar: %s"):format(#polar,   table.concat(polar,",")),   Color3.fromRGB(180,180,220)) end
    if #azure==0 and #crimson==0 and #white==0 and #polar==0 then
        createNotification("No Exotic Pelts","No Azure, Crimson, White, or Polar detected.",Color3.fromRGB(80,80,80))
    end
    createTrackerGui()

    -- LIVE WATCH + WARNINGS + TRACERS + SOUND
    local lw, lt = 0,0
    RunService.Heartbeat:Connect(function(dt)
        lw, lt, lastAlertSound = lw+dt, lt+dt, lastAlertSound+dt
        if lw >= WARNING_INTERVAL then
            lw = 0
            local parts = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl~=LocalPlayer and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then table.insert(parts, hrp.Position) end
                end
            end
            for folder, info in pairs(animalData) do
                local btn = buttonMap[folder]
                if not btn then continue end
                local icon = ""
                for _, ppos in ipairs(parts) do
                    local d=(ppos - info.torso.Position).Magnitude
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
                btn.Text = btn.Text:gsub(" 🚨",""):gsub(" ⚠️","")..icon
            end
        end
        if lt>=TRACE_INTERVAL then
            lt=0
            local cam=Workspace.CurrentCamera
            local center=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
            for _, data in pairs(tracerData) do
                data.line.Visible=true
                local pos,vis=cam:WorldToViewportPoint(data.box.Adornee.Position+Vector3.new(0,data.box.Adornee.Size.Y/2,0))
                if vis then
                    data.line.From=center; data.line.To=Vector2.new(pos.X,pos.Y)
                else
                    data.line.Visible=false
                end
            end
            for model,data in pairs(treeTracerData) do
                data.line.Visible=true
                local part=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if part then
                    local pos,vis=Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
                    if vis then
                        data.line.From=center; data.line.To=Vector2.new(pos.X,pos.Y)
                    else
                        data.line.Visible=false
                    end
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
