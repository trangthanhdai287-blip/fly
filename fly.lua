local Players = game:Service("Players")
local UserInputService = game:Service("UserInputService")
local RunService = game:Service("RunService")
local Workspace = game:Service("Workspace")
local TweenService = game:Service("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Cấu hình
local FLY_SPEED = 60
local FLYING = false

-- --- TỰ ĐỘNG KHỞI TẠO HOÀN TOÀN GUI ---
local playerGui = player:WaitForChild("PlayerGui")

-- Kiểm tra xem Menu cũ đã tồn tại chưa để xóa tránh trùng lặp
local oldGui = playerGui:FindFirstChild("AutoFlyGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFlyGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Tạo Frame chính cho Menu
local mainFrame = Instance.new("Frame")
mainFrame.Name = "FlyMenu"
mainFrame.Size = UDim2.new(0, 150, 0, 50)
mainFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- Nhấn giữ chuột để kéo menu đi chỗ khác
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- Tạo Nút Bấm Bay
local flyButton = Instance.new("TextButton")
flyButton.Name = "FlyButton"
flyButton.Size = UDim2.new(1, -10, 1, -10)
flyButton.Position = UDim2.new(0, 5, 0, 5)
flyButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Màu đỏ khi TẮT
flyButton.Text = "Bay: TẮT"
flyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flyButton.Font = Enum.Font.SourceSansBold
flyButton.TextSize = 18
flyButton.BorderSizePixel = 0
flyButton.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = flyButton

-- --- HỆ THỐNG VẬT LÝ BAY ---
local attachment = Instance.new("Attachment")
local linearVelocity = Instance.new("LinearVelocity")
linearVelocity.MaxForce = math.huge
linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector3
linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World

local alignOrientation = Instance.new("AlignOrientation")
alignOrientation.MaxTorque = math.huge
alignOrientation.Responsiveness = 20
alignOrientation.Mode = Enum.OrientationMode.OneAttachment

-- Xử lý khi nhân vật hồi sinh (Reset nhân vật không mất menu)
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	if FLYING then
		FLYING = false
		flyButton.Text = "Bay: TẮT"
		flyButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end
	linearVelocity.Parent = nil
	alignOrientation.Parent = nil
	attachment.Parent = nil
end)

-- Hàm xử lý Bật/Tắt bay
local function toggleFly()
	if not rootPart or not humanoid then return end
	FLYING = not FLYING
	
	if FLYING then
		-- Trạng thái BẬT
		humanoid.PlatformStand = true
		attachment.Parent = rootPart
		linearVelocity.Attachment0 = attachment
		linearVelocity.Parent = rootPart
		
		alignOrientation.Attachment0 = attachment
		alignOrientation.Parent = rootPart
		
		TweenService:Create(flyButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
		flyButton.Text = "Bay: BẬT"
	else
		-- Trạng thái TẮT
		humanoid.PlatformStand = false
		linearVelocity.Parent = nil
		alignOrientation.Parent = nil
		attachment.Parent = nil
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		
		TweenService:Create(flyButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}):Play()
		flyButton.Text = "Bay: TẮT"
	end
end

-- Click chuột vào nút trên Menu để bay
flyButton.MouseButton1Click:Connect(toggleFly)

-- Hoặc bấm phím E để bật/tắt nhanh
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		toggleFly()
	end
end)

-- Vòng lặp cập nhật chuyển động
RunService.RenderStepped:Connect(function()
	if not FLYING or not rootPart or not Workspace.CurrentCamera then return end
	
	local camera = Workspace.CurrentCamera
	local moveDirection = Vector3.new(0, 0, 0)
	
	-- Điều khiển hướng bay theo camera
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection += Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection -= Vector3.new(0, 1, 0) end
	
	if moveDirection.Magnitude > 0 then
		linearVelocity.VectorVelocity = moveDirection.Unit * FLY_SPEED
	else
		linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
	end
	
	-- Giữ nhân vật luôn hướng theo camera
	local camLook = camera.CFrame.LookVector
	local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + Vector3.new(camLook.X, 0, camLook.Z))
	alignOrientation.CFrame = targetCFrame
end)
