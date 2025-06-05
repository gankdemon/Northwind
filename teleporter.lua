-- TeleportHub.lua (v1.0)
----------------------
-- CONFIGURATION  --
----------------------
local ENTRY_HEIGHT      = 28                  -- height of each teleport button
local ENTRY_PADDING     = 4                   -- vertical padding between entries
local HEADER_HEIGHT     = 28                  -- height of header label
local FRAME_WIDTH       = 360                 -- fixed GUI width
local FRAME_MAX_HEIGHT  = 500                 -- maximum GUI height
local FRAME_MIN_HEIGHT  = HEADER_HEIGHT + 40  -- minimum GUI height (header + minimal padding)

----------------------
-- SERVICES & STATE --
----------------------
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local TeleportService    = game:GetService("TeleportService")

local LocalPlayer        = Players.LocalPlayer
if not LocalPlayer then
    warn("[TeleportHub] No LocalPlayer found. Exiting.")
    return
end

-- Parent the UI to CoreGui to ensure it appears in exploit executors
local GUI_PARENT         = game:GetService("CoreGui")

-- Will hold our ScreenGui and inner references
local teleportGui
local mainFrame
local listFrame
local headerLabel

-- Games configuration (Name and Roblox PlaceId)
local games = {
    { Name = "Isle of Rupert", PlaceId = 5465507265 },
    { Name = "Ellesmere",     PlaceId = 5620227713 },
    { Name = "Cantermagne",   PlaceId = 5620237741 },
    { Name = "Beauval",       PlaceId = 5620237900 },
    { Name = "Stonemore",     PlaceId = 6249721735 },
    { Name = "Event Isle",    PlaceId = 105329650725789 }
}

-------------------------------
-- UTILITY: CALCULATE HEIGHT --
-------------------------------
local function calculateFrameHeight(nEntries)
    -- Each entry takes ENTRY_HEIGHT + ENTRY_PADDING. Plus header + outer padding.
    local entriesHeight = (nEntries > 0) and (nEntries * ENTRY_HEIGHT + (nEntries - 1) * ENTRY_PADDING) or 0
    local totalHeight = HEADER_HEIGHT + 8 + entriesHeight + 20  -- 8px internal gap, 20px bottom padding
    if totalHeight < FRAME_MIN_HEIGHT then
        return FRAME_MIN_HEIGHT
    elseif totalHeight > FRAME_MAX_HEIGHT then
        return FRAME_MAX_HEIGHT
    else
        return totalHeight
    end
end

