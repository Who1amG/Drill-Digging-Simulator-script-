-- DRACO 🔫 (FINAL FIXED)
-- CASH • DRILL • WIN
-- Beautiful Notifications • Clock • REAL Cycles • Map Selector (ONLY MAPS)
-- NO += / NO ..= (executor friendly)
-- AUTO WIN uses TP -> short wait -> StopAutoFarm, every 7s

-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")


local lp = Players.LocalPlayer
local PlayerGui = lp:WaitForChild("PlayerGui")

-- ================= REMOTES (SAFE) =================
local GiveCash = RS:FindFirstChild("GiveCash")
local AFKFolder = RS:FindFirstChild("AFKFarming")
local StopAutoFarm = AFKFolder and AFKFolder:FindFirstChild("StopAutoFarm")

-- ================= CONFIG =================
local AUTO_CASH_RATE = 60
local CASH_RATE_MIN = 30
local CASH_RATE_MAX = 1000
local pendingCashRate = AUTO_CASH_RATE

local AUTO_WIN_DELAY = 7 -- fijo
local AUTO_WIN_RETURN_WAIT = 0.55 -- espera corta para que el juego lo detecte (no insta)
local AUTO_WIN_RESTORE_WAIT = 0.15 -- restore after StopAutoFarm

local VALID_DRILLS = {
	Infinity=true, Rusty=true, Golden=true, Candy=true,
	Neon=true, Cyber=true, Diamond=true, Lava=true,
	Fossil=true, Amber=true, Volcano=true,

	Vinecutter=true,
	["Jungle Beast"]=true,
	Thornspike=true,
	Spellboun=true,
	["Arcane Auger"]=true,
	["Mystic Bore"]=true,
    Glacier=true,
    Icebreaker=true,
    Permafrost=true,

	["Aegean Tide"]=true,
	Olympian=true,
	Herculean=true,

	["Celestial Borer"]=true,
	Voidstar=true,
	["Rift Auger"]=true
}

-- MAPAS (SOLO LOS QUE DIJISTE)
local MAPS = {
	"Jungle",
	"Magic",
	"Ancient Greek",
	"Astral",
	"Dragon",
	"Main",
	"Frozen",
	"Dinosaur"
}
local selectedMap = "Dragon"

-- ================= STATE =================
local cashOn = false
local drillOn = false
local winOn = false

local cashAcc = 0
local mouseDown = false

-- AUTO WIN STATE MACHINE (NO task.wait in Heartbeat)
local winTimer = AUTO_WIN_DELAY
local winCycles = 0
local winStage = "idle"     -- idle / returning / restoring
local winStageTimer = 0
local winBusy = false
local winReturnCFrame = nil

-- ================= WORLD HELPERS =================
local function getWorldsFolder()
	return workspace:FindFirstChild("Worlds")
end

local function getEndZone(worldName)
	local worlds = getWorldsFolder()
	if not worlds then return nil end
	local world = worlds:FindFirstChild(worldName)
	if not world then return nil end

	local ez = world:FindFirstChild("EndZone")
	if not ez then return nil end
	local ec = ez:FindFirstChild("EndCircle")
	if not ec then return nil end
	local part = ec:FindFirstChild("Part")
	if not part or not part:IsA("BasePart") then return nil end
	return part
end

local function findTeleportPartInWorld(world)
	if not world then return nil end

	local direct = world:FindFirstChild("Teleport") or world:FindFirstChild("TP") or world:FindFirstChild("Spawn") or world:FindFirstChild("Start") or world:FindFirstChild("StartZone") or world:FindFirstChild("SpawnLocation")
	if direct then
		if direct:IsA("BasePart") then return direct end
		if direct:IsA("Model") then
			local pp = direct.PrimaryPart or direct:FindFirstChildWhichIsA("BasePart", true)
			if pp and pp:IsA("BasePart") then return pp end
		end
		local bp = direct:FindFirstChildWhichIsA("BasePart", true)
		if bp and bp:IsA("BasePart") then return bp end
	end

	local candidates = {"Teleport","TP","Spawn","Start","StartZone","SpawnLocation","SpawnPoint","Lobby","Portal"}
	for _, name in ipairs(candidates) do
		local obj = world:FindFirstChild(name, true)
		if obj then
			if obj:IsA("BasePart") then return obj end
			if obj:IsA("Model") then
				local pp2 = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
				if pp2 and pp2:IsA("BasePart") then return pp2 end
			end
			local bp2 = obj:FindFirstChildWhichIsA("BasePart", true)
			if bp2 and bp2:IsA("BasePart") then return bp2 end
		end
	end

	local any = world:FindFirstChildWhichIsA("BasePart", true)
	if any and any:IsA("BasePart") then return any end
	return nil
