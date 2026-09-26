--!strict
--[[
    Utility Menu Client Script (Luau)
    Vị trí đặt: StarterPlayer > StarterPlayerScripts
    Mô tả: Hệ thống Utility Menu chạy hoàn toàn phía máy khách, tối ưu hóa hiệu năng,
           hỗ trợ Auto Farm, Auto Loot, ESP, Fix Lag, FullBright và Noclip.
--]]

--------------------------------------------------------------------------------
-- 0. BẢNG CẤU HÌNH (CONFIG)
--------------------------------------------------------------------------------
local CONFIG = {
	ToggleKey = Enum.KeyCode.RightShift,

	-- Di chuyển
	WalkSpeed = { Min = 16, Max = 150, Default = 16 },
	Jump = { Min = 7.2, Max = 200, Default = 7.2 },

	-- Tự động di chuyển
	FarmHeightOffset = 5, -- Khoảng cách đứng trên đầu kẻ địch (studs)
	LootStopDistance = 3, -- Khoảng cách dừng lại khi nhặt đồ (studs)
	TweenSpeed = 60, -- Tốc độ di chuyển Tween (studs/giây)
	SearchInterval = 0.5, -- Tần suất quét tìm mục tiêu (giây)

	-- Danh mục Auto Farm & Auto Loot
	EnemyFallbackFolder = "Enemies", -- Thư mục dự phòng chứa NPC trong Workspace
	LootTags = { "Treasure", "DevilFruit", "LootDrop" }, -- Thẻ CollectionService cho vật phẩm

	-- Cấu hình ESP
	ESP = {
		ShowName = true,
		ShowHealth = true,
		ShowDistance = true,
		HideTeammates = true,
		EnemyColor = Color3.fromRGB(255, 60, 60),
		AllyColor = Color3.fromRGB(60, 255, 60),
		UpdateInterval = 0.2,
	},
}

--------------------------------------------------------------------------------
-- 1. KHỞI TẠO DỊCH VỤ & BIẾN TOÀN CỤC CỤC BỘ
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- Quản lý trùng lặp Gui
local EXISTING_GUI = PlayerGui:FindFirstChild("UtilityMenuScreenGui")
if EXISTING_GUI then
	EXISTING_GUI:Destroy()
end

--------------------------------------------------------------------------------
-- 2. BỘ QUẢN LÝ TRẠNG THÁI (STATE MANAGER)
--------------------------------------------------------------------------------
type FeatureStates = {
	FixLag: boolean,
	FullBright: boolean,
	FastWalk: boolean,
	HighJump: boolean,
	AutoFarm: boolean,
	AutoLoot: boolean,
	NoclipManual: boolean,
	ESP: boolean,
}

local States: FeatureStates = {
	FixLag = false,
	FullBright = false,
	FastWalk = false,
	HighJump = false,
	AutoFarm = false,
	AutoLoot = false,
	NoclipManual = false,
	ESP = false,
}

local SettingsValues = {
	WalkSpeed = CONFIG.WalkSpeed.Default,
	JumpValue = CONFIG.Jump.Default,
	SelectedEnemy = "",
	SelectedLootType = "",
}

-- Quản lý Noclip đồng thời (Reference Counter)
local NoclipRequests: { [string]: boolean } = {}
local NoclipConnection: RBXScriptConnection? = nil

