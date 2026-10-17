-- EVENTGROUP! Adopt Me Auto-Farm & Event Hub (Parser & Obfuscator Clean v17.1.0)
local success, err = pcall(function()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer

    local SCRIPT_VERSION = "v17.1.0"
    local isRunning = true

    local ScriptEnabled = false       -- Auto Pet Farm
    local BabyFarmEnabled = false     -- Auto Baby Farm
    local AutoHauntletRunning = false -- Auto Hauntlet 2
    local AutoGhostRunning = false    -- Auto Ghost Gallery
    local AutoCircusRunning = false   -- Auto Circus (Spotlight Minigame)
    local AutoCandycornRunning = false-- Auto Circus Candycorn Collector
    local AutoHotbarRunning = false   -- Auto Hotbar Button Clicker
    local AutoRewardsRunning = false  -- Auto Claim Rewards
    
    local ghostShootHoldDuration = 0.60
    local circusTeleportDelay = 0.05
    local HAUNTLET_TELEPORT_DELAY = 0.15
    local TELEPORT_OFFSET_Y = 3.0

    local isPausedForMinigame = false
    local inMinigameSession = false

    local TaskQueue = {}
    local CurrentExecutingTask = nil
    local ActiveDetectedTasks = {}

    local targetQueue = {}
    local SAFE_DISTANCE = 4
    local GHOST_HOLD_DURATION = 1.5

    _G.HauntletGhostBlacklist = _G.HauntletGhostBlacklist or {}

    local CASEOH_EXTRA_ASSET = "https://www.roblox.com/asset-thumbnail/image?assetId=16019271267&width=420&height=420&format=png"
    local RESOLVED_PLANK_TEXTURE = "rbxassetid://16019271267"

    pcall(function()
        local objects = game:GetObjects("rbxassetid://16019271267")
        if objects and objects[1] and objects[1]:IsA("Decal") then
            RESOLVED_PLANK_TEXTURE = objects[1].Texture
        end
    end)

    -- Forward declarations
    local consoleText = nil
    local statusLabel = nil
    local activeMinigameStatusLabel = nil

    local function logConsole(msg)
        if not isRunning then return end
        local timestamp = os.date("%H:%M:%S")
        local formatted = string.format("[%s] %s\n", timestamp, tostring(msg))
        pcall(function() print("[EventGroup] " .. tostring(msg)) end)
        pcall(function()
            if consoleText and consoleText.Parent then
                if #consoleText.Text > 15000 then
                    local lines = string.split(consoleText.Text, "\n")
                    local trimmed = {}
                    for i = math.max(1, #lines - 30), #lines do
                        table.insert(trimmed, lines[i])
                    end
                    consoleText.Text = table.concat(trimmed, "\n")
                end
                consoleText.Text = consoleText.Text .. formatted
            end
        end)
    end

    local UserFurniture = {
        dirty = {"CheapPetBathtub", "Shower", "PowerWash", "CampingShower"},
        sleepy = {"BasicCrib", "Crib", "PetBed", "SleepingBag"},
        hungry = {"PetFoodBowl", "FoodBowl"},
        drink = {"PetWaterBowl", "WaterBowl"},
        thirsty = {"PetWaterBowl", "WaterBowl"},
        toilet = {"Toilet"}
    }

    local IgnoredAilments = {
        rain_puddle = true,
        cloud = true,
        sunburn = true,
        snow = true,
        mystery = true
    }

    local function makeDraggable(handle, frame)
        local dragging, dragInput, dragStart, startPos
        if not handle or not frame then return end
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        handle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    local function applyHoverEffect(btn, originalColor, hoverColor)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = hoverColor}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.15), {TextColor3 = originalColor}):Play()
        end)
    end

    -- Stat Tracker GUI
    local statGui = Instance.new("ScreenGui")
    statGui.Name = "AdoptMeStatTracker"
    statGui.ResetOnSpawn = false
    statGui.Enabled = true

    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(statGui)
            statGui.Parent = CoreGui
        elseif gethui then
            statGui.Parent = gethui()
        else
            statGui.Parent = CoreGui
        end
    end)

    local statFrame = Instance.new("Frame")
    statFrame.Name = "MainFrame"
    statFrame.Size = UDim2.new(0, 260, 0, 225)
    statFrame.Position = UDim2.new(0, 15, 0, 80)
    statFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    statFrame.BackgroundTransparency = 0.15
    statFrame.BorderSizePixel = 0
    statFrame.Active = true
    statFrame.Parent = statGui

    local statCorner = Instance.new("UICorner")
    statCorner.CornerRadius = UDim.new(0, 6)
    statCorner.Parent = statFrame

    local statStroke = Instance.new("UIStroke")
    statStroke.Color = Color3.fromRGB(80, 80, 120)
    statStroke.Thickness = 1.2
    statStroke.Parent = statFrame

    local statTitle = Instance.new("TextLabel")
    statTitle.Size = UDim2.new(1, 0, 0, 22)
    statTitle.BackgroundTransparency = 1
    statTitle.Font = Enum.Font.SourceSansBold
    statTitle.Text = "  STATS DASHBOARD"
    statTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    statTitle.TextSize = 12
    statTitle.TextXAlignment = Enum.TextXAlignment.Left
    statTitle.Parent = statFrame

    makeDraggable(statTitle, statFrame)

    local statContainer = Instance.new("Frame")
    statContainer.Position = UDim2.new(0, 6, 0, 24)
    statContainer.Size = UDim2.new(1, -12, 1, -28)
    statContainer.BackgroundTransparency = 1
    statContainer.Parent = statFrame

    local statListLayout = Instance.new("UIListLayout")
    statListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statListLayout.Padding = UDim.new(0, 2)
    statListLayout.Parent = statContainer

    local function CreateStatRow(name, defaultText, order)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.LayoutOrder = order
        label.Size = UDim2.new(1, 0, 0, 18)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.SourceSans
        label.TextColor3 = Color3.fromRGB(210, 210, 230)
        label.TextSize = 11
        label.RichText = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = defaultText
        label.Parent = statContainer
        return label
    end

    local StatLabels = {
        Time = CreateStatRow("TimeLabel", "<b>Time:</b> 0h 0m 0s", 1),
        Bucks = CreateStatRow("BucksLabel", "<b>Bucks:</b> 0", 2),
        Hatched = CreateStatRow("HatchedLabel", "<b>Hatched:</b> 0", 3),
        Pet = CreateStatRow("PetLabel", "<b>Pet:</b> Active", 4),
        Progress = CreateStatRow("ProgressLabel", "<b>Progress:</b> Running", 5),
        ActiveTasks = CreateStatRow("ActiveTasksLabel", "<b>Active:</b> IDLE", 6),
        CurrentDoing = CreateStatRow("CurrentDoingLabel", "<b>Doing:</b> None", 7),
        Location = CreateStatRow("LocationLabel", "<b>Location:</b> Main Map", 8),
        MinigameStatus = CreateStatRow("MinigameStatusLabel", "<b>In Minigame:</b> No", 9),
    }

    -- Main Hub GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EventGroupGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function()
        if gethui then
            screenGui.Parent = gethui()
        elseif syn and syn.protect_gui then
            syn.protect_gui(statGui)
            statGui.Parent = CoreGui
        else
            statGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end)

    local loadingFrame = Instance.new("Frame")
    loadingFrame.Name = "LoadingFrame"
    loadingFrame.Size = UDim2.new(0, 320, 0, 170)
    loadingFrame.Position = UDim2.new(0.5, -160, 0.4, -85)
    loadingFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    loadingFrame.BorderSizePixel = 0
    loadingFrame.Active = true
    loadingFrame.ZIndex = 10
    loadingFrame.Parent = screenGui

    local loadingTopBar = Instance.new("Frame")
    loadingTopBar.Size = UDim2.new(1, 0, 0, 30)
    loadingTopBar.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    loadingTopBar.BorderSizePixel = 0
    loadingTopBar.ZIndex = 11
    loadingTopBar.Parent = loadingFrame

    local loadingTitle = Instance.new("TextLabel")
    loadingTitle.Size = UDim2.new(1, 0, 1, 0)
    loadingTitle.BackgroundTransparency = 1
    loadingTitle.Text = "EVENTGROUP! - Loader"
    loadingTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadingTitle.TextSize = 14
    loadingTitle.Font = Enum.Font.SourceSansBold
    loadingTitle.ZIndex = 12
    loadingTitle.Parent = loadingTopBar

    local loadingStatus = Instance.new("TextLabel")
    loadingStatus.Size = UDim2.new(1, -20, 0, 40)
    loadingStatus.Position = UDim2.new(0, 10, 0, 40)
    loadingStatus.BackgroundTransparency = 1
    loadingStatus.Text = "Initializing EVENTGROUP! engine..."
    loadingStatus.TextColor3 = Color3.fromRGB(240, 240, 240)
    loadingStatus.TextSize = 14
    loadingStatus.TextWrapped = true
    loadingStatus.Font = Enum.Font.SourceSans
    loadingStatus.ZIndex = 11
    loadingStatus.Parent = loadingFrame

    local progressBarBG = Instance.new("Frame")
    progressBarBG.Size = UDim2.new(1, -30, 0, 18)
    progressBarBG.Position = UDim2.new(0, 15, 0, 100)
    progressBarBG.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
    progressBarBG.BorderColor3 = Color3.fromRGB(60, 75, 95)
    progressBarBG.BorderSizePixel = 1
    progressBarBG.ZIndex = 11
    progressBarBG.Parent = loadingFrame

    local progressBarFill = Instance.new("Frame")
    progressBarFill.Size = UDim2.new(0, 0, 1, 0)
    progressBarFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    progressBarFill.BorderSizePixel = 0
    progressBarFill.ZIndex = 12
    progressBarFill.Parent = progressBarBG

    local progressPercent = Instance.new("TextLabel")
    progressPercent.Size = UDim2.new(1, 0, 1, 0)
    progressPercent.BackgroundTransparency = 1
    progressPercent.Text = "0%"
    progressPercent.TextColor3 = Color3.fromRGB(255, 255, 255)
    progressPercent.TextSize = 12
    progressPercent.Font = Enum.Font.SourceSansBold
    progressPercent.ZIndex = 13
    progressPercent.Parent = progressBarBG

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 270, 0, 870)
    mainFrame.Position = UDim2.new(0.5, -135, 0.08, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Visible = false
    mainFrame.ZIndex = 10
    mainFrame.Parent = screenGui

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 11
    topBar.Parent = mainFrame

    makeDraggable(topBar, mainFrame)

    local assetIcon = Instance.new("ImageLabel")
    assetIcon.Size = UDim2.new(0, 20, 0, 20)
    assetIcon.Position = UDim2.new(0, 6, 0, 5)
    assetIcon.BackgroundTransparency = 1
    assetIcon.Image = CASEOH_EXTRA_ASSET
    assetIcon.ZIndex = 12
    assetIcon.Parent = topBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -95, 1, 0)
    titleLabel.Position = UDim2.new(0, 32, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "EVENTGROUP!"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.ZIndex = 12
    titleLabel.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 1, 0)
    closeBtn.Position = UDim2.new(1, -30, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeBtn.TextSize = 15
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.ZIndex = 12
    closeBtn.Parent = topBar
    applyHoverEffect(closeBtn, Color3.fromRGB(220, 220, 220), Color3.fromRGB(255, 60, 60))

    closeBtn.MouseButton1Click:Connect(function()
        isRunning = false
        pcall(function() screenGui:Destroy() end)
        pcall(function() statGui:Destroy() end)
    end)

    local minimized = false
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 1, 0)
    minimizeBtn.Position = UDim2.new(1, -60, 0, 0)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Text = "_"
    minimizeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    minimizeBtn.TextSize = 18
    minimizeBtn.Font = Enum.Font.SourceSansBold
    minimizeBtn.ZIndex = 12
    minimizeBtn.Parent = topBar
    applyHoverEffect(minimizeBtn, Color3.fromRGB(220, 220, 220), Color3.fromRGB(0, 220, 255))

    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        for _, child in ipairs(mainFrame:GetChildren()) do
            if child ~= topBar and child:IsA("GuiObject") then
                child.Visible = not minimized
            end
        end
        mainFrame.Size = minimized and UDim2.new(0, 270, 0, 30) or UDim2.new(0, 270, 0, 870)
    end)

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, 0, 0, 26)
    tabBar.Position = UDim2.new(0, 0, 0, 30)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
    tabBar.BorderSizePixel = 0
    tabBar.ZIndex = 11
    tabBar.Parent = mainFrame

    local tabBtnFarm = Instance.new("TextButton")
    tabBtnFarm.Size = UDim2.new(0.5, 0, 1, 0)
    tabBtnFarm.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
    tabBtnFarm.Text = "Main Farm"
    tabBtnFarm.TextColor3 = Color3.fromRGB(0, 162, 255)
    tabBtnFarm.TextSize = 12
    tabBtnFarm.Font = Enum.Font.SourceSansBold
    tabBtnFarm.ZIndex = 15
    tabBtnFarm.Parent = tabBar

    local tabBtnOpener = Instance.new("TextButton")
    tabBtnOpener.Size = UDim2.new(0.5, 0, 1, 0)
    tabBtnOpener.Position = UDim2.new(0.5, 0, 0, 0)
    tabBtnOpener.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    tabBtnOpener.Text = "Event Box Opener"
    tabBtnOpener.TextColor3 = Color3.fromRGB(160, 175, 195)
    tabBtnOpener.TextSize = 12
    tabBtnOpener.Font = Enum.Font.SourceSansBold
    tabBtnOpener.ZIndex = 15
    tabBtnOpener.Parent = tabBar

    local farmContainer = Instance.new("ScrollingFrame")
    farmContainer.Size = UDim2.new(1, 0, 1, -56)
    farmContainer.Position = UDim2.new(0, 0, 0, 56)
    farmContainer.BackgroundTransparency = 1
    farmContainer.Visible = true
    farmContainer.CanvasSize = UDim2.new(0, 0, 0, 1250)
    farmContainer.ScrollBarThickness = 3
    farmContainer.ZIndex = 11
    farmContainer.Parent = mainFrame

    local openerContainer = Instance.new("Frame")
    openerContainer.Size = UDim2.new(1, 0, 1, -56)
    openerContainer.Position = UDim2.new(0, 0, 0, 56)
    openerContainer.BackgroundTransparency = 1
    openerContainer.Visible = false
    openerContainer.ZIndex = 11
    openerContainer.Parent = mainFrame

    tabBtnFarm.MouseButton1Click:Connect(function()
        farmContainer.Visible = true
        openerContainer.Visible = false
        tabBtnFarm.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
        tabBtnFarm.TextColor3 = Color3.fromRGB(0, 162, 255)
        tabBtnOpener.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
        tabBtnOpener.TextColor3 = Color3.fromRGB(160, 175, 195)
    end)

    tabBtnOpener.MouseButton1Click:Connect(function()
        farmContainer.Visible = false
        openerContainer.Visible = true
        tabBtnOpener.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
        tabBtnOpener.TextColor3 = Color3.fromRGB(0, 162, 255)
        tabBtnFarm.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
        tabBtnFarm.TextColor3 = Color3.fromRGB(160, 175, 195)
    end)

    local consoleContainer = Instance.new("ScrollingFrame")
    consoleContainer.Size = UDim2.new(1, -20, 0, 120)
    consoleContainer.Position = UDim2.new(0, 10, 0, 520)
    consoleContainer.BackgroundColor3 = Color3.fromRGB(22, 25, 32)
    consoleContainer.BorderColor3 = Color3.fromRGB(60, 70, 90)
    consoleContainer.BorderSizePixel = 1
    consoleContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    consoleContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    consoleContainer.ScrollBarThickness = 3
    consoleContainer.ZIndex = 11
    consoleContainer.Parent = farmContainer

    consoleText = Instance.new("TextLabel")
    consoleText.Size = UDim2.new(1, -6, 1, 0)
    consoleText.Position = UDim2.new(0, 3, 0, 0)
    consoleText.BackgroundTransparency = 1
    consoleText.Text = "[Console] Initialized successfully.\n"
    consoleText.TextColor3 = Color3.fromRGB(180, 200, 220)
    consoleText.TextSize = 10
    consoleText.Font = Enum.Font.Code
    consoleText.TextXAlignment = Enum.TextXAlignment.Left
    consoleText.TextYAlignment = Enum.TextYAlignment.Top
    consoleText.TextWrapped = true
    consoleText.ZIndex = 12
    consoleText.Parent = consoleContainer

    RunService.Stepped:Connect(function()
        if not isRunning then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in ipairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)

    local subHeader = Instance.new("TextLabel")
    subHeader.Size = UDim2.new(1, 0, 0, 20)
    subHeader.Position = UDim2.new(0, 0, 0, 4)
    subHeader.BackgroundTransparency = 1
    subHeader.Text = "Halloween Event Farm! by EVENTGROUP"
    subHeader.TextColor3 = Color3.fromRGB(0, 162, 255)
    subHeader.TextSize = 12
    subHeader.Font = Enum.Font.SourceSansBold
    subHeader.ZIndex = 11
    subHeader.Parent = farmContainer

    local function CreateToggleRow(nameText, posY, parent, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 140, 0, 26)
        label.Position = UDim2.new(0, 10, 0, posY)
        label.BackgroundTransparency = 1
        label.Text = nameText
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.SourceSansBold
        label.ZIndex, label.Parent = 11, parent

        local border = Instance.new("Frame")
        border.Size = UDim2.new(0, 22, 0, 22)
        border.Position = UDim2.new(1, -35, 0, posY + 2)
        border.BackgroundColor3 = Color3.fromRGB(55, 65, 80)
        border.BorderColor3 = Color3.fromRGB(110, 130, 155)
        border.ZIndex, border.Parent = 11, parent

        local square = Instance.new("Frame")
        square.Size = UDim2.new(0, 14, 0, 14)
        square.Position = UDim2.new(0, 4, 0, 4)
        square.BackgroundColor3 = Color3.fromRGB(55, 65, 80)
        square.BorderSizePixel = 0
        square.ZIndex, square.Parent = 12, border

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.ZIndex, btn.Parent = 13, border

        local active = false
        btn.MouseButton1Click:Connect(function()
            active = not active
            square.BackgroundColor3 = active and Color3.fromRGB(50, 225, 50) or Color3.fromRGB(55, 65, 80)
            if callback then pcall(function() callback(active) end) end
        end)

        return square, btn
    end

    CreateToggleRow("Auto Ghost Farm", 30, farmContainer, function(v) AutoGhostRunning = v end)

    local sliderContainer = Instance.new("Frame")
    sliderContainer.Size = UDim2.new(1, -20, 0, 45)
    sliderContainer.Position = UDim2.new(0, 10, 0, 60)
    sliderContainer.BackgroundTransparency = 1
    sliderContainer.ZIndex = 11
    sliderContainer.Parent = farmContainer

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size = UDim2.new(1, -10, 0, 20)
    sliderLabel.Position = UDim2.new(0, 20, 0, 0)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Text = "L  Ghost Shoot Hold: 0.60s"
    sliderLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
    sliderLabel.TextSize = 11
    sliderLabel.Font = Enum.Font.SourceSansBold
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.ZIndex = 12
    sliderLabel.Parent = sliderContainer

    local sliderBG = Instance.new("Frame")
    sliderBG.Size = UDim2.new(1, -20, 0, 10)
    sliderBG.Position = UDim2.new(0, 10, 0, 24)
    sliderBG.BackgroundColor3 = Color3.fromRGB(55, 65, 80)
    sliderBG.BorderSizePixel = 0
    sliderBG.ZIndex = 12
    sliderBG.Parent = sliderContainer

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0.6, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.ZIndex = 13
    sliderFill.Parent = sliderBG

    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(1, 0, 1, 0)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.ZIndex = 14
    sliderBtn.Parent = sliderBG

    local draggingSlider = false
    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - sliderBG.AbsolutePosition.X) / sliderBG.AbsoluteSize.X, 0, 1)
            sliderFill.Size = UDim2.new(pos, 0, 1, 0)
            ghostShootHoldDuration = math.round((pos * 1.0) * 100) / 100
            sliderLabel.Text = string.format("L  Ghost Shoot Hold: %.2fs", ghostShootHoldDuration)
        end
    end)

    CreateToggleRow("Auto Hauntlet 2", 110, farmContainer, function(v) AutoHauntletRunning = v end)
    CreateToggleRow("Auto Circus", 150, farmContainer, function(v) AutoCircusRunning = v end)
    CreateToggleRow("Auto Candycorn (Circus)", 190, farmContainer, function(v) AutoCandycornRunning = v end)
    CreateToggleRow("Auto Pet Farm", 230, farmContainer, function(v) ScriptEnabled = v end)
    CreateToggleRow("Auto Baby Farm", 270, farmContainer, function(v) BabyFarmEnabled = v end)
    CreateToggleRow("Auto Claim Rewards", 310, farmContainer, function(v) AutoRewardsRunning = v end)

    local circusSliderContainer = Instance.new("Frame")
    circusSliderContainer.Size = UDim2.new(1, -20, 0, 45)
    circusSliderContainer.Position = UDim2.new(0, 10, 0, 350)
    circusSliderContainer.BackgroundTransparency = 1
    circusSliderContainer.ZIndex = 11
    circusSliderContainer.Parent = farmContainer

    local circusSliderLabel = Instance.new("TextLabel")
    circusSliderLabel.Size = UDim2.new(1, -10, 0, 20)
    circusSliderLabel.Position = UDim2.new(0, 20, 0, 0)
    circusSliderLabel.BackgroundTransparency = 1
    circusSliderLabel.Text = "L  Circus Teleport Delay: 0.05s"
    circusSliderLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
    circusSliderLabel.TextSize = 11
    circusSliderLabel.Font = Enum.Font.SourceSansBold
    circusSliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    circusSliderLabel.ZIndex = 12
    circusSliderLabel.Parent = circusSliderContainer

    local circusSliderBG = Instance.new("Frame")
    circusSliderBG.Size = UDim2.new(1, -20, 0, 10)
    circusSliderBG.Position = UDim2.new(0, 10, 0, 24)
    circusSliderBG.BackgroundColor3 = Color3.fromRGB(55, 65, 80)
    circusSliderBG.BorderSizePixel = 0
    circusSliderBG.ZIndex = 12
    circusSliderBG.Parent = circusSliderContainer

    local circusSliderFill = Instance.new("Frame")
    circusSliderFill.Size = UDim2.new(0.1, 0, 1, 0)
    circusSliderFill.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    circusSliderFill.BorderSizePixel = 0
    circusSliderFill.ZIndex = 13
    circusSliderFill.Parent = circusSliderBG

    local circusSliderBtn = Instance.new("TextButton")
    circusSliderBtn.Size = UDim2.new(1, 0, 1, 0)
    circusSliderBtn.BackgroundTransparency = 1
    circusSliderBtn.Text = ""
    circusSliderBtn.ZIndex = 14
    circusSliderBtn.Parent = circusSliderBG

    local draggingCircusSlider = false
    circusSliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingCircusSlider = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingCircusSlider = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingCircusSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((input.Position.X - circusSliderBG.AbsolutePosition.X) / circusSliderBG.AbsoluteSize.X, 0, 1)
            circusSliderFill.Size = UDim2.new(pos, 0, 1, 0)
            circusTeleportDelay = math.round((pos * 0.5) * 1000) / 1000
            circusSliderLabel.Text = string.format("L  Circus Teleport Delay: %.3fs", circusTeleportDelay)
        end
    end)

    local statusBox = Instance.new("Frame")
    statusBox.Size = UDim2.new(1, -20, 0, 25)
    statusBox.Position = UDim2.new(0, 10, 0, 400)
    statusBox.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    statusBox.BorderColor3 = Color3.fromRGB(60, 70, 90)
    statusBox.BorderSizePixel = 1
    statusBox.ZIndex = 11
    statusBox.Parent = farmContainer

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Idle"
    statusLabel.TextColor3 = Color3.fromRGB(180, 200, 220)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.SourceSansBold
    statusLabel.ZIndex = 12
    statusLabel.Parent = statusBox

    local timerContainer = Instance.new("Frame")
    timerContainer.Size = UDim2.new(1, -20, 0, 95)
    timerContainer.Position = UDim2.new(0, 10, 0, 435)
    timerContainer.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
    timerContainer.BorderColor3 = Color3.fromRGB(60, 70, 90)
    timerContainer.BorderSizePixel = 1
    timerContainer.ZIndex = 11
    timerContainer.Parent = farmContainer

    local timerListLayout = Instance.new("UIListLayout")
    timerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    timerListLayout.Padding = UDim.new(0, 2)
    timerListLayout.Parent = timerContainer

    activeMinigameStatusLabel = Instance.new("TextLabel")
    activeMinigameStatusLabel.Size = UDim2.new(1, 0, 0, 22)
    activeMinigameStatusLabel.BackgroundTransparency = 1
    activeMinigameStatusLabel.Text = "  Active Minigame: Waiting..."
    activeMinigameStatusLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
    activeMinigameStatusLabel.TextSize = 11
    activeMinigameStatusLabel.Font = Enum.Font.Code
    activeMinigameStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    activeMinigameStatusLabel.Parent = timerContainer

    local timerLabels = {}
    local function formatTimeMMSS(seconds)
        if seconds <= 0 then return "0m 0s" end
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%dm %ds", mins, secs)
    end

    local function updateTimerLabel(displayName, seconds)
        if not isRunning then return end
        if not timerLabels[displayName] then
            local lbl = Instance.new("TextLabel")
            lbl.Name = displayName .. "Timer"
            lbl.Size = UDim2.new(1, 0, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(255, 180, 50)
            lbl.TextSize = 11
            lbl.Font = Enum.Font.Code
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = timerContainer
            timerLabels[displayName] = lbl
        end

        local formatted = formatTimeMMSS(seconds)
        if seconds <= 0 then
            timerLabels[displayName].Text = string.format("  %s: Active / In-Game", displayName)
            timerLabels[displayName].TextColor3 = Color3.fromRGB(50, 255, 50)
        else
            timerLabels[displayName].Text = string.format("  %s: %s", displayName, formatted)
            timerLabels[displayName].TextColor3 = (seconds <= 101) and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 180, 50)
        end
    end

    local boxInput = Instance.new("TextBox")
    boxInput.Size = UDim2.new(0, 70, 0, 30)
    boxInput.Position = UDim2.new(0, 10, 0, 650)
    boxInput.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    boxInput.BorderColor3 = Color3.fromRGB(60, 70, 90)
    boxInput.Text = "1"
    boxInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    boxInput.TextSize = 14
    boxInput.Font = Enum.Font.SourceSansBold
    boxInput.ZIndex = 11
    boxInput.Parent = farmContainer

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(1, -90, 0, 30)
    buyBtn.Position = UDim2.new(0, 85, 0, 650)
    buyBtn.BackgroundColor3 = Color3.fromRGB(200, 110, 10)
    buyBtn.BorderSizePixel = 0
    buyBtn.Text = "Buy Skelicorn"
    buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyBtn.TextSize = 13
    buyBtn.Font = Enum.Font.SourceSansBold
    buyBtn.ZIndex = 11
    buyBtn.Parent = farmContainer
    applyHoverEffect(buyBtn, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 100))

    local Fsys, load, UIManager, ClientData, RouterClient, InteriorsM, AilmentsManager, PetEntityManager
    local GhostClustersConstants, GhostClustersGhosts, GhostVacuumToyNet, HauntletDoorDB, HauntletMinigameClient, GhostClustersMinigameClient
    local Router

    local function getInventoryCategory(category)
        if not ClientData then return {} end
        local inv = ClientData.get("inventory")
        if type(inv) == "table" and type(inv[category]) == "table" then
            return inv[category]
        end
        return {}
    end

    local function GetServerAilmentsData()
        local data = nil
        pcall(function()
            if ClientData and type(ClientData.get_server) == "function" then
                data = ClientData.get_server(LocalPlayer, "ailments_manager")
            end
        end)
        return data
    end

    local function GetBabyAilments()
        local serverData = GetServerAilmentsData()
        if serverData and type(serverData.baby_ailments) == "table" then
            return serverData.baby_ailments
        end
        return {}
    end

    local function GetPetAilments(petUid)
        local serverData = GetServerAilmentsData()
        if serverData and type(serverData.ailments) == "table" and petUid then
            return serverData.ailments[petUid] or {}
        end
        return {}
    end

    local function getAilmentIdFromInstance(inst)
        if not inst or type(inst) ~= "table" then return "unknown" end
        if inst.kind then 
            return tostring(inst.kind):lower()
        elseif inst.ailment_key then 
            return tostring(inst.ailment_key):lower() 
        elseif inst.id then
            return tostring(inst.id):lower()
        end
        return "unknown"
    end

    local function getPetModel(pUid)
        local petModel = nil
        pcall(function()
            local pets = getInventoryCategory("pets")
            if pUid and pets[pUid] and pets[pUid].kind then
                local kind = pets[pUid].kind
                for _, m in ipairs(Workspace.Pets:GetChildren()) do
                    if m.Name:lower() == kind:lower():gsub("_", " ") or m.Name == kind then 
                        petModel = m 
                        break 
                    end
                end
            end
        end)
        return petModel or Workspace.Pets:FindFirstChildOfClass("Model")
    end

    local function findHealingAppleId()
        local foodTable = getInventoryCategory("food")
        local foundUId = nil
        pcall(function()
            for uId, item in pairs(foodTable) do
                local itemId = type(item) == "table" and tostring(item.id or item.kind or "") or tostring(item)
                itemId = itemId:lower()
                if itemId:find("healing") and itemId:find("apple") then 
                    foundUId = uId 
                    break
                end
            end
        end)
        return foundUId
    end

    local function returnToHouse()
        pcall(function()
            if InteriorsM then
                InteriorsM.enter_smooth("housing", "MainDoor", { house_owner = LocalPlayer })
            end
            task.wait(1.5)
            if Router then 
                Router.get("HousingAPI/SetDoorLocked"):InvokeServer(true)
            end
        end)
    end

    local function getCurrentLocationName()
        local currentLocation = "MainMap"
        pcall(function()
            if InteriorsM and type(InteriorsM.get_current_location) == "function" then
                local locRes = InteriorsM.get_current_location()
                if type(locRes) == "string" then
                    currentLocation = locRes
                elseif type(locRes) == "table" then
                    currentLocation = locRes.interior or locRes.sub_destination_id or locRes.destination_id or locRes.name or "MainMap"
                end
            end
        end)
        return tostring(currentLocation)
    end

    local function managePlatform(targetCFrame, extraHeight)
        pcall(function()
            if isPausedForMinigame or inMinigameSession or getCurrentLocationName():lower():find("minigame") then return end

            local plat = Workspace:FindFirstChild("AutomatorPlatform")
            if not plat then
                plat = Instance.new("Part")
                plat.Name = "AutomatorPlatform"
                plat.Size = Vector3.new(2000, 1, 2000)
                plat.Anchored = true
                plat.CanCollide = true
                
                local texture = plat:FindFirstChild("PlatformTexture") or Instance.new("Texture", plat)
                texture.Name = "PlatformTexture"
                texture.Face = Enum.NormalId.Top
                texture.Texture = RESOLVED_PLANK_TEXTURE
                texture.StudsPerTileU = 10
                texture.StudsPerTileV = 10
                
                plat.Parent = Workspace
            else
                local texture = plat:FindFirstChild("PlatformTexture")
                if texture then
                    texture.Texture = RESOLVED_PLANK_TEXTURE
                end
            end
            plat.CFrame = CFrame.new(targetCFrame.Position + Vector3.new(0, extraHeight or 50, 0))
            if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
                LocalPlayer.Character:PivotTo(plat.CFrame * CFrame.new(0, 3, 0))
            end
        end)
    end

    task.spawn(function()
        while isRunning do
            pcall(function()
                local loc = getCurrentLocationName():lower()
                local inMinigame = loc:find("minigame") or loc:find("hotel") or loc:find("manor") or loc:find("circus")
                local plat = Workspace:FindFirstChild("AutomatorPlatform")
                local char = LocalPlayer.Character
                if not isPausedForMinigame and not inMinigame and not inMinigameSession and plat and char and char.PrimaryPart and ScriptEnabled then
                    local dist = (char.PrimaryPart.Position - plat.Position).Magnitude
                    if dist > 850 then
                        char:PivotTo(plat.CFrame * CFrame.new(0, 3, 0))
                    end
                end
            end)
            task.wait(0.5)
        end
    end)

    local function enterAndLock(interiorName, joinZoneName, targetPartName, duration, offsetY)
        if not isRunning then return end
        duration = duration or 5.0
        offsetY = offsetY or 3.0
        statusLabel.Text = string.format("Status: Entering %s...", interiorName)
        logConsole(string.format("[Cycle] Entering directly into %s...", interiorName))

        CurrentExecutingTask = nil
        table.clear(TaskQueue)
        isPausedForMinigame = true
        inMinigameSession = true

        task.spawn(function()
            pcall(function()
                if InteriorsM and type(InteriorsM.enter) == "function" then
                    InteriorsM.enter(interiorName, "MainDoor", { 
                        house_owner = LocalPlayer,
                        anchor_char_immediately = true,
                        spawn_cframe = function(interior)
                            local joinZone = interior:FindFirstChild(joinZoneName, true)
                            if joinZone then
                                local foundPart = joinZone:FindFirstChild(targetPartName, true) or joinZone:FindFirstChild("Collider", true) or (joinZone:IsA("BasePart") and joinZone)
                                if foundPart and foundPart:IsA("BasePart") then
                                    return foundPart.CFrame + Vector3.new(0, offsetY, 0)
                                end
                            end
                            return nil
                        end
                    })
                end
            end)
        end)
    end

    local function runSpotlightGame()
        pcall(function()
            local staticMap = Workspace:FindFirstChild("StaticMap")
            if not staticMap then return end

            local spawnersFolder = nil
            for _, child in ipairs(staticMap:GetChildren()) do
                if child.Name:match("^CircusMinigameInterior::") then
                    spawnersFolder = child:FindFirstChild("CandycornSpawners")
                    break
                end
            end

            if not spawnersFolder then return end

            logConsole("⚡ Starting direct character teleport to all Candycorn parts...")
            for _, item in ipairs(spawnersFolder:GetChildren()) do
                local valLbl = LocalPlayer.PlayerGui:FindFirstChild("MinigameInGameApp", true) and LocalPlayer.PlayerGui.MinigameInGameApp.Body.Left.Container.ValueLabel
                local timerTxt = valLbl and valLbl.Text:gsub("%s+", "") or ""
                if not AutoCandycornRunning or not isRunning or timerTxt == "00:20" or timerTxt == "00:30" or timerTxt:find("00:20") or timerTxt:find("00:30") or not spawnersFolder.Parent then break end
                
                local char = LocalPlayer.Character
                local root = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
                if not root then break end

                local targetCFrame = nil
                if item:IsA("BasePart") then
                    targetCFrame = item.CFrame
                else
                    local handle = item:FindFirstChild("Handle", true)
                    if handle and handle:IsA("BasePart") then
                        targetCFrame = handle.CFrame
                    end
                end

                if targetCFrame then
                    root.CFrame = targetCFrame + Vector3.new(0, 2, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    task.wait(circusTeleportDelay)
                end
            end
            logConsole("✅ Finished teleporting to all candy corn locations!")
        end)
    end

    task.spawn(function()
        while isRunning do
            if AutoCandycornRunning then
                runSpotlightGame()
            end
            task.wait(1.0)
        end
    end)

    local function triggerAllPotionsActive()
        task.spawn(function()
            local items = { "ghost_potion", "red_potion", "gold_potion", "rainbow_wand" }
            for _, item in ipairs(items) do
                pcall(function()
                    if Router then Router.get("ToolAPI/ServerUseTool"):InvokeServer(item, "START") end
                end)
                task.wait(0.1)
            end
        end)
    end

    local function runHauntlet()
        if not isRunning then return end
        enterAndLock("HauntedHotel", "HauntletMinigameJoinZone", "Collider", 5.0, 3.0)
        triggerAllPotionsActive()
        statusLabel.Text = "Status: Hauntlet Active..."
        statusLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
        logConsole("[Hauntlet] Routine started. Scanning rooms & doors...")

        task.spawn(function()
            while AutoHauntletRunning and isRunning do
                pcall(function()
                    local valLbl = LocalPlayer.PlayerGui:FindFirstChild("MinigameInGameApp", true) and LocalPlayer.PlayerGui.MinigameInGameApp.Body.Left.Container.ValueLabel
                    local timerTxt = valLbl and valLbl.Text:gsub("%s+", "") or ""
                    if timerTxt == "00:20" or timerTxt == "00:30" or timerTxt:find("00:20") or timerTxt:find("00:30") then break end

                    local interiorsRoot = Workspace:FindFirstChild("Interiors")
                    if interiorsRoot then
                        for _, model in ipairs(interiorsRoot:GetChildren()) do
                            if string.match(model.Name, "^HauntletInterior") and model:IsA("Model") then
                                for _, desc in ipairs(model:GetDescendants()) do
                                    local nameLower = desc.Name:lower()
                                    if desc:IsA("Instance") and (nameLower == "teleportring" or nameLower:match("teleport_ring") or nameLower == "ring") then
                                        for _, innerChild in ipairs(desc:GetDescendants()) do
                                            if innerChild:IsA("BasePart") and (innerChild.Name:lower() == "part" or innerChild.Name:lower() == "ring") then
                                                local char = LocalPlayer.Character
                                                local root = char and char:FindFirstChild("HumanoidRootPart")
                                                if root and char then
                                                    root.AssemblyLinearVelocity = Vector3.zero
                                                    root.AssemblyAngularVelocity = Vector3.zero
                                                    char:PivotTo(CFrame.new(innerChild.Position + Vector3.new(0, TELEPORT_OFFSET_Y, 0)))
                                                    task.wait(HAUNTLET_TELEPORT_DELAY)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait(0.5)
            end
        end)
    end

    task.spawn(function()
        while isRunning do
            pcall(function()
                for _, gcObj in ipairs(getgc(true)) do
                    if type(gcObj) == "table" then
                        local hasReveal = false
                        pcall(function() hasReveal = rawget(gcObj, "revealed_ghost_msg") ~= nil and type(rawget(gcObj, "revealed_ghost_msg")) == "function" end)
                        
                        if hasReveal then
                            local isHooked = false
                            pcall(function() isHooked = gcObj._hooked_auto end)
                            
                            if not isHooked then
                                pcall(function() gcObj._hooked_auto = true end)
                                logConsole("[HauntletAuto] Successfully hooked active HauntletMinigameClient instance!")
                                
                                local oldReveal = gcObj.revealed_ghost_msg
                                pcall(function()
                                    gcObj.revealed_ghost_msg = function(self, doorIndex, ...)
                                        _G.HauntletGhostBlacklist[doorIndex] = true
                                        logConsole(string.format("⚠️ [AUTO-BLACKLIST] Ghost detected behind Door Index %d! Skipping.", doorIndex))
                                        return oldReveal(self, doorIndex, ...)
                                    end
                                end)

                                local oldStartRoom = nil
                                pcall(function() oldStartRoom = gcObj.started_room_msg end)
                                
                                if oldStartRoom then
                                    pcall(function()
                                        gcObj.started_room_msg = function(self, ...)
                                            table.clear(_G.HauntletGhostBlacklist)
                                            local roomIdx = 0
                                            pcall(function() roomIdx = (self.current_room_index or 0) + 1 end)
                                            logConsole(string.format("[HauntletAuto] Initializing Room #%d.", roomIdx))
                                            
                                            local result = oldStartRoom(self, ...)
                                            
                                            task.delay(0.5, function()
                                                if AutoHauntletRunning and isRunning then
                                                    pcall(function() autoPickSafestDoor(self) end)
                                                end
                                            end)
                                            
                                            return result
                                        end
                                    end)
                                end
                            end

                            if AutoHauntletRunning and isRunning then
                                pcall(function() autoPickSafestDoor(gcObj) end)
                            end
                        end
                    end
                end
            end)
            task.wait(1.0)
        end
    end)

    task.spawn(function()
        local minigames = {
            { 
                Name = "Ghost Clusters", 
                Key = "ghost_clusters_cycle_timestamp",
                Routine = function()
                    if AutoGhostRunning and isRunning then
                        activeMinigameStatusLabel.Text = "  Active Minigame: Ghost Clusters"
                        logConsole("[Ghost Clusters] Timer reached. Entering Haunted Manor...")
                        enterAndLock("HauntedManor", "GhostClustersMinigameJoinZone", "Ring", 5.0, 3.0)
                    end
                end
            },
            { 
                Name = "Hauntlet", 
                Key = "hauntlet_cycle_timestamp", 
                Routine = function()
                    if AutoHauntletRunning and isRunning then
                        activeMinigameStatusLabel.Text = "  Active Minigame: Hauntlet"
                        logConsole("[Hauntlet] Timer reached. Starting Hauntlet routine...")
                        task.spawn(runHauntlet)
                    end
                end 
            },
            {
                Name = "Circus (Spotlight)", 
                Key = "spotlight_cycle_timestamp", 
                Routine = function()
                    if AutoCircusRunning and isRunning then
                        activeMinigameStatusLabel.Text = "  Active Minigame: Circus Spotlight"
                        logConsole("[Spotlight] Timer reached. Starting Spotlight routine...")
                        enterAndLock("Circus", "SpotlightMinigameJoinZone", "Collider", 5.0, 3.0)
                    end
                end 
            }
        }
        local lastTriggerTimes = {}

        while isRunning do
            pcall(function()
                if not ClientData or not isRunning then return end

                local timerTxt = ""
                pcall(function()
                    local valLbl = LocalPlayer.PlayerGui.MinigameInGameApp.Body.Left.Container.ValueLabel
                    if valLbl and valLbl:IsA("TextLabel") then
                        timerTxt = valLbl.Text:gsub("%s+", "")
                    end
                end)

                if timerTxt ~= "" then
                    activeMinigameStatusLabel.Text = "  Active Minigame: " .. timerTxt
                end

                if timerTxt == "00:20" or timerTxt == "00:30" or timerTxt:find("00:20") or timerTxt:find("00:30") then
                    if not isPausedForMinigame then
                        logConsole(string.format("[Minigame Watcher] ValueLabel hit %s! Instantly stopping all teleports.", timerTxt))
                        statusLabel.Text = string.format("Status: Minigame Ending (%s)", timerTxt)
                        activeMinigameStatusLabel.Text = "  Active Minigame: Waiting..."
                        isPausedForMinigame = true
                        inMinigameSession = true
                        AutoCandycornRunning = false
                    end
                end

                local rawData = ClientData.get_data()
                if not rawData then return end

                local playerData = rawData[LocalPlayer.Name] or rawData
                local now = Workspace:GetServerTimeNow()

                for _, mg in ipairs(minigames) do
                    if not isRunning then break end
                    local cycleData = playerData[mg.Key]
                    local timestamp = nil

                    if type(cycleData) == "table" then
                        timestamp = cycleData.timestamp
                    elseif type(cycleData) == "number" then
                        timestamp = cycleData
                    end

                    if timestamp and type(timestamp) == "number" then
                        local remaining = timestamp - now
                        updateTimerLabel(mg.Name, remaining)

                        if not isPausedForMinigame and not inMinigameSession and timerTxt ~= "00:20" and timerTxt ~= "00:30" and mg.Routine and remaining >= 0 and remaining <= 101 and isRunning then
                            local lastRun = lastTriggerTimes[mg.Key] or 0
                            if now - lastRun > 60 then
                                lastTriggerTimes[mg.Key] = now
                                task.spawn(mg.Routine)
                            end
                        end
                    else
                        updateTimerLabel(mg.Name, 0)
                    end
                end

                local locName = getCurrentLocationName():lower()
                local isMainMap = (locName == "mainmap" or locName:find("mainmap"))
                if isPausedForMinigame and isMainMap and (timerTxt == "" or timerTxt == "00:00") then
                    isPausedForMinigame = false
                    inMinigameSession = false
                    statusLabel.Text = "Status: Idle"
                    activeMinigameStatusLabel.Text = "  Active Minigame: Waiting..."
                end
            end)

            task.wait(0.2)
        end
    end)

    local function triggerHotbarButtons()
        if not isRunning then return end
        pcall(function()
            local hotbarApp = nil
            if UIManager then
                if type(UIManager.get_app_instance) == "function" then
                    hotbarApp = UIManager.get_app_instance("MinigameHotbarApp")
                elseif UIManager.apps and UIManager.apps.MinigameHotbarApp then
                    hotbarApp = UIManager.apps.MinigameHotbarApp
                end
            end

            if hotbarApp and hotbarApp.hotbar_buttons and isRunning then
                for _, button in pairs(hotbarApp.hotbar_buttons) do
                    if not isRunning then break end
                    if type(button) == "table" then
                        if type(button.use) == "function" then
                            task.spawn(function() if isRunning then button:use() end end)
                        end
                        if type(button.Click) == "function" then
                            task.spawn(function() if isRunning then button:Click() end end)
                        end
                        if type(button.activate) == "function" then
                            task.spawn(function() if isRunning then button:activate() end end)
                        end
                    end
                end
            end
        end)
    end

    task.spawn(function()
        while isRunning do
            if AutoHotbarRunning and isRunning then
                triggerHotbarButtons()
            end
            task.wait(0.05)
        end
    end)

    local function getVacuumToolWrapper()
        if not isRunning or not ClientData or not UIManager or not UIManager.apps or not UIManager.apps.ToolApp then return nil end
        local inventory = ClientData.get("inventory")
        if not (inventory and inventory.toys) then return nil end

        local vacuumToy = nil
        for _, toy in pairs(inventory.toys) do
            local goldKind = GhostClustersConstants and GhostClustersConstants.GOLD_TOY_KIND or "halloween_2026_vacuum_gold"
            local regKind = GhostClustersConstants and GhostClustersConstants.TOY_KIND or "halloween_2026_vacuum"
            if toy.kind == goldKind or toy.kind == regKind then
                vacuumToy = toy
                break
            end
        end

        if not vacuumToy then return nil end
        local success, wrapper = pcall(function()
            return UIManager.apps.ToolApp.active_tools[vacuumToy.unique]
        end)
        return success and wrapper or nil
    end

    local function isValidInstance(instance)
        return isRunning and instance ~= nil and instance.Parent ~= nil and pcall(function() return instance:IsDescendantOf(Workspace) end)
    end

    local function refreshTargetQueue()
        targetQueue = {}
        if not isRunning then return end
        pcall(function()
            local visuals = Workspace:FindFirstChild("GhostClustersVisuals")
            local liveName = GhostClustersConstants and GhostClustersConstants.LIVE_FOLDER_NAME or "GhostClustersLive"
            local live = Workspace:FindFirstChild("GhostClustersLive") or Workspace:FindFirstChild(liveName)

            local function scanForRootParts(folder)
                if not folder or not isRunning then return end
                for _, descendant in pairs(folder:GetDescendants()) do
                    if not isRunning then break end
                    local nameLower = descendant.Name:lower()
                    if descendant:IsA("BasePart") and (nameLower == "rootpart" or nameLower == "rootparts") then
                        table.insert(targetQueue, descendant)
                    end
                end
            end

            scanForRootParts(visuals)
            scanForRootParts(live)
        end)
    end

    local function getNextQueueTarget()
        while #targetQueue > 0 and isRunning do
            local target = table.remove(targetQueue, 1)
            if isValidInstance(target) then
                return target
            end
        end
        return nil
    end

    local function teleportAndVacuum(targetPart)
        if not isRunning or not isValidInstance(targetPart) then return false end
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not isRunning then return false end

        local toolWrapper = getVacuumToolWrapper()
        local ghostModel = targetPart:FindFirstAncestorOfClass("Model")
        local targetPos = targetPart.Position

        if ghostModel and GhostClustersGhosts then
            pcall(function()
                local anchor = GhostClustersGhosts.beam_anchor(ghostModel)
                if anchor then
                    local anchorPos = GhostClustersGhosts.anchor_world_position(anchor)
                    if anchorPos then
                        targetPos = anchorPos
                    end
                end
            end)
        end

        local offsetPos = targetPos + Vector3.new(SAFE_DISTANCE, 0, SAFE_DISTANCE)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { character, ghostModel or targetPart }

        local rayResult = Workspace:Raycast(offsetPos + Vector3.new(0, 15, 0), Vector3.new(0, -40, 0), rayParams)
        local finalY = rayResult and (rayResult.Position.Y + 3) or (targetPos.Y + 3)
        local safePos = Vector3.new(offsetPos.X, finalY, offsetPos.Z)

        if not isRunning then return false end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(safePos, targetPos))
        task.wait(0.03)

        local startTime = tick()
        while tick() - startTime < ghostShootHoldDuration and isRunning do
            if not isValidInstance(targetPart) or not AutoGhostRunning or not isRunning then break end

            pcall(function()
                if toolWrapper and toolWrapper.ghost_clusters_session then
                    if ghostModel then
                        toolWrapper.ghost_clusters_session.target = {
                            model = ghostModel,
                            part = targetPart
                        }
                    end

                    pcall(function()
                        if isRunning and type(toolWrapper.use) == "function" then
                            toolWrapper:use({
                                source = "MinigameHotbar",
                                aim_mode = "auto",
                                aim_screen_point = Workspace.CurrentCamera:WorldToScreenPoint(targetPos)
                            })
                        end
                    end)
                elseif GhostVacuumToyNet and isRunning then
                    local origin = root.Position
                    local payload = {
                        ox = origin.X,
                        oy = origin.Y,
                        oz = origin.Z,
                        hx = targetPos.X,
                        hy = targetPos.Y,
                        hz = targetPos.Z,
                        user_id = LocalPlayer.UserId,
                        pet_unique = nil
                    }
                    pcall(function()
                        if isRunning then
                            if type(GhostVacuumToyNet.replay) == "function" then
                                GhostVacuumToyNet.replay(character, Vector3.new(targetPos.X, targetPos.Y, targetPos.Z))
                            end
                            if GhostVacuumToyNet.Fire then
                                if typeof(GhostVacuumToyNet.Fire.fire_server) == "function" then
                                    GhostVacuumToyNet.Fire:fire_server(payload)
                                elseif typeof(GhostVacuumToyNet.Fire.fire) == "function" then
                                    GhostVacuumToyNet.Fire:fire(payload)
                                end
                            end
                        end
                    end)
                end
            end)

            task.wait(0.08)
        end

        return true
    end

    task.spawn(function()
        while isRunning do
            pcall(function()
                if AutoGhostRunning and isRunning then
                    refreshTargetQueue()
                    local target = getNextQueueTarget()
                    if target then
                        teleportAndVacuum(target)
                    else
                        task.wait(0.2)
                    end
                else
                    task.wait(0.5)
                end
            end)
            task.wait(0.05)
        end
    end)

    local function processTask(taskData)
        local aid = taskData.aid
        local entityRef = taskData.entityRef

        local valLbl = LocalPlayer.PlayerGui:FindFirstChild("MinigameInGameApp", true) and LocalPlayer.PlayerGui.MinigameInGameApp.Body.Left.Container.ValueLabel
        local timerTxt = valLbl and valLbl.Text:gsub("%s+", "") or ""
        if isPausedForMinigame or inMinigameSession or timerTxt == "00:20" or timerTxt == "00:30" or getCurrentLocationName():lower():find("minigame") then
            return
        end

        CurrentExecutingTask = aid
        statusLabel.Text = "Status: Doing " .. tostring(aid)

        pcall(function()
            local taskStartTime = tick()
            local hConfig = UserFurniture[aid]
            local pUid = taskData.petUniqueId or tostring(LocalPlayer.UserId)
            local targetModel = entityRef.is_pet and getPetModel(pUid) or LocalPlayer.Character
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local char = LocalPlayer.Character

            if entityRef.is_pet and aid ~= "walk" and aid ~= "ride" then
                pcall(function()
                    if Router then Router.get("AdoptAPI/HoldBaby"):InvokeServer(getPetModel(pUid)) end
                end)
            end

            local STATIC = { 
                camping = Workspace.StaticMap.Campsite.CampsiteOrigin, 
                beach_party = Workspace.StaticMap.Beach.BeachPartyAilmentTarget, 
                bored = Workspace.StaticMap.Park.BoredAilmentTarget 
            }
            local INTERIORS = { school = "School", salon = "Salon", pizza_party = "PizzaShop", cat_cafe = "CatCafe" }

            if INTERIORS[aid] then
                InteriorsM.enter_smooth(INTERIORS[aid], "MainDoor"); task.wait(0.5); if root then managePlatform(root.CFrame, 50) end
            elseif aid == "camping" or STATIC[aid] then
                InteriorsM.enter_smooth("MainMap", "MainDoor"); task.wait(0.5)
                managePlatform(STATIC[aid] and STATIC[aid].CFrame or STATIC["camping"].CFrame, 50)
            elseif aid == "walk" or aid == "ride" or hConfig then
                returnToHouse(); task.wait(0.5)
                local currentRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if currentRoot then managePlatform(currentRoot.CFrame, 50) end
            end

            if hConfig then
                local targetModelRef = entityRef.is_pet and getPetModel(pUid) or LocalPlayer.Character
                while ActiveDetectedTasks[aid] and ScriptEnabled and not isPausedForMinigame and not inMinigameSession do
                    if tick() - taskStartTime > 90 then break end
                    for _, furnitureName in ipairs(hConfig) do
                        pcall(function()
                            for _, container in ipairs(Workspace.HouseInteriors.furniture:GetChildren()) do
                                local model = container:FindFirstChild(furnitureName)
                                if model then
                                    local fId = string.match(container.Name, "f%-%w+") or container.Name
                                    local inter = model:FindFirstChild("UseBlocks") and (model.UseBlocks:FindFirstChild("Seat1") or model.UseBlocks:FindFirstChildOfClass("Part"))
                                    if inter and Router then 
                                        Router.get("HousingAPI/ActivateFurniture"):InvokeServer(LocalPlayer, fId, inter.Name, {cframe = targetModelRef:GetPivot()}, targetModelRef) 
                                        break 
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(3)
                end
            elseif aid == "sick" then
                local targetUid = findHealingAppleId()
                if not targetUid and Router then
                    Router.get("ShopAPI/BuyItem"):InvokeServer("food", "healing_apple", {buy_count = 1})
                    task.wait(1.5)
                    targetUid = findHealingAppleId()
                end
                if targetUid then
                    Router.get("ToolAPI/Equip"):InvokeServer(targetUid)
                    task.wait(1.2)
                    while ActiveDetectedTasks[aid] and ScriptEnabled and not isPausedForMinigame and not inMinigameSession do
                        if tick() - taskStartTime > 45 then break end
                        if entityRef.is_pet and Router then
                            Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_2", {additional_consume_uniques = {}, pet_unique = pUid, unique_id = targetUid})
                            task.wait(12)
                        elseif Router then
                            Router.get("ToolAPI/ServerUseTool"):InvokeServer(targetUid, "START")
                            task.wait(0.1)
                            Router.get("ToolAPI/ServerUseTool"):InvokeServer(targetUid, "END")
                        end
                        task.wait(4)
                    end
                    Router.get("ToolAPI/Unequip"):InvokeServer(targetUid)
                end
            elseif aid == "play" then
                local toyTable = getInventoryCategory("toys")
                for uId, item in pairs(toyTable) do 
                    if type(item) == "table" and item.id == "squeaky_bone_default" then 
                        if Router then Router.get("ToolAPI/Equip"):InvokeServer(uId) end
                        task.wait(1.2)
                        while ActiveDetectedTasks[aid] and ScriptEnabled and not isPausedForMinigame and not inMinigameSession do
                            if (tick() - taskStartTime > 45) then break end
                            if Router then
                                Router.get("ToolAPI/ServerUseTool"):InvokeServer(uId, "START")
                                Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_1", {reaction_name = "ThrowToyReaction", unique_id = uId})
                                Router.get("PetObjectAPI/CreatePetObject"):InvokeServer("__Enum_PetObjectCreatorType_2", {additional_consume_uniques = {uId}, pet_unique = pUid, unique_id = uId})
                            end
                            task.wait(12)
                        end
                        if Router then
                            Router.get("ToolAPI/ServerUseTool"):InvokeServer(uId, "END"); task.wait(0.5)
                            Router.get("ToolAPI/Unequip"):InvokeServer(uId)
                        end
                        break 
                    end 
                end
            elseif aid == "pet_me" then
                local targetPet = PetEntityManager and PetEntityManager.get_local_owned_pet_entities()[1]
                if targetPet and targetPet.base and targetPet.base.char_wrapper and UIManager and UIManager.apps and UIManager.apps["FocusPetApp"] and Router then
                    UIManager.apps["FocusPetApp"]:capture_focus(targetPet.base.char_wrapper)
                    Router.get("PetAPI/ReplicateActivePerformances"):FireServer(targetModel, { FocusPet = true })
                    task.wait(0.1); Router.get("AilmentsAPI/ProgressPetMeAilment"):FireServer(pUid); task.wait(0.1)
                    Router.get("PetAPI/ReplicateActivePerformances"):FireServer(targetModel, { FocusPet = false })
                    UIManager.apps["FocusPetApp"]:release_focus()
                end
                task.wait(2)
            elseif aid == "walk" or aid == "ride" then
                if entityRef.is_pet and targetModel then
                    local currentStroller = nil
                    if aid == "walk" then 
                        if Router then Router.get("AdoptAPI/HoldBaby"):InvokeServer(targetModel) end
                    elseif aid == "ride" then
                        local strollers = getInventoryCategory("strollers")
                        for uId, _ in pairs(strollers) do
                            currentStroller = uId
                            if Router then Router.get("ToolAPI/Equip"):InvokeServer(uId) end
                            task.wait(1.5)
                            local sit = char and char:FindFirstChild("TouchToSit", true)
                            if sit and Router then Router.get("AdoptAPI/UseStroller"):InvokeServer(LocalPlayer, targetModel, sit) end
                            break
                        end
                    end

                    local isCircling = true
                    local circleSteps = {
                        {Enum.KeyCode.W}, {Enum.KeyCode.W, Enum.KeyCode.A}, {Enum.KeyCode.A},
                        {Enum.KeyCode.S, Enum.KeyCode.A}, {Enum.KeyCode.S}, {Enum.KeyCode.S, Enum.KeyCode.D},
                        {Enum.KeyCode.D}, {Enum.KeyCode.W, Enum.KeyCode.D},
                    }
                    
                    coroutine.wrap(function()
                        local stepIndex = 1
                        while isCircling and CurrentExecutingTask == aid and ScriptEnabled and not isPausedForMinigame and not inMinigameSession do
                            if (tick() - taskStartTime > 180) or isPausedForMinigame or inMinigameSession then break end
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
                                if stepIndex % 2 == 0 then VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game) end
                            end)
                            task.wait(0.5)
                            pcall(function()
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
                            end)
                            stepIndex = (stepIndex % #circleSteps) + 1
                        end
                        isCircling = false
                    end)()

                    while CurrentExecutingTask == aid and ScriptEnabled and not isPausedForMinigame and not inMinigameSession do
                        local checkTable = entityRef.is_pet and GetPetAilments(entityRef.pet_unique) or GetBabyAilments()
                        if not checkTable[aid] or (tick() - taskStartTime > 180) or isPausedForMinigame or inMinigameSession then break end
                        task.wait(1.0)
                    end

                    isCircling = false
                    if currentStroller and Router then 
                        pcall(function() Router.get("ToolAPI/Unequip"):InvokeServer(currentStroller) end)
                    end
                end
            elseif aid == "mystery" then
                task.wait(0.1)
            else
                while ActiveDetectedTasks[aid] and (tick() - taskStartTime < 30) and not isPausedForMinigame and not inMinigameSession do task.wait(1) end
            end
        end)

        CurrentExecutingTask = nil
    end

    task.spawn(function()
        while isRunning do
            if not CurrentExecutingTask and #TaskQueue > 0 and not isPausedForMinigame and not inMinigameSession then
                local nextTask = table.remove(TaskQueue, 1)
                if nextTask and ActiveDetectedTasks[nextTask.aid] then
                    processTask(nextTask)
                end
            end
            task.wait(0.2)
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not isRunning then return end

        pcall(function()
            if not ClientData then return end
            ActiveDetectedTasks = {}

            if isPausedForMinigame or inMinigameSession then return end

            if BabyFarmEnabled then
                local babyAilments = GetBabyAilments()
                for _, ailment in pairs(babyAilments) do
                    local aid = getAilmentIdFromInstance(ailment)
                    if not IgnoredAilments[aid] then
                        ActiveDetectedTasks[aid] = { aid = aid, instance = ailment, entityRef = { player = LocalPlayer, is_pet = false }, petUniqueId = tostring(LocalPlayer.UserId) }
                        local alreadyQueued = (CurrentExecutingTask == aid)
                        for _, t in ipairs(TaskQueue) do if t.aid == aid then alreadyQueued = true break end end
                        if not alreadyQueued then table.insert(TaskQueue, ActiveDetectedTasks[aid]) end
                    end
                end
            end

            if ScriptEnabled then
                local rawData = ClientData.get_data()
                local playerData = rawData[LocalPlayer.Name] or rawData
                local equipManager = playerData and playerData.equip_manager

                local equippedPets = {}
                if equipManager then
                    if type(equipManager.pets) == "table" then
                        equippedPets = equipManager.pets
                    elseif type(equipManager.active_pets) == "table" then
                        equippedPets = equipManager.active_pets
                    end
                end

                for _, petEntry in pairs(equippedPets) do
                    local petUid = nil
                    if type(petEntry) == "table" then
                        petUid = petEntry.unique or petEntry.unique_id or petEntry.id or petEntry.uuid
                    elseif type(petEntry) == "string" then
                        petUid = petEntry
                    end

                    if petUid then
                        local petAilments = GetPetAilments(petUid)
                        for _, ailment in pairs(petAilments) do
                            local aid = getAilmentIdFromInstance(ailment)
                            if not IgnoredAilments[aid] then
                                local petEntityRef = { player = LocalPlayer, is_pet = true, pet_unique = petUid }
                                ActiveDetectedTasks[aid] = { aid = aid, instance = ailment, entityRef = petEntityRef, petUniqueId = petUid }
                                local alreadyQueued = (CurrentExecutingTask == aid)
                                for _, t in ipairs(TaskQueue) do if t.aid == aid then alreadyQueued = true break end end
                                if not alreadyQueued then table.insert(TaskQueue, ActiveDetectedTasks[aid]) end
                            end
                        end
                    end
                end
            end
        end)
    end)

    local loadingSteps = {
        {
            name = "Awaiting ServerInitDone replication signal...",
            action = function()
                pcall(function()
                    if not ReplicatedStorage:GetAttribute("ServerInitDone") then
                        ReplicatedStorage:GetAttributeChangedSignal("ServerInitDone"):Wait()
                    end
                end)
            end
        },
        {
            name = "Requiring core framework (Fsys)...",
            action = function()
                pcall(function()
                    if not ReplicatedStorage:FindFirstChild("Fsys") then return end
                    Fsys = require(ReplicatedStorage.Fsys)
                    load = Fsys.load
                end)
            end
        },
        {
            name = "Loading ClientData and InteriorsM...",
            action = function()
                if load then
                    pcall(function() ClientData = load("ClientData") end)
                    pcall(function() InteriorsM = load("InteriorsM") end)
                    pcall(function() RouterClient = load("RouterClient") end)
                    Router = RouterClient
                end
            end
        }
    }

    task.spawn(function()
        for i, step in ipairs(loadingSteps) do
            if not isRunning then break end
            loadingStatus.Text = step.name
            progressPercent.Text = tostring(math.floor((i / #loadingSteps) * 100)) .. "%"
            pcall(step.action)
            task.wait(0.1)
        end
        loadingStatus.Text = "All modules loaded successfully!"
        loadingStatus.TextColor3 = Color3.fromRGB(50, 225, 50)
        progressPercent.Text = "100%"
        logConsole("[Init] Synchronization complete.")
        task.wait(0.5)
        pcall(function() loadingFrame:Destroy() end)
        mainFrame.Visible = true
    end)
end)

if not success then warn("Hub Error: " .. tostring(err)) end
