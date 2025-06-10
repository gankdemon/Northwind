-- Treasure Chest Marker Tracker v1.3.2 -- Improvements: show message when no markers & auto-clear ESP on disappearance
print("[TreasureTracker] Script loaded. Initializing...")

-- CONFIGURATION
local TRACE_INTERVAL       = 0.1       -- how often to update tracer positions
local TELEPORT_OFFSET      = Vector3.new(0, 5, 0) -- teleport 5 studs above marker
local NOTIFY_DEBOUNCE      = 1.0       -- seconds between notifications
local ESP_COLOR            = Color3.new(1, 0, 0)    -- red
local TRACER_THICKNESS     = 2
local ENTRY_HEIGHT         = 28        -- height of a single list entry
local ENTRY_PADDING        = 4         -- vertical padding between entries
local HEADER_HEIGHT        = 28        -- height of header label
local FRAME_MAX_HEIGHT     = 500       -- maximum GUI height
local FRAME_WIDTH          = 360       -- fixed GUI width
local FRAME_MIN_HEIGHT     = HEADER_HEIGHT + 40 -- minimum GUI height

-- SERVICES
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local StarterGui        = game:GetService("StarterGui")

-- LOCAL PLAYER & GUI PARENT
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then warn("[TreasureTracker] No LocalPlayer found. Exiting.") return end
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- STATE TABLES
local markerData    = {} -- [markerInstance] = { espAdornment, tracer }
local buttonMap     = {} -- [markerInstance] = TextButton
local trackerGui
local listFrame
local lastNotifyTime = 0
local previousCount  = -1

-- WAIT FOR MARKERS FOLDER
local TargetFilter = Workspace:WaitForChild("TargetFilter", 5)
if not TargetFilter then warn("[TreasureTracker] workspace.TargetFilter not found. Exiting.") return end
local MARKERS_FOLDER = TargetFilter:WaitForChild("TreasureHuntMarkers", 5)
if not MARKERS_FOLDER then warn("[TreasureTracker] TreasureHuntMarkers folder not found. Exiting.") return end
print("[TreasureTracker] Found folder: workspace.TargetFilter.TreasureHuntMarkers")

-- UTILITIES --------------------------------------------------------------
local function sendNotification(text)
    local now = tick()
    if now - lastNotifyTime < NOTIFY_DEBOUNCE then return end
    lastNotifyTime = now
    StarterGui:SetCore("SendNotification", { Title = text, Text = "", Duration = 2 })
end

local function getDistance(part)
    local char = LocalPlayer.Character
    if not char or not part then return math.huge end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return math.huge end
    return (hrp.Position - part.Position).Magnitude
end

local function getAdorneePart(marker)
    if marker:IsA("BasePart") then return marker
    elseif marker:IsA("Model") then
        if marker.PrimaryPart then return marker.PrimaryPart end
        for _, d in ipairs(marker:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    end
    return nil
end

local function createESPAdornment(marker)
    local part = getAdorneePart(marker)
    if not part then return nil end
    local adorn = Instance.new("BoxHandleAdornment")
    adorn.Name         = "__TreasureESP"
    adorn.Adornee      = part
    adorn.AlwaysOnTop  = true
    adorn.ZIndex       = 10
    adorn.Size         = part.Size * 1.05
    adorn.Color3       = ESP_COLOR
    adorn.Transparency = 0.7
    adorn.Parent       = part
    return adorn
end

local function createTracer(marker)
    if type(Drawing) ~= "table" then return nil end
    local part = getAdorneePart(marker)
    if not part then return nil end
    local line = Drawing.new("Line")
    line.Color       = ESP_COLOR
    line.Thickness   = TRACER_THICKNESS
    line.Transparency= 1
    line.Visible     = true
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not line.Visible then conn:Disconnect() return end
        local cam = Workspace.CurrentCamera
        local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if onScreen then
            line.From = center
            line.To   = Vector2.new(screenPos.X, screenPos.Y)
            line.Visible = true
        else
            line.Visible = false
        end
    end)
    line.__conn = conn
    return line
end

local function toggleVisuals(marker)
    local data = markerData[marker]
    if data then
        -- remove
        if data.espAdornment   then data.espAdornment:Destroy() end
        if data.tracer and data.tracer.__conn then
            data.tracer.__conn:Disconnect()
            data.tracer:Remove()
        end
        markerData[marker] = nil
    else
        -- add
        local esp    = createESPAdornment(marker)
        local tracer = createTracer(marker)
        markerData[marker] = { espAdornment = esp, tracer = tracer }
    end