local function updateNoclipState()
	local needsNoclip = false
	for _, active in pairs(NoclipRequests) do
		if active then
			needsNoclip = true
			break
		end
	end

	if needsNoclip and not NoclipConnection then
		NoclipConnection = RunService.Stepped:Connect(function()
			local character = LocalPlayer.Character
			if character then
				for _, part in ipairs(character:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end)
	elseif not needsNoclip and NoclipConnection then
		NoclipConnection:Disconnect()
		NoclipConnection = nil
	end
end

local function setNoclipRequest(source: string, enabled: boolean)
	NoclipRequests[source] = enabled or nil
	updateNoclipState()
end

-- Bộ điều phối di chuyển tự động (Mutex)
local ActiveTween: Tween? = nil

local function stopActiveMovement()
	if ActiveTween then
		ActiveTween:Cancel()
		ActiveTween = nil
	end
end

local function setActiveAutoMovement(mode: "None" | "AutoFarm" | "AutoLoot")
	stopActiveMovement()
	if mode == "AutoFarm" then
		States.AutoLoot = false
		setNoclipRequest("AutoLoot", false)
	elseif mode == "AutoLoot" then
		States.AutoFarm = false
		setNoclipRequest("AutoFarm", false)
	elseif mode == "None" then
		States.AutoFarm = false
		States.AutoLoot = false
		setNoclipRequest("AutoFarm", false)
		setNoclipRequest("AutoLoot", false)
	end
end

--------------------------------------------------------------------------------
-- 3. HÀM KẾT NỐI (HOOK FUNCTIONS)
--------------------------------------------------------------------------------
--[[
    HÀM HOOK CHIẾN ĐẤU: Kết nối với hệ thống tấn công của trò chơi.
    Ví dụ: Gọi RemoteEvent tấn công hoặc trigger hàm kích hoạt vũ khí.
--]]
local function attackTarget(targetModel: Model)
	if not targetModel or not targetModel:FindFirstChild("Humanoid") then return end
	-- Chỗ trống an toàn: Thêm mã gọi hệ thống chiến đấu của trò chơi tại đây.
	-- Ví dụ: ReplicatedStorage.Events.Attack:FireServer(targetModel)
end

--[[
    HÀM HOOK NHẶT ĐỒ: Kết nối với cơ chế thu thập vật phẩm.
    Ví dụ: Kích hoạt ProximityPrompt hoặc ClickDetector.
--]]
local function collectLoot(itemInstance: Instance)
	if not itemInstance or not itemInstance.Parent then return end

	local prompt = itemInstance:FindFirstChildOfClass("ProximityPrompt")
		or itemInstance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and prompt.Enabled then
		fireproximityprompt(prompt)
		return
	end

	local detector = itemInstance:FindFirstChildOfClass("ClickDetector")
		or itemInstance:FindFirstChildWhichIsA("ClickDetector", true)
	if detector then
		fireclickdetector(detector)
		return
	end
end

--------------------------------------------------------------------------------
-- 4. THIẾT LẬP GIAO DIỆN NGƯỜI DÙNG (UI CREATION)
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UtilityMenuScreenGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Khung hiển thị Thông báo (Notification Toast)
local ToastContainer = Instance.new("Frame")
ToastContainer.Name = "ToastContainer"
ToastContainer.Size = UDim2.new(0, 250, 0, 150)
ToastContainer.Position = UDim2.new(1, -260, 1, -160)
ToastContainer.BackgroundTransparency = 1
ToastContainer.Parent = ScreenGui

local ToastLayout = Instance.new("UIListLayout")
ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
ToastLayout.Padding = UDim.new(0, 6)
ToastLayout.Parent = ToastContainer

local function showNotification(message: string, isError: boolean?)
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(1, 0, 0, 32)
	toast.BackgroundColor3 = isError and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(40, 140, 60)
	toast.BorderSizePixel = 0
	toast.Parent = ToastContainer

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 6)
	uiCorner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 13
	label.Font = Enum.Font.SourceSansBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = toast

	task.delay(3, function()
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

-- Khung Menu Chính
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 420)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- Thanh Tiêu đề & Cấu chế Kéo thả (Dragging)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 8)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Utility Menu | Luau Client"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -32, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 4)
CloseCorner.Parent = CloseBtn

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -64, 0, 4)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 15
MinimizeBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 4)
MinCorner.Parent = MinimizeBtn

-- Xử lý Kéo Thả (Drag Logic)
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

TopBar.InputChanged:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		MainFrame.Position =
			UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Scroll Container
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, -16, 1, -48)
ContentScroll.Position = UDim2.new(0, 8, 0, 42)
ContentScroll.BackgroundTransparency = 1
ContentScroll.BorderSizePixel = 0
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 620)
ContentScroll.ScrollBarThickness = 4
ContentScroll.Parent = MainFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.Parent = ContentScroll

