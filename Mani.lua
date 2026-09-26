--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ================================================================= --
-- CẤU HÌNH AUTO FARM + SMART QUEST (BAY TỚI NPC) + HITBOX
-- ================================================================= --
local CONFIG = {
    ToggleKey = Enum.KeyCode.F,             -- Phím Bật/Tắt Menu
    FarmOffset = Vector3.new(0, 9, 0),      -- Độ cao 9 Studs (Lơ lửng an toàn)
    TweenSpeed = 95,                        -- Tốc độ bay
    AutoEquip = true,                       -- Tự lấy vũ khí
    NoAnimation = true,                     -- BỎ ANIMATION ĐÒN ĐÁNH
    EnemyFolder = workspace:FindFirstChild("Enemies"),
    AutoQuest = true,                       -- Tự động nhận Quest theo Level

    -- Cấu hình Hitbox
    AutoHitbox = true,                      -- Bật/Tắt tăng Hitbox quái
    HitboxSize = Vector3.new(20, 20, 20),   -- Kích thước Hitbox
    HitboxTransparency = 0.7,               -- Độ trong suốt Hitbox
}

-- BẢNG DỮ LIỆU QUEST & TỌA ĐỘ NPC THEO LEVEL (SEA 1)
type QuestData = { 
    MinLv: number, 
    MaxLv: number, 
    QuestName: string, 
    QuestLevel: number, 
    MobName: string,
    NpcPos: Vector3 
}

local QUEST_DATABASE: {QuestData} = {
    { MinLv = 1,   MaxLv = 9,   QuestName = "BanditQuest1",  QuestLevel = 1, MobName = "Bandit",               NpcPos = Vector3.new(1059, 16, 1549) },
    { MinLv = 10,  MaxLv = 14,  QuestName = "JungleQuest",   QuestLevel = 1, MobName = "Monkey",               NpcPos = Vector3.new(-1598, 37, 153) },
    { MinLv = 15,  MaxLv = 29,  QuestName = "JungleQuest",   QuestLevel = 2, MobName = "Gorilla",              NpcPos = Vector3.new(-1598, 37, 153) },
    { MinLv = 30,  MaxLv = 39,  QuestName = "PirateQuest",   QuestLevel = 1, MobName = "Pirate",               NpcPos = Vector3.new(-1140, 4, 3828) },
    { MinLv = 40,  MaxLv = 59,  QuestName = "PirateQuest",   QuestLevel = 2, MobName = "Brute",                NpcPos = Vector3.new(-1140, 4, 3828) },
    { MinLv = 60,  MaxLv = 74,  QuestName = "DesertQuest",   QuestLevel = 1, MobName = "Desert Bandit",        NpcPos = Vector3.new(897, 6, 4388) },
    { MinLv = 75,  MaxLv = 89,  QuestName = "DesertQuest",   QuestLevel = 2, MobName = "Desert Officer",       NpcPos = Vector3.new(897, 6, 4388) },
    { MinLv = 90,  MaxLv = 99,  QuestName = "SnowQuest",     QuestLevel = 1, MobName = "Snow Bandit",          NpcPos = Vector3.new(1386, 87, -1298) },
    { MinLv = 100, MaxLv = 119, QuestName = "SnowQuest",     QuestLevel = 2, MobName = "Snowman",              NpcPos = Vector3.new(1386, 87, -1298) },
    { MinLv = 120, MaxLv = 149, QuestName = "MarineQuest2",  QuestLevel = 1, MobName = "Chief Petty Officer",  NpcPos = Vector3.new(-5030, 28, 4323) },
}

local LocalPlayer = Players.LocalPlayer
local IsFarming = false
local AutoQuestEnabled = CONFIG.AutoQuest
local ActiveTween: Tween? = nil
local NoclipConn: RBXScriptConnection? = nil
local BodyVel: BodyVelocity? = nil

local RegisterAttack = ReplicatedStorage:FindFirstChild("RegisterAttack", true) :: RemoteEvent?
local CommF = ReplicatedStorage:FindFirstChild("CommF_", true) :: RemoteFunction?

-- ================================================================= --
-- HỆ THỐNG ĐỌC LEVEL & SMART QUEST
-- ================================================================= --
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
    for _, qData in ipairs(QUEST_DATABASE) do
        if myLevel >= qData.MinLv and myLevel <= qData.MaxLv then
            return qData
        end
    end
    return QUEST_DATABASE[1]