end

local function calculateFrameHeight(n)
    local entriesHeight = (n>0) and (n*ENTRY_HEIGHT + (n-1)*ENTRY_PADDING) or 0
    local total = HEADER_HEIGHT + 8 + entriesHeight + 20
    if total < FRAME_MIN_HEIGHT then return FRAME_MIN_HEIGHT end
    if total > FRAME_MAX_HEIGHT then return FRAME_MAX_HEIGHT end
    return total
end

-- REBUILDS GUI LIST ------------------------------------------------------
local function updateList()
    if not listFrame then return end
    -- Collect markers
    local markers = {}
    for _, inst in ipairs(MARKERS_FOLDER:GetChildren()) do
        if inst:IsA("BasePart") or inst:IsA("Model") then
            table.insert(markers, inst)
        end
    end
    -- Notify on change
    if #markers ~= previousCount then
        if #markers>0 then sendNotification(string.format("%d treasure chest markers found!", #markers))
        else sendNotification("No treasure chest markers found.") end
        previousCount = #markers
    end
    table.sort(markers, function(a,b) return a.Name < b.Name end)
    -- Resize frame
    local main = trackerGui.MainFrame
    main.Size      = UDim2.new(0, FRAME_WIDTH, 0, calculateFrameHeight(#markers))
    listFrame.Size = UDim2.new(1, -16, 0, main.Size.Y.Offset - 40)

    -- Clear old entries
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    buttonMap = {}

    -- If no markers: show message
    if #markers == 0 then
        local label = Instance.new("TextLabel")
        label.Size               = UDim2.new(1, -4, 0, ENTRY_HEIGHT)
        label.LayoutOrder        = 1
        label.BackgroundTransparency = 1
        label.Font               = Enum.Font.SourceSansSemibold
        label.TextSize           = 16
        label.TextColor3         = Color3.new(1,1,1)
        label.Text               = "No treasure chests in this server"
        label.Parent             = listFrame
        return
    end

    -- Populate entries
    for idx, marker in ipairs(markers) do
        local part = getAdorneePart(marker)
        local dist = getDistance(part)
        local btn = Instance.new("TextButton")
        btn.Name           = "Entry_"..idx
        btn.Size           = UDim2.new(1, -4, 0, ENTRY_HEIGHT)
        btn.LayoutOrder    = idx
        btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        btn.BorderSizePixel  = 0
        btn.Font            = Enum.Font.SourceSansSemibold
        btn.TextSize        = 16
        btn.TextColor3      = Color3.new(1,1,1)
        btn.Text            = string.format("Treasure chest marker %d — %.1f studs", idx, dist)
        btn.Parent          = listFrame
        -- rounded corners
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0,6)
        -- left-click toggles ESP
        btn.MouseButton1Click:Connect(function() toggleVisuals(marker) end)
        -- right-click teleport
        btn.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton2 then
                local char = LocalPlayer.Character
                if char and part then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = part.CFrame + TELEPORT_OFFSET end
                end
            end
        end)
        buttonMap[marker] = btn
    end
end

-- PER-FRAME UPDATES ------------------------------------------------------
local function onHeartbeat()
    if not listFrame or not trackerGui then return end
    -- Auto-cleanup ESP for removed markers
    for marker, data in pairs(markerData) do
        if not (marker and marker.Parent == MARKERS_FOLDER) then
            if data.espAdornment then data.espAdornment:Destroy() end
            if data.tracer then
                if data.tracer.__conn then data.tracer.__conn:Disconnect() end
                data.tracer:Remove()
            end
            markerData[marker] = nil
        end
    end

    -- Update header count
    local count  = #MARKERS_FOLDER:GetChildren()
    local header = trackerGui.MainFrame.Header
    if header then header.Text = string.format("Marker Tracker - %d found", count) end

    -- Refresh distances on existing buttons
    local markers = {}
    for _, inst in ipairs(MARKERS_FOLDER:GetChildren()) do
        if inst:IsA("BasePart") or inst:IsA("Model") then table.insert(markers, inst) end
    end
    table.sort(markers, function(a,b) return a.Name < b.Name end)
    for idx, marker in ipairs(markers) do
        local part = getAdorneePart(marker)
        local dist = getDistance(part)
        local btn = listFrame:FindFirstChild("Entry_"..idx)
        if btn then btn.Text = string.format("Treasure chest marker %d — %.1f studs", idx, dist) end
    end

    -- Rebuild list if count changed
    if count ~= previousCount then updateList() end

    -- Re-apply missing ESP/tracer for active markers
    for marker, data in pairs(markerData) do
        -- ensure ESP adorn exists
        if data.espAdornment then
            local adornee = data.espAdornment.Adornee
            if not (adornee and adornee.Parent) then
                data.espAdornment:Destroy()
                data.espAdornment = createESPAdornment(marker)
            end
        end
        -- ensure tracer exists
        if data.tracer then
            if not data.tracer.__conn or not data.tracer.Visible then
                data.tracer:Remove()
                data.tracer = createTracer(marker)
            end
        end
    end