-- Hàm tạo Nút Bật/Tắt (Toggle Switch UI)
local function createToggle(name: string, callback: (boolean) -> ())
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 36)
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	frame.Parent = ContentScroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 50, 0, 22)
	btn.Position = UDim2.new(1, -60, 0.5, -11)
	btn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	btn.Text = "OFF"
	btn.TextColor3 = Color3.fromRGB(200, 200, 200)
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 12
	btn.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = btn

	local isOn = false
	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		btn.Text = isOn and "ON" or "OFF"
		btn.BackgroundColor3 = isOn and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(70, 70, 80)
		btn.TextColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
		callback(isOn)
	end)

	return function(newState: boolean)
		isOn = newState
		btn.Text = isOn and "ON" or "OFF"
		btn.BackgroundColor3 = isOn and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(70, 70, 80)
		btn.TextColor3 = isOn and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
	end
end

-- Hàm tạo Input/Slider kết hợp
local function createNumberInput(
	name: string,
	minVal: number,
	maxVal: number,
	defaultVal: number,
	onChange: (number) -> ()
)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 44)
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	frame.Parent = ContentScroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, 0, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, 60, 0, 20)
	box.Position = UDim2.new(1, -70, 0, 4)
	box.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	box.Text = tostring(defaultVal)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.Font = Enum.Font.SourceSansBold
	box.TextSize = 13
	box.Parent = frame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = box

	box.FocusLost:Connect(function()
		local num = tonumber(box.Text)
		if num then
			num = math.clamp(num, minVal, maxVal)
			box.Text = tostring(num)
			onChange(num)
		else
			box.Text = tostring(defaultVal)
		end
	end)
end

-- Hàm tạo Menu thả xuống có ô tìm kiếm (Searchable Dropdown)
local function createDropdown(
	name: string,
	getItems: () -> { string },
	onSelect: (string) -> ()
)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 60)
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
	frame.Parent = ContentScroll

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, 0, 0, 24)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(0.55, 0, 0, 24)
	searchBox.Position = UDim2.new(0.42, 0, 0, 4)
	searchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	searchBox.PlaceholderText = "Tìm kiếm..."
	searchBox.Text = ""
	searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	searchBox.Font = Enum.Font.SourceSans
	searchBox.TextSize = 12
	searchBox.Parent = frame

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Size = UDim2.new(1, -20, 0, 22)
	selectedLabel.Position = UDim2.new(0, 10, 0, 32)
	selectedLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	selectedLabel.Text = "Chưa chọn"
	selectedLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	selectedLabel.Font = Enum.Font.SourceSansItalic
	selectedLabel.TextSize = 12
	selectedLabel.Parent = frame

	local function refreshList()
		local query = string.lower(searchBox.Text)
		local items = getItems()
		for _, item in ipairs(items) do
			if query == "" or string.find(string.lower(item), query) then
				selectedLabel.Text = item
				onSelect(item)
				break
			end
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(refreshList)
end

--------------------------------------------------------------------------------
-- 5. TRIỂN KHAI CÁC TÍNH NĂNG (FEATURE IMPLEMENTATION)
--------------------------------------------------------------------------------

-- TÍNH NĂNG 1: FIX LAG (GIẢM GIẬT LAG)
local FixLagCache = {}
local FixLagConn: RBXScriptConnection? = nil

local function applyFixLagToInstance(inst: Instance)
	if
		inst:IsA("ParticleEmitter")
		or inst:IsA("Trail")
		or inst:IsA("Beam")
		or inst:IsA("Smoke")
		or inst:IsA("Fire")
		or inst:IsA("Sparkles")
	then
		if FixLagCache[inst] == nil then
			FixLagCache[inst] = inst.Enabled
		end
		inst.Enabled = false
	elseif
		inst:IsA("PointLight")
		or inst:IsA("SpotLight")
		or inst:IsA("SurfaceLight")
		or inst:IsA("Highlight")
	then
		if FixLagCache[inst] == nil then
			FixLagCache[inst] = inst.Enabled
		end
		inst.Enabled = false
	elseif inst:IsA("PostEffect") then
		if FixLagCache[inst] == nil then
			FixLagCache[inst] = inst.Enabled
		end
		inst.Enabled = false
	end
end

local function toggleFixLag(enable: boolean)
	States.FixLag = enable
	if enable then
		for _, v in ipairs(workspace:GetDescendants()) do
			applyFixLagToInstance(v)
		end
		for _, v in ipairs(Lighting:GetDescendants()) do
			applyFixLagToInstance(v)
		end

		FixLagConn = workspace.DescendantAdded:Connect(function(child)
			if States.FixLag then
				applyFixLagToInstance(child)
			end
		end)
		showNotification("Đã bật chế độ Fix Lag!")
	else
		if FixLagConn then
			FixLagConn:Disconnect()
			FixLagConn = nil
		end
		for inst, origState in pairs(FixLagCache) do
			if inst and inst.Parent then
				pcall(function()
					inst.Enabled = origState
				end)
			end
		end
		table.clear(FixLagCache)
		showNotification("Đã tắt chế độ Fix Lag, khôi phục gốc.")
	end
