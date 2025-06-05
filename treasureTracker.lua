-- Treasure Chest Marker Tracker v1.3.1
-- Improvements to ESP/tracer reliability

print("[TreasureTracker] Script loaded. Initializing...")

-- CONFIGURATION
local TRACE_INTERVAL    = 0.1                 -- how often to update tracer positions
local TELEPORT_OFFSET   = Vector3.new(0, 5, 0) -- teleport 5 studs above marker
local NOTIFY_DEBOUNCE   = 1.0                 -- seconds between notifications
local ESP_COLOR         = Color3.new(1, 0, 0)  -- red
local TRACER_THICKNESS  = 2
local ENTRY_HEIGHT      = 28                  -- height of a single list entry
local ENTRY_PADDING     = 4                   -- vertical padding between entries
local HEADER_HEIGHT     = 28                  -- height of header label
local FRAME_MAX_HEIGHT  = 500                 -- maximum GUI height
local FRAME_WIDTH       = 360                 -- fixed GUI width
local FRAME_MIN_HEIGHT  = HEADER_HEIGHT + 40  -- minimum GUI height

-- SERVICES
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")

-- LOCAL PLAYER & GUI PARENT
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[TreasureTracker] No LocalPlayer found. Exiting.")
    return
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- STATE TABLES
local markerData     = {}   -- mapping: markerInstance → { espAdornment, tracer, tracerConnActive }
local buttonMap      = {}   -- mapping: markerInstance → TextButton
local trackerGui     -- our ScreenGui
local listFrame      -- ScrollingFrame inside the GUI
local lastNotifyTime = 0
local previousCount  = -1

-- WAIT FOR “TreasureHuntMarkers” FOLDER
local TargetFilter = Workspace:WaitForChild("TargetFilter", 5)
if not TargetFilter then
    warn("[TreasureTracker] workspace.TargetFilter not found after waiting. Exiting.")
    return
end

local MARKERS_FOLDER = TargetFilter:WaitForChild("TreasureHuntMarkers", 5)
if not MARKERS_FOLDER then
    warn("[TreasureTracker] TargetFilter.TreasureHuntMarkers not found after waiting. Exiting.")
    return
end

print("[TreasureTracker] Found folder: workspace.TargetFilter.TreasureHuntMarkers")

-- UTILITIES --------------------------------------------------------------

-- Debounced notification
local function sendNotification(text)
    local now = tick()
    if now - lastNotifyTime < NOTIFY_DEBOUNCE then
        return
    end
    lastNotifyTime = now
    StarterGui:SetCore("SendNotification", {
        Title    = text,
        Text     = "",
        Duration = 2
    })
end

-- Compute distance from player’s HRP to the given part
local function getDistance(part)
    local char = LocalPlayer.Character
    if not char then return math.huge end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not part then return math.huge end
    return (hrp.Position - part.Position).Magnitude
end

-- Return the BasePart to adorn (the marker itself if it’s a BasePart, or PrimaryPart/first BasePart if it’s a Model)
local function getAdorneePart(markerInstance)
    if markerInstance:IsA("BasePart") then
        return markerInstance
    elseif markerInstance:IsA("Model") then
        if markerInstance.PrimaryPart then
            return markerInstance.PrimaryPart
        end
        for _,desc in ipairs(markerInstance:GetDescendants()) do
            if desc:IsA("BasePart") then
                return desc
            end
        end
    end
    return nil
end

-- Creates a BoxHandleAdornment around the marker for ESP
local function createESPAdornment(markerInstance)
    local part = getAdorneePart(markerInstance)
    if not part then return nil end
    local adorn = Instance.new("BoxHandleAdornment")
    adorn.Name         = "__TreasureESP"
    adorn.Adornee      = part
    adorn.AlwaysOnTop  = true
    adorn.ZIndex       = 10
    adorn.Size         = part.Size * 1.05 -- 5% larger for padding
    adorn.Color3       = ESP_COLOR
    adorn.Transparency = 0.7
    adorn.Parent       = part
    return adorn
end

-- Creates a Drawing.Line tracer pointing to the marker
local function createTracer(markerInstance)
    if type(Drawing) ~= "table" then
        return nil
    end
    local part = getAdorneePart(markerInstance)
    if not part then return nil end

    local line = Drawing.new("Line")
    line.Color        = ESP_COLOR
    line.Thickness    = TRACER_THICKNESS
    line.Transparency = 1
    line.Visible      = true

    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not line.Visible then
            conn:Disconnect()
            return
        end
        local cam    = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if onScreen then
            line.From    = center
            line.To      = Vector2.new(screenPos.X, screenPos.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    end)

    line.__conn = conn
    return line
end