end

local function getMapTeleportPart(worldName)
	local worlds = getWorldsFolder()
	if not worlds then return nil end
	local world = worlds:FindFirstChild(worldName)
	if not world then return nil end
	return findTeleportPartInWorld(world)
end

-- ================= TOOL CHECK =================
local function getDrill()
	local char = lp.Character
	if not char then return nil end
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("Tool") and VALID_DRILLS[v.Name] then
			return v
		end
	end
	return nil
end

-- ================= BEAUTIFUL NOTIFICATIONS =================
local NotifyGui = PlayerGui:FindFirstChild("DracoNotify")
if not NotifyGui then
	NotifyGui = Instance.new("ScreenGui")
	NotifyGui.Name = "DracoNotify"
	NotifyGui.ResetOnSpawn = false
	NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	NotifyGui.Parent = PlayerGui
end

local function notify(titleText, msgText)
	titleText = tostring(titleText or "DRACO PANEL  🔫")
	msgText = tostring(msgText or "")

	local box = Instance.new("Frame")
	box.Parent = NotifyGui
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0.02, 0)
	box.Size = UDim2.new(0, 560, 0, 100)
	box.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
	box.BackgroundTransparency = 0.05
	box.BorderSizePixel = 0
	box.ZIndex = 200
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 22)

	local stroke = Instance.new("UIStroke", box)
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 170, 255)
	stroke.Transparency = 0.25

	local glow = Instance.new("Frame", box)
	glow.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
	glow.BackgroundTransparency = 0.85
	glow.BorderSizePixel = 0
	glow.Position = UDim2.new(0, 0, 0, 0)
	glow.Size = UDim2.new(1, 0, 1, 0)
	glow.ZIndex = 199
	Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 22)

	local t1 = Instance.new("TextLabel", box)
	t1.BackgroundTransparency = 1
	t1.Position = UDim2.new(0, 18, 0, 10)
	t1.Size = UDim2.new(1, -36, 0, 28)
	t1.Font = Enum.Font.GothamBold
	t1.TextSize = 22
	t1.TextXAlignment = Enum.TextXAlignment.Left
	t1.TextColor3 = Color3.fromRGB(255,255,255)
	t1.Text = titleText
	t1.ZIndex = 201

	local msg = Instance.new("TextLabel", box)
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.new(0, 18, 0, 42)
	msg.Size = UDim2.new(1, -36, 0, 50)
	msg.Font = Enum.Font.Gotham
	msg.TextSize = 14
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Top
	msg.TextColor3 = Color3.fromRGB(210,210,235)
	msg.TextWrapped = true
	msg.Text = msgText
	msg.ZIndex = 201

	local inTween = TweenService:Create(box, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.06, 0)
	})
	inTween:Play()

	task.delay(3.2, function()
		if not box or not box.Parent then return end
		local outTween = TweenService:Create(box, TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, -0.30, 0)
		})
		outTween:Play()
		task.wait(0.40)
		if box then box:Destroy() end
	end)
end

-- ================= UI =================
local gui = PlayerGui:FindFirstChild("DracoPanel")
if gui then gui:Destroy() end

gui = Instance.new("ScreenGui")
gui.Name = "DracoPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(310, 410)
frame.Position = UDim2.fromScale(0.5, 0.70)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(15,15,25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 22)

local scale = Instance.new("UIScale", frame)

local function applyAutoScale()
	if UserInputService.TouchEnabled then
		scale.Scale = 0.80
	else
		local cam = workspace.CurrentCamera
		local vx = (cam and cam.ViewportSize and cam.ViewportSize.X) or 800
		local s = vx / 520
		if s < 0.78 then s = 0.78 end
		if s > 1.00 then s = 1.00 end
		scale.Scale = s
	end
end

applyAutoScale()


local topbar = Instance.new("Frame", frame)
topbar.Size = UDim2.new(1, 0, 0, 40)
topbar.Position = UDim2.new(0, 0, 0, 0)
topbar.BackgroundTransparency = 1