end

-- TÍNH NĂNG 2: FULL BRIGHT (ĐỘ SÁNG TỐI ĐA)
local LightingCache = {}

local function toggleFullBright(enable: boolean)
	States.FullBright = enable
	if enable then
		LightingCache.Brightness = Lighting.Brightness
		LightingCache.ClockTime = Lighting.ClockTime
		LightingCache.FogEnd = Lighting.FogEnd
		LightingCache.GlobalShadows = Lighting.GlobalShadows
		LightingCache.Ambient = Lighting.Ambient
		LightingCache.OutdoorAmbient = Lighting.OutdoorAmbient

		Lighting.Brightness = 2
		Lighting.ClockTime = 12
		Lighting.FogEnd = 78e3
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(255, 255, 255)
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		showNotification("Đã bật Full Bright!")
	else
		for prop, val in pairs(LightingCache) do
			pcall(function()
				(Lighting :: any)[prop] = val
			end)
		end
		table.clear(LightingCache)
		showNotification("Đã khôi phục ánh sáng ban đầu.")
	end
end

-- TÍNH NĂNG 3 & 4: FAST WALK & HIGH JUMP
local function applyCharacterStats()
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if States.FastWalk then
		humanoid.WalkSpeed = SettingsValues.WalkSpeed
	end

	if States.HighJump then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = SettingsValues.JumpValue
		else
			humanoid.JumpHeight = SettingsValues.JumpValue
		end
	end
end

-- Monitor server override
RunService.Stepped:Connect(function()
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if States.FastWalk and humanoid.WalkSpeed ~= SettingsValues.WalkSpeed then
		humanoid.WalkSpeed = SettingsValues.WalkSpeed
	end
end)

-- TÍNH NĂNG 5: AUTO FARM
local function getEnemiesList(): { string }
	local enemyNames = {}
	local tagged = CollectionService:GetTagged("FarmableEnemy")

	if #tagged > 0 then
		for _, model in ipairs(tagged) do
			if model:IsA("Model") and not table.find(enemyNames, model.Name) then
				table.insert(enemyNames, model.Name)
			end
		end
	else
		local folder = workspace:FindFirstChild(CONFIG.EnemyFallbackFolder)
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				if model:IsA("Model") and not table.find(enemyNames, model.Name) then
					table.insert(enemyNames, model.Name)
				end
			end
		end
	end
	return enemyNames
end

local function getClosestEnemy(targetName: string): Model?
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local myPos = char.HumanoidRootPart.Position

	local closest: Model? = nil
	local minDist = math.huge

	local candidateList = CollectionService:GetTagged("FarmableEnemy")
	if #candidateList == 0 then
		local folder = workspace:FindFirstChild(CONFIG.EnemyFallbackFolder)
		candidateList = folder and folder:GetChildren() or {}
	end

	for _, obj in ipairs(candidateList) do
		if obj:IsA("Model") and obj.Name == targetName then
			local hum = obj:FindFirstChildOfClass("Humanoid")
			local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
			if hum and hum.Health > 0 and root then
				local dist = (root.Position - myPos).Magnitude
				if dist < minDist then
					minDist = dist
					closest = obj
				end
			end
		end
	end
	return closest
end

task.spawn(function()
	while true do
		task.wait(CONFIG.SearchInterval)
		if States.AutoFarm and SettingsValues.SelectedEnemy ~= "" then
			local target = getClosestEnemy(SettingsValues.SelectedEnemy)
			local char = LocalPlayer.Character
			if target and char and char:FindFirstChild("HumanoidRootPart") then
				setNoclipRequest("AutoFarm", true)
				local root = char.HumanoidRootPart
				local targetRoot = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart

				if targetRoot then
					local destination = targetRoot.Position + Vector3.new(0, CONFIG.FarmHeightOffset, 0)
					local dist = (destination - root.Position).Magnitude
					local tweenTime = math.max(dist / CONFIG.TweenSpeed, 0.1)

					stopActiveMovement()
					local info = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
					ActiveTween = TweenService:Create(root, info, {
						CFrame = CFrame.new(destination, targetRoot.Position),
					})
					ActiveTween:Play()

					attackTarget(target)
				end
			else
				setNoclipRequest("AutoFarm", false)
			end
		end
	end
end)

