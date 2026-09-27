--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ================================================================= --
-- CẤU HÌNH AUTO FARM (FIXED REPEATED QUEST ISSUE)
-- ================================================================= --
local CONFIG = {
    ToggleKey = Enum.KeyCode.F,             -- Phím Bật/Tắt Auto Farm
    FarmOffset = Vector3.new(0, 10, 0),     -- Độ cao đứng trên đầu quái
    TweenSpeed = 95,                        -- Tốc độ bay
    AutoEquip = true,                       -- Tự lấy vũ khí
    NoAnimation = true,                     -- Bỏ Animation đánh
    AutoQuest = true,                       -- Tự động nhận Quest
    AutoHaki = true,                        -- Tự động bật Haki

    -- Cấu hình Hitbox
    AutoHitbox = true,                      
    HitboxSize = Vector3.new(25, 25, 25),   
    HitboxTransparency = 0.7,               
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

-- NHẬN DIỆN SEA QUA PLACEID
local function GetCurrentSea(): number
    local placeId = game.PlaceId
    if placeId == 2753915549 then
        return 1
    elseif placeId == 4442272183 then
        return 2
    elseif placeId == 7449423635 then
        return 3
    end
    return 1
end

local QUEST_DATABASE: {QuestData} = {
    -- SEA 1
    { Sea = 1, MinLv = 1,   MaxLv = 9,   QuestName = "BanditQuest1",  QuestLevel = 1, MobName = "Bandit",               NpcPos = Vector3.new(1059, 16, 1549),   MobPos = Vector3.new(1145, 17, 1634) },
    { Sea = 1, MinLv = 10,  MaxLv = 14,  QuestName = "JungleQuest",   QuestLevel = 1, MobName = "Monkey",               NpcPos = Vector3.new(-1598, 37, 153),   MobPos = Vector3.new(-1448, 50, 63) },
    { Sea = 1, MinLv = 15,  MaxLv = 29,  QuestName = "JungleQuest",   QuestLevel = 2, MobName = "Gorilla",              NpcPos = Vector3.new(-1598, 37, 153),   MobPos = Vector3.new(-1237, 6, -486) },
    { Sea = 1, MinLv = 30,  MaxLv = 39,  QuestName = "PirateQuest",   QuestLevel = 1, MobName = "Pirate",               NpcPos = Vector3.new(-1140, 4, 3828),   MobPos = Vector3.new(-1215, 4, 3915) },
    { Sea = 1, MinLv = 40,  MaxLv = 59,  QuestName = "PirateQuest",   QuestLevel = 2, MobName = "Brute",                NpcPos = Vector3.new(-1140, 4, 3828),   MobPos = Vector3.new(-1145, 14, 4308) },
    { Sea = 1, MinLv = 60,  MaxLv = 74,  QuestName = "DesertQuest",   QuestLevel = 1, MobName = "Desert Bandit",        NpcPos = Vector3.new(897, 6, 4388),    MobPos = Vector3.new(932, 6, 4484) },
    { Sea = 1, MinLv = 75,  MaxLv = 89,  QuestName = "DesertQuest",   QuestLevel = 2, MobName = "Desert Officer",       NpcPos = Vector3.new(897, 6, 4388),    MobPos = Vector3.new(1572, 10, 4374) },
    { Sea = 1, MinLv = 90,  MaxLv = 99,  QuestName = "SnowQuest",     QuestLevel = 1, MobName = "Snow Bandit",          NpcPos = Vector3.new(1386, 87, -1298), MobPos = Vector3.new(1287, 105, -1380) },
    { Sea = 1, MinLv = 100, MaxLv = 119, QuestName = "SnowQuest",     QuestLevel = 2, MobName = "Snowman",              NpcPos = Vector3.new(1386, 87, -1298), MobPos = Vector3.new(1285, 150, -1140) },
    { Sea = 1, MinLv = 120, MaxLv = 149, QuestName = "MarineQuest2",  QuestLevel = 1, MobName = "Chief Petty Officer",  NpcPos = Vector3.new(-5030, 28, 4323), MobPos = Vector3.new(-4855, 22, 4260) },
    { Sea = 1, MinLv = 150, MaxLv = 174, QuestName = "SkyQuest",      QuestLevel = 1, MobName = "Sky Bandit",           NpcPos = Vector3.new(-4842, 717, -2623),MobPos = Vector3.new(-4975, 718, -2885) },
    { Sea = 1, MinLv = 175, MaxLv = 224, QuestName = "SkyQuest",      QuestLevel = 2, MobName = "Dark Master",          NpcPos = Vector3.new(-4842, 717, -2623),MobPos = Vector3.new(-5250, 388, -2250) },
    { Sea = 1, MinLv = 225, MaxLv = 274, QuestName = "ColosseumQuest",QuestLevel = 1, MobName = "Toga Warrior",         NpcPos = Vector3.new(-1575, 7, -2982), MobPos = Vector3.new(-1805, 7, -2745) },
    { Sea = 1, MinLv = 275, MaxLv = 299, QuestName = "ColosseumQuest",QuestLevel = 2, MobName = "Gladiator",            NpcPos = Vector3.new(-1575, 7, -2982), MobPos = Vector3.new(-1385, 7, -3315) },
    { Sea = 1, MinLv = 300, MaxLv = 324, QuestName = "MagmaQuest",    QuestLevel = 1, MobName = "Military Soldier",     NpcPos = Vector3.new(-5313, 12, 8515),  MobPos = Vector3.new(-5415, 78, 8580) },
    { Sea = 1, MinLv = 325, MaxLv = 374, QuestName = "MagmaQuest",    QuestLevel = 2, MobName = "Military Spy",         NpcPos = Vector3.new(-5313, 12, 8515),  MobPos = Vector3.new(-5815, 78, 8820) },
    { Sea = 1, MinLv = 375, MaxLv = 399, QuestName = "FishmanQuest",  QuestLevel = 1, MobName = "Fishman Warrior",      NpcPos = Vector3.new(61122, 18, 1569), MobPos = Vector3.new(60885, 18, 1530) },
    { Sea = 1, MinLv = 400, MaxLv = 449, QuestName = "FishmanQuest",  QuestLevel = 2, MobName = "Fishman Commando",     NpcPos = Vector3.new(61122, 18, 1569), MobPos = Vector3.new(61815, 18, 1470) },
    { Sea = 1, MinLv = 450, MaxLv = 474, QuestName = "SkyExp1Quest",  QuestLevel = 1, MobName = "God's Guard",          NpcPos = Vector3.new(-4720, 845, -1950),MobPos = Vector3.new(-4715, 845, -1865) },
    { Sea = 1, MinLv = 475, MaxLv = 524, QuestName = "SkyExp1Quest",  QuestLevel = 2, MobName = "Shandora Warrior",     NpcPos = Vector3.new(-4720, 845, -1950),MobPos = Vector3.new(-5230, 845, -2250) },
    { Sea = 1, MinLv = 525, MaxLv = 550, QuestName = "SkyExp2Quest",  QuestLevel = 1, MobName = "Royal Squad",          NpcPos = Vector3.new(-7905, 5611, -2280),MobPos = Vector3.new(-7685, 5607, -1450) },
    { Sea = 1, MinLv = 551, MaxLv = 624, QuestName = "SkyExp2Quest",  QuestLevel = 2, MobName = "Royal Soldier",        NpcPos = Vector3.new(-7905, 5611, -2280),MobPos = Vector3.new(-7835, 5607, -1770) },
    { Sea = 1, MinLv = 625, MaxLv = 649, QuestName = "FountainQuest", QuestLevel = 1, MobName = "Galley Pirate",        NpcPos = Vector3.new(5258, 38, 4050),    MobPos = Vector3.new(5585, 38, 3990) },
    { Sea = 1, MinLv = 650, MaxLv = 700, QuestName = "FountainQuest", QuestLevel = 2, MobName = "Galley Captain",       NpcPos = Vector3.new(5258, 38, 4050),    MobPos = Vector3.new(5645, 38, 4950) },

    -- SEA 2
    { Sea = 2, MinLv = 700, MaxLv = 724, QuestName = "Area1Quest",    QuestLevel = 1, MobName = "Raider",               NpcPos = Vector3.new(-425, 73, 1836),   MobPos = Vector3.new(-740, 73, 2380) },
    { Sea = 2, MinLv = 725, MaxLv = 774, QuestName = "Area1Quest",    QuestLevel = 2, MobName = "Mercenary",            NpcPos = Vector3.new(-425, 73, 1836),   MobPos = Vector3.new(-960, 73, 1420) },
    { Sea = 2, MinLv = 775, MaxLv = 799, QuestName = "Area2Quest",    QuestLevel = 1, MobName = "Swan Pirate",          NpcPos = Vector3.new(637, 73, 918),     MobPos = Vector3.new(880, 120, 1210) },
    { Sea = 2, MinLv = 800, MaxLv = 874, QuestName = "Area2Quest",    QuestLevel = 2, MobName = "Factory Staff",        NpcPos = Vector3.new(637, 73, 918),     MobPos = Vector3.new(295, 73, -50) },
    { Sea = 2, MinLv = 875, MaxLv = 899, QuestName = "MarineQuest",   QuestLevel = 1, MobName = "Marine Lieutenant",    NpcPos = Vector3.new(-2440, 73, -3216), MobPos = Vector3.new(-2810, 73, -3030) },
    { Sea = 2, MinLv = 900, MaxLv = 949, QuestName = "MarineQuest",   QuestLevel = 2, MobName = "Marine Captain",       NpcPos = Vector3.new(-2440, 73, -3216), MobPos = Vector3.new(-1880, 73, -3320) },
    { Sea = 2, MinLv = 950, MaxLv = 974, QuestName = "ZombieQuest",   QuestLevel = 1, MobName = "Zombie",               NpcPos = Vector3.new(-5497, 48, -795),  MobPos = Vector3.new(-5630, 48, -710) },
    { Sea = 2, MinLv = 975, MaxLv = 999, QuestName = "ZombieQuest",   QuestLevel = 2, MobName = "Vampire",              NpcPos = Vector3.new(-5497, 48, -795),  MobPos = Vector3.new(-6010, 6, -1310) },
    { Sea = 2, MinLv = 1000,MaxLv = 1049,QuestName = "SnowMountainQuest", QuestLevel = 1, MobName = "Snow Trooper",     NpcPos = Vector3.new(609, 401, -5372),  MobPos = Vector3.new(480, 401, -5300) },
    { Sea = 2, MinLv = 1050,MaxLv = 1099,QuestName = "SnowMountainQuest", QuestLevel = 2, MobName = "Winter Warrior",   NpcPos = Vector3.new(609, 401, -5372),  MobPos = Vector3.new(1180, 430, -5180) },
    { Sea = 2, MinLv = 1100,MaxLv = 1124,QuestName = "IceSideQuest",  QuestLevel = 1, MobName = "Lab Subordinate",      NpcPos = Vector3.new(-6060, 16, -4905), MobPos = Vector3.new(-5780, 16, -4480) },
    { Sea = 2, MinLv = 1125,MaxLv = 1174,QuestName = "IceSideQuest",  QuestLevel = 2, MobName = "Horned Warrior",       NpcPos = Vector3.new(-6060, 16, -4905), MobPos = Vector3.new(-6410, 16, -5840) },
    { Sea = 2, MinLv = 1175,MaxLv = 1199,QuestName = "FireSideQuest", QuestLevel = 1, MobName = "Magma Ninja",         NpcPos = Vector3.new(-5430, 16, -5295), MobPos = Vector3.new(-5430, 16, -5840) },
    { Sea = 2, MinLv = 1200,MaxLv = 1249,QuestName = "FireSideQuest", QuestLevel = 2, MobName = "Lava Pirate",         NpcPos = Vector3.new(-5430, 16, -5295), MobPos = Vector3.new(-5240, 16, -4850) },
    { Sea = 2, MinLv = 1250,MaxLv = 1274,QuestName = "ShipQuest1",    QuestLevel = 1, MobName = "Ship Deckhand",        NpcPos = Vector3.new(1038, 125, 32911), MobPos = Vector3.new(1190, 130, 32980) },
    { Sea = 2, MinLv = 1275,MaxLv = 1299,QuestName = "ShipQuest1",    QuestLevel = 2, MobName = "Ship Engineer",        NpcPos = Vector3.new(1038, 125, 32911), MobPos = Vector3.new(910, 130, 32810) },
    { Sea = 2, MinLv = 1300,MaxLv = 1324,QuestName = "ShipQuest2",    QuestLevel = 1, MobName = "Ship Steward",         NpcPos = Vector3.new(968, 125, 32911),  MobPos = Vector3.new(910, 130, 33410) },
    { Sea = 2, MinLv = 1325,MaxLv = 1349,QuestName = "ShipQuest2",    QuestLevel = 2, MobName = "Clapper",              NpcPos = Vector3.new(968, 125, 32911),  MobPos = Vector3.new(680, 130, 33410) },
    { Sea = 2, MinLv = 1350,MaxLv = 1399,QuestName = "FrostQuest",    QuestLevel = 1, MobName = "Arctic Warrior",       NpcPos = Vector3.new(5667, 28, -6486),  MobPos = Vector3.new(6010, 28, -6210) },
    { Sea = 2, MinLv = 1400,MaxLv = 1424,QuestName = "FrostQuest",    QuestLevel = 2, MobName = "Snow Lurker",          NpcPos = Vector3.new(5667, 28, -6486),  MobPos = Vector3.new(5510, 60, -6810) },
    { Sea = 2, MinLv = 1425,MaxLv = 1474,QuestName = "ForgottenQuest",QuestLevel = 1, MobName = "Sea Soldier",          NpcPos = Vector3.new(-3054, 235, -10142),MobPos = Vector3.new(-3050, 235, -9780) },
    { Sea = 2, MinLv = 1475,MaxLv = 1500,QuestName = "ForgottenQuest",QuestLevel = 2, MobName = "Water Fighter",       NpcPos = Vector3.new(-3054, 235, -10142),MobPos = Vector3.new(-3380, 235, -10580) },

    -- SEA 3
    { Sea = 3, MinLv = 1500,MaxLv = 1524,QuestName = "PiratePortQuest",QuestLevel = 1, MobName = "Pirate Millionaire",  NpcPos = Vector3.new(-290, 44, 5580),   MobPos = Vector3.new(-370, 75, 5550) },
    { Sea = 3, MinLv = 1525,MaxLv = 1574,QuestName = "PiratePortQuest",QuestLevel = 2, MobName = "Pistol Billionaire", NpcPos = Vector3.new(-290, 44, 5580),   MobPos = Vector3.new(-460, 75, 5920) },
    { Sea = 3, MinLv = 1575,MaxLv = 1599,QuestName = "AmazonQuest",    QuestLevel = 1, MobName = "Dragon Crew Warrior",NpcPos = Vector3.new(5832, 52, -1105), MobPos = Vector3.new(6350, 52, -1210) },
    { Sea = 3, MinLv = 1600,MaxLv = 1624,QuestName = "AmazonQuest",    QuestLevel = 2, MobName = "Dragon Crew Archer", NpcPos = Vector3.new(5832, 52, -1105), MobPos = Vector3.new(6580, 52, -950) },
    { Sea = 3, MinLv = 1625,MaxLv = 1649,QuestName = "AmazonQuest2",   QuestLevel = 1, MobName = "Female Islander",    NpcPos = Vector3.new(5440, 602, 750),   MobPos = Vector3.new(4820, 602, 720) },
    { Sea = 3, MinLv = 1650,MaxLv = 1699,QuestName = "AmazonQuest2",   QuestLevel = 2, MobName = "Giant Islander",     NpcPos = Vector3.new(5440, 602, 750),   MobPos = Vector3.new(5020, 602, 310) },
    { Sea = 3, MinLv = 1700,MaxLv = 1724,QuestName = "MarineTreeQuest",QuestLevel = 1, MobName = "Marine Commodore",   NpcPos = Vector3.new(2180, 29, -6740),  MobPos = Vector3.new(2450, 73, -6780) },
    { Sea = 3, MinLv = 1725,MaxLv = 1774,QuestName = "MarineTreeQuest",QuestLevel = 2, MobName = "Rear Admiral",       NpcPos = Vector3.new(2180, 29, -6740),  MobPos = Vector3.new(2820, 73, -7200) },
    { Sea = 3, MinLv = 1775,MaxLv = 1799,QuestName = "DeepForestIsland1Quest", QuestLevel = 1, MobName = "Fishman Raider", NpcPos = Vector3.new(-10580, 332, -8758), MobPos = Vector3.new(-10380, 332, -8980) },
    { Sea = 3, MinLv = 1800,MaxLv = 1824,QuestName = "DeepForestIsland1Quest", QuestLevel = 2, MobName = "Fishman Captain", NpcPos = Vector3.new(-10580, 332, -8758), MobPos = Vector3.new(-10980, 332, -8920) },
    { Sea = 3, MinLv = 1825,MaxLv = 1849,QuestName = "DeepForestIsland2Quest", QuestLevel = 1, MobName = "Forest Pirate",  NpcPos = Vector3.new(-13230, 332, -7625), MobPos = Vector3.new(-13420, 332, -7910) },
    { Sea = 3, MinLv = 1850,MaxLv = 1899,QuestName = "DeepForestIsland2Quest", QuestLevel = 2, MobName = "Mythological Pirate", NpcPos = Vector3.new(-13230, 332, -7625), MobPos = Vector3.new(-13520, 332, -6910) },
    { Sea = 3, MinLv = 1900,MaxLv = 1924,QuestName = "HauntedQuest1",  QuestLevel = 1, MobName = "Reborn Skeleton",    NpcPos = Vector3.new(-9480, 142, 5520),  MobPos = Vector3.new(-8810, 142, 6030) },
    { Sea = 3, MinLv = 1925,MaxLv = 1974,QuestName = "HauntedQuest1",  QuestLevel = 2, MobName = "Living Zombie",      NpcPos = Vector3.new(-9480, 142, 5520),  MobPos = Vector3.new(-10110, 142, 5810) },
    { Sea = 3, MinLv = 1975,MaxLv = 1999,QuestName = "HauntedQuest2",  QuestLevel = 1, MobName = "Demonic Soul",       NpcPos = Vector3.new(-9515, 172, 6070),  MobPos = Vector3.new(-9510, 172, 6720) },
    { Sea = 3, MinLv = 2000,MaxLv = 2049,QuestName = "HauntedQuest2",  QuestLevel = 2, MobName = "Posessed Mummy",     NpcPos = Vector3.new(-9515, 172, 6070),  MobPos = Vector3.new(-9580, 10, 6180) },
    { Sea = 3, MinLv = 2050,MaxLv = 2074,QuestName = "PeanutQuest",    QuestLevel = 1, MobName = "Peanut Scout",       NpcPos = Vector3.new(-2105, 38, -10190),MobPos = Vector3.new(-2120, 38, -10410) },
    { Sea = 3, MinLv = 2075,MaxLv = 2124,QuestName = "PeanutQuest",    QuestLevel = 2, MobName = "Peanut President",   NpcPos = Vector3.new(-2105, 38, -10190),MobPos = Vector3.new(-2020, 38, -10710) },
    { Sea = 3, MinLv = 2125,MaxLv = 2149,QuestName = "IceCreamQuest",  QuestLevel = 1, MobName = "Ice Cream Chef",     NpcPos = Vector3.new(-820, 65, -10965), MobPos = Vector3.new(-640, 65, -11250) },
    { Sea = 3, MinLv = 2150,MaxLv = 2199,QuestName = "IceCreamQuest",  QuestLevel = 2, MobName = "Ice Cream Commander",NpcPos = Vector3.new(-820, 65, -10965), MobPos = Vector3.new(-1120, 65, -11250) },
    { Sea = 3, MinLv = 2200,MaxLv = 2224,QuestName = "CakeQuest1",     QuestLevel = 1, MobName = "Cookie Crafter",     NpcPos = Vector3.new(-2020, 38, -12025),MobPos = Vector3.new(-2380, 38, -12110) },
    { Sea = 3, MinLv = 2225,MaxLv = 2249,QuestName = "CakeQuest1",     QuestLevel = 2, MobName = "Cake Guard",          NpcPos = Vector3.new(-2020, 38, -12025),MobPos = Vector3.new(-1610, 38, -12410) },
    { Sea = 3, MinLv = 2250,MaxLv = 2299,QuestName = "CakeQuest2",     QuestLevel = 1, MobName = "Baking Staff",        NpcPos = Vector3.new(-1925, 38, -12850),MobPos = Vector3.new(-1820, 38, -13110) },
    { Sea = 3, MinLv = 2300,MaxLv = 2324,QuestName = "CakeQuest2",     QuestLevel = 2, MobName = "Head Baker",          NpcPos = Vector3.new(-1925, 38, -12850),MobPos = Vector3.new(-2180, 38, -13110) },
    { Sea = 3, MinLv = 2325,MaxLv = 2374,QuestName = "ChocolatierQuest",QuestLevel = 1, MobName = "Cocoa Warrior",     NpcPos = Vector3.new(220, 24, -12100),  MobPos = Vector3.new(210, 24, -12410) },
    { Sea = 3, MinLv = 2375,MaxLv = 2399,QuestName = "ChocolatierQuest",QuestLevel = 2, MobName = "Chocolate Bar Battler",NpcPos = Vector3.new(220, 24, -12100),MobPos = Vector3.new(580, 24, -12410) },
    { Sea = 3, MinLv = 2400,MaxLv = 2449,QuestName = "CandyQuest",     QuestLevel = 1, MobName = "Sweet Thief",        NpcPos = Vector3.new(-1150, 15, -14250),MobPos = Vector3.new(-1150, 15, -14550) },
    { Sea = 3, MinLv = 2450,MaxLv = 2550,QuestName = "CandyQuest",     QuestLevel = 2, MobName = "Candy Rebel",        NpcPos = Vector3.new(-1150, 15, -14250),MobPos = Vector3.new(-1420, 15, -14550) },
}

local LocalPlayer = Players.LocalPlayer
local IsFarming = false
local AutoQuestEnabled = CONFIG.AutoQuest
local ActiveTween: Tween? = nil
local NoclipConn: RBXScriptConnection? = nil
local BodyVel: BodyVelocity? = nil

local RegisterAttack = ReplicatedStorage:FindFirstChild("RegisterAttack", true) :: RemoteEvent?
local CommF = ReplicatedStorage:FindFirstChild("CommF_", true) :: RemoteFunction?

local function EnableHaki()
    if not CONFIG.AutoHaki then return end
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild("HasBuso") then
        if CommF then
            pcall(function() CommF:InvokeServer("Buso") end)
        end
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
    
    local matchedQuest: QuestData? = nil
    local lastQuestOfSea: QuestData? = nil

    for _, qData in ipairs(QUEST_DATABASE) do
        if qData.Sea == currentSea then
            lastQuestOfSea = qData
            if myLevel >= qData.MinLv and myLevel <= qData.MaxLv then
                matchedQuest = qData
                break
            end
        end
    end

    if matchedQuest then return matchedQuest end
    if lastQuestOfSea then return lastQuestOfSea end
    return QUEST_DATABASE[1]
end

-- KIỂM TRA QUEST ỔN ĐỊNH (CHỐNG CHỚP UI KHI QUÁI CHẾT)
local function HasActiveQuest(): boolean
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    local mainGui = playerGui:FindFirstChild("Main")
    if not mainGui then return false end

    local questFrame = mainGui:FindFirstChild("Quest")
    if questFrame and questFrame.Visible then
        return true
    end

    -- Thử kiểm tra lại sau 0.25s để tránh trường hợp UI đang chớp refresh
    task.wait(0.25)
    if questFrame and questFrame.Visible then
        return true
    end

    return false
end

-- HÀM NHẬN QUEST CHẮC CHẮN
local function TakeQuest(): boolean
    if not AutoQuestEnabled or HasActiveQuest() then return true end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return false end

    local qInfo = GetCurrentQuestInfo()
    local targetNpcCFrame = CFrame.new(qInfo.NpcPos + Vector3.new(0, 3, 0))

    -- 1. Bay đến NPC
    local distToNpc = (qInfo.NpcPos - hrp.Position).Magnitude
    if distToNpc > 10 then
        local tweenTime = math.max(0.1, distToNpc / CONFIG.TweenSpeed)
        if ActiveTween then ActiveTween:Cancel() end
        
        ActiveTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = targetNpcCFrame
        })
        ActiveTween:Play()
        task.wait(tweenTime)
    end

    -- 2. Giữ chân nhân vật 0.4s để Server xác nhận đứng cạnh NPC
    local startWait = os.clock()
    while os.clock() - startWait < 0.4 do
        hrp.CFrame = targetNpcCFrame
        task.wait(0.05)
    end

    -- 3. Gọi RemoteFunction nhận Quest
    for retry = 1, 3 do
        if HasActiveQuest() then return true end

        if CommF then
            pcall(function()
                CommF:InvokeServer("StartQuest", qInfo.QuestName, qInfo.QuestLevel)
            end)
        end

        task.wait(0.3)
    end

    return HasActiveQuest()