-- Toggles ESP & tracer for a given markerInstance
local function toggleVisuals(markerInstance)
    local data = markerData[markerInstance]
    if data and data.espAdornment then
        -- Remove existing adornment
        if data.espAdornment and data.espAdornment.Parent then
            data.espAdornment:Destroy()
        end
        -- Remove tracer if exists
        if data.tracer then
            if data.tracer.__conn then
                data.tracer.__conn:Disconnect()
            end
            data.tracer.Visible = false
            data.tracer:Remove()
        end
        markerData[markerInstance] = nil
    else
        -- Create new ESP + tracer
        local espAdorn = createESPAdornment(markerInstance)
        local tracer   = createTracer(markerInstance)
        markerData[markerInstance] = { espAdornment = espAdorn, tracer = tracer }
    end
end

-- Calculates the frame height based on the number of markers
local function calculateFrameHeight(nMarkers)
    -- total entries height = (n * ENTRY_HEIGHT) + ((n - 1) * ENTRY_PADDING)
    local entriesHeight = (nMarkers > 0) and (nMarkers * ENTRY_HEIGHT + (nMarkers - 1) * ENTRY_PADDING) or 0
    local totalHeight = HEADER_HEIGHT + 8 + entriesHeight + 20
    if totalHeight < FRAME_MIN_HEIGHT then
        return FRAME_MIN_HEIGHT
    elseif totalHeight > FRAME_MAX_HEIGHT then
        return FRAME_MAX_HEIGHT
    else
        return totalHeight
    end
end