local title = Instance.new("TextLabel", topbar)
title.Size = UDim2.new(1, -96, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "DRACO PANEL 🔫"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1,1,1)

local minimize = Instance.new("TextButton", topbar)
minimize.Size = UDim2.fromOffset(34, 30)
minimize.Position = UDim2.new(1, -86, 0, 5)
minimize.Text = "–"
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 22
minimize.BackgroundColor3 = Color3.fromRGB(70,70,90)
minimize.TextColor3 = Color3.new(1,1,1)
minimize.AutoButtonColor = false
Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 10)

local close = Instance.new("TextButton", topbar)
close.Size = UDim2.fromOffset(34, 30)
close.Position = UDim2.new(1, -46, 0, 5)
close.Text = "✕"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.BackgroundColor3 = Color3.fromRGB(180,60,60)
close.TextColor3 = Color3.new(1,1,1)
close.AutoButtonColor = false
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 10)

local status = Instance.new("TextLabel", frame)
status.Position = UDim2.new(0, 10, 0, 40)
status.Size = UDim2.new(1, -20, 0, 24)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(180,180,220)
status.Text = ""

local content = Instance.new("Frame", frame)
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 10, 0, 70)
content.Size = UDim2.new(1, -20, 1, -80)

local list = Instance.new("UIListLayout", content)
list.FillDirection = Enum.FillDirection.Vertical
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 10)

local function mkBtn(text)
	local b = Instance.new("TextButton", content)
	b.Size = UDim2.new(1, 0, 0, 40)
	b.Text = text .. " : OFF"
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(40,40,60)
	b.TextColor3 = Color3.new(1,1,1)
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
	return b
end

local cashBtn = mkBtn("CASH")

local rateBlock = Instance.new("Frame", content)
rateBlock.BackgroundTransparency = 1
rateBlock.Size = UDim2.new(1, 0, 0, 62)

local rateLabel = Instance.new("TextLabel", rateBlock)
rateLabel.BackgroundTransparency = 1
rateLabel.Position = UDim2.new(0, 0, 0, 0)
rateLabel.Size = UDim2.new(1, 0, 0, 18)
rateLabel.Font = Enum.Font.Gotham
rateLabel.TextSize = 12
rateLabel.TextXAlignment = Enum.TextXAlignment.Left
rateLabel.TextColor3 = Color3.fromRGB(200,200,230)
rateLabel.Text = "Rate: " .. tostring(pendingCashRate) .. " / sec"

local rateRow = Instance.new("Frame", rateBlock)
rateRow.BackgroundTransparency = 1
rateRow.Position = UDim2.new(0, 0, 0, 22)
rateRow.Size = UDim2.new(1, 0, 0, 40)

local rowList = Instance.new("UIListLayout", rateRow)
rowList.FillDirection = Enum.FillDirection.Horizontal
rowList.SortOrder = Enum.SortOrder.LayoutOrder
rowList.Padding = UDim.new(0, 8)

local function mkSmall(text, w)
	local b = Instance.new("TextButton", rateRow)
	b.Size = UDim2.new(0, w, 1, 0)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(35,35,55)
	b.TextColor3 = Color3.new(1,1,1)
	b.AutoButtonColor = false
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	return b
end

local rateMinus = mkSmall("-", 48)

local rateApply = Instance.new("TextButton", rateRow)
rateApply.Size = UDim2.new(1, -112, 1, 0)
rateApply.Text = "APPLY RATE"
rateApply.Font = Enum.Font.GothamBold
rateApply.TextSize = 13
rateApply.BackgroundColor3 = Color3.fromRGB(60,60,90)
rateApply.TextColor3 = Color3.new(1,1,1)
rateApply.AutoButtonColor = false
Instance.new("UICorner", rateApply).CornerRadius = UDim.new(0, 12)

local ratePlus = mkSmall("+", 48)

local drillBtn = mkBtn("DRILL")
local winBtn = mkBtn("WIN")

local mapBtn = Instance.new("TextButton", content)
mapBtn.Size = UDim2.new(1, 0, 0, 36)
mapBtn.Text = "MAP: " .. selectedMap
mapBtn.Font = Enum.Font.GothamBold
mapBtn.TextSize = 13
mapBtn.BackgroundColor3 = Color3.fromRGB(30,30,45)
mapBtn.TextColor3 = Color3.fromRGB(230,230,255)
mapBtn.AutoButtonColor = false
Instance.new("UICorner", mapBtn).CornerRadius = UDim.new(0, 14)