end

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

local function ExecuteAttack()
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
    if currentTool then currentTool:Activate() end

    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)

    if RegisterAttack then
        pcall(function() RegisterAttack:FireServer(0) end)
    end
end

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
    local targetMobName = qInfo.MobName

    local closest: Model? = nil
    local minDist = math.huge

    for _, enemy in ipairs(enemyFolder:GetChildren()) do
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

-- GUI CONTROL
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
MainFrame.Size = UDim2.new(0, 270, 0, 310)
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
TitleLabel.Text = "⚡ AUTO FARM (STABLE QUEST)"
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

local HakiBtn = Instance.new("TextButton")
HakiBtn.Size = UDim2.new(0.85, 0, 0, 38)
HakiBtn.Position = UDim2.new(0.075, 0, 0, 178)
HakiBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
HakiBtn.Text = "AUTO HAKI: ON"
HakiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HakiBtn.TextSize = 12
HakiBtn.Font = Enum.Font.GothamBold
HakiBtn.Parent = MainFrame

local HakiBtnCorner = Instance.new("UICorner")
HakiBtnCorner.CornerRadius = UDim.new(0, 6)
HakiBtnCorner.Parent = HakiBtn

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 45)
InfoLabel.Position = UDim2.new(0, 10, 0, 224)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Sea: " .. GetCurrentSea() .. " | Lv: " .. GetPlayerLevel() .. " | Ready"
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

