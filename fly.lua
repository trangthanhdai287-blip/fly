local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local IsFarming = false
local ActiveTween = nil
local BodyVel = nil
local NoclipConn = nil

local RegisterAttack = ReplicatedStorage:FindFirstChild("RegisterAttack", true)
local CommF = ReplicatedStorage:FindFirstChild("CommF_", true)

-- Hàm ép cầm tool đầu tiên (Slot 1)
local function EquipFirstTool()
    local char = LocalPlayer.Character
    if not char then return end
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then return end -- Đang cầm rồi thì thôi
    
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                item.Parent = char
                break
            end
        end
    end
end

-- Hàm Auto Click tấn công
local function AutoClick()
    local char = LocalPlayer.Character
    if not char then return end
    
    EquipFirstTool()
    
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        pcall(function()
            currentTool:Activate()
        end)
    end
    
    if RegisterAttack then
        pcall(function()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                RegisterAttack:FireServer(0, hrp.CFrame)
            end
        end)
    end
end

-- Vòng lặp chính xử lý Auto Farm
task.spawn(function()
    while true do
        if IsFarming then
            AutoClick()
        end
        task.wait(0.05)
    end
end)

-- Tạo giao diện GUI
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local OldGui = playerGui:FindFirstChild("SimpleBloxHub")
if OldGui then OldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SimpleBloxHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 130)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 35)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ BLOX FRUITS HUB"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 12
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Parent = MainFrame

local FarmBtn = Instance.new("TextButton")
FarmBtn.Size = UDim2.new(0.85, 0, 0, 40)
FarmBtn.Position = UDim2.new(0.075, 0, 0, 45)
FarmBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
FarmBtn.Text = "AUTO FARM: OFF"
FarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FarmBtn.TextSize = 12
FarmBtn.Font = Enum.Font.GothamBold
FarmBtn.Parent = MainFrame

local FarmCorner = Instance.new("UICorner")
FarmCorner.CornerRadius = UDim.new(0, 6)
FarmCorner.Parent = FarmBtn

FarmBtn.MouseButton1Click:Connect(function()
    IsFarming = not IsFarming
    if IsFarming then
        FarmBtn.Text = "AUTO FARM: ON"
        FarmBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    else
        FarmBtn.Text = "AUTO FARM: OFF"
        FarmBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    end
end)

-- Kéo thả khung GUI dễ dàng trên màn hình
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
