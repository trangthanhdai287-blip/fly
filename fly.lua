--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local ActiveTween: Tween? = nil
local LastQuestAttempt = 0
local QUEST_COOLDOWN = 3.0 -- Thời gian chờ giữa các lần gọi nhận quest
local TWEEN_SPEED = 95     -- Tốc độ di chuyển tới NPC

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

-- Tìm CommF_ an toàn và chuẩn xác
local function GetCommF(): RemoteFunction?
    local rem = ReplicatedStorage:FindFirstChild("CommF_")
    if not rem then
        rem = ReplicatedStorage:FindFirstChild("CommF_", true)
    end
    return rem :: RemoteFunction?
end

-- Xác định Sea hiện tại
local function GetCurrentSea(): number
    local placeId = game.PlaceId
    if placeId == 2753915549 then return 1
    elseif placeId == 4442272183 then return 2
    elseif placeId == 7449423635 then return 3 end
    return 1
end

-- Lấy Level nhân vật
local function GetPlayerLevel(): number
    local data = LocalPlayer:FindFirstChild("Data")
    if data then
        local levelVal = data:FindFirstChild("Level") :: IntValue?
        if levelVal then return levelVal.Value end
    end
    return 1
end

-- Database Quest đầy đủ (Sea 1, 2, 3)
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

-- Lấy thông tin Quest phù hợp theo Level và Sea
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

-- Kiểm tra xem đã nhận quest chưa
local function HasActiveQuest(): boolean
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return false end

    local trackedFrame = playerGui:FindFirstChild("TrackedQuestFrame", true)
    if trackedFrame then
        if trackedFrame:IsA("GuiObject") and not trackedFrame.Visible then return false end
        local frame = trackedFrame:FindFirstChild("Frame") :: GuiObject?
        if frame then
            if not frame.Visible then return false end
            local progressLabel = frame:FindFirstChild("progress", true) :: TextLabel?
            local headerLabel = frame:FindFirstChild("header", true) :: TextLabel?

            if progressLabel and progressLabel.Text ~= "" and progressLabel.Text ~= "0" then return true end
            if headerLabel and headerLabel.Text ~= "" then return true end
        end
    end
    return false
end

-- Hàm thực hiện đi nhận Quest (Tween đến NPC và gọi Remotes qua GetCommF an toàn)
local function TakeQuest()
    if HasActiveQuest() then return end
    if os.clock() - LastQuestAttempt < QUEST_COOLDOWN then return end

    LastQuestAttempt = os.clock()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    local qInfo = GetCurrentQuestInfo()
    print("[AutoQuest] Đang nhận quest:", qInfo.QuestName, "Level:", qInfo.QuestLevel, "Mob:", qInfo.MobName)

    local targetNpcCFrame = CFrame.new(qInfo.NpcPos + Vector3.new(0, 3, 0))
    local distToNpc = (qInfo.NpcPos - hrp.Position).Magnitude

    -- Tween tới NPC nếu ở xa
    if distToNpc > 10 then
        local tweenTime = math.max(0.1, distToNpc / TWEEN_SPEED)
        if ActiveTween then ActiveTween:Cancel() end

        ActiveTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = targetNpcCFrame
        })
        ActiveTween:Play()

        local checkInterval = 0.1
        for _ = 1, math.floor(tweenTime / checkInterval) do
            if HasActiveQuest() then
                if ActiveTween then ActiveTween:Cancel() end
                return
            end
            task.wait(checkInterval)
        end
    end

    if HasActiveQuest() then return end

    -- Teleport nhẹ sát NPC và gọi Remote nhận Quest
    hrp.CFrame = targetNpcCFrame
    task.wait(0.2)

    local CommF = GetCommF()
    if CommF then
        local success, err = pcall(function()
            CommF:InvokeServer("StartQuest", qInfo.QuestName, qInfo.QuestLevel)
        end)
        if not success then
            warn("[AutoQuest Lỗi]: ", err)
        end
    else
        warn("[AutoQuest Lỗi]: Không tìm thấy RemoteFunction CommF_!")
    end
end

-- Vòng lặp chạy ngầm tự động nhận Quest liên tục
task.spawn(function()
    while true do
        if not HasActiveQuest() then
            TakeQuest()
        end
        task.wait(1)
    end
end)