-- VÒNG LẶP CHÍNH (STABLE FARM LOOP)
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
                EnableHaki()

                local currentLv = GetPlayerLevel()
                local qInfo = GetCurrentQuestInfo()

                -- 1. Chỉ nhận Quest khi CHẮC CHẮN không có Quest
                if AutoQuestEnabled and not HasActiveQuest() then
                    InfoLabel.Text = "Sea " .. GetCurrentSea() .. " | Lv: " .. currentLv .. " | Đang nhận Quest..."
                    TakeQuest()
                end

                -- 2. Đánh quái
                local target = GetTargetEnemy()

                if target then
                    InfoLabel.Text = "Sea " .. GetCurrentSea() .. " | Target: " .. qInfo.MobName
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
                            task.wait(0.12)
                        end
                    end
                else
                    InfoLabel.Text = "Sea " .. GetCurrentSea() .. " | Tim quai: " .. qInfo.MobName
                    local targetMobPos = qInfo.MobPos + CONFIG.FarmOffset
                    local distToMobPos = (targetMobPos - hrp.Position).Magnitude

                    if distToMobPos > 15 then
                        local tweenTime = math.max(0.1, distToMobPos / CONFIG.TweenSpeed)
                        if ActiveTween then ActiveTween:Cancel() end
                        ActiveTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                            CFrame = CFrame.new(targetMobPos)
                        })
                        ActiveTween:Play()
                        task.wait(tweenTime)
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

HakiBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoHaki = not CONFIG.AutoHaki
    if CONFIG.AutoHaki then
        HakiBtn.Text = "AUTO HAKI: ON"
        HakiBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        EnableHaki()
    else
        HakiBtn.Text = "AUTO HAKI: OFF"
        HakiBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CONFIG.ToggleKey then
        ToggleFarm()
    end
end)