local tpBtn = Instance.new("TextButton", content)
tpBtn.Size = UDim2.new(1, 0, 0, 36)
tpBtn.Text = "TELEPORT"
tpBtn.Font = Enum.Font.GothamBold
tpBtn.TextSize = 13
tpBtn.BackgroundColor3 = Color3.fromRGB(50,70,120)
tpBtn.TextColor3 = Color3.new(1,1,1)
tpBtn.AutoButtonColor = false
Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 14)

-- ===== Confirm Modal (required) =====
local confirmOpen = false
local confirmOverlay = Instance.new("Frame", frame)
confirmOverlay.Visible = false
confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
confirmOverlay.BackgroundTransparency = 0.35
confirmOverlay.BorderSizePixel = 0
confirmOverlay.ZIndex = 500

local modal = Instance.new("Frame", confirmOverlay)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.Size = UDim2.fromOffset(290, 180)
modal.BackgroundColor3 = Color3.fromRGB(18,18,28)
modal.BorderSizePixel = 0
modal.ZIndex = 501
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 18)

local modalStroke = Instance.new("UIStroke", modal)
modalStroke.Thickness = 2
modalStroke.Color = Color3.fromRGB(120,170,255)
modalStroke.Transparency = 0.3

local modalTitle = Instance.new("TextLabel", modal)
modalTitle.BackgroundTransparency = 1
modalTitle.Position = UDim2.new(0, 14, 0, 10)
modalTitle.Size = UDim2.new(1, -28, 0, 22)
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 16
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.TextColor3 = Color3.fromRGB(255,255,255)
modalTitle.Text = "⚠️ CONFIRM CASH RATE"
modalTitle.ZIndex = 502

local modalText = Instance.new("TextLabel", modal)
modalText.BackgroundTransparency = 1
modalText.Position = UDim2.new(0, 14, 0, 36)
modalText.Size = UDim2.new(1, -28, 0, 86)
modalText.Font = Enum.Font.Gotham
modalText.TextSize = 12
modalText.TextXAlignment = Enum.TextXAlignment.Left
modalText.TextYAlignment = Enum.TextYAlignment.Top
modalText.TextWrapped = true
modalText.TextColor3 = Color3.fromRGB(210,210,235)
modalText.Text = ""
modalText.ZIndex = 502

local cancelBtn = Instance.new("TextButton", modal)
cancelBtn.Size = UDim2.fromOffset(132, 34)
cancelBtn.Position = UDim2.new(0, 14, 1, -48)
cancelBtn.Text = "CANCEL"
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 13
cancelBtn.BackgroundColor3 = Color3.fromRGB(70,70,90)
cancelBtn.TextColor3 = Color3.new(1,1,1)
cancelBtn.AutoButtonColor = false
cancelBtn.ZIndex = 502
Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 12)

local confirmBtn = Instance.new("TextButton", modal)
confirmBtn.Size = UDim2.fromOffset(132, 34)
confirmBtn.Position = UDim2.new(1, -146, 1, -48)
confirmBtn.Text = "CONFIRM"
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.TextSize = 13
confirmBtn.BackgroundColor3 = Color3.fromRGB(60,180,120)
confirmBtn.TextColor3 = Color3.new(1,1,1)
confirmBtn.AutoButtonColor = false
confirmBtn.ZIndex = 502
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 12)

-- ================= UI BEHAVIOR =================
local minimizedState = false

local function setBtn(btn, on, name)
	btn.Text = name .. (on and " : ON" or " : OFF")
	btn.BackgroundColor3 = on and Color3.fromRGB(60,180,120) or Color3.fromRGB(40,40,60)
end

local function mouseUp()
	if mouseDown then
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
		end)
		mouseDown = false
	end
end

local function stopAllAndResetUI()
	cashOn = false
	drillOn = false
	winOn = false

	winBusy = false
	winStage = "idle"
	winStageTimer = 0
	winTimer = AUTO_WIN_DELAY
	winReturnCFrame = nil

	mouseUp()

	setBtn(cashBtn, false, "CASH")
	setBtn(drillBtn, false, "DRILL")
	setBtn(winBtn, false, "WIN")

	if StopAutoFarm then
		pcall(function()
			StopAutoFarm:FireServer()
		end)
	end
