--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CONFIG = {
    ToggleFarmKey = Enum.KeyCode.F,
    FarmOffset = Vector3.new(0, 30, 0),
    TweenSpeed = 95,
    AutoEquip = true,
    NoAnimation = true,
    AutoQuest = true,
    QuestCooldown = 3.0,
    AutoHaki = true,
    AttackDelay = 0.1, -- Tăng độ trễ an toàn
    AutoHitbox = true,
    HitboxSize = Vector3.new(60, 60, 60),
    HitboxTransparency = 0.8,
}

type QuestData = {
    Sea: number,
    MinLv: number,
    MaxLv: number,
    QuestName: string,
    QuestLevel: number,
    MobName: string,
    NpcPos: Vector3,
    MobPos: Vector3
}

local function GetCurrentSea(): number
    local placeId = game.PlaceId
    if placeId == 2753915549 then return 1
    elseif placeId == 4442272183 then return 2
    elseif placeId == 7449423635 then return 3 end
    return 1
end

-- Database Quest thu gọn chuẩn xác
local QUEST_DATABASE: {QuestData} = {
    { Sea = 1, MinLv = 1,   MaxLv = 9,   QuestName = "BanditQuest1",  QuestLevel = 1, MobName = "Bandit",               NpcPos = Vector3.new(1059, 16, 1549),   MobPos = Vector3.new(1145, 17, 1634) },
    { Sea = 1, MinLv = 10,  MaxLv = 14,  QuestName = "JungleQuest",   QuestLevel = 1, MobName = "Monkey",               NpcPos = Vector3.new(-1598, 37, 153),   MobPos = Vector3.new(-1448, 50, 63) },
    { Sea = 2, MinLv = 700, MaxLv = 724, QuestName = "Area1Quest",    QuestLevel = 1, MobName = "Raider",               NpcPos = Vector3.new(-425, 73, 1836),   MobPos = Vector3.new(-740, 73, 2380) },
    { Sea = 3, MinLv = 1500,MaxLv = 1524,QuestName = "PiratePortQuest",QuestLevel = 1, MobName = "Pirate Millionaire",  NpcPos = Vector3.new(-290, 44, 5580),   MobPos = Vector3.new(-370, 75, 5550) },
}

local LocalPlayer = Players.LocalPlayer
local IsFarming = false
local ActiveTween: Tween? = nil
local NoclipConn: RBXScriptConnection? = nil
local BodyVel: BodyVelocity? = nil
local LastQuestAttempt = 0

local RegisterAttack = ReplicatedStorage:FindFirstChild("RegisterAttack", true) :: RemoteEvent?
local CommF = ReplicatedStorage:FindFirstChild("CommF_", true) :: RemoteFunction?

local function EnableHaki()
    if not CONFIG.AutoHaki then return end
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("HasBuso") then
        if CommF then pcall(function() CommF:InvokeServer("Buso") end) end
    end
end

local function GetPlayerLevel(): number
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local levelVal = data:FindFirstChild("Level") :: IntValue?
        if levelVal then return levelVal.Value end
    end
    return 1
end

local function GetCurrentQuestInfo(): QuestData
    local myLevel = GetPlayerLevel()
    local currentSea = GetCurrentSea()
    for _, qData in ipairs(QUEST_DATABASE) do
        if qData.Sea == currentSea and myLevel >= qData.MinLv and myLevel <= qData.MaxLv then
            return qData
        end
    end
    return QUEST_DATABASE[1]
end

local function HasActiveQuest(): boolean
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    local trackedFrame = playerGui:FindFirstChild("TrackedQuestFrame", true)
    if trackedFrame then
        local frame = trackedFrame:FindFirstChild("Frame") :: GuiObject?
        if frame and frame.Visible then
            local progressLabel = frame:FindFirstChild("progress", true) :: TextLabel?
            if progressLabel and progressLabel.Text ~= "" and progressLabel.Text ~= "0" then return true end
        end
    end
    return false
end

local function TakeQuest()
    if not CONFIG.AutoQuest or HasActiveQuest() then return end
    if os.clock() - LastQuestAttempt < CONFIG.QuestCooldown then return end
    LastQuestAttempt = os.clock()

    local qInfo = GetCurrentQuestInfo()
    if CommF then
        pcall(function()
            CommF:InvokeServer("StartQuest", qInfo.QuestName, qInfo.QuestLevel)
        end)
    end
end

local function ApplyHitbox(enemy: Model)
    if not CONFIG.AutoHitbox then return end
    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "HumanoidRootPart" or part.Name == "Head") then
            part.Size = CONFIG.HitboxSize
            part.Transparency = CONFIG.HitboxTransparency
            part.CanCollide = false
        end
    end
end