----------------------
-- BUILD UI METHOD --
----------------------
local function createTeleportHubUI()
    -- If GUI already exists, destroy it (toggle off)
    if teleportGui then
        teleportGui:Destroy()
        teleportGui = nil
        return
    end

    -- Create the ScreenGui
    teleportGui = Instance.new("ScreenGui")
    teleportGui.Name            = "TeleportHubUI"
    teleportGui.ResetOnSpawn    = false
    teleportGui.Parent          = GUI_PARENT

    -- Calculate initial frame height
    local entryCount  = #games
    local frameHeight = calculateFrameHeight(entryCount)

    -- Main window frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name               = "MainFrame"
    mainFrame.Size               = UDim2.new(0, FRAME_WIDTH, 0, frameHeight)
        -- Position the Teleport Hub at X = 35% of the screen, Y = 10% down from top
    mainFrame.AnchorPoint = Vector2.new(0, 0)
    mainFrame.Position    = UDim2.new(0.35, 0, 0.10, 0)

    mainFrame.BackgroundColor3   = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel    = 0
    mainFrame.Active             = true
    mainFrame.Draggable          = true
    mainFrame.Parent             = teleportGui

    -- Rounded corners for mainFrame
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent       = mainFrame

    -- Header label
    headerLabel = Instance.new("TextLabel")
    headerLabel.Name             = "Header"
    headerLabel.Size             = UDim2.new(0.75, -10, 0, HEADER_HEIGHT)
    headerLabel.Position         = UDim2.new(0, 10, 0, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Font             = Enum.Font.GothamBold
    headerLabel.TextSize         = 18
    headerLabel.TextColor3       = Color3.new(1,1,1)
    headerLabel.TextXAlignment   = Enum.TextXAlignment.Left
    headerLabel.Text              = "Teleport Hub – " .. tostring(entryCount) .. " games"
    headerLabel.Parent            = mainFrame

    -- Minimize button (➖ / ➕)
    local minimized = false
    local minBtn = Instance.new("TextButton", mainFrame)
    minBtn.Name              = "Minimize"
    minBtn.Size              = UDim2.new(0, 28, 0, 28)
    minBtn.Position          = UDim2.new(1, -32, 0, 0)
    minBtn.BackgroundTransparency = 1
    minBtn.Font              = Enum.Font.GothamBold
    minBtn.TextSize          = 18
    minBtn.TextColor3        = Color3.new(1,1,1)
    minBtn.Text              = "➖"
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        listFrame.Visible = not minimized
        minBtn.Text = minimized and "➕" or "➖"
        local targetHeight = minimized and (HEADER_HEIGHT + 8) or calculateFrameHeight(#games)
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, FRAME_WIDTH, 0, targetHeight)
        }):Play()
    end)

    -- Refresh button (🔄)
    local refreshBtn = Instance.new("TextButton", mainFrame)
    refreshBtn.Name              = "Refresh"
    refreshBtn.Size              = UDim2.new(0, 28, 0, 28)
    refreshBtn.Position          = UDim2.new(1, -32 * 4, 0, 0)
    refreshBtn.BackgroundTransparency = 1
    refreshBtn.Font              = Enum.Font.GothamBold
    refreshBtn.TextSize          = 18
    refreshBtn.TextColor3        = Color3.new(1,1,1)
    refreshBtn.Text              = "🔄"
    refreshBtn.MouseButton1Click:Connect(function()
        updateTeleportList()  -- defined below
    end)

    -- Container frame for teleport buttons
    listFrame = Instance.new("ScrollingFrame")
    listFrame.Name                   = "List"
    listFrame.Size                   = UDim2.new(1, -16, 0, frameHeight - (HEADER_HEIGHT + 8))
    listFrame.Position               = UDim2.new(0, 8, 0, HEADER_HEIGHT + 4)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel        = 0
    listFrame.ScrollBarThickness     = 6
    listFrame.Parent                 = mainFrame

    local listCorner = Instance.new("UICorner", listFrame)
    listCorner.CornerRadius = UDim.new(0, 6)

    -- UIListLayout stacks entries vertically
    local layout = Instance.new("UIListLayout", listFrame)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, ENTRY_PADDING)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    -- Build the initial list
    updateTeleportList()
end

--------------------------------
-- REBUILD LIST OF TELEPORTS --
--------------------------------
function updateTeleportList()
    if not listFrame or not teleportGui then
        return
    end

    -- Clear existing children
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    -- Gather games array (name + PlaceId)
    local sortedGames = {}
    for _, info in ipairs(games) do
        table.insert(sortedGames, info)
    end
    table.sort(sortedGames, function(a, b)
        return a.Name < b.Name
    end)

    -- Update header text with count
    local count = #sortedGames
    headerLabel.Text = "Teleport Hub – " .. tostring(count) .. " games"

    -- Resize mainFrame & listFrame based on count
    local newHeight = calculateFrameHeight(count)
    mainFrame.Size = UDim2.new(0, FRAME_WIDTH, 0, newHeight)
    listFrame.Size = UDim2.new(1, -16, 0, newHeight - (HEADER_HEIGHT + 8))

    -- Create one button per game
    for idx, gameInfo in ipairs(sortedGames) do
        local btn = Instance.new("TextButton")
        btn.Name             = "TeleportButton_" .. gameInfo.Name:gsub("%s+", "")
        btn.Size             = UDim2.new(1, 0, 0, ENTRY_HEIGHT)
        btn.LayoutOrder      = idx
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        btn.BorderSizePixel  = 0
        btn.Font             = Enum.Font.SourceSansSemibold
        btn.TextSize         = 16
        btn.TextColor3       = Color3.new(1, 1, 1)
        btn.Text             = gameInfo.Name
        btn.Parent           = listFrame

        -- Rounded corners on each entry
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent       = btn

        -- Teleport on left click
        btn.MouseButton1Click:Connect(function()
            TeleportService:Teleport(gameInfo.PlaceId, LocalPlayer)
        end)
    end
end

--------------------
-- INITIALIZATION --
--------------------
createTeleportHubUI()

-- Toggle GUI visibility with F8
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F8 then
        if teleportGui then
            teleportGui.Enabled = not teleportGui.Enabled
        end
    end
end)