end

minimize.MouseButton1Click:Connect(function()
	minimizedState = not minimizedState
	content.Visible = not minimizedState
	if minimizedState then
		frame.Size = UDim2.fromOffset(310, 78)
	else
		frame.Size = UDim2.fromOffset(310, 410)
	end
end)

close.MouseButton1Click:Connect(function()
	stopAllAndResetUI()
	gui:Destroy()
	notify("DRACO", "Stopped all systems.")
end)

-- ================= MAP CYCLE =================
local function nextMap(curr)
	for i = 1, #MAPS do
		if MAPS[i] == curr then
			local ni = i + 1
			if ni > #MAPS then ni = 1 end
			return MAPS[ni]
		end
	end
	return MAPS[1]
end

mapBtn.MouseButton1Click:Connect(function()
	selectedMap = nextMap(selectedMap)
	mapBtn.Text = "MAP: " .. selectedMap
	notify("🗺️ MAP SELECTED", "Win will use: " .. selectedMap)
end)

tpBtn.MouseButton1Click:Connect(function()
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		notify("🧭 TELEPORT", "Character not ready.")
		return
	end

	local tp = getMapTeleportPart(selectedMap)
	if not tp then
		notify("🧭 TELEPORT", "Teleport point not found for: " .. tostring(selectedMap))
		return
	end

	pcall(function()
		hrp.CFrame = tp.CFrame + Vector3.new(0, 3, 0)
	end)
	notify("🧭 TELEPORT", "Teleported to: " .. tostring(selectedMap))
end)

-- ================= CASH RATE LOGIC =================
local function updateRateLabel()
	rateLabel.Text = "Rate: " .. tostring(pendingCashRate) .. " / sec"
end

rateMinus.MouseButton1Click:Connect(function()
	pendingCashRate = math.max(CASH_RATE_MIN, pendingCashRate - 10)
	updateRateLabel()
end)

ratePlus.MouseButton1Click:Connect(function()
	pendingCashRate = math.min(CASH_RATE_MAX, pendingCashRate + 10)
	updateRateLabel()
end)

local function openConfirm()
	if confirmOpen then return end
	confirmOpen = true
	confirmOverlay.Visible = true
	confirmOverlay.BackgroundTransparency = 1
	modal.Position = UDim2.new(0.5, 0, 0.52, 0)

	modalText.Text =
		"Some devices may NOT support 1000 per second.\n" ..
		"Use at your own risk.\n" ..
		"This may cause lag, crash or worse.\n\n" ..
		"Pending rate: " .. tostring(pendingCashRate) .. " / sec"

	TweenService:Create(confirmOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 0.35}):Play()
	TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()
end