-- HÀM AUTO CLICK AN TOÀN (Đã bỏ VirtualInputManager để không làm đơ game/chuột)
local function ExecuteAutoClick()
    local char = LocalPlayer.Character
    if not char then return end

    EnableHaki()

    if CONFIG.AutoEquip then
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            if backpack then
                tool = backpack:FindFirstChildOfClass("Tool")
                if tool then tool.Parent = char end
            end
        end
    end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        currentTool:Activate() -- Dùng chuẩn tool:Activate() không gây kẹt chuột
    end

    if RegisterAttack then
        pcall(function() RegisterAttack:FireServer(0) end)
    end
end

-- Vòng lặp Auto Attack nền
task.spawn(function()
    while true do
        if IsFarming then
            ExecuteAutoClick()
        end
        task.wait(CONFIG.AttackDelay)
    end
end)

local function EnablePhysics(hrp: BasePart)
    if not BodyVel or BodyVel.Parent ~= hrp then
        if BodyVel then BodyVel:Destroy() end
        BodyVel = Instance.new("BodyVelocity")
        BodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BodyVel.Velocity = Vector3.zero
        BodyVel.Parent = hrp
    end

    if not NoclipConn then
        NoclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
end

local function DisablePhysics()
    if BodyVel then BodyVel:Destroy() BodyVel = nil end
    if NoclipConn then NoclipConn:Disconnect() NoclipConn = nil end
end

local function GetTargetEnemy(): Model?
    local char = LocalPlayer.Character
    local myHrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
    local enemyFolder = workspace:FindFirstChild("Enemies")
    if not myHrp or not enemyFolder then return nil end

    local qInfo = GetCurrentQuestInfo()
    local closest: Model? = nil
    local minDist = math.huge

    for _, enemy in ipairs(enemyFolder:GetChildren()) do
        if enemy:IsA("Model") and string.find(enemy.Name, qInfo.MobName) then
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local hrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart
            if hum and hrp and hum.Health > 0 then
                ApplyHitbox(enemy)
                local dist = (hrp.Position - myHrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = enemy
                end
            end
        end
    end
    return closest
end

-- Tạo Giao Diện an toàn với PlayerGui để không bị xung đột CoreGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CleanAutoFarmHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 150)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Hỗ trợ kéo thả tự nhiên của Roblox
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

local FarmBtn = Instance.new("TextButton")
FarmBtn.Size = UDim2.new(0.9, 0, 0, 40)
FarmBtn.Position = UDim2.new(0.05, 0, 0, 20)
FarmBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
FarmBtn.Text = "AUTO FARM: OFF (F)"
FarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmBtn.Font = Enum.Font.GothamBold
FarmBtn.TextSize = 13
FarmBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 4)
BtnCorner.Parent = FarmBtn

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(0.9, 0, 0, 40)
InfoLabel.Position = UDim2.new(0.05, 0, 0, 80)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Trạng thái: Sẵn sàng"
InfoLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.TextSize = 11
InfoLabel.Parent = MainFrame

local function StopFarm()
    IsFarming = false
    if ActiveTween then ActiveTween:Cancel() ActiveTween = nil end
    DisablePhysics()
    FarmBtn.Text = "AUTO FARM: OFF (F)"
    FarmBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
end

local function StartFarm()
    if IsFarming then return end
    IsFarming = true
    FarmBtn.Text = "AUTO FARM: ON (F)"
    FarmBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)

    task.spawn(function()
        while IsFarming do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                EnablePhysics(hrp)
                if CONFIG.AutoQuest and not HasActiveQuest() then
                    TakeQuest()
                end

                local target = GetTargetEnemy()
                if target then
                    local targetHrp = target:FindFirstChild("HumanoidRootPart") :: BasePart
                    local targetHum = target:FindFirstChildOfClass("Humanoid")
                    if targetHrp and targetHum and targetHum.Health > 0 then
                        local targetPos = targetHrp.Position + CONFIG.FarmOffset
                        local dist = (targetPos - hrp.Position).Magnitude
                        local tweenTime = math.max(0.1, dist / CONFIG.TweenSpeed)

                        if ActiveTween then ActiveTween:Cancel() end
                        ActiveTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                            CFrame = CFrame.lookAt(targetPos, targetHrp.Position)
                        })
                        ActiveTween:Play()
                        if dist > 10 then task.wait(tweenTime) end

                        while IsFarming and targetHum.Health > 0 and target.Parent do
                            hrp.CFrame = CFrame.lookAt(targetHrp.Position + CONFIG.FarmOffset, targetHrp.Position)
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        StopFarm()
    end)
end

FarmBtn.MouseButton1Click:Connect(function()
    if IsFarming then StopFarm() else StartFarm() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CONFIG.ToggleFarmKey then
        if IsFarming then StopFarm() else StartFarm() end
    end
end)
