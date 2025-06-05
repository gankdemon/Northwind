-- TeleportHub.lua
-- A teleport hub UI based on the PeltTracker layout, with topbar buttons removed, toggleable via F8.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local function createTeleportHub(games)
    -- Calculate dynamic height: header + padding + buttons
    local buttonHeight = 30
    local padding = 5
    local headerHeight = 30
    local totalHeight = headerHeight + padding + #games * (buttonHeight + padding)
    local frameWidth = 300

    -- ScreenGui parented to CoreGui for exploit environments
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TeleportHub"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.Parent = game:GetService("CoreGui")

    -- Main window frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, frameWidth, 0, totalHeight)
    mainFrame.Position = UDim2.new(0.5, -frameWidth/2, 0.5, -totalHeight/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    mainFrame.Active = true
    mainFrame.Draggable = true

    -- Smooth corners for frame
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = mainFrame

    -- Title label
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, headerHeight)
    title.BackgroundTransparency = 1
    title.Text = "Teleport Hub"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.Parent = mainFrame

    -- Container for teleport buttons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ButtonContainer"
    buttonContainer.Size = UDim2.new(1, -padding*2, 1, -(headerHeight + padding*2))
    buttonContainer.Position = UDim2.new(0, padding, 0, headerHeight + padding)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, padding)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = buttonContainer

    -- Create a teleport button for each game
    for i, gameInfo in ipairs(games) do
        local btn = Instance.new("TextButton")
        btn.Name = "TeleportButton_" .. gameInfo.Name:gsub("%s+", "")
        btn.Size = UDim2.new(1, 0, 0, buttonHeight)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.BorderSizePixel = 0
        btn.Text = gameInfo.Name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 16
        btn.LayoutOrder = i
        btn.Parent = buttonContainer

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

        -- Smooth corners for buttons
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            TeleportService:Teleport(gameInfo.PlaceId, player)
        end)
    end

    -- Toggle visibility with F8
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
end

-- Defined game list with actual place names
local games = {
    { Name = "Isle of Rupert", PlaceId = 5465507265 },
    { Name = "Ellesmere", PlaceId = 5620227713 },
    { Name = "Cantermagne", PlaceId = 5620237741 },
    { Name = "Beauval", PlaceId = 5620237900 },
    { Name = "Stonemore", PlaceId = 6249721735 },
    { Name = "Event Isle", PlaceId = 105329650725789 }
}

createTeleportHub(games)