end

local function HasActiveQuest(): boolean
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local mainGui = playerGui:FindFirstChild("Main")
        if mainGui then
            local questFrame = mainGui:FindFirstChild("Quest")
            if questFrame and questFrame.Visible then
                return true
            end
        end
    end
    return false
end

-- ================================================================= --
-- HỆ THỐNG TỰ BAY ĐẾN NPC NHẬN QUEST
-- ================================================================= --
local function TakeQuest()
    if not AutoQuestEnabled or HasActiveQuest() then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local qInfo = GetCurrentQuestInfo()

    -- 1. Bay lại gần NPC
    local distToNpc = (qInfo.NpcPos - hrp.Position).Magnitude
    if distToNpc > 15 then
        local tweenTime = math.max(0.1, distToNpc / CONFIG.TweenSpeed)
        if ActiveTween then ActiveTween:Cancel() end
        
        ActiveTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(qInfo.NpcPos + Vector3.new(0, 3, 0))
        })
        ActiveTween:Play()
        task.wait(tweenTime)
    end

    -- 2. Gửi Remote nhận Quest khi đã đứng sát NPC
    if CommF then
        pcall(function()
            CommF:InvokeServer("StartQuest", qInfo.QuestName, qInfo.QuestLevel)
        end)
    end
    task.wait(0.5)
end

-- ================================================================= --
-- HỆ THỐNG TĂNG HITBOX QUÁI
-- ================================================================= --
local function ApplyHitbox(enemy: Model)
    if not CONFIG.AutoHitbox then return end
    for _, part in ipairs(enemy:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" or part.Name == "Head" then
                part.Size = CONFIG.HitboxSize
                part.Transparency = CONFIG.HitboxTransparency
                part.CanCollide = false
            end
        end
    end
end

-- ================================================================= --
-- HỆ THỐNG TRIỆT HẠ ANIMATION ĐÒN ĐÁNH (NO ANIMATION)
-- ================================================================= --
local function HookNoAnim(char: Model)
    local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
    if not hum then return end
    local animator = hum:WaitForChild("Animator", 5) :: Animator?
    if not animator then return end

    animator.AnimationPlayed:Connect(function(track)
        if CONFIG.NoAnimation and IsFarming then
            if track.AnimationPriority == Enum.AnimationPriority.Action 
                or track.AnimationPriority == Enum.AnimationPriority.Action2 
                or track.AnimationPriority == Enum.AnimationPriority.Action3 
                or track.AnimationPriority == Enum.AnimationPriority.Action4 then
                
                track:Stop(0)
            end
        end
    end)
end

if LocalPlayer.Character then HookNoAnim(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(HookNoAnim)

-- ================================================================= --
-- HỆ THỐNG XẢ DAME FAST ATTACK (TỐI ƯU AN TOÀN)
-- ================================================================= --
local function ExecuteAttack()
    local char = LocalPlayer.Character
    if not char then return end

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
    if currentTool then currentTool:Activate() end

    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)

    if RegisterAttack then
        pcall(function() RegisterAttack:FireServer(0) end)
    end
end

-- ================================================================= --
-- KHÓA VẬT LÝ & NOCLIP
-- ================================================================= --
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

-- Quét quái chuẩn theo Quest & Tự động áp dụng Hitbox
local function GetTargetEnemy(): Model?
    local char = LocalPlayer.Character
    local myHrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
    if not myHrp or not CONFIG.EnemyFolder then return nil end

    local qInfo = GetCurrentQuestInfo()
    local targetMobName = qInfo.MobName

    local closest: Model? = nil
    local minDist = math.huge

    for _, enemy in ipairs(CONFIG.EnemyFolder:GetChildren()) do
        if enemy:IsA("Model") then
            if targetMobName == "" or string.find(enemy.Name, targetMobName) then
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
    end
    return closest
end

-- ================================================================= --
-- GIAO DIỆN BẢNG ĐIỀU KHIỂN (GUI)
-- ================================================================= --
local function GetGuiParent(): Instance
    local success, result = pcall(function() return game:GetService("CoreGui") end)
    if success and result then return result end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ParentGui = GetGuiParent()
local OldGui = ParentGui:FindFirstChild("BloxFruitsFullHub")
if OldGui then OldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxFruitsFullHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = ParentGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 270, 0, 260)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 200, 255)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 35)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ AUTO FARM (SMART NPC TWEEN)"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 11
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Parent = MainFrame