local function closeConfirm()
	if not confirmOpen then return end
	confirmOpen = false
	TweenService:Create(confirmOverlay, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
	task.delay(0.12, function()
		if confirmOpen then return end
		confirmOverlay.Visible = false
	end)
end

rateApply.MouseButton1Click:Connect(function()
	openConfirm()
end)

cancelBtn.MouseButton1Click:Connect(function()
	closeConfirm()
	notify("💰 CASH RATE", "Cancelled. Rate unchanged.")
end)

confirmBtn.MouseButton1Click:Connect(function()
	AUTO_CASH_RATE = pendingCashRate
	closeConfirm()
	notify("💰 CASH RATE APPLIED", "New cash rate set to " .. tostring(AUTO_CASH_RATE) .. " / sec")
end)

-- ================= BUTTON LOGIC =================
cashBtn.MouseButton1Click:Connect(function()
	if not GiveCash then
		notify("⚠️ ERROR", "GiveCash remote not found.")
		return
	end
	if not getDrill() then
		notify("⛏️ NO DRILL", "Equip a drill to use CASH.")
		return
	end
	cashOn = not cashOn
	setBtn(cashBtn, cashOn, "CASH")
	notify("💰 CASH", cashOn and "Activated successfully." or "Deactivated.")
end)

drillBtn.MouseButton1Click:Connect(function()
	if not getDrill() then
		notify("⛏️ NO DRILL", "Equip a drill to use DRILL.")
		return
	end
	drillOn = not drillOn
	setBtn(drillBtn, drillOn, "DRILL")

	if drillOn then
		notify("⚠️ IMPORTANT",
			"THIS MAY FAIL SOMETIMES.\nCLICK 1–3 TIMES AND IT WORKS AGAIN.\nGAME ISSUE.\nTHANKS FOR USING DRACO SCRIPT.")
	else
		mouseUp()
		notify("⛏️ DRILL", "Deactivated.")
	end
end)

winBtn.MouseButton1Click:Connect(function()
	if not StopAutoFarm then
		notify("⚠️ ERROR", "StopAutoFarm remote not found.")
		return
	end

	local ez = getEndZone(selectedMap)
	if not ez then
		notify("🏆 WIN", "EndZone not found for map: " .. tostring(selectedMap))
		return
	end

	winOn = not winOn
	setBtn(winBtn, winOn, "WIN")

	if winOn then
		winCycles = 0
		winTimer = AUTO_WIN_DELAY
		winStage = "idle"
		winStageTimer = 0
		winBusy = false
		winReturnCFrame = nil
		notify("🏆 WIN", "Loop activated. Delay: 7s.\nMap: " .. selectedMap)
	else
		notify("🏆 WIN", "Loop deactivated.")
	end
end)

-- ================= MAIN LOOP =================
RunService.Heartbeat:Connect(function(dt)
	local timeStr = os.date("%I:%M %p")
	local showTimer = 0
	if winOn then
		if winStage == "idle" then
			showTimer = math.max(0, math.ceil(winTimer))
		else
			showTimer = math.max(0, math.ceil(winStageTimer))
		end
	end

	status.Text = string.format(
	"🕒 %s | 🔁 Cycles: %d | 💰 %d/s | ⏳ %ds | 🗺️ %s",
	timeStr, winCycles, AUTO_CASH_RATE, showTimer, selectedMap
)


	if cashOn and GiveCash then
		cashAcc = cashAcc + dt
		while cashAcc >= (1 / AUTO_CASH_RATE) do
			cashAcc = cashAcc - (1 / AUTO_CASH_RATE)
			local tool = getDrill()
			if tool then
				pcall(function()
					GiveCash:FireServer(tool)
				end)
			else
				cashOn = false
				setBtn(cashBtn, false, "CASH")
				notify("⛏️ NO DRILL", "Equip a drill to use CASH.")
				break
			end
		end
	end

	if drillOn then
		if getDrill() then
			if not mouseDown then
				pcall(function()
					VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
				end)
				mouseDown = true
			end
		else
			drillOn = false
			setBtn(drillBtn, false, "DRILL")
			mouseUp()
			notify("⛏️ NO DRILL", "Equip a drill to use DRILL.")
		end
	else
		mouseUp()
	end

	if winOn and StopAutoFarm then
		if winStage == "idle" then
			winTimer = winTimer - dt
			if winTimer <= 0 and not winBusy then
				winBusy = true

				local char = lp.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local endZone = getEndZone(selectedMap)

				if hrp and endZone then
					winReturnCFrame = hrp.CFrame

					pcall(function()
						hrp.CFrame = endZone.CFrame + Vector3.new(0, 3, 0)
					end)

					winStage = "returning"
					winStageTimer = AUTO_WIN_RETURN_WAIT
				else
					notify("🏆 WIN", "Character or EndZone not ready.")
					winTimer = AUTO_WIN_DELAY
					winBusy = false
				end
			end
		elseif winStage == "returning" then
			winStageTimer = winStageTimer - dt
			if winStageTimer <= 0 then
				pcall(function()
					StopAutoFarm:FireServer()
				end)

				winStage = "restoring"
				winStageTimer = AUTO_WIN_RESTORE_WAIT
			end
		elseif winStage == "restoring" then
			winStageTimer = winStageTimer - dt
			if winStageTimer <= 0 then
				local char2 = lp.Character
				local hrp2 = char2 and char2:FindFirstChild("HumanoidRootPart")
				if hrp2 and winReturnCFrame then
					pcall(function()
						hrp2.CFrame = winReturnCFrame
					end)
				end

				winCycles = winCycles + 1
				winTimer = AUTO_WIN_DELAY
				winStage = "idle"
				winBusy = false
				winReturnCFrame = nil
			end
		end
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyAutoScale)


notify("DRACO PANEL 🔫", "Panel loaded. Select your map and turn ON what you want.")