-- REBUILDS the GUI list of all markers
local function updateList()
    if not listFrame then
        warn("[TreasureTracker] updateList called but listFrame is nil.")
        return
    end

    -- Gather all direct children of MARKERS_FOLDER, whether BasePart or Model
    local markers = {}
    for _, instance in ipairs(MARKERS_FOLDER:GetChildren()) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            table.insert(markers, instance)
        end
    end

    -- Notification if count changed
    if #markers ~= previousCount then
        if #markers > 0 then
            sendNotification(string.format("%d treasure chest markers found!", #markers))
        else
            sendNotification("No treasure chest markers found.")
        end
        previousCount = #markers
    end

    -- Sort by Name for stable ordering
    table.sort(markers, function(a, b)
        return a.Name < b.Name
    end)

    -- Resize main frame based on marker count
    local main = trackerGui:FindFirstChild("MainFrame")
    local newHeight = calculateFrameHeight(#markers)
    main.Size = UDim2.new(0, FRAME_WIDTH, 0, newHeight)
    listFrame.Size = UDim2.new(1, -16, 0, newHeight - 40)

    -- Clear existing entries
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    buttonMap = {}

    -- Create one TextButton per marker
    for idx, markerInstance in ipairs(markers) do
        local part = getAdorneePart(markerInstance)
        local dist = getDistance(part)

        local btn = Instance.new("TextButton")
        btn.Name             = "Entry_" .. idx
        btn.Size             = UDim2.new(1, -4, 0, ENTRY_HEIGHT)
        btn.LayoutOrder      = idx
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        btn.BorderSizePixel  = 0
        btn.Font             = Enum.Font.SourceSansSemibold
        btn.TextSize         = 16
        btn.TextColor3       = Color3.new(1, 1, 1)
        btn.Text             = string.format("Treasure chest marker %d — %.1f studs", idx, dist)
        btn.Parent           = listFrame

        -- Rounded corners
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        -- Left-click toggles ESP/tracer
        btn.MouseButton1Click:Connect(function()
            toggleVisuals(markerInstance)
        end)

        -- Right-click teleports above the marker
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                local char = LocalPlayer.Character
                if char and part then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = part.CFrame + TELEPORT_OFFSET
                    end
                end
            end
        end)

        buttonMap[markerInstance] = btn
    end

    -- Adjust CanvasSize
    local layout = listFrame.UIListLayout
    listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end

-- UPDATES distances & re-checks ESP/tracer each frame
local function onHeartbeat()
    if not listFrame or not trackerGui then
        return
    end

    -- Update header (count)
    local count = #MARKERS_FOLDER:GetChildren()
    local header = trackerGui:FindFirstChild("MainFrame"):FindFirstChild("Header")
    if header then
        header.Text = string.format("Treasure Tracker - %d found", count)
    end

    -- Refresh distances on buttons
    local markers = {}
    for _, instance in ipairs(MARKERS_FOLDER:GetChildren()) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            table.insert(markers, instance)
        end
    end
    table.sort(markers, function(a, b)
        return a.Name < b.Name
    end)
    for idx, markerInstance in ipairs(markers) do
        local part = getAdorneePart(markerInstance)
        local dist = getDistance(part)
        local btn  = listFrame:FindFirstChild("Entry_" .. idx)
        if btn then
            btn.Text = string.format("Treasure chest marker %d — %.1f studs", idx, dist)
        end
    end

    -- Rebuild list if count changed
    if count ~= previousCount then
        updateList()
    end

    -- Re-apply ESP/tracer for any enabled markers if they got removed or lost their adornee
    for markerInstance, data in pairs(markerData) do
        -- If the adornee was destroyed or replaced, recreate ESP adornment
        if data.espAdornment then
            local adornee = data.espAdornment.Adornee
            if not (adornee and adornee.Parent) then
                -- Adornee is gone, recreate
                data.espAdornment:Destroy()
                data.espAdornment = createESPAdornment(markerInstance)
            end
        end

        -- If tracer exists but connection broken, recreate
        if data.tracer then
            if not data.tracer.__conn or not data.tracer.Visible then
                data.tracer:Remove()
                data.tracer = createTracer(markerInstance)
            end
        end
    end
end

-- CREATES THE GUI (same layout as PeltTracker)
local function createTrackerGui()
    if trackerGui then
        trackerGui:Destroy()
        trackerGui = nil
        return
    end

    trackerGui = Instance.new("ScreenGui")
    trackerGui.Name   = "TreasureTrackerGUI"
    trackerGui.Parent = PlayerGui   -- swap to CoreGui if needed

    -- Main frame
    local main = Instance.new("Frame", trackerGui)
    main.Name              = "MainFrame"
    main.Size              = UDim2.new(0, FRAME_WIDTH, 0, FRAME_MIN_HEIGHT)
    main.Position          = UDim2.new(0.65, 0, 0, 100)
    main.BackgroundColor3  = Color3.fromRGB(25, 25, 25)
    main.BorderSizePixel   = 0
    main.Active            = true
    main.Draggable         = true
    local mainCorner = Instance.new("UICorner", main)
    mainCorner.CornerRadius = UDim.new(0, 8)

    -- Header (shows “Tracker – X found”)
    local hdr = Instance.new("TextLabel", main)
    hdr.Name              = "Header"
    hdr.Size              = UDim2.new(0.75, -10, 0, HEADER_HEIGHT)
    hdr.Position          = UDim2.new(0, 10, 0, 0)
    hdr.BackgroundTransparency = 1
    hdr.Font              = Enum.Font.GothamBold
    hdr.TextSize          = 18
    hdr.TextColor3        = Color3.new(1, 1, 1)
    hdr.TextXAlignment    = Enum.TextXAlignment.Left
    hdr.Text              = "Treasure Tracker - 0 found"

    -- Minimize button
    local minimized = false
    local minBtn = Instance.new("TextButton", main)
    minBtn.Name              = "Minimize"
    minBtn.Size              = UDim2.new(0, 28, 0, 28)
    minBtn.Position          = UDim2.new(1, -32, 0, 0)
    minBtn.BackgroundTransparency = 1
    minBtn.Font              = Enum.Font.GothamBold
    minBtn.TextSize          = 18
    minBtn.TextColor3        = Color3.new(1, 1, 1)
    minBtn.Text              = "➖"
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        listFrame.Visible = not minimized
        minBtn.Text = minimized and "➕" or "➖"
        local currentHeight = main.Size.Y.Offset
        local newSize = minimized
            and UDim2.new(0, FRAME_WIDTH, 0, HEADER_HEIGHT + 4)
            or UDim2.new(0, FRAME_WIDTH, 0, calculateFrameHeight(previousCount))
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = newSize }):Play()
        mainCorner.CornerRadius = UDim.new(0, minimized and 15 or 8)
    end)

    -- Refresh button (🔄)
    local refreshBtn = Instance.new("TextButton", main)
    refreshBtn.Size              = UDim2.new(0, 28, 0, 28)
    refreshBtn.Position          = UDim2.new(1, -32 * 4, 0, 0)
    refreshBtn.BackgroundTransparency = 1
    refreshBtn.Font              = Enum.Font.GothamBold
    refreshBtn.TextSize          = 18
    refreshBtn.TextColor3        = Color3.new(1, 1, 1)
    refreshBtn.Text              = "🔄"
    refreshBtn.MouseButton1Click:Connect(updateList)

    -- ScrollingFrame to hold the list
    listFrame = Instance.new("ScrollingFrame", main)
    listFrame.Name                   = "List"
    listFrame.Size                   = UDim2.new(1, -16, 0, FRAME_MIN_HEIGHT - 40)
    listFrame.Position               = UDim2.new(0, 8, 0, 32)
    listFrame.BackgroundTransparency = 1
    listFrame.ScrollBarThickness     = 6
    local listCorner = Instance.new("UICorner", listFrame)
    listCorner.CornerRadius = UDim.new(0, 6)

    -- UIListLayout stacks entries vertically
    local layout = Instance.new("UIListLayout", listFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, ENTRY_PADDING)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    updateList()
end

-- INITIALIZE GUI
createTrackerGui()

-- RUN LOOP: update header/count, distances every frame,
-- rebuild list if marker count changes, and reapply any missing ESP/tracer
RunService.Heartbeat:Connect(onHeartbeat)

-- TOGGLE GUI WITH F5
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == Enum.KeyCode.F5 then
        createTrackerGui()
    end
end)