local FarmBtn = Instance.new("TextButton")
FarmBtn.Size = UDim2.new(0.85, 0, 0, 38)
FarmBtn.Position = UDim2.new(0.075, 0, 0, 40)
FarmBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
FarmBtn.Text = "AUTO FARM: OFF (F)"
FarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmBtn.TextSize = 12
FarmBtn.Font = Enum.Font.GothamBold
FarmBtn.Parent = MainFrame

local FarmBtnCorner = Instance.new("UICorner")
FarmBtnCorner.CornerRadius = UDim.new(0, 6)
FarmBtnCorner.Parent = FarmBtn

local QuestBtn = Instance.new("TextButton")
QuestBtn.Size = UDim2.new(0.85, 0, 0, 38)
QuestBtn.Position = UDim2.new(0.075, 0, 0, 86)
QuestBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
QuestBtn.Text = "AUTO QUEST NPC: ON"
QuestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuestBtn.TextSize = 12
QuestBtn.Font = Enum.Font.GothamBold
QuestBtn.Parent = MainFrame

local QuestBtnCorner = Instance.new("UICorner")
QuestBtnCorner.CornerRadius = UDim.new(0, 6)
QuestBtnCorner.Parent = QuestBtn

local HitboxBtn = Instance.new("TextButton")
HitboxBtn.Size = UDim2.new(0.85, 0, 0, 38)
HitboxBtn.Position = UDim2.new(0.075, 0, 0, 132)
HitboxBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
HitboxBtn.Text = "AUTO HITBOX: ON"
HitboxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HitboxBtn.TextSize = 12
HitboxBtn.Font = Enum.Font.GothamBold
HitboxBtn.Parent = MainFrame

local HitboxBtnCorner = Instance.new("UICorner")
HitboxBtnCorner.CornerRadius = UDim.new(0, 6)
HitboxBtnCorner.Parent = HitboxBtn

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 45)
InfoLabel.Position = UDim2.new(0, 10, 0, 178)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Lv: " .. GetPlayerLevel() .. " | Auto NPC Tween"
InfoLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
InfoLabel.TextSize = 11
InfoLabel.Font = Enum.Font.GothamMedium
InfoLabel.TextWrapped = true
InfoLabel.Parent = MainFrame

-- Kéo thả GUI
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

MainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ================================================================= --
-- VÒNG LẶP CHÍNH AUTO FARM
-- ================================================================= --
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

                local currentLv = GetPlayerLevel()
                local qInfo = GetCurrentQuestInfo()
                InfoLabel.Text = "Lv: " .. currentLv .. " | Target: " .. qInfo.MobName

                -- 1. Nếu chưa nhận Quest -> Tự động bay lại NPC nhận Quest
                if AutoQuestEnabled and not HasActiveQuest() then
                    TakeQuest()
                end

                -- 2. Đánh quái khi đã nhận Quest
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
                            ExecuteAttack()
                            task.wait(0.12) -- Giảm nhẹ tốc độ đánh để tránh văng Game
                        end
                    end
                end
            end
            task.wait(0.2)
        end
        StopFarm()
    end)
end

local function ToggleFarm()
    if IsFarming then StopFarm() else StartFarm() end
end

FarmBtn.MouseButton1Click:Connect(ToggleFarm)

QuestBtn.MouseButton1Click:Connect(function()
    AutoQuestEnabled = not AutoQuestEnabled
    if AutoQuestEnabled then
        QuestBtn.Text = "AUTO QUEST NPC: ON"
        QuestBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        QuestBtn.Text = "AUTO QUEST NPC: OFF"
        QuestBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    end
end)

HitboxBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoHitbox = not CONFIG.AutoHitbox
    if CONFIG.AutoHitbox then
        HitboxBtn.Text = "AUTO HITBOX: ON"
        HitboxBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        HitboxBtn.Text = "AUTO HITBOX: OFF"
        HitboxBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CONFIG.ToggleKey then
        ToggleFarm()
    end
end)
