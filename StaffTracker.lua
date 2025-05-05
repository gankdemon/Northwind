local StaffTracker = {}
function StaffTracker.init()
  --// NORTHWIND STAFF TRACKER v14 //--

-- CONFIG
local groupId           = 32704720
local notificationSound = "rbxassetid://6026984224"
local highRankSound     = "rbxassetid://2514375878"
local highRankThreshold = 200

-- SERVICES
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- SOLARA HTTP
local httpRequest = (syn and syn.request) or http_request or request

-- CLIPBOARD UTILITY
local function copyToClipboard(text)
    if syn and syn.set_clipboard then
        syn.set_clipboard(text)
    elseif setclipboard then
        setclipboard(text)
    end
end

-- STATE
local staffMembers = {}
local trackerGui, trackerOpen = nil, false
local listFrame
local sectionOrder
local sectionData

-- [[ HTTP FUNCTIONS ]]
local function httpGet(url)
    local ok, res = pcall(function() return httpRequest({ Url = url, Method = "GET" }) end)
    if not ok or not res or res.StatusCode ~= 200 then warn("StaffTracker HTTP GET failed:", res and res.StatusCode); return end
    return HttpService:JSONDecode(res.Body)
end

local function httpPost(url, body)
    local ok, res = pcall(function()
        return httpRequest({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(body) })
    end)
    if not ok or not res or res.StatusCode ~= 200 then warn("StaffTracker HTTP POST failed:", res and res.StatusCode); return end
    return HttpService:JSONDecode(res.Body)
end

-- [[ LOAD STAFF DATA ]]
local function loadStaffMembers()
    staffMembers = {}
    local rolesData = httpGet(("https://groups.roblox.com/v1/groups/%d/roles"):format(groupId))
    if not rolesData or not rolesData.roles then warn("StaffTracker: failed to fetch roles"); return end
    for _, role in ipairs(rolesData.roles) do
        local cursor
        repeat
            local url = ("https://groups.roblox.com/v1/groups/%d/roles/%d/users?limit=100%s"):format(groupId, role.id, cursor and "&cursor="..cursor or "")
            local page = httpGet(url)
            if page and page.data then
                for _, u in ipairs(page.data) do
                    staffMembers[u.userId] = { name = u.username, rankName = role.name, rankLevel = role.rank }
                end
            end
            cursor = page and page.nextPageCursor
            wait(0.3)
        until not cursor
    end
end

-- [[ NOTIFICATIONS ]]
local function createNotification(title, message, isHigh)
    local gui = Instance.new("ScreenGui", PlayerGui)
    gui.Name = "NW_StaffAlert"

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 420, 0, 120)
    frame.Position = UDim2.new(1.05, 0, 0.78, 0)
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.BackgroundColor3 = isHigh and Color3.fromRGB(120,20,20) or Color3.fromRGB(40,40,40)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.new(0,10,0,10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.TextColor3 = Color3.new(1,1,1)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local bodyLabel = Instance.new("TextLabel", frame)
    bodyLabel.Size = UDim2.new(1, -20, 0, 50)
    bodyLabel.Position = UDim2.new(0,10,0,45)
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Text = message
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.TextSize = 16
    bodyLabel.TextWrapped = true
    bodyLabel.TextColor3 = Color3.new(1,1,1)
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0,80,0,30)
    btn.Position = UDim2.new(1,-90,1,-40)
    btn.Text = "OK"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = Color3.fromRGB(70,70,70)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    local inTween = TweenService:Create(frame,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.95,0,0.78,0) }
    )
    inTween:Play()

    btn.MouseButton1Click:Connect(function()
        local outTween = TweenService:Create(frame,
            TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(1.05,0,0.78,0) }
        )
        outTween:Play()
        outTween.Completed:Wait()
        gui:Destroy()
    end)

    local snd = Instance.new("Sound", frame)
    snd.SoundId = isHigh and highRankSound or notificationSound
    snd.Volume = 1
    snd:Play()
end


-- [[ ALERT + LIVE UPDATE ]]
local function alertStaff(userId)
    local info = staffMembers[userId]; if not info then return end
    local isHigh = info.rankLevel >= highRankThreshold
    createNotification(isHigh and "‼ HIGH-RANK STAFF ‼" or "Staff Detected!", ("Name: %s  |  Rank: %s"):format(info.name, info.rankName), isHigh)
    if trackerOpen then updateList() end
end