end

-- GUI CREATION ----------------------------------------------------------
local function createTrackerGui()
    if trackerGui then trackerGui:Destroy() trackerGui = nil return end
    trackerGui = Instance.new("ScreenGui")
    trackerGui.Name   = "TreasureTrackerGUI"
    trackerGui.Parent = PlayerGui

    local main = Instance.new("Frame", trackerGui)
    main.Name            = "MainFrame"
    main.Size            = UDim2.new(0, FRAME_WIDTH, 0, FRAME_MIN_HEIGHT)
    main.Position        = UDim2.new(0.35, -352, 0.70, -474)
    main.BackgroundColor3= Color3.fromRGB(25,25,25)
    main.BorderSizePixel = 0
    main.Active          = true
    main.Draggable       = true
    local mainCorner = Instance.new("UICorner", main)
    mainCorner.CornerRadius = UDim.new(0,8)

    -- Header
    local hdr = Instance.new("TextLabel", main)
    hdr.Name     = "Header"
    hdr.Size     = UDim2.new(0.75, -10, 0, HEADER_HEIGHT)
    hdr.Position = UDim2.new(0,10,0,0)
    hdr.BackgroundTransparency=1
    hdr.Font     = Enum.Font.GothamBold
    hdr.TextSize = 18
    hdr.TextColor3=Color3.new(1,1,1)
    hdr.Text     = "Treasure Tracker - 0 found"

    -- Minimize button
    local minimized = false
    local minBtn = Instance.new("TextButton", main)
    minBtn.Name     = "Minimize"
    minBtn.Size     = UDim2.new(0,28,0,28)
    minBtn.Position = UDim2.new(1,-32,0,0)
    minBtn.BackgroundTransparency=1
    minBtn.Font     = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.TextColor3=Color3.new(1,1,1)
    minBtn.Text     = "➖"
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        listFrame.Visible = not minimized
        minBtn.Text = minimized and "➕" or "➖"
        local newSize = minimized and UDim2.new(0,FRAME_WIDTH,0,HEADER_HEIGHT+4)
                                    or UDim2.new(0,FRAME_WIDTH,0,calculateFrameHeight(previousCount))
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = newSize }):Play()
        mainCorner.CornerRadius = UDim.new(0, minimized and 15 or 8)
    end)

    -- Refresh button
    local refreshBtn = Instance.new("TextButton", main)
    refreshBtn.Size     = UDim2.new(0,28,0,28)
    refreshBtn.Position = UDim2.new(1, -128, 0, 0)
    refreshBtn.BackgroundTransparency=1
    refreshBtn.Font     = Enum.Font.GothamBold
    refreshBtn.TextSize = 18
    refreshBtn.TextColor3=Color3.new(1,1,1)
    refreshBtn.Text     = "🔄"
    refreshBtn.MouseButton1Click:Connect(updateList)

    -- ScrollingFrame
    listFrame = Instance.new("ScrollingFrame", main)
    listFrame.Name            = "List"
    listFrame.Size            = UDim2.new(1, -16, 0, FRAME_MIN_HEIGHT-40)
    listFrame.Position        = UDim2.new(0, 8, 0, 32)
    listFrame.BackgroundTransparency=1
    listFrame.ScrollBarThickness=6
    local listCorner = Instance.new("UICorner", listFrame)
    listCorner.CornerRadius = UDim.new(0,6)
    local layout = Instance.new("UIListLayout", listFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, ENTRY_PADDING)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    updateList()
end

-- INITIALIZE & RUN
createTrackerGui()
RunService.Heartbeat:Connect(onHeartbeat)
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Keyboard and inp.KeyCode==Enum.KeyCode.F6 then
        createTrackerGui()
    end
end)