-- TÍNH NĂNG 6: AUTO LOOT
local function getClosestLootItem(): Instance?
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local myPos = char.HumanoidRootPart.Position

	local closest: Instance? = nil
	local minDist = math.huge

	for _, tag in ipairs(CONFIG.LootTags) do
		for _, item in ipairs(CollectionService:GetTagged(tag)) do
			if item:IsDescendantOf(workspace) then
				local part: BasePart? = nil
				if item:IsA("BasePart") then
					part = item
				elseif item:IsA("Model") then
					part = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
				end

				if part then
					local dist = (part.Position - myPos).Magnitude
					if dist < minDist then
						minDist = dist
						closest = item
					end
				end
			end
		end
	end
	return closest
end

task.spawn(function()
	while true do
		task.wait(CONFIG.SearchInterval)
		if States.AutoLoot then
			local item = getClosestLootItem()
			local char = LocalPlayer.Character
			if item and char and char:FindFirstChild("HumanoidRootPart") then
				setNoclipRequest("AutoLoot", true)
				local root = char.HumanoidRootPart
				local targetPart = item:IsA("BasePart") and item
					or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)))

				if targetPart then
					local destination = targetPart.Position + Vector3.new(0, CONFIG.LootStopDistance, 0)
					local dist = (destination - root.Position).Magnitude
					local tweenTime = math.max(dist / CONFIG.TweenSpeed, 0.1)

					stopActiveMovement()
					local info = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
					ActiveTween = TweenService:Create(root, info, { CFrame = CFrame.new(destination) })
					ActiveTween:Play()

					if dist <= CONFIG.LootStopDistance + 2 then
						collectLoot(item)
					end
				end
			else
				setNoclipRequest("AutoLoot", false)
			end
		end
	end
end)

-- TÍNH NĂNG 7: ESP PLAYER
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESP_Storage"
ESPFolder.Parent = ScreenGui

local function removeESP(player: Player)
	local oldContainer = ESPFolder:FindFirstChild(player.Name)
	if oldContainer then
		oldContainer:Destroy()
	end
end

local function createESP(player: Player)
	if player == LocalPlayer then return end
	removeESP(player)

	if CONFIG.ESP.HideTeammates and player.Team ~= nil and player.Team == LocalPlayer.Team then
		return
	end

	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChildOfClass("Humanoid") then
		return
	end

	local container = Instance.new("Folder")
	container.Name = player.Name
	container.Parent = ESPFolder

	-- Highlight
	local highlight = Instance.new("Highlight")
	highlight.Adornee = char
	highlight.FillColor = (player.Team == LocalPlayer.Team) and CONFIG.ESP.AllyColor or CONFIG.ESP.EnemyColor
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.Parent = container

	-- Billboard GUI
	local bb = Instance.new("BillboardGui")
	bb.Adornee = char:FindFirstChild("Head") or char.HumanoidRootPart
	bb.Size = UDim2.new(0, 150, 0, 40)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = container

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 1, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.Font = Enum.Font.SourceSansBold
	infoLabel.TextSize = 12
	infoLabel.TextStrokeTransparency = 0
	infoLabel.Parent = bb

	task.spawn(function()
		while States.ESP and player.Parent and char.Parent do
			local hum = char:FindFirstChildOfClass("Humanoid")
			local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local targetRoot = char:FindFirstChild("HumanoidRootPart")

			if hum and myRoot and targetRoot then
				local dist = math.floor((targetRoot.Position - myRoot.Position).Magnitude)
				infoLabel.Text = string.format(
					"%s\nMáu: %d/%d | [%dm]",
					player.Name,
					math.floor(hum.Health),
					math.floor(hum.MaxHealth),
					dist
				)
			end
			task.wait(CONFIG.ESP.UpdateInterval)
		end
	end)
end