-- [[ LIST UPDATE LOGIC ]]
function updateList()
    if not listFrame then return end
    for _, child in ipairs(listFrame:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
    local ids, presMap = {}, {}
    for id in pairs(staffMembers) do ids[#ids+1] = id end
    for i=1,#ids,50 do
        local chunk = { unpack(ids,i,math.min(i+49,#ids)) }
        local resp = httpPost("https://presence.roblox.com/v1/presence/users",{userIds=chunk})
        if resp and resp.userPresences then for _,e in ipairs(resp.userPresences) do presMap[e.userId]=(e.userPresenceType~=0) end end
        wait(0.1)
    end
    local orderIdx=1
    for _, rankName in ipairs(sectionOrder) do
        local title=Instance.new("TextLabel",listFrame)
        title.LayoutOrder=orderIdx;orderIdx+=1; title.Size=UDim2.new(1,0,0,20); title.BackgroundTransparency=1
        title.Text="─── "..rankName.." ───"; title.Font=Enum.Font.GothamBold; title.TextSize=16; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Center
        table.sort(sectionData[rankName].members,function(a,b)return a.name:lower()<b.name:lower()end)
        for _,mem in ipairs(sectionData[rankName].members) do
            local isOnline=presMap[mem.id] or false; local emoji=isOnline and "🔵" or "⚪"
            local original = ("%s %s [%d]"):format(emoji,mem.name,mem.id)
            local row=Instance.new("TextLabel",listFrame)
            row.LayoutOrder=orderIdx;orderIdx+=1; row.Size=UDim2.new(1,0,0,28); row.BackgroundColor3=Color3.fromRGB(45,45,45); row.BorderSizePixel=0
            row.Font=Enum.Font.SourceSansSemibold; row.TextSize=16; row.TextColor3=Color3.new(1,1,1); row.TextXAlignment=Enum.TextXAlignment.Left; row.TextYAlignment=Enum.TextYAlignment.Center
            row.TextWrapped=false; row.Text=original; Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)
            row.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 then
                    copyToClipboard("https://www.roblox.com/users/"..mem.id.."/profile")
                    row.Text="Profile link successfully copied"
                    spawn(function() wait(2) row.Text=original end)
                end
            end)
            row.MouseEnter:Connect(function() row.TextWrapped=true end)
            row.MouseLeave:Connect(function() row.TextWrapped=false end)
        end
    end
end

-- [[ BUILD/TOGGLE GUI ]]
function createTrackerGui()
    -- Toggle: close if already open
    if trackerGui and trackerOpen then
        trackerGui:Destroy(); trackerGui=nil; trackerOpen=false; return
    end
    -- Build new panel
    trackerGui = Instance.new("ScreenGui",PlayerGui); trackerGui.Name="NW_StaffTracker"; trackerOpen=true
    local main=Instance.new("Frame",trackerGui); main.Name="MainFrame"; main.Size=UDim2.new(0,320,1,0)
    main.Position=main.Position or UDim2.new(0.65,0,0,0); main.BackgroundColor3=Color3.fromRGB(25,25,25); main.BorderSizePixel=0
    Instance.new("UICorner",main).CornerRadius=UDim.new(0,8); main.Active,main.Draggable=true,true
    -- Header + Refresh
    local total=0;for _ in pairs(staffMembers)do total+=1 end
    local hdr=Instance.new("TextLabel",main)
    hdr.Size, hdr.Position = UDim2.new(1,-32,0,28), UDim2.new(0,0,0,0)
    hdr.BackgroundTransparency,hdr.Text=1,("Staff Tracker — %d members"):format(total)
    hdr.Font,hdr.TextSize,hdr.TextColor3,hdr.TextXAlignment=Enum.Font.GothamBold,18,Color3.new(1,1,1),Enum.TextXAlignment.Left
    local refreshBtn=Instance.new("TextButton",main)
    refreshBtn.Size,refreshBtn.Position=UDim2.new(0,28,0,28),UDim2.new(1,-32,0,0)
    refreshBtn.BackgroundTransparency,refreshBtn.Text,refreshBtn.Font,refreshBtn.TextSize,refreshBtn.TextColor3=1,"🔄",Enum.Font.GothamBold,18,Color3.new(1,1,1)
    refreshBtn.MouseButton1Click:Connect(updateList)
    -- List frame
    listFrame=Instance.new("ScrollingFrame",main); listFrame.Name="List"
    listFrame.Size,listFrame.Position=UDim2.new(1,-16,1,-40),UDim2.new(0,8,0,32)
    listFrame.BackgroundTransparency,listFrame.ScrollBarThickness=1,6
    Instance.new("UICorner",listFrame).CornerRadius=UDim.new(0,6)
    local layout=Instance.new("UIListLayout",listFrame)
    layout.Padding,layout.SortOrder=UDim.new(0,4),Enum.SortOrder.LayoutOrder
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize=UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+8)
    end)
    -- Prepare sections
    sectionData={}
    for id,info in pairs(staffMembers)do
        if not sectionData[info.rankName]then sectionData[info.rankName]={level=info.rankLevel,members={}} end
        table.insert(sectionData[info.rankName].members,{id=id,name=info.name})
    end
    sectionOrder={}
    for name,_ in pairs(sectionData)do table.insert(sectionOrder,name) end
    table.sort(sectionOrder,function(a,b) return sectionData[a].level>sectionData[b].level end)
    -- Initial populate
    updateList()
end

-- [[ EVENTS & INIT ]]
UserInputService.InputBegan:Connect(function(inp,gp)
    if not gp and inp.KeyCode==Enum.KeyCode.F6 then createTrackerGui() end
end)
Players.PlayerAdded:Connect(function(plr) wait(1) if staffMembers[plr.UserId]then alertStaff(plr.UserId) end end)
spawn(function() loadStaffMembers(); wait(1)
    local found=false
    for _,p in ipairs(Players:GetPlayers())do if staffMembers[p.UserId]then found=true;alertStaff(p.UserId)end end
    if not found then createNotification("No Staff Here","No NORTHWIND staff members are in this server.",false) end
end)

end
return StaffTracker
