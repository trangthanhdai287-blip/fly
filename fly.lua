-- Menu tối giản hiển thị trạng thái Fast Attack (Dùng Drawing API)
_G.FastAttack = true
_G.ToggleKey = Enum.KeyCode.End -- Phím End trên bàn phím để bật/tắt

local _ENV = (getgenv or getrenv or getfenv)()

local function SafeWaitForChild(parent, childName)
    local success, result = pcall(function()
        return parent:WaitForChild(childName)
    end)
    return result
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

if not Player then return end

local Net = SafeWaitForChild(SafeWaitForChild(ReplicatedStorage, "Modules"), "Net")
local Enemies = SafeWaitForChild(workspace, "Enemies")
local Characters = SafeWaitForChild(workspace, "Characters")

local Settings = {
    AutoClick = true,
    ClickDelay = 0,
}

local FastAttack = {
    Distance = 100,
    attackMobs = true,
    attackPlayers = true,
}

local RegisterAttack = SafeWaitForChild(Net, "RE/RegisterAttack")
local RegisterHit = SafeWaitForChild(Net, "RE/RegisterHit")

-- Tạo Text hiển thị trạng thái lên màn hình (Menu mini)
local StatusText = Drawing.new("Text")
StatusText.Text = "Fast Attack: [ON]"
StatusText.Size = 18
StatusText.Color = Color3.fromRGB(0, 255, 0)
StatusText.Position = Vector2.new(50, 50)
StatusText.Outline = true
StatusText.Visible = true

-- Phím tắt bật/tắt
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == _G.ToggleKey then
        _G.FastAttack = not _G.FastAttack
        if _G.FastAttack then
            StatusText.Text = "Fast Attack: [ON]"
            StatusText.Color = Color3.fromRGB(0, 255, 0)
        else
            StatusText.Text = "Fast Attack: [OFF]"
            StatusText.Color = Color3.fromRGB(255, 0, 0)
        end
    end
end)

local function IsAlive(character)
    return character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
end

local function ProcessEnemies(OthersEnemies, Folder)
    local BasePart = nil
    if not Folder then return BasePart end
    for _, Enemy in Folder:GetChildren() do
        local Head = Enemy:FindFirstChild("Head")
        if Head and IsAlive(Enemy) and Player:DistanceFromCharacter(Head.Position) < FastAttack.Distance then
            if Enemy ~= Player.Character then
                table.insert(OthersEnemies, { Enemy, Head })
                BasePart = Head
            end
        end
    end
    return BasePart
end

function FastAttack:Attack(BasePart, OthersEnemies)
    if not BasePart or #OthersEnemies == 0 then return end
    RegisterAttack:FireServer(Settings.ClickDelay or 0)
    RegisterHit:FireServer(BasePart, OthersEnemies)
end

function FastAttack:AttackNearest()
    local OthersEnemies = {}
    local Part1 = ProcessEnemies(OthersEnemies, Enemies)
    local Part2 = ProcessEnemies(OthersEnemies, Characters)
    if #OthersEnemies > 0 then
        self:Attack(Part1 or Part2, OthersEnemies)
    end
end

function FastAttack:BladeHits()
    local Equipped = IsAlive(Player.Character) and Player.Character:FindFirstChildOfClass("Tool")
    if Equipped and Equipped.ToolTip ~= "Gun" then
        self:AttackNearest()
    end
end

-- Vòng lặp chạy ngầm
task.spawn(function()
    while task.wait(Settings.ClickDelay) do
        if _G.FastAttack and Settings.AutoClick then
            pcall(function()
                FastAttack:BladeHits()
            end)
        end
    end
end)