local function toggleESP(enable: boolean)
	States.ESP = enable
	if enable then
		for _, p in ipairs(Players:GetPlayers()) do
			createESP(p)
		end
		showNotification("Đã bật ESP Người chơi!")
	else
		ESPFolder:ClearAllChildren()
		showNotification("Đã tắt ESP.")
	end
end

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		if States.ESP then
			task.wait(0.5)
			createESP(p)
		end
	end)
end)

Players.PlayerRemoving:Connect(removeESP)

--------------------------------------------------------------------------------
-- 6. TẢI CÁC PHẦN TỬ LÊN MENU (REGISTER UI TOGGLES)
--------------------------------------------------------------------------------

createToggle("Tối ưu Đồ họa (Fix Lag)", function(state)
	toggleFixLag(state)
end)

createToggle("Độ sáng Tối đa (Full Bright)", function(state)
	toggleFullBright(state)
end)

createToggle("Di chuyển Nhanh (Fast Walk)", function(state)
	States.FastWalk = state
	applyCharacterStats()
end)

createNumberInput("Tốc độ Đi bộ", CONFIG.WalkSpeed.Min, CONFIG.WalkSpeed.Max, CONFIG.WalkSpeed.Default, function(val)
	SettingsValues.WalkSpeed = val
	applyCharacterStats()
end)

createToggle("Nhảy Cao (High Jump)", function(state)
	States.HighJump = state
	applyCharacterStats()
end)

createNumberInput("Sức mạnh Nhảy", CONFIG.Jump.Min, CONFIG.Jump.Max, CONFIG.Jump.Default, function(val)
	SettingsValues.JumpValue = val
	applyCharacterStats()
end)

createDropdown("Chọn Kẻ địch (Auto Farm)", getEnemiesList, function(selected)
	SettingsValues.SelectedEnemy = selected
	showNotification("Mục tiêu: " .. selected)
end)

createToggle("Tự động Cày (Auto Farm)", function(state)
	if state then
		setActiveAutoMovement("AutoFarm")
		States.AutoFarm = true
		showNotification("Đã bật Auto Farm!")
	else
		setActiveAutoMovement("None")
	end
end)

createToggle("Tự động Nhặt đồ (Auto Loot)", function(state)
	if state then
		setActiveAutoMovement("AutoLoot")
		States.AutoLoot = true
		showNotification("Đã bật Auto Loot!")
	else
		setActiveAutoMovement("None")
	end
end)

createToggle("Đi xuyên Tường (Noclip)", function(state)
	States.NoclipManual = state
	setNoclipRequest("Manual", state)
end)

createToggle("Hiện Người chơi (ESP)", function(state)
	toggleESP(state)
end)

--------------------------------------------------------------------------------
-- 7. NÚT VÀ PHÍM TẮT THU NHỎ / ĐÓNG MENU
--------------------------------------------------------------------------------

local MiniOpenBtn = Instance.new("TextButton")
MiniOpenBtn.Name = "MiniOpenBtn"
MiniOpenBtn.Size = UDim2.new(0, 45, 0, 45)
MiniOpenBtn.Position = UDim2.new(0, 15, 0.5, -22)
MiniOpenBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MiniOpenBtn.Text = "MENU"
MiniOpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniOpenBtn.Font = Enum.Font.SourceSansBold
MiniOpenBtn.TextSize = 12
MiniOpenBtn.Visible = false
MiniOpenBtn.Parent = ScreenGui

local MiniCorner = Instance.new("UICorner")
MiniCorner.CornerRadius = UDim.new(0, 22)
MiniCorner.Parent = MiniOpenBtn

local function toggleMenuVisibility(visible: boolean)
	MainFrame.Visible = visible
	MiniOpenBtn.Visible = not visible
end

MinimizeBtn.MouseButton1Click:Connect(function()
	toggleMenuVisibility(false)
end)

MiniOpenBtn.MouseButton1Click:Connect(function()
	toggleMenuVisibility(true)
end)

CloseBtn.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == CONFIG.ToggleKey then
		toggleMenuVisibility(not MainFrame.Visible)
	end
end)

-- Xử lý Nhân vật Hồi sinh (Respawn Safety)
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	applyCharacterStats()
	if States.NoclipManual then
		setNoclipRequest("Manual", true)
	end
end)

showNotification("Đã tải thành công Utility Menu! Phím mở: RightShift")
