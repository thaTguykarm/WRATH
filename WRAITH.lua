do
local Boot = {phase = "Starting", parts = {}, done = false}

function Boot.trace(message)
	local text = tostring(message)
	if type(debug) == "table" and type(debug.traceback) == "function" then
		return debug.traceback(text, 2)
	end
	return text
end

function Boot.widget(class, parent, props)
	local object = Instance.new(class)
	table.insert(Boot.parts, object)
	for key, value in pairs(props) do object[key] = value end
	object.Parent = parent
	return object
end

function Boot.dismiss()
	if Boot.gui then
		local gui = Boot.gui
		Boot.gui = nil
		pcall(function() gui:Destroy() end)
	end
end

function Boot.removeTopButton()
	if Boot.topConnection then pcall(function() Boot.topConnection:Disconnect() end) end
	Boot.topConnection = nil
	if Boot.topGui then pcall(function() Boot.topGui:Destroy() end) end
	Boot.topGui, Boot.launcher = nil, nil
end

function Boot.refreshTopButton()
	local button = Boot.launcher
	if not button or not button.Parent then return end
	Boot.topGui.Enabled = true
	button.Visible, button.Modal = true, false
	local state = Boot.state
	local showing = state and state.running and state.open and state.ui
		and state.ui.root and state.ui.root.Enabled and state.ui.main and state.ui.main.Visible
	local accent = state and state.woodColors and state.woodColors.accent or Color3.fromRGB(205, 174, 133)
	button.BackgroundColor3 = Boot.failed and Color3.fromRGB(103, 59, 47) or Color3.fromRGB(68, 52, 39)
	button.Text = Boot.failed and "Error" or (showing and "Close" or "Menu")
	button.TextColor3 = Color3.fromRGB(240, 232, 218)
	if Boot.dockLines then
		for i, line in ipairs(Boot.dockLines) do
			line.BackgroundColor3 = accent
			line.Position = UDim2.new(0.5, 0, 0, showing and 17 or (11 + (i - 1) * 5))
			line.Rotation = showing and (i == 1 and 45 or -45) or 0
			line.Visible = not showing or i ~= 2
		end
	end
end

function Boot.showFailureDetails()
	if not Boot.playerGui then return end
	if not Boot.gui or not Boot.gui.Parent then Boot.attach(Boot.playerGui) end
	if not Boot.gui then return end
	Boot.gui.Enabled = true
	Boot.panel.Visible = true
	Boot.panel.Size = UDim2.new(0.92, 0, 0, 300)
	Boot.title.Text = "WRAITH / STARTUP ERROR"
	Boot.title.TextColor3 = Color3.fromRGB(213, 141, 121)
	Boot.detail.Text = string.sub(Boot.lastFailure or "Startup could not finish.", 1, 6000)
end

function Boot.makeTopButton(playerGui)
	Boot.playerGui = playerGui
	Boot.removeTopButton()
	for _, name in ipairs({"FUSION_TOP_BUTTON", "FUSION_WOOD_DOCK"}) do
		local old = playerGui:FindFirstChild(name)
		if old then old:Destroy() end
	end
	Boot.topGui = Boot.widget("ScreenGui", playerGui, {
		Name = "FUSION_WOOD_DOCK", Enabled = true, ResetOnSpawn = false,
		IgnoreGuiInset = false, DisplayOrder = 2147483000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	pcall(function() Boot.topGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
	Boot.launcher = Boot.widget("TextButton", Boot.topGui, {
		Name = "OpenMenuButton", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(48, 48),
		Text = "Menu", Font = Enum.Font.GothamMedium, TextSize = 10,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextColor3 = Color3.fromRGB(240, 232, 218),
		BackgroundColor3 = Color3.fromRGB(68, 52, 39), BackgroundTransparency = 0,
		BorderSizePixel = 0, AutoButtonColor = true, Visible = true,
		Active = true, Modal = false, Selectable = false, ZIndex = 10,
	})
	Boot.widget("UIPadding", Boot.launcher, {PaddingBottom = UDim.new(0, 5)})
	Boot.widget("UICorner", Boot.launcher, {CornerRadius = UDim.new(0, 13)})
	Boot.widget("UIStroke", Boot.launcher, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(169, 131, 88), Thickness = 1, Transparency = 0.45,
	})
	Boot.dockLines = {}
	for i = 1, 3 do
		Boot.dockLines[i] = Boot.widget("Frame", Boot.launcher, {
			Name = "MenuLine" .. i, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 11 + (i - 1) * 5), Size = UDim2.fromOffset(17, 1),
			BackgroundColor3 = Color3.fromRGB(205, 174, 133), BorderSizePixel = 0,
			Active = false, ZIndex = 11,
		})
	end
	Boot.topConnection = Boot.launcher.Activated:Connect(function()
		if Boot.failed then Boot.showFailureDetails() return end
		local state = Boot.state
		if not Boot.done or not state or not state.running or state.initializing then
			if not Boot.gui or not Boot.gui.Parent then Boot.attach(playerGui) end
			Boot.gui.Enabled = true
			Boot.detail.Text = "Building your workspace.\n" .. Boot.phase
			return
		end
		local ok, problem = xpcall(function()
			local root, panel = state.ui.root, state.ui.main
			if not root or not root.Parent or not panel or not panel.Parent then
				error("The menu was removed. Run the replacement file again.", 0)
			end
			state.windowFocused = true
			if state.hotkeys then pcall(state.hotkeys.cancelCapture) end
			pcall(state.releaseTextFocus)
			if state.open and panel.Visible and root.Enabled then
				state.setOpen(false)
			else
				root.Enabled = true
				state.setOpen(true)
				pcall(state.fitWindow, true)
			end
		end, Boot.trace)
		if not ok then
			Boot.lastFailure = "Menu button: " .. tostring(problem)
			Boot.showFailureDetails()
		end
		Boot.refreshTopButton()
	end)
	Boot.refreshTopButton()
end

function Boot.attach(playerGui)
	Boot.playerGui = playerGui
	local previous = playerGui:FindFirstChild("FUSION_STARTUP_STATUS")
	if previous then previous:Destroy() end
	local gui = Boot.widget("ScreenGui", playerGui, {
		Name = "FUSION_STARTUP_STATUS", Enabled = true, ResetOnSpawn = false,
		IgnoreGuiInset = false, DisplayOrder = 2147482995, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	Boot.gui = gui
	local panel = Boot.widget("Frame", gui, {
		Name = "StartupCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.new(0.92, 0, 0, 144), BackgroundColor3 = Color3.fromRGB(36, 34, 30),
		BorderSizePixel = 0, Active = false,
	})
	Boot.widget("UISizeConstraint", panel, {MaxSize = Vector2.new(560, 320), MinSize = Vector2.new(180, 100)})
	Boot.widget("UICorner", panel, {CornerRadius = UDim.new(0, 10)})
	Boot.title = Boot.widget("TextLabel", panel, {
		Name = "StartupTitle", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -64, 0, 26),
		Text = "WRAITH / PREPARING WORKSPACE", Font = Enum.Font.Code, TextSize = 16,
		TextColor3 = Color3.fromRGB(205, 174, 133), TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	local close = Boot.widget("TextButton", panel, {
		Name = "Close", Position = UDim2.new(1, -42, 0, 9), Size = UDim2.fromOffset(30, 28),
		Text = "x", Font = Enum.Font.Code, TextSize = 18, TextColor3 = Color3.fromRGB(240, 232, 218),
		BackgroundColor3 = Color3.fromRGB(52, 48, 42), BorderSizePixel = 0,
		Modal = false, Selectable = false,
	})
	close.Activated:Connect(Boot.dismiss)
	local scroll = Boot.widget("ScrollingFrame", panel, {
		Name = "StartupDetails", Position = UDim2.fromOffset(16, 47), Size = UDim2.new(1, -32, 1, -75),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
	})
	Boot.detail = Boot.widget("TextLabel", scroll, {
		Name = "ErrorText", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Text = "Preparing the menu. No gameplay tools have been enabled.", Font = Enum.Font.Code, TextSize = 12,
		TextColor3 = Color3.fromRGB(223, 211, 194), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
	})
	Boot.widget("TextLabel", panel, {
		Position = UDim2.new(0, 16, 1, -24), Size = UDim2.new(1, -32, 0, 18),
		Text = "Startup errors are also printed to Output / F9.", Font = Enum.Font.Code, TextSize = 11,
		TextColor3 = Color3.fromRGB(174, 164, 148), TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	Boot.panel = panel
end

function Boot.stage(text)
	Boot.phase = text
	if Boot.gui and Boot.gui.Parent and Boot.detail then Boot.detail.Text = text end
end

function Boot.oldCleanup(label, callback)
	local completed, succeeded, result = false, false, nil
	local worker = task.spawn(function()
		succeeded, result = xpcall(callback, Boot.trace)
		completed = true
	end)
	local deadline = os.clock() + 1.5
	while not completed and os.clock() < deadline do task.wait(0.03) end
	if not completed then
		pcall(function() task.cancel(worker) end)
		error(label .. " did not finish shutting down. Rejoin once, then run only Fusion 7 Wood.", 0)
	end
	if not succeeded then warn("[FUSION 7 WOOD] " .. label .. ": " .. tostring(result)) end
end

function Boot.fail(message)
	Boot.done, Boot.failed = true, true
	local text = "Stage: " .. Boot.phase .. "\n\n" .. tostring(message)
	Boot.lastFailure = text
	warn("[FUSION 7 WOOD STARTUP ERROR]\n" .. text)
	local state = Boot.state
	if state then
		local cleanup = state.cleanup or state.bootstrapCleanup
		if type(cleanup) == "function" then pcall(cleanup) end
		state.running = false
		for _, connection in ipairs(state.connections or {}) do pcall(function() connection:Disconnect() end) end
		if state.renderName then pcall(function() game:GetService("RunService"):UnbindFromRenderStep(state.renderName) end) end
		for _, key in ipairs({"root", "hud"}) do
			local gui = state.ui and state.ui[key]
			if gui then pcall(function() gui:Destroy() end) end
		end
		if _G.__WRAITH_VECTOR == state then _G.__WRAITH_VECTOR = nil _G.__WRAITH_CLEANUP = nil end
	end
	pcall(function()
		if not Boot.topGui or not Boot.topGui.Parent then
			local player = game:GetService("Players").LocalPlayer
			local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
			if playerGui then Boot.makeTopButton(playerGui) end
		end
		Boot.showFailureDetails()
		Boot.refreshTopButton()
	end)
end

local bootOK, bootError = xpcall(function()

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Tween      = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")
local Sound      = game:GetService("SoundService")
local Debris     = game:GetService("Debris")
local CAS        = game:GetService("ContextActionService")

local player = Players.LocalPlayer
if not player then
	error("Fusion needs a client LocalScript. Use StarterPlayerScripts and start Play, not Run.", 0)
end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8)
if not playerGui then error("PlayerGui was not available. The client is not ready; rejoin and try again.", 0) end
Boot.makeTopButton(playerGui)
Boot.attach(playerGui)
Boot.stage("Checking client and previous copies...")
task.wait()

local replacingWraith = false
do
	local previous = _G.__WRAITH_VECTOR
	local cleanup = _G.__WRAITH_CLEANUP
	if type(cleanup) == "function" then replacingWraith = true Boot.oldCleanup("Previous Fusion", cleanup) end
	if type(previous) == "table" then
		previous.running = false
		for _, connection in ipairs(previous.connections or {}) do pcall(function() connection:Disconnect() end) end
		for _, name in ipairs({"watchConn", "speedConn", "deathConn", "viewportConn"}) do
			local connection = previous[name]
			if connection then pcall(function() connection:Disconnect() end) end
		end
		if previous.flyRig then
			for _, key in ipairs({"velocity", "lift", "facing", "attachment"}) do
				local object = previous.flyRig[key]
				if object then pcall(function() object:Destroy() end) end
			end
		end
	end
	local vector = _G.__VECTOR_CLIENT
	if type(vector) == "table" and type(vector.Unload) == "function" then Boot.oldCleanup("Previous VECTOR", function() vector:Unload() end) end
	for _, name in ipairs({"WRAITH_VECTOR_V6_Camera", "WRAITH_VECTOR_V6_Camera", "WRAITH_VECTOR_V5_Camera", "WRAITH_V45_Camera", "WRAITH_V44_Camera", "WRAITH_V43_Camera", "WRAITH_V42_Camera", "WRAITH_V41_Camera"}) do
		pcall(function() RunService:UnbindFromRenderStep(name) end)
	end
	for _, name in ipairs({"W_FreecamSink", "KarFreecamSink", "FUSION6_Freecam"}) do pcall(function() CAS:UnbindAction(name) end) end
	local gui = playerGui
	for _, name in ipairs({"VECTOR_MENU_V1", "VECTOR_OVERLAY_V1", "WRAITH_VECTOR_FUSION", "WRAITH_V4_3_Platinum", "WRAITH_HUD", "WRAITH_VECTOR_HUD", "FUSION6"}) do
		local old = gui:FindFirstChild(name)
		if old then
			local shutdown = old:FindFirstChild("Shutdown")
			if shutdown and shutdown:IsA("BindableFunction") then Boot.oldCleanup("Previous menu", function() shutdown:Invoke() end) end
			pcall(function() old:Destroy() end)
		end
	end
end


local mouse  = player:GetMouse()
Boot.stage("Waiting for the client camera...")
local camera = workspace.CurrentCamera
local cameraDeadline = os.clock() + 8
while not camera and os.clock() < cameraDeadline do task.wait(0.05) camera = workspace.CurrentCamera end
if not camera then error("CurrentCamera was not available. Startup stopped without changing movement.", 0) end
Boot.stage("Building the menu...")

local W = {
	page      = "Home",
	open      = false,
	target    = nil,

	fly       = false,
	flySpeed  = 90,
	noclip    = false,
	clickTP   = false,
	infJump   = false,
	float     = false,
	floatPow  = 38,
	jumpUntil = 0,
	antiFling = false,
	flingCap  = 145,

	speedLock = false,
	speedVal  = 16,
	speedBusy = false,
	speedConn = nil,

	gravOn    = false,
	grav      = 196,

	espNames  = false,
	espDist   = true,
	espHp     = true,
	espTools  = false,
	espOnly   = false,
	espBox    = false,
	espBones  = false,
	espBar    = false,
	espTracer = false,
	deathChk  = true,

	radar     = false,
	radarRng  = 200,
	radarSize = 190,

	lowHp     = false,
	lowHpPct  = 30,
	selfHp    = false,
	hpFlash   = 0,

	bright    = false,
	forceBright = false,

	follow    = false,
	followD   = 12,
	followH   = 4,
	orbit     = false,
	orbitR    = 14,
	orbitH    = 6,
	orbitS    = 1.6,
	orbitA    = 0,

	camLock   = false,
	spectate  = false,

	freecam   = false,
	fcSpeed   = 60,
	fcYaw     = 0,
	fcPitch   = 0,
	fcPos     = Vector3.zero,

	inspect   = false,
	inspected = nil,

	slots     = {},
	deathCF   = nil,
	retDeath  = false,
	retSlot   = false,
	autoSlot  = 1,
	respawnD  = 0.4,

	macro     = {},
	macroRec  = false,
	macroPlay = false,
	macroLoop = false,
	macroT0   = 0,
	macroP0   = 0,
	macroIdx  = 1,
	macroRate = 1 / 30,
	macroAcc  = 0,

	ugState   = "SURFACE",
	ugAnchor  = nil,
	ugHold    = nil,
	ugT0      = 0,
	ugFrom    = nil,
	ugTo      = nil,
	ugDur     = 0,
	ugJoints  = nil,
	ugDepth   = 10,
	ugSink    = 4.2,
	ugRise    = 2.6,
	ugFollow  = false,
	ugSmooth  = 0.12,
	ugFlail   = 4.5,
	ugSpin    = 6,
	ugSpeed   = nil,
	ugJump    = nil,
	ugRotate  = nil,

	debug     = false,
	dbgStart  = os.clock(),

	pages     = {},
	tabs      = {},
	toggles   = {},
	sliders   = {},
	rigs      = {},
	dots      = {},
	lastAlert = {},
	lightBak  = nil,
	gravBak   = nil,
	order     = 0,
	dragging  = nil,
	running   = true,
	connections = {},

	expRoot   = nil,
	expFilter = "",

	scanScripts = {},
	scanParts   = {},
	scanRemotes = {},
	scanNew     = {},
	scanMode    = "scripts",
	scanPage    = 1,
	scanning    = false,
	scanFilter  = "",
	watchNew    = false,
	watchConn   = nil,
}

Boot.state = W
W.initializing = true
W.created = {}
function W.bootstrapCleanup()
	if W.cleanup then return W.cleanup() end
	W.running = false
	for _, connection in ipairs(W.connections) do pcall(function() connection:Disconnect() end) end
	if W.renderName then pcall(function() RunService:UnbindFromRenderStep(W.renderName) end) end
	pcall(function() CAS:UnbindAction("FUSION6_Freecam") end)
	for index = #W.created, 1, -1 do pcall(function() W.created[index]:Destroy() end) end
	if _G.__WRAITH_VECTOR == W then _G.__WRAITH_VECTOR = nil end
	if _G.__WRAITH_CLEANUP == W.bootstrapCleanup then _G.__WRAITH_CLEANUP = nil end
end
_G.__WRAITH_VECTOR = W
_G.__WRAITH_CLEANUP = W.bootstrapCleanup


function W.bind(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(W.connections, conn)
	return conn
end

local C = {
	bg = Color3.fromRGB(27, 26, 23),
	panel = Color3.fromRGB(36, 34, 30),
	raised = Color3.fromRGB(52, 48, 42),
	accent = Color3.fromRGB(205, 174, 133),
	accent2 = Color3.fromRGB(91, 72, 51),
	text = Color3.fromRGB(240, 232, 218),
	dim = Color3.fromRGB(174, 164, 148),
	good = Color3.fromRGB(159, 184, 143),
	warn = Color3.fromRGB(222, 184, 121),
	bad = Color3.fromRGB(213, 141, 121),
}

C.wood = Color3.fromRGB(53, 42, 33)
C.woodLight = Color3.fromRGB(128, 99, 65)
C.line = Color3.fromRGB(75, 67, 55)
C.ink = Color3.fromRGB(36, 30, 23)
W.woodColors = C
W.themeId = "soft-wood-v1"

local PAGES = {
	"Home", "Favorites", "Presets", "Hotkeys", "Aim", "Auto", "Players", "Vision", "Hunter",
	"Movement", "Camera", "Positions", "Macro", "Underground", "World", "Explorer", "Deep Scan",
	"Inspector", "Profiles", "System",
}

W.windowMode = "MOVE"
W.kar = {
	enabled = false, fov = 120, smooth = 0.3, part = "Head", mode = "Lock", wallCheck = false,
	activation = "RMB", teamCheck = false, selectedOnly = false,
	blacklist = {}, teammates = {}, teamSize = 0, teamPicking = false, stickMargin = 0.7,
	profiles = {}, calibration = 1, lastConf = 0, lastAimUserId = 0, lastAimTime = -math.huge,
	advLead = 0.15, advSpeed = 0.55, advAggression = 1, projSpeed = 0,
	centerCursor = false, predDotOn = false, fovCircleOn = false,
	hitTrackerOn = false, lastFireTime = -math.huge, hitWindow = 1.2, hyperDamage = 115,
	hitCount = 0, hitDamage = 0, lastHit = "No hits observed.",
	approachOn = false, approachSpeed = 24, approachStop = 6,
	espTransparency = 0.22, beamsOn = false, beams = {}, cursorOrbOn = false,
	radarOn = false, radarPingRange = 30, radarSound = true, lastRadarPing = -math.huge,
	profT = 0, choiceRefresh = {}, kShortcut = true, rightShotArmed = false, state = "OFF",
}
W.vector = {
	engine = "WRAITH", mode = "Smooth", origin = "Center", priority = "Crosshair", part = "Head",
	response = 12, lead = 0.025, distance = 1500, shieldCheck = true, sticky = true,
	trigger = false, triggerDelay = 0.12, triggerInterval = 0.14, lastTrigger = -math.huge,
	arrows = false, throughWalls = true, teamColors = false, tracerOrigin = "Bottom",
	healthText = true, targetCard = true, bunnyHop = false, flightScheme = "WRAITH", flightBoost = 2, teleportActivation = "Click",
	freecamSensitivity = 0.258, noFog = false, clockLock = false, clockTime = 14,
	nearbyAlert = false, nearbyRadius = 35, joinAlert = false, teamAttribute = "",
	lastNearby = -math.huge, velocity = Vector3.zero, targetRoot = nil, favorites = {},
	owners = {}, favoriteRows = {}, favoriteQuery = "", loaded = false,
}
W.ui = {}
W.commands = {}
W.logs = {}
W.logDirty = true
W.sounds = false
W.reducedMotion = false
W.interfaceScale = 1
W.menuToken = 0
W.paletteToken = 0
W.collisionBak = setmetatable({}, { __mode = "k" })
W.speedBak = setmetatable({}, { __mode = "k" })
W.jumpBak = setmetatable({}, { __mode = "k" })
W.bodyBak = setmetatable({}, { __mode = "k" })
W.teleportHistory = {}
W.markers = {}
W.profiles = type(_G.__WRAITH_V4_PROFILES) == "table" and _G.__WRAITH_V4_PROFILES or {}
W.fov = 70
W.fovOn = false
W.crosshair = false
W.crossSize = 7
W.crossGap = 4
W.jumpOn = false
W.jumpPower = 50
W.jumpHeight = 7.2
W.followSmooth = 8
W.macroSpeed = 1
W.scanToken = 0
W.expPage = 1
W.playerFilter = ""
W.hiddenHUD = false
W.pins = {}
W.fps = 0
W.ping = "--"
W.sessionStart = os.clock()
W.frameCount = 0
W.frameTime = 0
W.platformOwned = false
W.touchUp = false
W.touchDown = false
W.windowFocused = true
W.releasingMovement = false
W.manualOverride = true
W.manualGraceUntil = 0
W.lastRecoveryReport = nil
W.motionToggles = {
	["Fly"] = true, ["Follow"] = true, ["Orbit Target"] = true,
	["Free Cam"] = true, ["Camera Lock"] = true, ["Spectate Target"] = true,
	["Approach Assist"] = true, ["Stalk Under Target"] = true,
	["Hold-Jump Float"] = true, ["Lock Walkspeed"] = true, ["Custom Jump"] = true,
}
W.frameErrors = {}
W.flightKeys = {}
W.flightDirection = Vector3.zero
W.flightRequested = Vector3.zero
W.flightVelocity = Vector3.zero
W.flightInputSource = "IDLE"
W.flightBlockedTime = 0
W.flightTakeoffUntil = 0
W.sectionForRow = setmetatable({}, {__mode = "k"})
W.sections = {}
W.activeTweens = setmetatable({}, {__mode = "k"})
W.enableOnEdit = {
	["Walk Speed"] = "Lock Walkspeed", ["Gravity"] = "Custom Gravity",
	["Jump Power"] = "Custom Jump", ["Jump Height"] = "Custom Jump",
	["Field Of View"] = "Custom FOV",
}
W.GuiService = game:GetService("GuiService")
W.TextService = game:GetService("TextService")
W.about = {
	Home = {"01", "Your tools, settings, and session."},
	Favorites = {"FV", "Your pinned tools, without the scrolling."},
	Presets = {"PS", "One-click setup and settings resets."},
	Auto = {"AU", "Direct right-click sweep. No weapon check."},
	Hotkeys = {"HK", "Rebind tools without stealing movement input."},
	Movement = {"MV", "Flight, movement and local physics."},
	Players = {"PL", "Select targets and manage aim exclusions."},
	Aim = {"AM", "Two aim engines. One active controller. Shared player exclusions."},
	Vision = {"VI", "Player overlays and visibility tools."},
	Hunter = {"RA", "Radar and health alerts."},
	Camera = {"CA", "Freecam, spectating and framing."},
	Positions = {"TP", "Saved locations and teleport history."},
	Macro = {"RE", "Record a route. Replay the movement."},
	Underground = {"UG", "Sink, drift and return to the surface."},
	Explorer = {"EX", "Browse instances visible to this client."},
	["Deep Scan"] = {"SC", "Search client-visible objects and scripts."},
	Inspector = {"IN", "Point at a part. Read its properties."},
	World = {"WO", "Lighting changes for your local view."},
	Profiles = {"PR", "Saved settings and hotkey export."},
	System = {"SY", "Appearance, diagnostics and recovery."},
}

function W.new(class, parent, props)
	local o = Instance.new(class)
	for key, value in pairs(props or {}) do o[key] = value end
	if o:IsA("GuiButton") then o.Active = true o.Selectable = false o.Modal = false end
	if o:IsA("GuiObject") and not o:IsA("GuiButton") and not o:IsA("TextBox") and not o:IsA("ScrollingFrame") then o.Active = false o.Selectable = false end
	o.Parent = parent
	if W.initializing and W.created then table.insert(W.created, o) end
	return o
end

function W.animate(o, props, duration)
	if not o or not o.Parent then return end
	local previous = W.activeTweens[o]
	if previous then previous:Cancel() W.activeTweens[o] = nil end
	if W.reducedMotion then
		for key, value in pairs(props) do o[key] = value end
		return
	end
	local tween = Tween:Create(o, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
	W.activeTweens[o] = tween
	tween:Play()
end

function W.log(text, level)
	local elapsed = os.clock() - W.sessionStart
	table.insert(W.logs, { t = elapsed, text = tostring(text), level = level or "INFO" })
	if #W.logs > 160 then table.remove(W.logs, 1) end
	W.logDirty = true
end

local function dbg(msg)
	if W.debug then print("[WRAITH] " .. tostring(msg)) end
end

local function getChar(p) return p and p.Character end
local function getHum(p)
	local c = getChar(p)
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot(p)
	local c = getChar(p)
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function alive(p)
	local h = getHum(p)
	return h ~= nil and h.Health > 0
end
local function allowed(p)
	if not p or p == player or p.Parent ~= Players then return false end
	return not W.deathChk or alive(p)
end
local function corner(o, r)
	return W.new("UICorner", o, { CornerRadius = UDim.new(0, r or 10) })
end
local function stroke(o, col, th, tr)
	return W.new("UIStroke", o, {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = col or C.raised,
		Thickness = th or 1, Transparency = tr or 0,
	})
end
local function label(parent, text, size, col, bold)
	return W.new("TextLabel", parent, {
		BackgroundTransparency = 1, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = text, TextSize = size or 13, TextColor3 = col or C.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		BorderSizePixel = 0,
	})
end
local function ord(o)
	W.order = W.order + 1
	o.LayoutOrder = W.order
	return o
end
local function beep(pitch)
	if not W.sounds or not W.running then return end
	local s = W.new("Sound", Sound, {
		SoundId = "rbxassetid://12221967", Volume = 0.08, PlaybackSpeed = pitch or 1,
	})
	s:Play()
	Debris:AddItem(s, 2)
end

function W.reportError(scope, message)
	local now = os.clock()
	local key = tostring(scope)
	local previous = W.frameErrors[key]
	local text = tostring(message)
	W.frameErrors[key] = {message = text, time = now, count = previous and previous.count + 1 or 1}
	W.lastError = key .. ": " .. text
	if not previous or previous.message ~= text or now - (previous.notified or 0) > 8 then
		W.frameErrors[key].notified = now
		warn("[FUSION 7 WOOD / " .. key .. "] " .. text)
		W.log(W.lastError, "ERROR")
		if W.ui.liveDot then W.ui.liveDot.BackgroundColor3 = C.bad end
		if W.toast then W.toast(key .. " failed. System > Diagnostics has the details.", C.bad) end
	else
		W.frameErrors[key].notified = previous.notified
	end
end

function W.safe(fn, ...)
	if not W.running then return false end
	local ok, result = xpcall(fn, debug.traceback, ...)
	if not ok then pcall(W.reportError, "Action", result) end
	return ok, result
end

function W.guard(scope, fn, ...)
	if not W.running then return false end
	local failure = W.frameErrors[scope]
	if failure and os.clock() - failure.time < 0.5 then return false end
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then pcall(W.reportError, scope, err) end
	return ok
end

function W.woodInlay(parent, z, density)
	local grain = W.new("Frame", parent, {Name = "WalnutInlay", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.wood, BorderSizePixel = 0, ClipsDescendants = true, Active = false, ZIndex = z})
	corner(grain, 12)
	for line = 1, density or 7 do
		for segment = 1, 8 do
			local x = (segment - 1) / 8
			local y = line / ((density or 7) + 1) + math.sin(segment * 0.8 + line * 1.7) * 0.018
			W.new("Frame", grain, {Name = "Grain", Position = UDim2.fromScale(x, y),
				Size = UDim2.new(0.126, 1, 0, 1), Rotation = math.sin(segment + line) * 1.8,
				BackgroundColor3 = C.woodLight, BackgroundTransparency = 0.86 + (line % 3) * 0.025,
				BorderSizePixel = 0, Active = false, ZIndex = z + 1})
		end
	end
	return grain
end

function W.logo(parent, size, z)
	local box = W.new("Frame", parent, {Name = "WoodMonogram", Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = C.wood, BorderSizePixel = 0, ZIndex = z or 102, Active = false})
	corner(box, 10)
	local text = label(box, "w", math.floor(size * 0.63), C.accent, true)
	text.Size, text.TextXAlignment, text.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, (z or 102) + 1
	return box
end

local hud = W.new("ScreenGui", playerGui, {
	Name = "WRAITH_VECTOR_HUD", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local ui = W.new("ScreenGui", player.PlayerGui, {
	Name = "WRAITH_VECTOR_FUSION", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 2147482990, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local drawLayer = W.new("Frame", hud, {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1,
})
W.ui.root = ui
W.ui.hud = hud
W.ui.drawLayer = drawLayer

local statusLbl
local function setStatus(t)
	local text = tostring(t)
	if statusLbl then statusLbl.Text = text end
	W.log(text)
	dbg(text)
end

W.ui.toasts = W.new("Frame", ui, {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 64),
	Size = UDim2.fromOffset(320, 260), BackgroundTransparency = 1, ZIndex = 400,
})
W.new("UIListLayout", W.ui.toasts, {
	SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
})
W.toastQueue = {}
local function flash(text, col)
	if not W.running then return end
	if #W.toastQueue >= 3 then
		local old = table.remove(W.toastQueue, 1)
		if old.Parent then old:Destroy() end
	end
	local toast = W.new("Frame", W.ui.toasts, {
		Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panel,
		BorderSizePixel = 0, ZIndex = 401, LayoutOrder = W.order,
	})
	W.order = W.order + 1
	corner(toast, 12)
	stroke(toast, col or C.accent, 1, 0.45)
	local mark = W.new("Frame", toast, {
		Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(3, 24),
		BackgroundColor3 = col or C.accent, BorderSizePixel = 0, ZIndex = 402,
	})
	corner(mark, 2)
	local txt = label(toast, tostring(text), 12, C.text, true)
	txt.Position = UDim2.fromOffset(25, 7)
	txt.Size = UDim2.new(1, -36, 1, -14)
	txt.TextWrapped = true
	txt.TextTruncate = Enum.TextTruncate.None
	txt.ZIndex = 402
	table.insert(W.toastQueue, toast)
	W.log(text, "NOTICE")
	task.delay(3.5, function()
		local idx = table.find(W.toastQueue, toast)
		if idx then table.remove(W.toastQueue, idx) end
		if toast.Parent then toast:Destroy() end
	end)
end
W.toast = flash

local PW, PH = 940, 650
local main = W.new("Frame", ui, {
	Name = "FusionWoodWindow", Size = UDim2.fromOffset(PW, PH), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg, BorderSizePixel = 0,
	Visible = false, Active = false, ZIndex = 100, ClipsDescendants = true,
})
corner(main, 18)
stroke(main, C.line, 1, 0.25)
W.ui.main = main
W.ui.scale = W.new("UIScale", main, {Scale = 1})
local header = W.new("Frame", main, {Name = "WoodHeader", Size = UDim2.new(1, 0, 0, 73),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = false, ZIndex = 102})
W.ui.header = header
corner(header, 18)
W.ui.topTrim = W.new("Frame", header, {Name = "WalnutTrim", Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 0, 3), BackgroundColor3 = C.wood,
	BorderSizePixel = 0, ZIndex = 103, Active = false})
W.ui.logo = W.logo(header, 36, 103)
W.ui.logo.Position = UDim2.fromOffset(20, 22)
W.ui.brand = label(header, "WRAITH", 21, C.text, true)
W.ui.brand.Position, W.ui.brand.Size, W.ui.brand.ZIndex = UDim2.fromOffset(68, 17), UDim2.fromOffset(180, 29), 104
W.ui.version = label(header, "FUSION  /  WOOD EDITION", 9, C.dim, true)
W.ui.version.Position, W.ui.version.Size, W.ui.version.ZIndex = UDim2.fromOffset(69, 45), UDim2.fromOffset(190, 16), 104
W.ui.dragHandle = W.new("TextButton", header, {Name = "DragHandle", Size = UDim2.new(1, -267, 1, 0),
	BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 107})
function W.smallButton(parent, text, width, z, fn)
	local b = W.new("TextButton", parent, {Size = UDim2.fromOffset(width or 34, 34), BackgroundColor3 = C.raised,
		BorderSizePixel = 0, Text = text, TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 12,
		AutoButtonColor = false, ZIndex = z or 104, Modal = false, Selectable = false})
	corner(b, 9)
	W.bind(b.MouseEnter, function() if W.running then W.animate(b, {BackgroundColor3 = C.accent2}, 0.12) end end)
	W.bind(b.MouseLeave, function() if W.running then W.animate(b, {BackgroundColor3 = C.raised}, 0.12) end end)
	if fn then W.bind(b.Activated, function() if W.running then W.safe(fn) end end) end
	return b
end
W.ui.searchButton = W.smallButton(header, "Search settings", 122, 108, function() if W.showPalette then W.showPalette(not W.ui.palette.Visible) end end)
W.ui.searchButton.Position = UDim2.new(1, -264, 0, 24)
W.ui.stopButton = W.smallButton(header, "Release", 76, 108, function() if W.emergencyRelease then W.emergencyRelease() end end)
W.ui.stopButton.Position, W.ui.stopButton.TextColor3 = UDim2.new(1, -132, 0, 24), C.warn
local closeBtn = W.smallButton(header, "x", 32, 108)
closeBtn.Position = UDim2.new(1, -46, 0, 24)
W.ui.closeButton = closeBtn
local side = W.new("ScrollingFrame", main, {Name = "TopNavigation", Position = UDim2.fromOffset(18, 82), Size = UDim2.new(1, -36, 0, 43),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent2, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 103})
W.new("UIListLayout", side, {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
W.ui.side = side
W.ui.navDivider = W.new("Frame", main, {Position = UDim2.fromOffset(20, 132), Size = UDim2.new(1, -40, 0, 1),
	BackgroundColor3 = C.line, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 102})
W.ui.rail = W.new("Frame", main, {Name = "WoodPageRail", Position = UDim2.fromOffset(14, 147), Size = UDim2.new(0, 164, 1, -193),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 101, ClipsDescendants = true})
W.woodInlay(W.ui.rail, 101, 8)
W.ui.railCaption = label(W.ui.rail, "PAGES", 10, C.dim, true)
W.ui.railCaption.Position, W.ui.railCaption.Size, W.ui.railCaption.ZIndex = UDim2.fromOffset(15, 17), UDim2.new(1, -30, 0, 18), 104
W.ui.identity = label(W.ui.rail, "Karma", 13, C.text, true)
W.ui.identity.Position, W.ui.identity.Size, W.ui.identity.ZIndex = UDim2.new(0, 15, 1, -49), UDim2.new(1, -30, 0, 20), 104
W.ui.identitySub = label(W.ui.rail, "Local workspace", 10, C.dim)
W.ui.identitySub.Position, W.ui.identitySub.Size, W.ui.identitySub.ZIndex = UDim2.new(0, 15, 1, -28), UDim2.new(1, -30, 0, 16), 104
W.ui.subtabs = W.new("ScrollingFrame", W.ui.rail, {Name = "PageList", Position = UDim2.fromOffset(10, 49), Size = UDim2.new(1, -20, 1, -113),
	BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent2, ZIndex = 104})
W.ui.subtabLayout = W.new("UIListLayout", W.ui.subtabs, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
W.ui.pageHeader = W.new("Frame", main, {Position = UDim2.fromOffset(202, 146), Size = UDim2.new(1, -226, 0, 57), BackgroundTransparency = 1, ZIndex = 103})
W.ui.pageTitle = label(W.ui.pageHeader, "Dashboard", 23, C.text, true)
W.ui.pageTitle.Size, W.ui.pageTitle.ZIndex = UDim2.new(1, 0, 0, 30), 104
W.ui.pageSubtitle = label(W.ui.pageHeader, "Your session, at a glance.", 11, C.dim)
W.ui.pageSubtitle.Position, W.ui.pageSubtitle.Size, W.ui.pageSubtitle.ZIndex = UDim2.fromOffset(1, 34), UDim2.new(1, 0, 0, 18), 104
local content = W.new("Frame", main, {Name = "Content", Position = UDim2.fromOffset(202, 210), Size = UDim2.new(1, -226, 1, -254), BackgroundTransparency = 1, ZIndex = 101})
W.ui.content = content
W.ui.statusLine = W.new("Frame", main, {Position = UDim2.new(0, 20, 1, -34), Size = UDim2.new(1, -40, 0, 1), BackgroundColor3 = C.line, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 102})
W.ui.liveDot = W.new("Frame", main, {Position = UDim2.new(0, 22, 1, -21), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = C.good, BorderSizePixel = 0, ZIndex = 103})
corner(W.ui.liveDot, 3)
statusLbl = label(main, "Ready", 10, C.dim)
statusLbl.Position, statusLbl.Size, statusLbl.ZIndex = UDim2.new(0, 35, 1, -28), UDim2.new(1, -185, 0, 20), 103
W.ui.footerStats = label(main, "WOOD / 07", 10, C.dim)
W.ui.footerStats.Position, W.ui.footerStats.Size, W.ui.footerStats.ZIndex = UDim2.new(1, -148, 1, -28), UDim2.fromOffset(126, 20), 103
W.ui.footerStats.TextXAlignment = Enum.TextXAlignment.Right
W.ui.launcher, W.ui.launcherRoot = Boot.launcher, Boot.topGui

function W.register(title, page, kind, fn, row, object)
	local cmd = {title = title, page = page, kind = kind, run = fn, row = row, object = object}
	table.insert(W.commands, cmd)
	return cmd
end

local function makePage(name)
	local p = W.new("ScrollingFrame", content, {
		Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, ZIndex = 101,
	})
	W.new("UIListLayout", p, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 9) })
	W.new("UIPadding", p, { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 22), PaddingTop = UDim.new(0, 2) })
	W.pages[name] = p
	return p
end

W.groups = {
	{"Overview", "01", {"Home", "Favorites", "Presets"}},
	{"Combat", "02", {"Aim", "Auto"}},
	{"Visuals", "03", {"Vision", "Hunter", "World"}},
	{"Movement", "04", {"Movement", "Camera", "Underground"}},
	{"Players", "05", {"Players", "Positions", "Macro"}},
	{"Inspect", "06", {"Explorer", "Deep Scan", "Inspector"}},
	{"Settings", "07", {"Hotkeys", "Profiles", "System"}},
}
W.pageGroups, W.groupTabs, W.groupLast = {}, {}, {}
W.displayNames = {Home = "Dashboard", Vision = "Overlays", Hunter = "Radar & alerts", Auto = "Automation", System = "Preferences", Macro = "Routes", Positions = "Locations", Favorites = "Pinned", Presets = "Presets", ["Deep Scan"] = "Scanner"}
for _, group in ipairs(W.groups) do for _, name in ipairs(group[3]) do W.pageGroups[name] = group[1] end end
local function showPage(name)
	if not W.pages[name] then return end
	W.releaseTextFocus()
	W.page = name
	local group = W.pageGroups[name] or "Overview"
	W.groupLast[group] = name
	for n, p in pairs(W.pages) do p.Visible = n == name end
	for n, tab in pairs(W.tabs) do
		tab.Visible = W.pageGroups[n] == group
		tab.BackgroundColor3 = n == name and C.accent2 or C.wood
		tab.TextColor3 = n == name and C.text or C.dim
	end
	for n, tab in pairs(W.groupTabs) do
		local selected = n == group
		tab.BackgroundColor3 = selected and C.panel or C.bg
		tab.TabText.TextColor3 = selected and C.text or C.dim
		tab.TabIcon.TextColor3 = selected and C.accent or C.dim
		tab.ActiveMark.Visible = selected
	end
	W.ui.pageTitle.Text = W.displayNames[name] or name
	W.ui.pageSubtitle.Text = W.about[name] and W.about[name][2] or group
	W.ui.subtabs.CanvasPosition = Vector2.zero
	if W.ui.palette then W.ui.palette.Visible = false end
	if W.layoutSections then W.layoutSections(name) end
end
W.showPage = showPage


function W.pretty(text)
	if text == string.upper(text) then return string.upper(string.sub(text, 1, 1)) .. string.lower(string.sub(text, 2)) end
	return text
end
function W.tip(text, object)
	if not text or not W.open then return end
	if not W.ui.tooltip then
		local tip = label(main, "", 12, C.text)
		tip.BackgroundTransparency, tip.BackgroundColor3, tip.ZIndex = 0, C.raised, 500
		tip.TextWrapped, tip.TextTruncate = true, Enum.TextTruncate.None
		W.new("UIPadding", tip, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)})
		corner(tip, 8)
		W.ui.tooltip = tip
	end
	local tip, scale = W.ui.tooltip, math.max(W.ui.targetScale or 1, 0.1)
	local point = UIS:GetMouseLocation()
	local width = math.min(290, main.Size.X.Offset - 28)
	local height = W.TextService:GetTextSize(text, 12, tip.Font, Vector2.new(width - 24, 10000)).Y + 22
	local x = math.clamp((point.X - main.AbsolutePosition.X) / scale + 12, 8, math.max(8, main.Size.X.Offset - width - 8))
	local y = math.clamp((point.Y - main.AbsolutePosition.Y) / scale + 21, 8, math.max(8, main.Size.Y.Offset - height - 8))
	tip.Text, tip.Position, tip.Size, tip.Visible = text, UDim2.fromOffset(x, y), UDim2.fromOffset(width, height), true
	W.ui.tipOwner = object
end
function W.help(object, text)
	if not text then return end
	object.MouseEnter:Connect(function() W.tip(text, object) end)
	object.MouseLeave:Connect(function() if W.ui.tipOwner == object and W.ui.tooltip then W.ui.tooltip.Visible = false end end)
end
local function heading(parent, text)
	local row = W.new("Frame", parent, {Name = "SectionHeading", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, ZIndex = 102})
	row:SetAttribute("SectionTitle", text)
	local title = label(row, string.upper(string.sub(text, 1, 1)) .. string.sub(W.pretty(text), 2), 14, C.text, true)
	title.Name = "SectionTitle"
	title.Position, title.Size, title.ZIndex = UDim2.fromOffset(1, 0), UDim2.new(1, -36, 1, 0), 103
	return ord(row)
end
local function note(parent, text, h)
	local l = label(parent, text, 12, C.dim)
	l.Name = "HelpNote"
	l.Size, l.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	l.TextWrapped, l.TextTruncate, l.TextYAlignment, l.ZIndex = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top, 102
	return ord(l)
end
local function input(parent, placeholder, cb)
	local box = W.new("TextBox", parent, {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.bg,
		BorderSizePixel = 0, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = C.dim,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 103})
	W.new("UIPadding", box, {PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11)})
	corner(box, 9)
	local edge = stroke(box, C.line, 1, 0.5)
	ord(box)
	box.Focused:Connect(function() edge.Color = C.accent end)
	box.FocusLost:Connect(function()
		edge.Color = C.line
		if box:GetAttribute("WRAITHSkipCommit") then box:SetAttribute("WRAITHSkipCommit", nil) return end
		if not W.releasingMovement then W.safe(cb, box.Text, box) end
	end)
	return box
end
local function button(parent, text, cb)
	local b = W.new("TextButton", parent, {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.raised, BorderSizePixel = 0,
		Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false, ZIndex = 102})
	corner(b, 9)
	local title = label(b, W.pretty(text), 13, C.text, true)
	title.Position, title.Size, title.ZIndex = UDim2.fromOffset(14, 0), UDim2.new(1, -38, 1, 0), 103
	local arrow = label(b, ">", 13, C.dim)
	arrow.Position, arrow.Size, arrow.ZIndex = UDim2.new(1, -23, 0, 0), UDim2.fromOffset(15, 37), 103
	ord(b)
	b.MouseEnter:Connect(function() W.animate(b, {BackgroundColor3 = C.accent2}) end)
	b.MouseLeave:Connect(function() W.animate(b, {BackgroundColor3 = C.raised}) end)
	b.Activated:Connect(function() W.safe(cb) end)
	W.register(text, parent.Name, "ACTION", cb, b)
	return b
end
local function toggle(parent, text, desc, cb)
	local row = W.new("Frame", parent, {Name = "WoodToggle", Size = UDim2.new(1, 0, 0, desc and 64 or 49),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 102})
	corner(row, 9)
	ord(row)
	local title = label(row, text, 13, C.text, true)
	title.Name, title.Position, title.Size, title.ZIndex = "ControlTitle", UDim2.fromOffset(13, 11), UDim2.new(1, -84, 0, 21), 103
	title.TextWrapped, title.TextTruncate = true, Enum.TextTruncate.None
	local detail
	if desc then
		detail = label(row, desc, 11, C.dim)
		detail.Name, detail.Position, detail.Size, detail.ZIndex = "ControlDescription", UDim2.fromOffset(13, 33), UDim2.new(1, -84, 0, 20), 103
		detail.TextWrapped, detail.TextTruncate, detail.TextYAlignment = true, Enum.TextTruncate.None, Enum.TextYAlignment.Top
	end
	local hit = W.new("TextButton", row, {Name = "ToggleHit", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 104})
	local track = W.new("Frame", hit, {Name = "Switch", Size = UDim2.fromOffset(38, 22), Position = UDim2.new(1, -51, 0.5, -11),
		BackgroundColor3 = C.raised, BorderSizePixel = 0, ZIndex = 105})
	corner(track, 11)
	local knob = W.new("Frame", track, {Name = "Knob", Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.dim, BorderSizePixel = 0, ZIndex = 106})
	corner(knob, 8)
	local obj = {state = false, row = row, name = text, default = false}
	function obj.Render()
		W.animate(knob, {Position = UDim2.fromOffset(obj.state and 19 or 3, 3), BackgroundColor3 = obj.state and C.ink or C.dim}, 0.13)
		W.animate(track, {BackgroundColor3 = obj.state and C.accent or C.raised}, 0.13)
	end
	function obj.Set(value, silent)
		value = value == true
		if not W.running and value then return end
		if obj.changing then if not value then obj.state = false end return end
		if W.releasingMovement and value and W.motionToggles[text] then return end
		if obj.state == value then return end
		obj.changing, obj.state = true, value
		if not silent then
			local ok, accepted = pcall(cb, value)
			if not ok or accepted == false then
				obj.state = false
				pcall(cb, false)
				if not ok and W.motionToggles[text] and W.releaseMovement then pcall(W.releaseMovement, "Stopped after a control error", true) end
				if not ok then pcall(W.reportError, text, accepted) end
			end
			pcall(W.log, text .. ": " .. (obj.state and "ON" or "OFF"))
		end
		obj.changing = false
		pcall(obj.Render)
	end
	function obj.Get() return obj.state end
	function obj.Fit()
		if not row.Parent then return end
		local width = math.floor(row.AbsoluteSize.X / math.max(W.ui.targetScale or 1, 0.1))
		if width < 100 or width == obj.lastWidth then return end
		obj.lastWidth = width
		local available = math.max(60, width - 84)
		local titleH = math.max(19, W.TextService:GetTextSize(text, 13, title.Font, Vector2.new(available, 10000)).Y + 2)
		local detailH = detail and W.TextService:GetTextSize(desc, 11, detail.Font, Vector2.new(available, 10000)).Y + 2 or 0
		title.Size = UDim2.new(1, -84, 0, titleH)
		if detail then
			detail.Position, detail.Size = UDim2.fromOffset(13, titleH + 15), UDim2.new(1, -84, 0, detailH)
		end
		row.Size = UDim2.new(1, 0, 0, math.max(detail and 62 or 48, titleH + (detail and detailH + 5 or 0) + 22))
	end
	W.bind(row:GetPropertyChangedSignal("AbsoluteSize"), function() W.safe(obj.Fit) end)
	W.bind(hit.Activated, function() obj.Set(not obj.state) end)
	W.toggles[text] = obj
	task.defer(function() if W.running and row.Parent then obj.Fit() end end)
	W.register(text, parent.Name, "TOGGLE", function() obj.Set(not obj.state) end, row, obj)
	return obj
end

local function slider(parent, text, minimum, maximum, default, decimals, cb)
	local row = W.new("Frame", parent, {Name = "WoodSlider", Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = C.bg, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 102})
	corner(row, 9)
	ord(row)
	local title = label(row, text, 13, C.text)
	title.Position, title.Size, title.ZIndex = UDim2.fromOffset(13, 6), UDim2.new(1, -108, 0, 30), 103
	local valueBox = W.new("TextBox", row, {Position = UDim2.new(1, -88, 0, 9), Size = UDim2.fromOffset(75, 25),
		BackgroundColor3 = C.bg, BorderSizePixel = 0, Text = "", Font = Enum.Font.Code, TextSize = 13,
		TextColor3 = C.accent, ClearTextOnFocus = false, ZIndex = 104})
	corner(valueBox, 6)
	local hit = W.new("TextButton", row, {Position = UDim2.fromOffset(17, 40), Size = UDim2.new(1, -34, 0, 25), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 103})
	local rail = W.new("Frame", hit, {Position = UDim2.new(0, 0, 0.5, -2), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.raised, BorderSizePixel = 0, ZIndex = 104})
	corner(rail, 2)
	local fill = W.new("Frame", rail, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 105})
	corner(fill, 2)
	local knob = W.new("Frame", rail, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 106})
	corner(knob, 6)
	local value = default
	local obj = {name = text, row = row, default = default, min = minimum, max = maximum}
	function obj.Render()
		local alpha = (value - minimum) / math.max(maximum - minimum, 0.001)
		fill.Size, knob.Position = UDim2.fromScale(alpha, 1), UDim2.fromScale(alpha, 0.5)
		valueBox.Text = string.format("%." .. (decimals or 0) .. "f", value)
	end
	function obj.Set(v, userEdit)
		v = tonumber(v)
		if not v or v ~= v or math.abs(v) == math.huge then obj.Render() return end
		local step = 10 ^ (decimals or 0)
		value = math.clamp(math.floor(v * step + 0.5) / step, minimum, maximum)
		obj.Render()
		W.safe(cb, value)
	end
	function obj.Get() return value end
	local function setX(x)
		obj.Set(minimum + (maximum - minimum) * math.clamp((x - hit.AbsolutePosition.X) / math.max(hit.AbsoluteSize.X, 1), 0, 1), true)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			W.dragging, W.dragInput, W.dragTouch = setX, i, i.UserInputType == Enum.UserInputType.Touch
			parent.ScrollingEnabled, W.dragPage = false, parent
			setX(i.Position.X)
		end
	end)
	valueBox.FocusLost:Connect(function()
		if valueBox:GetAttribute("WRAITHSkipCommit") then valueBox:SetAttribute("WRAITHSkipCommit", nil) obj.Render() return end
		if not W.releasingMovement then obj.Set(valueBox.Text, true) end
	end)
	obj.Render()
	W.sliders[text] = obj
	W.register(text, parent.Name, "VALUE", function() valueBox:CaptureFocus() end, row, obj)
	return obj
end
local function readout(parent, height)
	local box = W.new("Frame", parent, {Name = "WoodReadout", Size = UDim2.new(1, 0, 0, height or 130), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 102})
	corner(box, 9)
	stroke(box, C.line, 1, 0.65)
	ord(box)
	local scroll = W.new("ScrollingFrame", box, {Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 1, -24),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent2,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 103})
	local text = W.new("TextLabel", scroll, {Name = "ReadOnlyText", Text = "", BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		TextSize = 12, TextColor3 = C.dim, Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
		BorderSizePixel = 0, ZIndex = 104, Active = false, Selectable = false})
	return text
end


for index, name in ipairs(PAGES) do
	makePage(name)
	local b = W.new("TextButton", W.ui.subtabs, {Name = name, Size = UDim2.new(1, -3, 0, 37), Text = W.displayNames[name] or name,
		TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = C.dim, BackgroundColor3 = C.wood,
		TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 105, LayoutOrder = index})
	corner(b, 8)
	W.new("UIPadding", b, {PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 8)})
	W.bind(b.Activated, function() showPage(name) end)
	W.tabs[name] = b
	W.register("Open " .. name, name, "PAGE", function() showPage(name) end)
end
for index, group in ipairs(W.groups) do
	local name = group[1]
	local b = W.new("TextButton", side, {Name = name, Size = UDim2.fromOffset(116, 38), Text = "", BackgroundColor3 = C.bg,
		BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 104, LayoutOrder = index})
	corner(b, 9)
	local icon = label(b, "", 10, C.dim)
	icon.Name, icon.Visible = "TabIcon", false
	local text = label(b, name, 12, C.dim, true)
	text.Name, text.Position, text.Size, text.ZIndex = "TabText", UDim2.fromOffset(0, -1), UDim2.fromScale(1, 1), 105
	text.TextXAlignment = Enum.TextXAlignment.Center
	local mark = W.new("Frame", b, {Name = "ActiveMark", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.fromOffset(20, 2), BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false, ZIndex = 105})
	corner(mark, 1)
	W.groupTabs[name] = b
	W.bind(b.Activated, function() showPage(W.groupLast[name] or group[3][1]) end)
end

function W.fitWindow(recenter)
	camera = workspace.CurrentCamera or camera
	if not camera then return end
	local viewport, top = camera.ViewportSize, 20
	pcall(function()
		local inset = W.GuiService:GetGuiInset()
		if inset then top = math.max(top, inset.Y + 12) end
	end)
	local availableW, availableH = math.max(100, viewport.X - 96), math.max(100, viewport.Y - top - 14)
	local scale = math.max(0.1, math.min(W.interfaceScale, availableW / 460, availableH / 430))
	local width, height = math.min(940, availableW / scale), math.min(650, availableH / scale)
	if W.windowMode == "LOCK" and W.windowSize then
		width, height = math.clamp(W.windowSize.X, 460, width), math.clamp(W.windowSize.Y, 430, height)
	elseif W.windowMode == "HUD" then width, height = math.min(width, 540), math.min(height, 520) end
	local compact = width < 700
	local left, bodyTop = compact and 20 or 202, compact and 244 or 210
	W.ui.targetScale, W.ui.compact, W.ui.contentWidth = scale, compact, width - left - 22
	W.ui.scale.Scale, main.Size = scale, UDim2.fromOffset(width, height)
	W.ui.rail.Visible = not compact
	W.ui.pageHeader.Position = UDim2.fromOffset(left, 146)
	W.ui.pageHeader.Size = UDim2.new(1, -left - 22, 0, 57)
	W.ui.searchButton.Text = compact and "Find" or "Search settings"
	W.ui.searchButton.Size = UDim2.fromOffset(compact and 50 or 122, 34)
	W.ui.searchButton.Position = UDim2.new(1, compact and -192 or -264, 0, 24)
	W.ui.dragHandle.Size = UDim2.new(1, compact and -200 or -272, 0, 73)
	W.ui.brand.TextSize = compact and 18 or 21
	W.ui.brand.Size = UDim2.fromOffset(compact and 115 or 180, 29)
	W.ui.version.Text = compact and "WOOD / 07" or "FUSION  /  WOOD EDITION"
	W.ui.version.Size = UDim2.fromOffset(compact and 113 or 190, 16)
	if compact then
		W.ui.subtabs.Parent = main
		W.ui.subtabs.Position, W.ui.subtabs.Size = UDim2.fromOffset(left, 201), UDim2.new(1, -left - 22, 0, 34)
		W.ui.subtabLayout.FillDirection = Enum.FillDirection.Horizontal
		W.ui.subtabs.AutomaticCanvasSize, W.ui.subtabs.ScrollingDirection = Enum.AutomaticSize.X, Enum.ScrollingDirection.X
	else
		W.ui.subtabs.Parent = W.ui.rail
		W.ui.subtabs.Position, W.ui.subtabs.Size = UDim2.fromOffset(10, 49), UDim2.new(1, -20, 1, -113)
		W.ui.subtabLayout.FillDirection = Enum.FillDirection.Vertical
		W.ui.subtabs.AutomaticCanvasSize, W.ui.subtabs.ScrollingDirection = Enum.AutomaticSize.Y, Enum.ScrollingDirection.Y
	end
	for name, tab in pairs(W.tabs) do
		local measured = W.TextService:GetTextSize(W.displayNames[name] or name, 12, Enum.Font.GothamMedium, Vector2.new(400, 30)).X
		tab.Size = compact and UDim2.fromOffset(math.max(70, measured + 24), 30) or UDim2.new(1, -3, 0, 37)
		tab.TextXAlignment = compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	end
	for name, tab in pairs(W.groupTabs) do
		local measured = W.TextService:GetTextSize(name, 12, Enum.Font.GothamMedium, Vector2.new(400, 30)).X
		tab.Size = UDim2.fromOffset(math.max(84, measured + 28, (width - 72) / 7), 38)
		tab.TabText.Visible, tab.TabIcon.Visible = true, false
	end
	content.Position, content.Size = UDim2.fromOffset(left, bodyTop), UDim2.new(1, -left - 22, 1, -bodyTop - 44)
	if W.ui.resizeGrip then W.ui.resizeGrip.Visible = W.windowMode == "LOCK" end
	if W.ui.hudPrev then W.ui.hudPrev.Visible, W.ui.hudNext.Visible = false, false end
	W.ui.toasts.Size = UDim2.fromOffset(math.max(160, math.min(310, viewport.X - 100)), 250)
	W.ui.toasts.Position = UDim2.new(1, -78, 0, top + 6)
	local half = Vector2.new(width * scale / 2, height * scale / 2)
	local lowX, highX = 12 + half.X, math.max(12 + half.X, viewport.X - 76 - half.X)
	local lowY, highY = top + half.Y, math.max(top + half.Y, viewport.Y - 14 - half.Y)
	if recenter then main.Position = UDim2.fromOffset((lowX + highX) / 2, (lowY + highY) / 2) end
	local center = Vector2.new(main.Position.X.Scale * viewport.X + main.Position.X.Offset, main.Position.Y.Scale * viewport.Y + main.Position.Y.Offset)
	main.Position = UDim2.fromOffset(math.clamp(center.X, lowX, highX), math.clamp(center.Y, lowY, highY))
	if W.layoutSections then W.layoutSections(W.page) end
end

function W.ownsGui(object)
	return object ~= nil and (object:IsDescendantOf(ui) or object:IsDescendantOf(hud) or (Boot.topGui ~= nil and object:IsDescendantOf(Boot.topGui)))
end

function W.releaseMenuCursor()
	W.menuCursor = nil
	if W.ui.closeButton then W.ui.closeButton.Modal = false end
end
function W.updateMenuCursor()
	return
end
function W.closeInput()
	W.open = false
	main.Visible = false
	W.ui.closeButton.Modal = false
	Boot.refreshTopButton()
	W.menuToken = W.menuToken + 1
	W.paletteToken = W.paletteToken + 1
	if W.hotkeys then W.hotkeys.capture = nil W.hotkeys.held = {} W.hotkeys.captureToken = W.hotkeys.captureToken + 1 end
	pcall(W.releaseTextFocus)
	pcall(function() if W.dragPage and W.dragPage.Parent then W.dragPage.ScrollingEnabled = true end end)
	W.dragging, W.dragInput, W.dragPage, W.windowDrag, W.windowResize, W.radarDrag = nil, nil, nil, nil, nil, nil
	if W.ui.palette then W.ui.palette.Visible = false end
	if W.ui.tooltip then W.ui.tooltip.Visible = false end
	pcall(W.releaseMenuCursor)
	pcall(function() if W.ownsGui(W.GuiService.SelectedObject) then W.GuiService.SelectedObject = nil end end)
end
function W.setOpen(on)
	if not W.running then return end
	ui.Enabled = true
	if not on then W.closeInput() if W.hotkeys then pcall(W.hotkeys.refresh) end return end
	if W.freecam or W.camLock or W.spectate then
		W.freecam, W.camLock, W.spectate = false, false, false
		pcall(W.restoreCamera)
		pcall(W.syncOff, {"Free Cam", "Camera Lock", "Spectate Target"})
	end
	if W.fallback and W.fallback.on then pcall(W.stopFallback) end
	if W.auto and W.auto.running then pcall(W.auto.stop, "Panel opened", false) end
	if W.vector and W.vector.releaseTool then pcall(W.vector.releaseTool) end
	if W.kar and W.kar.releaseCursor then pcall(W.kar.releaseCursor) end
	W.open, main.Visible = true, true
	Boot.refreshTopButton()
	local fitted, problem = pcall(W.fitWindow, false)
	if not fitted then
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		W.ui.scale.Scale = math.max(0.2, math.min(1, (viewport.X - 96) / 940, (viewport.Y - 80) / 650))
		main.Size, main.Position = UDim2.fromOffset(940, 650), UDim2.fromScale(0.46, 0.5)
		pcall(W.reportError, "Menu layout", problem)
	end
	W.ui.closeButton.Modal = true
end


function W.overUI(point)
	local function inside(o)
		if not o or not o.Parent or not o.Visible then return false end
		local ancestor = o.Parent
		while ancestor and ancestor ~= player.PlayerGui do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
			if ancestor:IsA("LayerCollector") and not ancestor.Enabled then return false end
			ancestor = ancestor.Parent
		end
		local p, s = o.AbsolutePosition, o.AbsoluteSize
		return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + s.X and point.Y <= p.Y + s.Y
	end
	if inside(main) or inside(W.ui.launcher) or inside(W.ui.palette) or inside(W.ui.radar) then return true end
	if inside(W.ui.touchFlight) then return true end
	return false
end

W.bind(W.ui.dragHandle.InputBegan, function(i)
	if W.windowMode == "LOCK" then return end
	if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
	if i.Position.X > W.ui.searchButton.AbsolutePosition.X - 6 then return end
	W.windowDrag = {input = i, touch = i.UserInputType == Enum.UserInputType.Touch, start = Vector2.new(i.Position.X, i.Position.Y), pos = main.Position}
end)

W.bind(UIS.InputChanged, function(i)
	if W.windowDrag and ((not W.windowDrag.touch and i.UserInputType == Enum.UserInputType.MouseMovement) or i == W.windowDrag.input) then
		local d = Vector2.new(i.Position.X, i.Position.Y) - W.windowDrag.start
		main.Position = W.windowDrag.pos + UDim2.fromOffset(d.X, d.Y)
		W.fitWindow(false)
	end
end)

Boot.stage("Building controls and overlays...")
W.worldFolder = W.new("Folder", workspace, {Name = "WRAITH_LocalVisuals"})
W.atmoBak = setmetatable({}, {__mode = "k"})

function W.setToggle(name, value)
	local t = W.toggles[name]
	if t then t.Set(value) end
end
function W.restoreCollisions()
	for part, value in pairs(W.collisionBak) do
		if part.Parent then part.CanCollide = value end
		W.collisionBak[part] = nil
	end
end
function W.setBody(on)
	if on then
		local h = getHum(player)
		if not h or h.Health <= 0 then return end
		if not W.bodyBak[h] then W.bodyBak[h] = {AutoRotate = h.AutoRotate} end
		h.AutoRotate = false
	else
		for h, base in pairs(W.bodyBak) do
			W.bodyBak[h] = nil
			if h.Parent then pcall(function() h.AutoRotate = base.AutoRotate end) end
		end
	end
end

function W.destroyFlightConstraints()
	local rig = W.flyRig
	W.flyRig = nil
	if not rig then return end
	for _, key in ipairs({"velocity", "lift", "facing", "attachment"}) do
		local object = rig[key]
		if object then pcall(function() object:Destroy() end) end
	end
end

function W.stopFlyRig()
	W.fly = false
	local rig, body = W.flyRig, W.flightBody
	local root = body and body.root or (rig and rig.root)
	W.flightBody = nil
	W.destroyFlightConstraints()
	W.flightVelocity, W.flightRequested, W.flightDirection = Vector3.zero, Vector3.zero, Vector3.zero
	W.flightKeys = {}
	W.touchUp, W.touchDown = false, false
	W.flightTakeoffUntil, W.flightBlockedTime = 0, 0
	W.flightBlockReason, W.lastFlightTick = nil, nil
	if root and root.Parent then
		pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
		pcall(function() root.AssemblyAngularVelocity = Vector3.zero end)
	end
	if body and body.hum and body.hum.Parent then
		pcall(function() body.hum.AutoRotate = body.autoRotate end)
	end
end

function W.stopFlight(message)
	W.stopFlyRig()
	local toggleObject = W.toggles.Fly
	if toggleObject then
		toggleObject.state = false
		pcall(toggleObject.Render)
	end
	if message then
		W.lastFlightIssue = message
		pcall(setStatus, message)
	end
end

function W.clearFlightRemnants(root)
	local ownedNames = {
		WRAITH_FlightAttachment = true, WRAITH_FlightVelocity = true,
		WRAITH_FlightFacing = true, WRAITH_FlightLift = true,
		WraithFlightAttachment = true, WraithFlightVelocity = true,
		WraithFlightOrientation = true,
		VECTOR_FlightAttachment = true, VECTOR_FlightVelocity = true, VECTOR_FlightOrientation = true,
	}
	for _, object in ipairs(root:GetChildren()) do
		if ownedNames[object.Name] and (object:IsA("Attachment") or object:IsA("Constraint")) then
			object:Destroy()
		end
	end
end

function W.makeFlyRig(root)
	local rig = W.flyRig
	if rig and rig.root == root and rig.attachment and rig.attachment.Parent == root
		and rig.velocity and rig.velocity.Parent == root and rig.facing and rig.facing.Parent == root then
		return rig
	end
	W.destroyFlightConstraints()
	W.clearFlightRemnants(root)
	rig = {root = root, previousPosition = root.Position}
	W.flyRig = rig
	rig.attachment = W.new("Attachment", root, {Name = "WRAITH_FlightAttachment"})
	rig.velocity = W.new("LinearVelocity", root, {
		Name = "WRAITH_FlightVelocity", Attachment0 = rig.attachment,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
		ForceLimitsEnabled = true, ForceLimitMode = Enum.ForceLimitMode.Magnitude,
		MaxForce = math.max(100000, root.AssemblyMass * (workspace.Gravity + 4000)),
		VectorVelocity = Vector3.zero, Enabled = true,
	})
	rig.facing = W.new("AlignOrientation", root, {
		Name = "WRAITH_FlightFacing", Attachment0 = rig.attachment,
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		MaxTorque = 1000000, MaxAngularVelocity = 30,
		Responsiveness = 20, RigidityEnabled = false, Enabled = true,
		CFrame = root.CFrame.Rotation,
	})
	return rig
end

function W.bodyAvailable(action)
	local root, hum = getRoot(player), getHum(player)
	if not root or not hum or hum.Health <= 0 then
		flash("Respawn before using " .. action .. ".", C.warn)
		return false
	end
	local assembly = root.AssemblyRootPart
	if root.Anchored or (assembly and assembly.Anchored) then
		flash("The game has anchored your character. " .. action .. " cannot move it.", C.warn)
		return false
	end
	return true
end

function W.startFlight()
	if W.fly then return true end
	local ok, started = xpcall(function()
		W.stopMotion("Fly")
		W.stopFlyRig()
		W.setBody(false)
		if not W.bodyAvailable("Fly") then return false end
		local hum, root = getHum(player), getRoot(player)
		if hum.SeatPart then flash("Leave the seat before using Fly.", C.warn) return false end
		if hum.PlatformStand or hum:GetState() == Enum.HumanoidStateType.Physics then
			flash("Your character is already in a locked state. Press F8 to recover it first.", C.warn)
			return false
		end
		if W.ui.palette and W.ui.palette.Visible then W.showPalette(false) end
		W.releaseTextFocus()
		W.setOpen(false)
		W.windowFocused = true
		CAS:UnbindAction("W_FreecamSink")
		W.flightBody = {hum = hum, root = root, autoRotate = hum.AutoRotate}
		W.makeFlyRig(root)
		hum.AutoRotate = false
		W.fly = true
		W.lastFlightIssue, W.frameErrors.Flight = nil, nil
		W.lastFlightTick = os.clock()
		W.flightTakeoffUntil = hum.FloorMaterial ~= Enum.Material.Air and os.clock() + 0.2 or 0
		W.updateFlight(1 / 60, root, hum)
		return W.fly
	end, debug.traceback)
	if not ok or not started then
		W.stopFlight()
		if not ok then
			W.lastFlightIssue = tostring(started)
			pcall(W.reportError, "Flight", started)
		end
		return false
	end
	local t = W.toggles.Fly
	if t then t.state = true pcall(t.Render) end
	setStatus("Fly / WASD move / Space or E up / Shift or Q down / F8 release")
	return true
end

function W.releaseTextFocus()
	local focused = UIS:GetFocusedTextBox()
	if focused and focused:IsDescendantOf(ui) then
		focused:SetAttribute("WRAITHSkipCommit", true)
		focused:ReleaseFocus(false)
	end
end

function W.syncOff(names)
	for _, name in ipairs(names) do
		local t = W.toggles[name]
		if t then t.state = false pcall(t.Render) end
	end
end

function W.unlockHumanoid(h)
	return false
end
function W.releaseMovement(reason, hard)
	if W.releasingMovement then return end
	W.releasingMovement = true
	local underground = W.ugState ~= "SURFACE"
	local goal, root = W.ugAnchor, getRoot(player)
	W.fly, W.follow, W.orbit, W.freecam, W.camLock, W.spectate, W.float = false, false, false, false, false, false, false
	W.macroPlay, W.macroRec, W.ugFollow = false, false, false
	W.ugState, W.ugHold, W.ugFrom, W.ugTo, W.pickUGSpot = "SURFACE", nil, nil, nil, false
	W.touchUp, W.touchDown, W.jumpUntil, W.flightKeys = false, false, 0, {}
	if W.fallback and W.fallback.on then pcall(W.stopFallback) end
	if W.kar then
		W.kar.approachOn = false
		if hard then W.kar.enabled, W.kar.centerCursor = false, false end
	end
	if W.vector then
		if hard then W.vector.trigger, W.vector.bunnyHop = false, false end
		if W.vector.releaseTool then pcall(W.vector.releaseTool) end
	end
	if W.auto then pcall(W.auto.stop, reason or "Stopped", false) pcall(W.auto.releaseMouse) W.auto.running = false end
	if W.hotkeys then pcall(W.hotkeys.cancelCapture) end
	pcall(W.releaseTextFocus)
	pcall(function() if W.dragPage and W.dragPage.Parent then W.dragPage.ScrollingEnabled = true end end)
	W.dragPage, W.dragging, W.dragInput, W.windowDrag, W.windowResize, W.radarDrag = nil, nil, nil, nil, nil, nil
	W.touchInputUp, W.touchInputDown = nil, nil
	pcall(function() CAS:UnbindAction("FUSION6_Freecam") end)
	pcall(function() CAS:UnbindAction("W_FreecamSink") end)
	pcall(W.stopFlyRig)
	for motor, base in pairs(W.ugJoints or {}) do pcall(function() if motor.Parent then motor.C0 = base end end) end
	W.ugJoints = nil
	pcall(W.setBody, false)
	if W.kar then
		pcall(W.kar.releaseApproach)
		pcall(W.kar.releaseCursor)
		if hard then pcall(W.kar.clearTracking) end
	end
	pcall(W.restoreCamera)
	if underground then
		pcall(function() if root and goal and not root.Anchored then root.CFrame = goal + Vector3.new(0, 3, 0) end end)
		W.noclip, W.ugWasNoclip = W.ugWasNoclip == true, nil
		if not W.noclip then pcall(W.restoreCollisions) end
	end
	if hard then
		W.speedLock, W.jumpOn, W.noclip, W.infJump, W.antiFling, W.clickTP = false, false, false, false, false, false
		if W.speedConn then pcall(function() W.speedConn:Disconnect() end) W.speedConn = nil end
		pcall(W.restoreSpeed)
		pcall(W.restoreJump)
		pcall(W.restoreCollisions)
		W.gravOn = false
		if W.gravBak then pcall(function() workspace.Gravity = W.gravBak end) W.gravBak = nil end
		pcall(W.syncOff, {"Custom Gravity"})
		pcall(W.closeInput)
		pcall(W.syncOff, {"Aim Assist", "ADV Center Cursor", "Lock Walkspeed", "Custom Jump", "Noclip", "Infinite Jump", "Anti-Fling", "Click Teleport", "Tool Trigger", "Bunny Hop", "Fallback Controls"})
	end
	pcall(W.syncOff, {"Fly", "Follow", "Orbit Target", "Free Cam", "Camera Lock", "Spectate Target", "Hold-Jump Float", "Approach Assist", "Stalk Under Target", "Backstab Sweep"})
	W.releasingMovement = false
	if reason then W.lastRelease = reason pcall(setStatus, reason) end
end


function W.manualMovementHeld()
	if UIS:GetFocusedTextBox() then return false end
	for _, code in ipairs({Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right}) do
		if UIS:IsKeyDown(code) then return true end
	end
	if UIS.GamepadEnabled then
		local ok, inputs = pcall(function() return UIS:GetGamepadState(Enum.UserInputType.Gamepad1) end)
		if ok then for _, item in ipairs(inputs) do if item.KeyCode == Enum.KeyCode.Thumbstick1 and Vector2.new(item.Position.X, item.Position.Y).Magnitude > 0.15 then return true end end end
	end
	if UIS.TouchEnabled then local h = getHum(player) if h and h.MoveDirection.Magnitude > 0.1 then return true end end
	return false
end


function W.checkManualOverride()
	if not W.manualOverride or os.clock() < W.manualGraceUntil then return end
	if (W.follow or W.orbit or W.macroPlay or W.ugState ~= "SURFACE") and W.manualMovementHeld() then
		W.releaseMovement("Manual movement / automatic movement stopped", false)
	end
end

function W.emergencyRelease()
	W.windowFocused = true
	local ok, report = pcall(W.diagnostics)
	W.lastRecoveryReport = ok and report or tostring(report)
	W.releasingMovement = false
	local released, err = pcall(W.releaseMovement, "Stopped owned tools. F7 offers fallback controls.", true)
	W.fly, W.freecam, W.camLock, W.spectate, W.follow, W.orbit, W.macroPlay, W.macroRec, W.float = false, false, false, false, false, false, false, false, false
	W.ugState, W.ugFollow = "SURFACE", false
	if W.kar then W.kar.enabled, W.kar.approachOn = false, false pcall(W.kar.clearTracking) end
	if W.vector then W.vector.trigger, W.vector.bunnyHop = false, false pcall(W.vector.releaseTool) end
	if W.auto then W.auto.running = false pcall(W.auto.releaseMouse) end
	pcall(W.stopFallback)
	pcall(W.stopFlyRig)
	pcall(W.restoreCamera)
	pcall(W.restoreSpeed)
	pcall(W.restoreJump)
	pcall(W.restoreCollisions)
	pcall(W.closeInput)
	pcall(function() CAS:UnbindAction("FUSION6_Freecam") end)
	W.releasingMovement = false
	if not released then pcall(W.reportError, "Recovery", err) end
	print("[FUSION 6 / before stop]\n" .. W.lastRecoveryReport)
	pcall(function() flash("Owned tools stopped. F7: optional fallback controller.", C.good) end)
end


function W.stopMotion(except)
	if W.fallback and W.fallback.on and except ~= "fallback" then W.stopFallback() end
	if W.auto and W.auto.running and except ~= "Auto" then W.auto.stop("Another movement tool started", false) end
	W.manualGraceUntil = os.clock() + 0.25
	if except ~= "approach" then W.setToggle("Approach Assist", false) end
	if except ~= "camera" then W.setToggle("Free Cam", false) end
	if except ~= "float" then W.setToggle("Hold-Jump Float", false) end
	for _, name in ipairs({"Fly", "Follow", "Orbit Target"}) do
		if name ~= except then W.setToggle(name, false) end
	end
	if except ~= "macro" and W.macroPlay then
		W.macroPlay = false
		W.setBody(false)
	end
	if except ~= "underground" and W.ugState ~= "SURFACE" and W.surfaceNow then W.surfaceNow() end
end
function W.clearTarget()
	for _, name in ipairs({"Follow", "Orbit Target", "Camera Lock", "Spectate Target", "Stalk Under Target"}) do W.setToggle(name, false) end
	W.target = nil
	if W.ui.targetLbl then
		W.ui.targetLbl.Text = "Select a player below"
		W.ui.targetLbl.TextColor3 = C.dim
	end
	if W.rebuildPlayers then W.rebuildPlayers() end
end
function W.requireTarget(toggleName)
	if W.target and allowed(W.target) and getRoot(W.target) then return true end
	if W.toggles[toggleName] then W.toggles[toggleName].Set(false, true) end
	flash("Select a living player first.", C.warn)
	return false
end
function W.captureCamera()
	camera = workspace.CurrentCamera or camera
	if W.cameraBak then W.restoreCamera() end
	W.cameraBak = {camera = camera, CameraType = camera.CameraType, CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame, Focus = camera.Focus, MouseBehavior = UIS.MouseBehavior, MouseIconEnabled = UIS.MouseIconEnabled}
	W.cameraOwned = true
end
function W.restoreCamera()
	local bak = W.cameraBak
	W.cameraBak, W.cameraOwned = nil, false
	pcall(function() CAS:UnbindAction("FUSION6_Freecam") end)
	W.freecamSinkOwned = false
	if not bak then return end
	local owned = bak.camera
	if owned and owned.Parent then
		pcall(function() if bak.lastType and owned.CameraType == bak.lastType then owned.CameraType = bak.CameraType end end)
		pcall(function() if bak.lastSubject and owned.CameraSubject == bak.lastSubject and bak.CameraSubject and bak.CameraSubject.Parent then owned.CameraSubject = bak.CameraSubject end end)
		if bak.CameraType == Enum.CameraType.Scriptable and bak.lastFrame and owned.CFrame == bak.lastFrame then
			pcall(function() owned.CFrame, owned.Focus = bak.CFrame, bak.Focus end)
		end
	end
	pcall(function() if bak.mouseClaimed and UIS.MouseBehavior == bak.lastMouse then UIS.MouseBehavior = bak.MouseBehavior end end)
	pcall(function() if bak.iconClaimed and UIS.MouseIconEnabled == bak.lastIcon then UIS.MouseIconEnabled = bak.MouseIconEnabled end end)
end
function W.ownCameraType(value)
	if not W.cameraBak or W.cameraBak.camera ~= camera then return end
	if camera.CameraType ~= value then camera.CameraType = value end
	W.cameraBak.lastType = value
end
function W.ownCameraFrame(value)
	if not W.cameraBak or W.cameraBak.camera ~= camera then return end
	camera.CFrame = value
	W.cameraBak.lastFrame = value
end
function W.ownMouse(value)
	local bak = W.cameraBak
	if not bak then return end
	if UIS.MouseBehavior ~= value then UIS.MouseBehavior = value end
	bak.mouseClaimed, bak.lastMouse = true, value
end


function W.cameraMode(except)
	if W.auto and W.auto.running then W.auto.stop("Sweep stopped: another camera controller started", false) end
	if W.fallback and W.fallback.on then W.stopFallback() end
	for _, name in ipairs({"Free Cam", "Camera Lock", "Spectate Target", "Aim Assist"}) do
		if name ~= except then W.setToggle(name, false) end
	end
	if except ~= "Aim Assist" then W.setOpen(false) W.captureCamera() end
end
function W.teleport(cf, record)
	local root = getRoot(player)
	local hum = getHum(player)
	if not W.bodyAvailable("Teleport") then return false end
	hum.Sit = false
	if typeof(cf) ~= "CFrame" then return false end
	if cf.Position.Y < workspace.FallenPartsDestroyHeight + 10 then flash("That position is below the map limit.", C.warn) return false end
	W.stopMotion("teleport")
	if record ~= false then
		table.insert(W.teleportHistory, root.CFrame)
		if #W.teleportHistory > 20 then table.remove(W.teleportHistory, 1) end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = cf
	return true
end
function W.undoTeleport()
	local cf = W.teleportHistory[#W.teleportHistory]
	if not cf then flash("No teleport to undo yet.", C.warn) return end
	if W.teleport(cf, false) then
		table.remove(W.teleportHistory)
		setStatus("Returned to previous location")
	end
end
function W.captureWorld()
	if W.worldBak then return end
	W.worldBak = {}
	for _, key in ipairs({"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "FogColor", "FogStart", "FogEnd", "GlobalShadows", "ExposureCompensation"}) do
		W.worldBak[key] = Lighting[key]
	end
end
function W.restoreWorld()
	if W.vector.restoreVisuals then W.vector.restoreVisuals() end
	W.setToggle("Fullbright", false)
	if W.worldBak then
		for key, value in pairs(W.worldBak) do Lighting[key] = value end
		W.worldBak = nil
	end
	for atmo, density in pairs(W.atmoBak) do if atmo.Parent then atmo.Density = density end end
	W.atmoBak = setmetatable({}, {__mode = "k"})
end
function W.restoreSpeed()
	if W.speedConn then W.speedConn:Disconnect() W.speedConn = nil end
	for h, value in pairs(W.speedBak) do
		if h.Parent then h.WalkSpeed = value end
		W.speedBak[h] = nil
	end
end
function W.restoreJump()
	for h, bak in pairs(W.jumpBak) do
		if h.Parent then h.JumpPower = bak.JumpPower h.JumpHeight = bak.JumpHeight end
		W.jumpBak[h] = nil
	end
end
function W.applyJump()
	if not W.jumpOn or W.ugState ~= "SURFACE" then return end
	local h = getHum(player)
	if not h then return end
	if not W.jumpBak[h] then W.jumpBak[h] = {JumpPower = h.JumpPower, JumpHeight = h.JumpHeight} end
	if h.UseJumpPower then h.JumpPower = W.jumpPower else h.JumpHeight = W.jumpHeight end
end
function W.refreshMarkers()
	for _, marker in pairs(W.markers) do marker:Destroy() end
	W.markers = {}
	if not W.showMarkers then return end
	for i, cf in pairs(W.slots) do
		local part = W.new("Part", W.worldFolder, {
			Name = "Slot_" .. i, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.one, CFrame = cf,
		})
		local tag = W.new("BillboardGui", part, {
			Adornee = part, Size = UDim2.fromOffset(110, 32), AlwaysOnTop = true,
			MaxDistance = 3000, StudsOffset = Vector3.new(0, 2, 0),
		})
		local txt = label(tag, "SLOT " .. string.format("%02d", i), 12, C.accent, true)
		txt.Size = UDim2.fromScale(1, 1)
		txt.TextXAlignment = Enum.TextXAlignment.Center
		txt.BackgroundColor3 = C.bg
		txt.BackgroundTransparency = 0.15
		corner(txt, 8)
		stroke(txt, C.accent, 1, 0.4)
		W.markers[i] = part
	end
end

function W.applySpeed()
	if not W.speedLock or W.ugState ~= "SURFACE" or (W.kar and W.kar.approachBody) then return end
	local h = getHum(player)
	if not h then return end
	if W.speedBak[h] == nil then W.speedBak[h] = h.WalkSpeed end
	if h.WalkSpeed == W.speedVal then return end
	W.speedBusy = true
	h.WalkSpeed = W.speedVal
	W.speedBusy = false
end
function W.hookSpeed()
	if W.speedConn then W.speedConn:Disconnect() W.speedConn = nil end
	if not W.speedLock then return end
	local h = getHum(player)
	if not h then return end
	if W.speedBak[h] == nil then W.speedBak[h] = h.WalkSpeed end
	W.speedConn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if W.running and not W.speedBusy then W.applySpeed() end
	end)
	W.applySpeed()
end

local function applyGravity()
	if W.gravOn then
		if not W.gravBak then W.gravBak = workspace.Gravity end
		workspace.Gravity = W.grav
	elseif W.gravBak then
		workspace.Gravity = W.gravBak
		W.gravBak = nil
	end
end

function W.updateCollisions()
	if not W.noclip then return end
	local c = getChar(player)
	if not c then return end
	for _, part in ipairs(c:GetDescendants()) do
		if part:IsA("BasePart") then
			if W.collisionBak[part] == nil then W.collisionBak[part] = part.CanCollide end
			if part.CanCollide then part.CanCollide = false end
		end
	end
end

local hl = Instance.new("Highlight")
hl.FillColor = C.accent
hl.OutlineColor = Color3.new(1, 1, 1)
hl.FillTransparency = 0.75
hl.OutlineTransparency = 0
hl.Enabled = false
hl.Parent = W.worldFolder

local inspectOut

local function fullPath(obj)
	local parts = {}
	local cur = obj
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, ".")
end

local function inspectPart(part)
	if not part or not part:IsA("BasePart") then return end

	W.inspected = part
	hl.Adornee = part
	hl.Enabled = true

	local owner = Players:GetPlayerFromCharacter(part.Parent)
	local lines = {
		"PATH   " .. fullPath(part),
		"",
		"CLASS  " .. part.ClassName,
		"NAME   " .. part.Name,
		"SIZE   " .. string.format("%.2f, %.2f, %.2f", part.Size.X, part.Size.Y, part.Size.Z),
		"POS    " .. string.format("%.1f, %.1f, %.1f", part.Position.X, part.Position.Y, part.Position.Z),
		"MAT    " .. part.Material.Name,
		"COLLIDE " .. tostring(part.CanCollide),
		"ANCHOR " .. tostring(part.Anchored),
		"TRANSP " .. string.format("%.2f", part.Transparency),
		"COLOR  " .. string.format("%d, %d, %d",
			math.floor(part.Color.R * 255),
			math.floor(part.Color.G * 255),
			math.floor(part.Color.B * 255)),
	}

	if owner then
		table.insert(lines, "")
		table.insert(lines, "BELONGS TO  " .. owner.Name)
	end

	local txt = table.concat(lines, "\n")

	if inspectOut then
		inspectOut.Text = txt
		inspectOut.TextColor3 = C.text
	end

	setStatus("inspected " .. part.Name)
end

local BONES_R15 = {
	{"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local LIMBS_R6 = {"Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
local MAX_BONES = 14

local function drawLine(col)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = col
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = 2
	f.Parent = drawLayer
	return f
end

local function placeLine(f, ax, ay, bx, by, th)
	local dx, dy = bx - ax, by - ay
	f.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
	f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), th)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.Visible = true
end

local function project(pos)
	local v, on = camera:WorldToViewportPoint(pos)
	return v.X, v.Y, v.Z > 0.1
end

local function makeRig(p)
	local r = {}

	r.bb = Instance.new("BillboardGui")
	r.bb.Size = UDim2.fromOffset(150, 46)
	r.bb.StudsOffset = Vector3.new(0, 3.2, 0)
	r.bb.AlwaysOnTop = true
	r.bb.MaxDistance = 5000
	r.bb.Parent = hud

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(0, 0, 0)
	card.BackgroundTransparency = 0.35
	card.BorderSizePixel = 0
	card.Parent = r.bb
	corner(card, 5)
	r.cardStroke = stroke(card, C.accent, 1)

	r.name = label(card, p.DisplayName, 11, C.text, true)
	r.name.Position = UDim2.new(0, 6, 0, 2)
	r.name.Size = UDim2.new(1, -12, 0, 13)
	r.name.TextXAlignment = Enum.TextXAlignment.Center

	local hpbg = Instance.new("Frame")
	hpbg.Size = UDim2.new(1, -12, 0, 4)
	hpbg.Position = UDim2.new(0, 6, 0, 18)
	hpbg.BackgroundColor3 = Color3.fromRGB(60, 53, 45)
	hpbg.BorderSizePixel = 0
	hpbg.Parent = card
	corner(hpbg, 2)
	r.hpbg = hpbg

	r.hp = Instance.new("Frame")
	r.hp.Size = UDim2.fromScale(1, 1)
	r.hp.BackgroundColor3 = C.good
	r.hp.BorderSizePixel = 0
	r.hp.Parent = hpbg
	corner(r.hp, 2)

	r.info = label(card, "", 9, C.dim)
	r.info.Position = UDim2.new(0, 6, 0, 26)
	r.info.Size = UDim2.new(1, -12, 0, 16)
	r.info.TextXAlignment = Enum.TextXAlignment.Center

	r.box = Instance.new("Frame")
	r.box.BackgroundTransparency = 1
	r.box.BorderSizePixel = 0
	r.box.Visible = false
	r.box.ZIndex = 2
	r.box.Parent = drawLayer
	r.boxStroke = stroke(r.box, C.accent, 1.5)

	r.barBg = Instance.new("Frame")
	r.barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	r.barBg.BackgroundTransparency = 0.25
	r.barBg.BorderSizePixel = 0
	r.barBg.Visible = false
	r.barBg.ZIndex = 2
	r.barBg.Parent = drawLayer

	r.bar = Instance.new("Frame")
	r.bar.BackgroundColor3 = C.good
	r.bar.BorderSizePixel = 0
	r.bar.ZIndex = 3
	r.bar.Parent = r.barBg

	r.arrow = label(drawLayer, "^", 23, C.accent, true)
	r.arrow.Size, r.arrow.AnchorPoint = UDim2.fromOffset(26, 26), Vector2.new(0.5, 0.5)
	r.arrow.TextXAlignment, r.arrow.Visible, r.arrow.ZIndex = Enum.TextXAlignment.Center, false, 12
	r.tracer = drawLine(C.accent)
	r.tracer.BackgroundTransparency = 0.2

	r.bones = {}
	for i = 1, MAX_BONES do
		r.bones[i] = drawLine(Color3.new(1, 1, 1))
	end

	r.glow = W.new("Highlight", W.worldFolder, {
		Name = "WRAITH_" .. p.UserId, Enabled = false, FillColor = C.accent,
		OutlineColor = C.accent, FillTransparency = 0.82, OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	})
	W.rigs[p] = r
	return r
end

local function hideRig(r)
	if r.arrow then r.arrow.Visible = false end
	if r.glow then r.glow.Enabled = false end
	r.bb.Enabled = false
	r.box.Visible = false
	r.barBg.Visible = false
	r.tracer.Visible = false
	for _, b in ipairs(r.bones) do b.Visible = false end
end

local function killRig(p)
	local r = W.rigs[p]
	if not r then return end
	if r.arrow then r.arrow:Destroy() end
	if r.glow then r.glow:Destroy() end
	r.bb:Destroy()
	r.box:Destroy()
	r.barBg:Destroy()
	r.tracer:Destroy()
	for _, b in ipairs(r.bones) do b:Destroy() end
	W.rigs[p] = nil
end

local function toolsText(p)
	local c = getChar(p)
	local bp = p:FindFirstChildOfClass("Backpack")
	local names = {}
	if c then
		for _, o in ipairs(c:GetChildren()) do
			if o:IsA("Tool") then table.insert(names, "[" .. o.Name .. "]") end
		end
	end
	if bp then
		for _, o in ipairs(bp:GetChildren()) do
			if o:IsA("Tool") then table.insert(names, o.Name) end
		end
	end
	return #names > 0 and table.concat(names, ", ") or "no tools"
end

local function updateESP()
	local anyOn = W.espNames or W.espBox or W.espBones or W.espBar or W.espTracer or W.espGlow or W.lowHp or W.vector.arrows
	local myRoot = getRoot(player)
	local vp = camera.ViewportSize
	for _, rig in pairs(W.rigs) do hideRig(rig) end

	if W.hiddenHUD or not anyOn or not myRoot then
		for _, r in pairs(W.rigs) do hideRig(r) end
		return
	end

	for p, r in pairs(W.rigs) do
		if p.Parent == nil then killRig(p) end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if allowed(p) and (not W.espOnly or p == W.target) then
			local c    = getChar(p)
			local h    = getHum(p)
			local root = getRoot(p)

			if c and h and root and (root.Position - myRoot.Position).Magnitude <= (W.espMaxDistance or 1500)
				and not (W.espTeamCheck and W.vector.sameTeam(p))
				and (W.vector.throughWalls or W.kar.canSee(root)) then
				local r = W.rigs[p] or makeRig(p)
				local dist = (root.Position - myRoot.Position).Magnitude
				local ratio = h.MaxHealth > 0 and math.clamp(h.Health / h.MaxHealth, 0, 1) or 0

				local col
				if dist < 50 then col = C.bad
				elseif dist < 150 then col = C.warn
				else col = C.good end
				if W.vector.teamColors and p.Team and not p.Neutral then col = p.Team.TeamColor.Color end
				if p == W.target then col = C.accent end
				r.bb.AlwaysOnTop = W.vector.throughWalls
				r.glow.DepthMode = W.vector.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
				if W.vector.arrows then W.vector.drawArrow(r.arrow, root, col) end
				r.glow.Adornee = c
				r.glow.FillColor = col
				r.glow.OutlineColor = col
				r.glow.Enabled = W.espGlow == true

				if W.lowHp and ratio * 100 <= W.lowHpPct then
					local last = W.lastAlert[p] or 0
					if os.clock() - last > 6 then
						W.lastAlert[p] = os.clock()
						flash(string.format("LOW HP  -  %s  (%d%%)  %d st",
							p.DisplayName, math.floor(ratio * 100), math.floor(dist)), C.warn)
					end
				elseif ratio * 100 > W.lowHpPct then
					W.lastAlert[p] = nil
				end

				r.bb.Enabled = W.espNames
				if W.espNames then
					r.bb.Adornee = root
					r.cardStroke.Color = col
					r.name.TextColor3 = col
					r.name.Text = (W.kar.teammates[p.UserId] and "[MATE] " or "") .. p.DisplayName
					r.name.Parent.BackgroundTransparency = W.kar.espTransparency
					r.hpbg.Visible = W.espHp
					r.hp.Size = UDim2.fromScale(ratio, 1)
					r.hp.BackgroundColor3 = Color3.fromRGB(
						math.floor(200 * (1 - ratio)) + 55,
						math.floor(190 * ratio) + 40, 90)

					local bits = {}
					if W.espDist then table.insert(bits, math.floor(dist) .. " st") end
					if W.vector.healthText then table.insert(bits, math.floor(h.Health) .. "hp") end
					if W.espTools then table.insert(bits, toolsText(p)) end
					r.info.Text = table.concat(bits, "  |  ")
				end

				local ok, cf, size = false, nil, nil
				if W.espBox or W.espBones or W.espBar or W.espTracer then ok, cf, size = pcall(c.GetBoundingBox, c) end
				local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
				local seen = false

				if ok then
					for x = -1, 1, 2 do
						for y = -1, 1, 2 do
							for z = -1, 1, 2 do
								local pt = cf:PointToWorldSpace(
									Vector3.new(size.X / 2 * x, size.Y / 2 * y, size.Z / 2 * z))
								local sx, sy, front = project(pt)
								if front then
									seen = true
									minX = math.min(minX, sx) minY = math.min(minY, sy)
									maxX = math.max(maxX, sx) maxY = math.max(maxY, sy)
								end
							end
						end
					end
				end

				if seen and maxX > 0 and maxY > 0 and minX < vp.X and minY < vp.Y and maxX - minX < vp.X * 3 and maxY - minY < vp.Y * 3 then
					local bw, bh = maxX - minX, maxY - minY

					if W.espBox then
						r.box.Position = UDim2.fromOffset(minX, minY)
						r.box.Size = UDim2.fromOffset(bw, bh)
						r.boxStroke.Color = col
						r.box.Visible = true
					else
						r.box.Visible = false
					end

					if W.espBar then
						r.barBg.Position = UDim2.fromOffset(minX, maxY + 3)
						r.barBg.Size = UDim2.fromOffset(bw, 4)
						r.bar.Size = UDim2.new(ratio, 0, 1, 0)
						r.barBg.Visible = true
					else
						r.barBg.Visible = false
					end

					if W.espTracer then
						r.tracer.BackgroundColor3 = col
						local origin = W.vector.tracerPoint()
						placeLine(r.tracer, origin.X, origin.Y, minX + bw / 2, maxY, 1)
					else
						r.tracer.Visible = false
					end

					if W.espBones then
						local n = 0
						if h.RigType == Enum.HumanoidRigType.R15 then
							for _, pair in ipairs(BONES_R15) do
								local a, b = c:FindFirstChild(pair[1]), c:FindFirstChild(pair[2])
								if a and b then
									local ax, ay, af = project(a.Position)
									local bx, by, bf = project(b.Position)
									if af and bf then
										n = n + 1
										placeLine(r.bones[n], ax, ay, bx, by, 1.5)
									end
								end
							end
						else
							for _, nm in ipairs(LIMBS_R6) do
								local part = c:FindFirstChild(nm)
								if part and part:IsA("BasePart") then
									local top = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2, 0))
									local bot = part.CFrame:PointToWorldSpace(Vector3.new(0, -part.Size.Y / 2, 0))
									local ax, ay, af = project(top)
									local bx, by, bf = project(bot)
									if af and bf then
										n = n + 1
										placeLine(r.bones[n], ax, ay, bx, by, 1.5)
									end
								end
							end
						end
						for i = n + 1, MAX_BONES do r.bones[i].Visible = false end
					else
						for _, b in ipairs(r.bones) do b.Visible = false end
					end
				else
					r.box.Visible = false
					r.barBg.Visible = false
					r.tracer.Visible = false
					for _, b in ipairs(r.bones) do b.Visible = false end
				end
			end
		elseif W.rigs[p] then
			hideRig(W.rigs[p])
		end
	end
end

local radar = Instance.new("Frame")
radar.Size = UDim2.fromOffset(W.radarSize, W.radarSize)
radar.AnchorPoint = Vector2.new(0.5, 0.5)
radar.Position = UDim2.new(1, -125, 1, -155)
radar.BackgroundColor3 = Color3.new(0, 0, 0)
radar.BackgroundTransparency = 0.65
radar.BorderSizePixel = 0
radar.Visible = false
radar.Active = true
W.ui.radar = radar
radar.ZIndex = 20
radar.Parent = hud
local radarCorner = corner(radar, W.radarSize / 2)
stroke(radar, C.accent, 1)

local function ring(scale, tr)
	local r = Instance.new("Frame")
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromScale(0.5, 0.5)
	r.Size = UDim2.fromScale(scale, scale)
	r.BackgroundTransparency = 1
	r.ZIndex = 21
	r.Parent = radar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = r
	stroke(r, C.accent, 1, tr)
end

ring(0.66, 0.75)
ring(0.33, 0.82)

local sweep = Instance.new("Frame")
sweep.AnchorPoint = Vector2.new(0, 0.5)
sweep.Position = UDim2.fromScale(0.5, 0.5)
sweep.Size = UDim2.new(0.5, 0, 0, 1)
sweep.BackgroundColor3 = C.accent
sweep.BackgroundTransparency = 0.5
sweep.BorderSizePixel = 0
sweep.ZIndex = 21
sweep.Parent = radar

local me = Instance.new("Frame")
me.AnchorPoint = Vector2.new(0.5, 0.5)
me.Position = UDim2.fromScale(0.5, 0.5)
me.Size = UDim2.fromOffset(6, 6)
me.BackgroundColor3 = Color3.new(1, 1, 1)
me.BorderSizePixel = 0
me.ZIndex = 23
me.Parent = radar
corner(me, 3)

local rangeLbl = label(radar, "", 9, C.dim, true)
rangeLbl.AnchorPoint = Vector2.new(0.5, 0)
rangeLbl.Position = UDim2.new(0.5, 0, 1, -16)
rangeLbl.Size = UDim2.fromOffset(80, 14)
rangeLbl.TextXAlignment = Enum.TextXAlignment.Center
rangeLbl.ZIndex = 22

local function updateRadar(dt)
	if not W.radar or W.hiddenHUD then radar.Visible = false return end
	radar.Visible = true
	local myRoot = getRoot(player)
	for _, dot in pairs(W.dots) do dot.Visible = false end
	if not myRoot then return end

	sweep.Rotation = (sweep.Rotation + dt * 90) % 360
	rangeLbl.Text = W.radarRng .. " st"
	local rad = W.radarSize / 2 - 8

	for _, p in ipairs(Players:GetPlayers()) do
		if allowed(p) and not (W.espTeamCheck and W.vector.sameTeam(p)) then
			local root = getRoot(p)
			if root then
				local delta = root.Position - myRoot.Position
				local facing = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
				if facing.Magnitude < 0.001 then facing = Vector3.new(0, 0, -1) else facing = facing.Unit end
				local right = Vector3.new(-facing.Z, 0, facing.X)
				local rel = Vector3.new(delta:Dot(right), delta.Y, -delta:Dot(facing))
				local flat = Vector2.new(rel.X, rel.Z)
				local d = flat.Magnitude

				local dot = W.dots[p]
				if not dot then
					dot = Instance.new("Frame")
					dot.AnchorPoint = Vector2.new(0.5, 0.5)
					dot.Size = UDim2.fromOffset(7, 7)
					dot.BorderSizePixel = 0
					dot.ZIndex = 24
					dot.Parent = radar
					corner(dot, 4)
					W.dots[p] = dot
				end

				if d <= W.radarRng then
					local a = d / W.radarRng
					local dir = d > 0.01 and flat.Unit or Vector2.zero
					dot.Visible = true
					dot.Position = UDim2.new(0.5, dir.X * a * rad, 0.5, dir.Y * a * rad)

					local real = (root.Position - myRoot.Position).Magnitude
					if real < 50 then dot.BackgroundColor3 = C.bad
					elseif real < 150 then dot.BackgroundColor3 = C.warn
					else dot.BackgroundColor3 = C.good end

					local sz = 7
					if rel.Y > 6 then sz = 10 elseif rel.Y < -6 then sz = 5 end
					dot.Size = UDim2.fromOffset(sz, sz)
				else
					dot.Visible = false
				end
			end
		elseif W.dots[p] then
			W.dots[p].Visible = false
		end
	end
end

local function pushBright()
	W.captureWorld()
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(178, 178, 178)
	Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	for _, atmo in ipairs(Lighting:GetChildren()) do
		if atmo:IsA("Atmosphere") then
			if W.atmoBak[atmo] == nil then W.atmoBak[atmo] = atmo.Density end
			atmo.Density = 0
		end
	end
end
local function setBright(on)
	if on then
		W.vector.releaseOwner("fog")
		W.vector.releaseOwner("clock")
		W.captureWorld()
		if not W.lightBak then
			W.lightBak = {}
			for _, key in ipairs({"Brightness", "ClockTime", "FogEnd", "GlobalShadows", "Ambient", "OutdoorAmbient"}) do W.lightBak[key] = Lighting[key] end
		end
		pushBright()
	elseif W.lightBak then
		for key, value in pairs(W.lightBak) do Lighting[key] = value end
		W.lightBak = nil
		for atmo, density in pairs(W.atmoBak) do if atmo.Parent then atmo.Density = density end end
		W.atmoBak = setmetatable({}, {__mode = "k"})
	end
end

local function startFreecam()
	W.setOpen(false)
	W.cameraMode("Free Cam")
	W.stopMotion("camera")
	W.freecam = true
	local look = camera.CFrame.LookVector
	W.fcYaw, W.fcPitch = math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
	W.fcPos, W.fcVelocity = camera.CFrame.Position, Vector3.zero
	W.ownCameraType(Enum.CameraType.Scriptable)
	W.ownMouse(Enum.MouseBehavior.LockCenter)
	W.freecamSinkOwned = true
	CAS:BindActionAtPriority("FUSION6_Freecam", function()
		if W.running and W.freecam and not W.open then return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward, Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump)
end
local function stopFreecam()
	W.freecam = false
	W.fcVelocity = Vector3.zero
	W.restoreCamera()
end


local pMove = W.pages.Movement

heading(pMove, "flight")
toggle(pMove, "Fly", "WASD / arrows to move. Space or E up; Shift or Q down.", function(v)
	if v then return W.startFlight() end
	W.stopFlight("Flight off / normal movement restored")
	return true
end)
W.ui.flightStatus = label(pMove, "FLIGHT OFF\nStarting flight closes the panel so movement input stays available.", 12, C.dim, false)
W.ui.flightStatus.Size = UDim2.new(1, 0, 0, 76)
W.ui.flightStatus.TextWrapped = true
W.ui.flightStatus.TextTruncate = Enum.TextTruncate.None
W.ui.flightStatus.ZIndex = 102
ord(W.ui.flightStatus)

slider(pMove, "Fly Speed", 10, 400, W.flySpeed, 0, function(v) W.flySpeed = v end)

heading(pMove, "ground")
toggle(pMove, "Lock Walkspeed", "Maintains your selected walk speed.", function(v)
	W.speedLock = v
	if v then W.hookSpeed() W.applySpeed()
	else W.restoreSpeed() end
	setStatus(v and ("speed locked at " .. W.speedVal) or "speed lock off")
end)
slider(pMove, "Walk Speed", 1, 250, W.speedVal, 0, function(v)
	W.speedVal = v
	W.applySpeed()
end)
toggle(pMove, "Noclip", "Collision bypass for local playtesting.", function(v)
	if not v and W.ugState ~= "SURFACE" and W.surfaceNow then W.surfaceNow() end
	W.noclip = v
	if not v then W.restoreCollisions() end
end)
toggle(pMove, "Infinite Jump", "Allows another jump while airborne.", function(v) W.infJump = v end)
toggle(pMove, "Hold-Jump Float", "Hold Space to rise. Stops other movement modes.", function(v) if v then W.stopMotion("float") end W.float = v end)
slider(pMove, "Float Power", 5, 180, W.floatPow, 0, function(v) W.floatPow = v end)
toggle(pMove, "Click Teleport", "Click a surface outside this panel.", function(v) if v then W.setToggle("Inspect Mode", false) end W.clickTP = v end)

heading(pMove, "physics")
toggle(pMove, "Custom Gravity", "Local gravity override.", function(v)
	W.gravOn = v
	applyGravity()
end)
slider(pMove, "Gravity", 0, 300, W.grav, 0, function(v)
	W.grav = v
	applyGravity()
end)
toggle(pMove, "Anti-Fling", "Limits sudden physics velocity spikes.", function(v) W.antiFling = v end)

do
	local K = W.kar

	function K.count(values)
		local n = 0
		for _ in pairs(values) do n = n + 1 end
		return n
	end

	function K.releaseCursor()
		if K.cursorBackup ~= nil then
			local previous = K.cursorBackup
			K.cursorBackup = nil
			if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then UIS.MouseBehavior = previous end
		end
	end

	function K.releaseApproach()
		local body = K.approachBody
		K.approachBody = nil
		if body and body.hum and body.hum.Parent then
			if not W.manualMovementHeld() then body.hum:Move(Vector3.zero, false) end
			body.hum.WalkSpeed = body.speed
			W.applySpeed()
		end
	end

	function K.watchTarget(p)
		local hum = p and getHum(p)
		if K.hitTarget == p and K.hitHum == hum and (K.hitConn or not K.hitTrackerOn) then return end
		if K.hitConn then K.hitConn:Disconnect() K.hitConn = nil end
		K.hitTarget, K.hitHum = p, hum
		if not K.hitTrackerOn or not hum then return end
		local lastHealth = hum.Health
		K.hitConn = hum.HealthChanged:Connect(function(newHealth)
			local damage = lastHealth - newHealth
			lastHealth = newHealth
			if not W.running or not K.hitTrackerOn or damage <= 0 then return end
			if os.clock() - K.lastFireTime <= K.hitWindow then
				K.hitCount = K.hitCount + 1
				K.hitDamage = K.hitDamage + damage
				K.lastHit = string.format("Possible hit: %s / %.0f damage%s", p.DisplayName, damage, damage >= K.hyperDamage and " / high damage" or "")
				if damage >= K.hyperDamage then beep(1.8) end
			else
				K.lastHit = string.format("Observed damage: %s / %.0f / no recent shot", p.DisplayName, damage)
			end
			W.log(K.lastHit, "HIT ESTIMATE")
		end)
	end

	function K.clearTracking()
		W.vector.velocity, W.vector.targetRoot = Vector3.zero, nil
		K.currentPart, K.currentPlayer, K.predictedPosition = nil, nil, nil
		K.lastConf = 0
		K.watchTarget(nil)
		K.releaseCursor()
		K.releaseApproach()
		if K.predOrb then K.predOrb:Destroy() K.predOrb = nil end
	end

	function K.clearSquad()
		for id in pairs(K.teammates) do K.blacklist[id] = nil end
		K.teammates = {}
		K.teamSize = 0
		K.teamPicking = false
		if W.sliders["Squad Size"] then W.sliders["Squad Size"].Set(0) end
		if W.rebuildPlayers then W.rebuildPlayers() end
	end

	function K.setSquadSize(value)
		K.teamSize = math.clamp(math.floor(value), 0, 6)
		if K.teamSize == 0 then
			for id in pairs(K.teammates) do K.blacklist[id] = nil end
			K.teammates = {}
		else
			local ids = {}
			for id in pairs(K.teammates) do table.insert(ids, id) end
			table.sort(ids)
			for i = K.teamSize + 1, #ids do K.teammates[ids[i]] = nil end
		end
		K.teamPicking = K.count(K.teammates) < K.teamSize
		if W.rebuildPlayers then W.rebuildPlayers() end
	end

	function K.toggleSkip(p)
		if not p or p == player then return end
		local id = p.UserId
		if K.blacklist[id] then
			K.blacklist[id], K.teammates[id] = nil, nil
		else
			K.blacklist[id] = true
			if K.count(K.teammates) < K.teamSize then K.teammates[id] = p.DisplayName end
			if K.currentPlayer == p then K.clearTracking() end
		end
		K.teamPicking = K.count(K.teammates) < K.teamSize
		if W.rebuildPlayers then W.rebuildPlayers() end
	end

	function K.isAllowed(p)
		if not allowed(p) or K.blacklist[p.UserId] then return false end
		if K.selectedOnly and p ~= W.target then return false end
		if K.teamCheck and W.vector.sameTeam(p) then return false end
		local char, hum, root = getChar(p), getHum(p), getRoot(p)
		if not char or not hum or hum.Health <= 0 or not root then return false end
		if W.vector.shieldCheck and char:FindFirstChildOfClass("ForceField") then return false end
		local originRoot = getRoot(player)
		if (root.Position - (originRoot and originRoot.Position or camera.CFrame.Position)).Magnitude > W.vector.distance then return false end
		return true
	end

	function K.canSee(part)
		local origin = camera.CFrame.Position
		local direction = part.Position - origin
		if direction.Magnitude < 0.001 then return true end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = {W.worldFolder}
		if player.Character then table.insert(excluded, player.Character) end
		params.FilterDescendantsInstances = excluded
		params.IgnoreWater = true
		local result = workspace:Raycast(origin, direction, params)
		return result == nil or result.Instance:IsDescendantOf(part.Parent)
	end

	function K.score(part, center, myRoot)
		local point, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or point.Z <= 0 then return nil end
		local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
		if K.mode ~= "Legacy" and distance > K.fov then return nil end
		if (K.mode == "Legacy" or K.wallCheck) and not K.canSee(part) then return nil end
		if K.mode == "Adv" and myRoot then return (part.Position - myRoot.Position).Magnitude end
		return distance
	end

	function K.getTarget()
		local center, myRoot = camera.ViewportSize / 2, getRoot(player)
		local best, bestPlayer, bestScore = nil, nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if K.isAllowed(p) then
				local char = getChar(p)
				local part = char and (char:FindFirstChild(K.part) or char:FindFirstChild("HumanoidRootPart"))
				if part and part:IsA("BasePart") then
					local score = K.score(part, center, myRoot)
					if score and score < bestScore then best, bestPlayer, bestScore = part, p, score end
				end
			end
		end
		local current, currentPlayer = K.currentPart, K.currentPlayer
		if best and current and best ~= current and current.Parent and currentPlayer and K.isAllowed(currentPlayer) then
			local score = K.score(current, center, myRoot)
			if score and bestScore > score * K.stickMargin then best, bestPlayer = current, currentPlayer end
		end
		if best ~= K.currentPart and W.debug then dbg("Aim: " .. (bestPlayer and bestPlayer.Name or "no target") .. " / " .. K.mode) end
		K.currentPart, K.currentPlayer = best, bestPlayer
		K.watchTarget(bestPlayer)
		return best, bestPlayer
	end

	function K.confidence(profile)
		local consistency = 1 - math.clamp(profile.jerk * 1.6, 0, 1)
		local samples = math.clamp(profile.samples / 250, 0, 1)
		local movementPenalty = math.clamp(profile.air * 0.5 + (profile.slides > 8 and 0.1 or 0) + (profile.djumps > 5 and 0.08 or 0), 0, 0.4)
		return math.clamp((0.15 + 0.55 * consistency + 0.30 * samples - movementPenalty) * K.calibration, 0.05, 0.99)
	end

	function K.predict(part, p)
		local position, response = part.Position, K.smooth
		K.lastConf = 0
		if K.mode ~= "Adv" then return position, response end
		local velocity = part.AssemblyLinearVelocity
		local lead = K.advLead * K.advAggression
		if K.projSpeed > 0 then lead = math.min((part.Position - camera.CFrame.Position).Magnitude / K.projSpeed * K.advAggression, 1.5) end
		local yScale, confidence = 0.8, 0.5
		local profile = p and K.profiles[p.UserId]
		if profile then
			lead = lead * (1 - math.clamp(profile.jerk * 1.2, 0, 0.75))
			if profile.air > 0.35 then yScale = 0.45 end
			confidence = K.confidence(profile)
		end
		K.lastConf = confidence
		return position + Vector3.new(velocity.X * lead, velocity.Y * lead * yScale, velocity.Z * lead), K.advSpeed * (0.6 + 0.4 * confidence)
	end

	function K.blockReason()
		if W.hotkeys and W.hotkeys.capture then return "BINDING HOTKEY" end
		if W.open then return "PANEL OPEN" end
		if W.auto and W.auto.running then return "AUTO CONTROLS AIM" end
		if not K.enabled then return "OFF" end
		if W.freecam or W.camLock or W.spectate then return "OTHER CAMERA MODE" end
		local hum = getHum(player)
		if not hum or hum.Health <= 0 then return "WAITING FOR CHARACTER" end
		local reason = W.inputBlockReason()
		if reason then return reason end
		if W.overUI(UIS:GetMouseLocation()) then return "POINTER OVER UI" end
		if K.activation == "RMB" and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) and not W.vector.holdKeyDown() then return "HOLD RMB / AIM HOLD KEY" end
		if K.activation == "Fire" and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return "HOLD LEFT MOUSE" end
		return nil
	end

	function K.makeOrb(name, size, transparency)
		return W.new("Part", W.worldFolder, {
			Name = name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size),
			Material = Enum.Material.Neon, Color = C.accent, Transparency = transparency,
		})
	end

	function K.updateAim(dt)
		if W.vector.engine == "VECTOR" then return W.vector.stepAim(dt) end
		K.fovCircle.Position = UDim2.fromScale(0.5, 0.5)
		K.state = K.blockReason()
		K.fovCircle.Visible = K.enabled and K.fovCircleOn and K.mode ~= "Legacy" and not W.hiddenHUD
		K.fovCircle.Size = UDim2.fromOffset(K.fov * 2, K.fov * 2)
		if K.state then K.clearTracking() return end
		local part, p = K.getTarget()
		if not part then K.state = "SEARCHING" K.clearTracking() return end
		K.state = "TRACKING"
		K.lastAimUserId, K.lastAimTime = p.UserId, os.clock()
		local position, response = K.predict(part, p)
		K.predictedPosition = position
		if (position - camera.CFrame.Position).Magnitude > 0.001 then
			local alpha = 1 - (1 - math.clamp(response, 0, 1)) ^ (math.clamp(dt, 0, 0.1) * 60)
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, position), alpha)
		end
		if K.mode == "Adv" and K.predDotOn and not W.hiddenHUD then
			if not K.predOrb or not K.predOrb.Parent then K.predOrb = K.makeOrb("PlatinumPrediction", 0.9, 0.25) end
			K.predOrb.Position, K.predOrb.Color = position, C.accent
		elseif K.predOrb then K.predOrb:Destroy() K.predOrb = nil end
		if K.mode == "Adv" and K.centerCursor and not W.open then
			if K.cursorBackup == nil then K.cursorBackup = UIS.MouseBehavior end
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		else K.releaseCursor() end
	end

	function K.stopAim()
		K.enabled = false
		K.clearTracking()
		K.state = "OFF"
		K.fovCircle.Visible = false
		W.setToggle("Approach Assist", false)
		W.setToggle("Aim Assist", false)
	end

	function K.updateApproach()
		if not K.approachOn or not K.enabled or K.state ~= "TRACKING" or W.fly or W.follow or W.orbit or W.macroPlay or W.float or W.ugState ~= "SURFACE" or W.freecam then
			K.releaseApproach()
			return
		end
		local hum, root, target = getHum(player), getRoot(player), K.currentPart
		if not hum or hum.Health <= 0 or not root or root.Anchored or hum.SeatPart or not target or not target.Parent then K.releaseApproach() return end
		if W.manualMovementHeld() then K.releaseApproach() return end
		local delta = target.Position - root.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude <= K.approachStop then K.releaseApproach() return end
		if not K.approachBody or K.approachBody.hum ~= hum then
			K.releaseApproach()
			K.approachBody = {hum = hum, speed = hum.WalkSpeed}
		end
		hum.WalkSpeed = K.approachSpeed
		hum:Move(flat.Unit, false)
	end

	function K.sampleProfiles(dt)
		K.calibration = math.min(K.calibration + dt * 0.02, 1.2)
		if not K.enabled then return end
		K.profT = K.profT + dt
		if K.profT < 0.12 then return end
		K.profT = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local hum, root = getHum(p), getRoot(p)
				local profile = K.profiles[p.UserId]
				if not profile then
					profile = {spd = 0, vspd = 0, jerk = 0, air = 0, jumps = 0, djumps = 0, slides = 0, slideFrames = 0, samples = 0, lastVelY = 0, wasAir = false, aliveWas = false}
					K.profiles[p.UserId] = profile
				end
				local aliveNow = hum ~= nil and hum.Health > 0
				if profile.aliveWas and not aliveNow and p.UserId == K.lastAimUserId and os.clock() - K.lastAimTime < 4 then K.calibration = math.min(K.calibration + 0.15, 1.2) end
				profile.aliveWas = aliveNow
				if aliveNow and root then
					if profile.root ~= root then profile.root, profile.lastH, profile.lastVelY, profile.wasAir = root, nil, 0, false end
					local velocity = root.AssemblyLinearVelocity
					local flat = Vector3.new(velocity.X, 0, velocity.Z)
					local airborne = hum.FloorMaterial == Enum.Material.Air
					profile.spd = profile.spd + (flat.Magnitude - profile.spd) * 0.12
					profile.vspd = profile.vspd + (math.abs(velocity.Y) - profile.vspd) * 0.12
					profile.air = profile.air + ((airborne and 1 or 0) - profile.air) * 0.08
					if airborne and not profile.wasAir and velocity.Y > 10 then profile.jumps = profile.jumps + 1 end
					if airborne and profile.wasAir and velocity.Y > 14 and profile.lastVelY < 4 then profile.djumps = profile.djumps + 1 end
					if not airborne and flat.Magnitude > math.max(24, hum.WalkSpeed * 1.35) then
						profile.slideFrames = profile.slideFrames + 1
						if profile.slideFrames == 2 then profile.slides = profile.slides + 1 end
					else profile.slideFrames = 0 end
					if flat.Magnitude > 3 and profile.lastH and profile.lastH.Magnitude > 3 then
						local dot = math.clamp(flat.Unit:Dot(profile.lastH.Unit), -1, 1)
						profile.jerk = profile.jerk + ((1 - dot) * 0.5 - profile.jerk) * 0.15
					end
					profile.lastH, profile.lastVelY, profile.wasAir = flat, velocity.Y, airborne
					profile.samples = profile.samples + 1
				end
			end
		end
	end

	function K.clearBeams()
		for p, rig in pairs(K.beams) do
			for _, obj in pairs(rig) do obj:Destroy() end
			K.beams[p] = nil
		end
		if K.beamOrigin then K.beamOrigin:Destroy() K.beamOrigin = nil end
	end

	function K.updateBeams()
		local root = getRoot(player)
		if not K.beamsOn or W.hiddenHUD or not root then K.clearBeams() return end
		if not K.beamOrigin or K.beamOrigin.Parent ~= root then
			K.clearBeams()
			K.beamOrigin = W.new("Attachment", root, {Name = "WRAITH_PlatinumBeamOrigin"})
		end
		local wanted = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local target = getRoot(p)
			if target and allowed(p) and (not W.espOnly or p == W.target)
				and not (W.espTeamCheck and W.vector.sameTeam(p))
				and (W.vector.throughWalls or K.canSee(target))
				and (target.Position - root.Position).Magnitude <= (W.espMaxDistance or 1500) then wanted[p] = target end
		end
		for p, rig in pairs(K.beams) do
			if not wanted[p] or rig.target.Parent ~= wanted[p] then
				rig.beam:Destroy() rig.target:Destroy() K.beams[p] = nil
			end
		end
		for p, target in pairs(wanted) do
			if not K.beams[p] then
				local attachment = W.new("Attachment", target, {Name = "WRAITH_PlatinumBeamTarget"})
				local beam = W.new("Beam", W.worldFolder, {
					Name = "PlatinumBeam", Attachment0 = K.beamOrigin, Attachment1 = attachment,
					Width0 = 0.06, Width1 = 0.03, FaceCamera = true, LightEmission = 0.9,
					Color = ColorSequence.new(C.text, C.accent), Transparency = NumberSequence.new(0.08),
				})
				K.beams[p] = {beam = beam, target = attachment}
			end
			K.beams[p].beam.Color = ColorSequence.new(C.text, C.accent)
			K.beams[p].beam.Color = ColorSequence.new(C.text, C.accent)
		end
	end

	function K.updateExtras()
		K.updateBeams()
		if K.cursorOrbOn and not W.hiddenHUD then
			if not K.cursorOrb or not K.cursorOrb.Parent then
				K.cursorOrb = K.makeOrb("PlatinumCursor", 0.55, 0.03)
				W.new("PointLight", K.cursorOrb, {Color = C.accent, Brightness = 1.8, Range = 9})
			end
			if mouse.Hit then K.cursorOrb.Position = mouse.Hit.Position + Vector3.new(0, 0.35, 0) end
			K.cursorOrb.Color = C.accent
		elseif K.cursorOrb then K.cursorOrb:Destroy() K.cursorOrb = nil end
		K.radarArrow.Visible, K.radarInfo.Visible = false, false
		if not K.radarOn or W.hiddenHUD then return end
		local root = getRoot(player)
		if not root then return end
		local nearest, distance = nil, math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local target = getRoot(p)
			if allowed(p) and target then
				local d = (target.Position - root.Position).Magnitude
				if d < distance then nearest, distance = p, d end
			end
		end
		local target = nearest and getRoot(nearest)
		if not target then return end
		local relative = camera.CFrame:PointToObjectSpace(target.Position)
		local angle = math.atan2(relative.X, -relative.Z)
		local radius = math.min(150, math.min(camera.ViewportSize.X, camera.ViewportSize.Y) * 0.27)
		K.radarArrow.Position = UDim2.new(0.5, math.sin(angle) * radius, 0.5, -math.cos(angle) * radius)
		K.radarArrow.Rotation = math.deg(angle)
		K.radarArrow.Visible = true
		K.radarInfo.Position = UDim2.new(0.5, 0, 0.5, radius + 28)
		K.radarInfo.Text = nearest.DisplayName .. "  /  " .. math.floor(distance) .. " studs"
		K.radarInfo.Visible = true
		if K.radarSound and distance <= K.radarPingRange and relative.Z > 0 and os.clock() - K.lastRadarPing > 2 then
			K.lastRadarPing = os.clock()
			local sound = W.new("Sound", Sound, {SoundId = "rbxassetid://12221967", Volume = 0.12, PlaybackSpeed = 1.6})
			sound:Play() Debris:AddItem(sound, 2)
		end
	end

	function K.refreshHUD()
		local targetName = K.currentPlayer and (K.currentPlayer.DisplayName .. " @" .. K.currentPlayer.Name) or "None"
		local description = K.mode == "Adv" and string.format("Movement confidence: %d%%", math.floor(K.lastConf * 100)) or "Prediction: inactive in this mode"
		if W.vector.engine == "VECTOR" then description = string.format("VECTOR / %s origin / %s priority / %.3fs lead", W.vector.origin, W.vector.priority, W.vector.lead) end
		local modeName = W.vector.engine == "VECTOR" and W.vector.mode or K.mode
		K.aimReadout.Text = string.format("%s  /  %s  /  %s\nTarget: %s\n%s", K.enabled and "ON" or "OFF", string.upper(modeName), K.state or "OFF", targetName, description)
		K.hitReadout.Text = string.format("Estimated hits: %d\nEstimated damage: %.0f\n%s\nClick timing is not server-confirmed hit attribution.", K.hitCount, K.hitDamage, K.lastHit)
		K.squadReadout.Text = string.format("Squad: %d / %d  |  Excluded: %d\nSet squad size, then use SKIP in Players to choose your teammates.", K.count(K.teammates), K.teamSize, K.count(K.blacklist))
		K.aimBadge.Visible = K.enabled and not W.open and not W.hiddenHUD
		K.aimBadge.Text = string.format("%s / %s / %s", W.vector.engine, string.upper(modeName), K.state or "OFF")
	end

	function K.exportSettings()
		local skipped, squad = {}, {}
		for id in pairs(K.blacklist) do table.insert(skipped, id) end
		for id in pairs(K.teammates) do table.insert(squad, id) end
		table.sort(skipped) table.sort(squad)
		return {mode = K.mode, part = K.part, activation = K.activation, skipped = skipped, squad = squad, windowMode = W.windowMode}
	end

	function K.importSettings(data)
		if type(data) ~= "table" then return end
		if data.mode == "Lock" or data.mode == "Legacy" or data.mode == "Adv" then K.mode = data.mode end
		if data.part == "Head" or data.part == "HumanoidRootPart" then K.part = data.part end
		if data.activation == "Always" or data.activation == "RMB" or data.activation == "Fire" then K.activation = data.activation end
		local function validId(id) return type(id) == "number" and id == id and id > 0 and id < 9007199254740992 and id % 1 == 0 end
		K.blacklist, K.teammates = {}, {}
		if type(data.skipped) == "table" then
			for index, id in ipairs(data.skipped) do
				if index > 200 then break end
				if validId(id) then K.blacklist[id] = true end
			end
		end
		if type(data.squad) == "table" then
			for index, id in ipairs(data.squad) do
				if index > K.teamSize then break end
				if validId(id) then
					local p = Players:GetPlayerByUserId(id)
					K.teammates[id] = p and p.DisplayName or tostring(id)
					K.blacklist[id] = true
				end
			end
		end
		K.teamPicking = K.count(K.teammates) < K.teamSize
		if data.windowMode == "MOVE" or data.windowMode == "LOCK" or data.windowMode == "HUD" then K.setWindowMode(data.windowMode) end
		for _, refresh in ipairs(K.choiceRefresh) do refresh() end
		if W.rebuildPlayers then W.rebuildPlayers() end
	end

	function K.cleanup()
		K.stopAim()
		K.clearBeams()
		if K.cursorOrb then K.cursorOrb:Destroy() K.cursorOrb = nil end
		K.radarArrow.Visible, K.radarInfo.Visible = false, false
		K.profiles = {}
	end

	function K.choice(parent, title, choices, getter, setter)
		local holder = W.new("Frame", parent, {Name = title, Size = UDim2.new(1, 0, 0, 71), BackgroundColor3 = C.bg, BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 102})
		corner(holder, 9)
		ord(holder)
		local text = label(holder, title, 13, C.text)
		text.Position, text.Size, text.ZIndex = UDim2.fromOffset(13, 8), UDim2.new(1, -26, 0, 24), 103
		local buttons = {}
		local function refresh()
			for i, item in ipairs(choices) do
				buttons[i].BackgroundColor3 = getter() == item[1] and C.accent or C.raised
				buttons[i].TextColor3 = getter() == item[1] and C.ink or C.dim
			end
		end
		local function fit()
			local width = holder.AbsoluteSize.X / math.max(W.ui.targetScale or 1, 0.1)
			if width < 40 then width = 330 end
			local columns = math.min(#choices, math.max(1, math.floor((width - 26) / 102)))
			for i, b in ipairs(buttons) do
				b.Position = UDim2.fromOffset(13 + ((i - 1) % columns) * ((width - 26) / columns), 40 + math.floor((i - 1) / columns) * 36)
				b.Size = UDim2.fromOffset((width - 26) / columns - 5, 29)
			end
			holder.Size = UDim2.new(1, 0, 0, 46 + math.ceil(#choices / columns) * 36)
		end
		for i, item in ipairs(choices) do
			local b = W.new("TextButton", holder, {Text = item[2], TextSize = 11, TextColor3 = C.dim, Font = Enum.Font.GothamMedium,
				BackgroundColor3 = C.bg, BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 104})
			corner(b, 6)
			buttons[i] = b
			local function apply() setter(item[1]) refresh() end
			b.Activated:Connect(function() W.safe(apply) end)
			W.register(title .. ": " .. item[2], parent.Name, "ACTION", apply, holder)
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		table.insert(K.choiceRefresh, refresh)
		fit() refresh()
	end


	K.fovCircle = W.new("Frame", hud, {Name = "PlatinumAimFOV", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(K.fov * 2, K.fov * 2), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Active = false, ZIndex = 16})
	W.new("UICorner", K.fovCircle, {CornerRadius = UDim.new(1, 0)})
	stroke(K.fovCircle, C.accent, 1.4, 0.2)
	K.aimBadge = label(hud, "", 11, C.text, true)
	K.aimBadge.AnchorPoint, K.aimBadge.Position, K.aimBadge.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -28), UDim2.fromOffset(380, 28)
	K.aimBadge.TextXAlignment, K.aimBadge.ZIndex, K.aimBadge.Visible = Enum.TextXAlignment.Center, 28, false
	K.radarArrow = label(hud, "^", 30, C.accent, true)
	K.radarArrow.AnchorPoint, K.radarArrow.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(32, 32)
	K.radarArrow.TextXAlignment, K.radarArrow.ZIndex, K.radarArrow.Visible = Enum.TextXAlignment.Center, 24, false
	K.radarInfo = label(hud, "", 12, C.text, true)
	K.radarInfo.AnchorPoint, K.radarInfo.Size = Vector2.new(0.5, 0), UDim2.fromOffset(280, 22)
	K.radarInfo.TextXAlignment, K.radarInfo.ZIndex, K.radarInfo.Visible = Enum.TextXAlignment.Center, 24, false

	local p = W.pages.Aim
	heading(p, "aim engine")
	K.choice(p, "Active Engine", {{"WRAITH", "WRAITH"}, {"VECTOR", "VECTOR"}}, function() return W.vector.engine end, function(v) W.vector.setEngine(v) end)
	note(p, "WRAITH keeps Lock / Legacy / ADV. VECTOR adds Smooth / Lock / Adaptive. Both use the same master switch and player exclusions.")
	heading(p, "aim assist")
	toggle(p, "Aim Assist", "Enable the selected engine. Aim pauses while this menu is open.", function(v)
		if v then W.cameraMode("Aim Assist") end
		K.enabled = v
		if not v then K.clearTracking() K.fovCircle.Visible = false K.aimBadge.Visible = false W.setToggle("Approach Assist", false) end
	end)
	K.choice(p, "Aim Mode", {{"Lock", "LOCK"}, {"Legacy", "LEGACY"}, {"Adv", "ADV"}}, function() return K.mode end, function(v) K.mode = v K.clearTracking() end)
	K.choice(p, "Activation", {{"Always", "TOGGLE"}, {"RMB", "HOLD RMB"}, {"Fire", "HOLD FIRE"}}, function() return K.activation end, function(v) K.activation = v K.clearTracking() end)
	K.aimReadout = readout(p, 92)
	heading(p, "targeting")
	K.choice(p, "Aim Part", {{"Head", "HEAD"}, {"HumanoidRootPart", "BODY"}}, function() return K.part end, function(v) K.part = v K.clearTracking() end)
	slider(p, "Aim FOV Radius", 20, 1200, K.fov, 0, function(v) K.fov = v end)
	slider(p, "Aim Smoothness", 0.03, 1, K.smooth, 2, function(v) K.smooth = v end)
	slider(p, "Target Stick Margin", 0, 1, K.stickMargin, 2, function(v) K.stickMargin = v end)
	toggle(p, "Aim Wall Check", "Lock / ADV line of sight. Legacy always checks walls.", function(v) K.wallCheck = v K.clearTracking() end)
	toggle(p, "Aim Team Check", "Exclude non-neutral players on your Roblox team.", function(v) K.teamCheck = v K.clearTracking() end)
	toggle(p, "Aim Selected Only", "Only aim at your selected player; still respects SKIP.", function(v) K.selectedOnly = v K.clearTracking() end)
	toggle(p, "Aim FOV Circle", "Show the pixel radius used by Lock and ADV.", function(v) K.fovCircleOn = v if not v then K.fovCircle.Visible = false end end)
	note(p, "Lock selects nearest to screen center. Legacy uses the whole screen with a wall check. ADV prioritizes the closest eligible player. Larger smoothness values turn faster.")
	heading(p, "advanced prediction")
	slider(p, "ADV Lead", 0, 0.6, K.advLead, 2, function(v) K.advLead = v end)
	slider(p, "ADV Response", 0.05, 1, K.advSpeed, 2, function(v) K.advSpeed = v end)
	slider(p, "ADV Aggression", 0.2, 3, K.advAggression, 2, function(v) K.advAggression = v end)
	slider(p, "Projectile Speed", 0, 5000, K.projSpeed, 0, function(v) K.projSpeed = v end)
	toggle(p, "Prediction Dot", "Mark ADV's predicted world position.", function(v) K.predDotOn = v if not v and K.predOrb then K.predOrb:Destroy() K.predOrb = nil end end)
	toggle(p, "ADV Center Cursor", "Lock the mouse while tracking, only with the panel closed.", function(v) K.centerCursor = v if not v then K.releaseCursor() end end)
	note(p, "Projectile speed 0 uses fixed lead; otherwise distance sets travel time. Motion profiles estimate strafing, jumps and airborne movement. Confidence is a heuristic, not a measured hit probability.")
	button(p, "RESET MOTION PROFILES", function() K.profiles = {} K.calibration = 1 K.clearTracking() end)
	heading(p, "approach assist")
	toggle(p, "Approach Assist", "Walk toward the aim target. Manual WASD takes priority.", function(v)
		if v then
			if not W.bodyAvailable("Approach") then return false end
			W.stopMotion("approach")
			W.setToggle("Aim Assist", true)
		end
		K.approachOn = v
		if not v then K.releaseApproach() end
	end)
	slider(p, "Approach Speed", 1, 200, K.approachSpeed, 0, function(v) K.approachSpeed = v end)
	slider(p, "Approach Stop Distance", 2, 60, K.approachStop, 0, function(v) K.approachStop = v end)
	note(p, "Approach uses normal movement and collisions, not teleporting or pathfinding. Flight, follow, macros and underground movement stop it.")
	heading(p, "hit tracker")
	toggle(p, "Hit Tracker", "Correlate target health drops with M1 / M2-release timing.", function(v)
		K.hitTrackerOn = v
		if not v then K.watchTarget(nil) else K.watchTarget(K.currentPlayer) end
	end)
	slider(p, "Hit Window", 0.1, 5, K.hitWindow, 2, function(v) K.hitWindow = v end)
	slider(p, "High Damage Threshold", 1, 100000, K.hyperDamage, 0, function(v) K.hyperDamage = v end)
	K.hitReadout = readout(p, 110)
	button(p, "RESET HIT ESTIMATES", function() K.hitCount, K.hitDamage, K.lastHit = 0, 0, "No hits observed." end)
	heading(p, "squad")
	slider(p, "Squad Size", 0, 6, K.teamSize, 0, K.setSquadSize)
	K.squadReadout = readout(p, 85)
	button(p, "OPEN PLAYER EXCLUSIONS", function() showPage("Players") end)
	button(p, "CLEAR SQUAD", K.clearSquad)
	button(p, "CLEAR ALL AIM EXCLUSIONS", function() K.blacklist, K.teammates = {}, {} K.teamPicking = K.teamSize > 0 if W.rebuildPlayers then W.rebuildPlayers() end end)

	heading(W.pages.Vision, "platinum visuals")
	toggle(W.pages.Vision, "World Player Beams", "3D lines from your character to visible-to-client players.", function(v) K.beamsOn = v if not v then K.clearBeams() end end)
	slider(W.pages.Vision, "Name Card Transparency", 0, 0.9, K.espTransparency, 2, function(v) K.espTransparency = v end)
	toggle(W.pages.Vision, "3D Cursor Orb", "A local marker at the mouse's world position.", function(v) K.cursorOrbOn = v if not v and K.cursorOrb then K.cursorOrb:Destroy() K.cursorOrb = nil end end)
	heading(W.pages.Hunter, "platinum proximity")
	toggle(W.pages.Hunter, "Directional Radar", "Point toward the nearest player, including behind you.", function(v) K.radarOn = v if not v then K.radarArrow.Visible, K.radarInfo.Visible = false, false end end)
	slider(W.pages.Hunter, "Proximity Ping Range", 5, 300, K.radarPingRange, 0, function(v) K.radarPingRange = v end)
	toggle(W.pages.Hunter, "Proximity Ping Sound", "Ping when a nearby player is behind the camera.", function(v) K.radarSound = v end).Set(true)

	function K.setWindowMode(mode)
		if mode ~= "MOVE" and mode ~= "LOCK" and mode ~= "HUD" then return end
		if mode == "LOCK" and not W.windowSize then W.windowSize = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset) end
		W.windowMode, W.windowDrag, W.windowResize = mode, nil, nil
		W.fitWindow(false)
	end
	function K.cyclePage(step)
		local index = table.find(PAGES, W.page) or 1
		showPage(PAGES[((index - 1 + step) % #PAGES) + 1])
	end
	heading(W.pages.System, "platinum layout")
	K.choice(W.pages.System, "Window Layout", {{"MOVE", "MOVE"}, {"LOCK", "LOCK"}, {"HUD", "HUD"}}, function() return W.windowMode end, K.setWindowMode)
	note(W.pages.System, "MOVE: drag the header. LOCK: drag the bottom-right corner to resize. HUD: compact panel with page arrows.")
	toggle(W.pages.System, "KarGUI K Shortcut", "K opens this panel. Ctrl+K still opens search.", function(v) K.kShortcut = v end).Set(true)
	W.ui.resizeGrip = W.new("TextButton", main, {Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(27, 27), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "/", TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextSize = 20, ZIndex = 120, Visible = false})
	W.ui.hudPrev = W.smallButton(W.ui.pageHeader, "<", 28, 110, function() K.cyclePage(-1) end)
	W.ui.hudPrev.Position, W.ui.hudPrev.Visible = UDim2.new(1, -64, 0, 1), false
	W.ui.hudNext = W.smallButton(W.ui.pageHeader, ">", 28, 110, function() K.cyclePage(1) end)
	W.ui.hudNext.Position, W.ui.hudNext.Visible = UDim2.new(1, -30, 0, 1), false
	W.ui.resizeGrip.InputBegan:Connect(function(i)
		if W.windowMode ~= "LOCK" then return end
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			W.windowResize = {input = i, touch = i.UserInputType == Enum.UserInputType.Touch, start = Vector2.new(i.Position.X, i.Position.Y), size = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)}
		end
	end)
	W.bind(UIS.InputChanged, function(i)
		local resize = W.windowResize
		if resize and ((not resize.touch and i.UserInputType == Enum.UserInputType.MouseMovement) or resize.input == i) then
			local delta = (Vector2.new(i.Position.X, i.Position.Y) - resize.start) / math.max(W.ui.targetScale or 1, 0.1)
			W.windowSize = resize.size + delta * 2
			W.fitWindow(false)
		end
	end)
	W.bind(UIS.InputEnded, function(i)
		if W.windowResize and (W.windowResize.input == i or i.UserInputType == Enum.UserInputType.MouseButton1) then W.windowResize = nil end
		if i.UserInputType == Enum.UserInputType.MouseButton2 then
			if K.rightShotArmed and W.canMove() and not W.overUI(UIS:GetMouseLocation()) then K.lastFireTime = os.clock() end
			K.rightShotArmed = false
		end
	end)
	W.bind(UIS.InputBegan, function(i, processed)
		if processed or not W.canMove() or W.overUI(UIS:GetMouseLocation()) then return end
		if i.UserInputType == Enum.UserInputType.MouseButton1 then K.lastFireTime = os.clock() end
		if i.UserInputType == Enum.UserInputType.MouseButton2 then K.rightShotArmed = true end
	end)
	W.bind(UIS.WindowFocusReleased, function() K.rightShotArmed = false W.windowResize = nil K.clearTracking() end)
end


local pPlayers = W.pages.Players

heading(pPlayers, "target")

local targetLbl = Instance.new("TextLabel")
targetLbl.Size = UDim2.new(1, 0, 0, 46)
targetLbl.BackgroundColor3 = C.panel
targetLbl.BorderSizePixel = 0
targetLbl.Font = Enum.Font.GothamBold
targetLbl.Text = "Select a player below"
targetLbl.TextSize = 12
targetLbl.TextColor3 = C.dim
targetLbl.ZIndex = 101
targetLbl.Parent = pPlayers
corner(targetLbl, 10)
stroke(targetLbl, C.raised, 1, 0.5)
W.ui.targetLbl = targetLbl
ord(targetLbl)

local listHolder = Instance.new("Frame")
listHolder.Size = UDim2.new(1, 0, 0, 0)
listHolder.AutomaticSize = Enum.AutomaticSize.Y
listHolder.BackgroundTransparency = 1
listHolder.ZIndex = 101
listHolder.Parent = pPlayers
ord(listHolder)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = listHolder

local rebuildList

local function setTarget(p)
	if W.target == p then W.clearTarget() setStatus("Target cleared") return end
	W.target = p
	targetLbl.Text = p.DisplayName .. "   @" .. p.Name
	targetLbl.TextColor3 = C.accent
	setStatus("Target: " .. p.Name)
	rebuildList()
end
rebuildList = function()
	if not W.running or not listHolder.Parent then return end
	for _, c in ipairs(listHolder:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local roster = Players:GetPlayers()
	table.sort(roster, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	local count = 0
	for _, p in ipairs(roster) do
		local hay = string.lower(p.DisplayName .. " " .. p.Name)
		if p ~= player and (W.playerFilter == "" or string.find(hay, W.playerFilter, 1, true)) then
			count = count + 1
			local selected = W.target == p
			local row = W.new("Frame", listHolder, {Size = UDim2.new(1, 0, 0, 51), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 101, LayoutOrder = count})
			local b = W.new("TextButton", row, {Size = UDim2.new(1, -72, 1, 0), BackgroundColor3 = C.panel, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 101})
			corner(b, 10)
			stroke(b, selected and C.accent or C.raised, 1, selected and 0.35 or 0.6)
			local icon = label(b, string.upper(string.sub(p.DisplayName, 1, 2)), 12, selected and C.accent or C.text, true)
			icon.Position = UDim2.fromOffset(10, 8)
			icon.Size = UDim2.fromOffset(34, 34)
			icon.BackgroundColor3 = C.raised
			icon.BackgroundTransparency = 0
			icon.TextXAlignment = Enum.TextXAlignment.Center
			icon.ZIndex = 102
			corner(icon, 9)
			local name = label(b, (W.kar.teammates[p.UserId] and "[MATE] " or "") .. p.DisplayName, 12, selected and C.accent or C.text, true)
			name.Position = UDim2.fromOffset(54, 7) name.Size = UDim2.new(1, -66, 0, 19) name.ZIndex = 102
			local user = label(b, "@" .. p.Name, 10, C.dim)
			user.Position = UDim2.fromOffset(54, 28) user.Size = UDim2.new(1, -66, 0, 17) user.ZIndex = 102
			b.Activated:Connect(function() beep(1.05) setTarget(p) end)
			local excluded, mate = W.kar.blacklist[p.UserId], W.kar.teammates[p.UserId]
			local skip = W.new("TextButton", row, {
				Position = UDim2.new(1, -66, 0, 0), Size = UDim2.new(0, 66, 1, 0),
				BackgroundColor3 = C.panel, BorderSizePixel = 0, Text = mate and "MATE" or (excluded and "SKIP" or "AIM"),
				TextColor3 = mate and C.good or (excluded and C.bad or C.dim), Font = Enum.Font.GothamBold,
				TextSize = 11, AutoButtonColor = false, ZIndex = 102,
			})
			corner(skip, 10)
			stroke(skip, mate and C.good or (excluded and C.bad or C.raised), 1, 0.45)
			skip.Activated:Connect(function() beep(0.95) W.safe(W.kar.toggleSkip, p) end)
		end
	end
	if count == 0 then
		local t = label(listHolder, W.playerFilter == "" and "No other players in this session." or "No matching players.", 12, C.dim)
		t.Size = UDim2.new(1, 0, 0, 40) t.TextWrapped = true t.ZIndex = 102
	end
end
W.rebuildPlayers = rebuildList
local playerSearch = input(pPlayers, "Search players...", function(text) W.playerFilter = string.lower(text) rebuildList() end)
playerSearch.LayoutOrder = listHolder.LayoutOrder
listHolder.LayoutOrder = listHolder.LayoutOrder + 1
playerSearch:GetPropertyChangedSignal("Text"):Connect(function() W.playerFilter = string.lower(playerSearch.Text) rebuildList() end)

button(pPlayers, "REFRESH LIST", rebuildList)
button(pPlayers, "CLEAR TARGET", W.clearTarget)

heading(pPlayers, "actions")
button(pPlayers, "TELEPORT TO TARGET", function()
	local tr = W.target and getRoot(W.target)
	local mr = getRoot(player)
	if tr and mr then
		W.teleport(tr.CFrame * CFrame.new(0, 3, 5))
		setStatus("teleported")
	else
		flash("NO TARGET", C.warn)
	end
end)

toggle(pPlayers, "Follow", "Follow the selected player smoothly.", function(v)
	if v and not W.requireTarget("Follow") then W.follow = false return end
	if v and not W.bodyAvailable("Follow") then return false end
	if v then W.stopMotion("Follow") end
	W.follow = v
	W.setBody(v)
end)

slider(pPlayers, "Follow Distance", 4, 40, W.followD, 0, function(v) W.followD = v end)
slider(pPlayers, "Follow Height", 0, 20, W.followH, 0, function(v) W.followH = v end)

heading(pPlayers, "orbit")
toggle(pPlayers, "Orbit Target", "Circle your selected player.", function(v)
	if v and not W.requireTarget("Orbit Target") then W.orbit = false return end
	if v and not W.bodyAvailable("Orbit") then return false end
	if v then W.stopMotion("Orbit Target") W.orbitA = 0 end
	W.orbit = v
	W.setBody(v)
end)

slider(pPlayers, "Orbit Radius", 4, 50, W.orbitR, 0, function(v) W.orbitR = v end)
slider(pPlayers, "Orbit Height", -5, 30, W.orbitH, 0, function(v) W.orbitH = v end)
slider(pPlayers, "Orbit Speed", 0.2, 8, W.orbitS, 1, function(v) W.orbitS = v end)

local pVision = W.pages.Vision

heading(pVision, "name cards")
toggle(pVision, "Player Names", "billboard over their head", function(v) W.espNames = v end)
toggle(pVision, "Show Distance", nil, function(v) W.espDist = v end).Set(true)
toggle(pVision, "Show HP Bar", nil, function(v) W.espHp = v end).Set(true)
toggle(pVision, "Show Tools", nil, function(v) W.espTools = v end)
toggle(pVision, "Target Only", "hide everyone but your target", function(v) W.espOnly = v end)

heading(pVision, "skeleton")
toggle(pVision, "Box ESP", "frame around the body", function(v) W.espBox = v end)
toggle(pVision, "Bone Rig", "live skeleton through their limbs", function(v) W.espBones = v end)
toggle(pVision, "Ground HP Bar", "bar under their feet", function(v) W.espBar = v end)
toggle(pVision, "Tracer Lines", "line from your screen to them", function(v) W.espTracer = v end)

heading(pVision, "checks")
toggle(pVision, "Death Check", "ignore dead players", function(v) W.deathChk = v end).Set(true)

heading(pVision, "lighting")
toggle(pVision, "Fullbright", "for the dark part of your map", function(v)
	W.bright = v
	if not v then W.setToggle("Force Fullbright", false) end
	setBright(v)
end)
toggle(pVision, "Force Fullbright", "Enables Fullbright and keeps it applied locally.", function(v)
	if v then W.setToggle("Fullbright", true) end
	W.forceBright = v
	if v and W.bright then pushBright() end
end)

local pHunt = W.pages.Hunter

heading(pHunt, "radar")
toggle(pHunt, "Hunter Radar", "drag it anywhere, up = where you face", function(v)
	W.radar = v
	radar.Visible = v
	if not v then
		for _, d in pairs(W.dots) do d.Visible = false end
	end
end)
slider(pHunt, "Ping Range", 25, 1000, W.radarRng, 0, function(v) W.radarRng = v end)
slider(pHunt, "Radar Size", 120, 320, W.radarSize, 0, function(v)
	W.radarSize = v
	radar.Size = UDim2.fromOffset(v, v)
	radarCorner.CornerRadius = UDim.new(0, v / 2)
end)

heading(pHunt, "alerts")
toggle(pHunt, "Low HP Alert", "fires when anyone nearby drops", function(v) W.lowHp = v end)
toggle(pHunt, "Own HP Alert", "warn when YOU get low", function(v) W.selfHp = v end)
slider(pHunt, "HP Threshold %", 5, 90, W.lowHpPct, 0, function(v) W.lowHpPct = v end)

local pCam = W.pages.Camera

heading(pCam, "free cam")
toggle(pCam, "Free Cam", "WASD, E up, Q down, Shift boost", function(v)
	if v then startFreecam() else stopFreecam() end
	setStatus(v and "freecam on" or "freecam off")
end)
slider(pCam, "Free Cam Speed", 5, 400, W.fcSpeed, 0, function(v) W.fcSpeed = v end)

heading(pCam, "target camera")
toggle(pCam, "Camera Lock", "Keep the selected player in frame.", function(v)
	if v and not W.requireTarget("Camera Lock") then W.camLock = false return end
	if v then W.cameraMode("Camera Lock") else W.restoreCamera() end
	W.camLock = v
end)
toggle(pCam, "Spectate Target", "Follow their character with your camera.", function(v)
	if v and not W.requireTarget("Spectate Target") then W.spectate = false return end
	if v then
		W.cameraMode("Spectate Target")
		W.ownCameraType(Enum.CameraType.Custom)
	else W.restoreCamera() end
	W.spectate = v
end)

local pInspect = W.pages.Inspector

heading(pInspect, "part inspector")
note(pInspect, "Enable Inspect Mode and click a part outside the panel. Properties appear below; use Print Selection to send them to Output.", 56)

toggle(pInspect, "Inspect Mode", "click any part to read it", function(v)
	if v then W.setToggle("Click Teleport", false) end
	W.inspect = v
	if not v then
		hl.Enabled = false
		W.inspected = nil
	end
	setStatus(v and "inspect mode on, click something" or "inspect mode off")
end)

inspectOut = readout(pInspect, 200)
inspectOut.Text = "nothing selected"

button(pInspect, "SHOW FULL PATH", function()
	if W.inspected then
		inspectOut.Text = fullPath(W.inspected)
		inspectOut.TextColor3 = C.accent
		setStatus("path shown above")
	else
		flash("NOTHING SELECTED", C.warn)
	end
end)

button(pInspect, "CLEAR SELECTION", function()
	W.inspected = nil
	hl.Enabled = false
	inspectOut.Text = "nothing selected"
	inspectOut.TextColor3 = C.dim
end)

heading(pInspect, "quick scan")
button(pInspect, "COUNT WORKSPACE PARTS", function()
	local parts, models, scripts = 0, 0, 0
	for _, o in ipairs(workspace:GetDescendants()) do
		if o:IsA("BasePart") then parts = parts + 1
		elseif o:IsA("Model") then models = models + 1
		elseif o:IsA("LuaSourceContainer") then scripts = scripts + 1 end
	end
	local txt = string.format("parts:   %d\nmodels:  %d\nscripts: %d", parts, models, scripts)
	inspectOut.Text = txt
	inspectOut.TextColor3 = C.text
	setStatus("scanned workspace")
end)

button(pInspect, "LIST WORKSPACE TOP LEVEL", function()
	local lines = {}
	for _, o in ipairs(workspace:GetChildren()) do
		if not Players:GetPlayerFromCharacter(o) then
			table.insert(lines, string.format("%-22s %s", o.Name, o.ClassName))
		end
	end
	local txt = table.concat(lines, "\n")
	inspectOut.Text = txt
	inspectOut.TextColor3 = C.text
	setStatus(#lines .. " top-level objects")
end)

local pPos = W.pages.Positions
local slotLabels = {}

local function slotText(i)
	local cf = W.slots[i]
	if not cf then return "slot " .. i .. "   empty" end
	local p = cf.Position
	return string.format("slot %d   %d, %d, %d", i,
		math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
end

local function refreshSlots()
	for i, l in pairs(slotLabels) do
		l.Text = slotText(i)
		l.TextColor3 = W.slots[i] and C.text or C.dim
	end
end

heading(pPos, "position slots")

for i = 1, 8 do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundColor3 = C.panel
	row.BorderSizePixel = 0
	row.ZIndex = 101
	row.Parent = pPos
	corner(row, 7)
	ord(row)

	local l = label(row, slotText(i), 11, C.dim, true)
	l.Position = UDim2.new(0, 12, 0, 0)
	l.Size = UDim2.new(1, -130, 1, 0)
	l.ZIndex = 102
	slotLabels[i] = l

	local sv = Instance.new("TextButton")
	sv.Size = UDim2.fromOffset(52, 22)
	sv.Position = UDim2.new(1, -118, 0.5, -11)
	sv.BackgroundColor3 = C.raised
	sv.BorderSizePixel = 0
	sv.Font = Enum.Font.GothamBold
	sv.Text = "SAVE"
	sv.TextSize = 9
	sv.TextColor3 = C.text
	sv.AutoButtonColor = false
	sv.ZIndex = 102
	sv.Parent = row
	corner(sv, 5)
	sv.MouseButton1Click:Connect(function()
		local root = getRoot(player)
		if not root then return end
		W.slots[i] = root.CFrame
		refreshSlots()
		W.refreshMarkers()
		beep(1.1)
		flash("SAVED TO SLOT " .. i, C.good)
	end)

	local tp = Instance.new("TextButton")
	tp.Size = UDim2.fromOffset(52, 22)
	tp.Position = UDim2.new(1, -62, 0.5, -11)
	tp.BackgroundColor3 = C.accent2
	tp.BorderSizePixel = 0
	tp.Font = Enum.Font.GothamBold
	tp.Text = "TP"
	tp.TextSize = 9
	tp.TextColor3 = C.text
	tp.AutoButtonColor = false
	tp.ZIndex = 102
	tp.Parent = row
	corner(tp, 5)
	tp.MouseButton1Click:Connect(function()
		local root = getRoot(player)
		if root and W.slots[i] then
			W.teleport(W.slots[i])
			beep(1.1)
			setStatus("tp to slot " .. i)
		else
			flash("SLOT " .. i .. " IS EMPTY", C.warn)
		end
	end)
end

button(pPos, "CLEAR ALL SLOTS", function()
	W.slots = {}
	refreshSlots()
	W.refreshMarkers()
	setStatus("slots cleared")
end)

heading(pPos, "on respawn")
toggle(pPos, "Return To Death Spot", "spawn back where you died", function(v)
	W.retDeath = v
	if v and W.toggles["Return To Slot"] then W.toggles["Return To Slot"].Set(false) end
end)
toggle(pPos, "Return To Slot", "spawn at a saved slot instead", function(v)
	W.retSlot = v
	if v and W.toggles["Return To Death Spot"] then W.toggles["Return To Death Spot"].Set(false) end
end)
slider(pPos, "Auto Slot", 1, 8, W.autoSlot, 0, function(v) W.autoSlot = v end)
slider(pPos, "Respawn Delay", 0, 5, W.respawnD, 1, function(v) W.respawnD = v end)

local pMacro = W.pages.Macro
local macroStatus

local function setMacroStatus()
	if not macroStatus then return end
	if W.macroRec then
		macroStatus.Text = string.format("RECORDING   %.1fs   %d frames",
			os.clock() - W.macroT0, #W.macro)
		macroStatus.TextColor3 = C.bad
	elseif W.macroPlay then
		local dur = #W.macro > 0 and W.macro[#W.macro][1] or 0
		macroStatus.Text = string.format("PLAYING%s   %.1f / %.1fs",
			W.macroLoop and " (loop)" or "", (os.clock() - W.macroP0) * W.macroSpeed, dur)
		macroStatus.TextColor3 = C.good
	elseif #W.macro > 0 then
		macroStatus.Text = string.format("READY   %.1fs   %d frames",
			W.macro[#W.macro][1], #W.macro)
		macroStatus.TextColor3 = C.accent
	else
		macroStatus.Text = "EMPTY"
		macroStatus.TextColor3 = C.dim
	end
end

heading(pMacro, "movement macro")
note(pMacro, "Records a route at up to 30 samples per second. Playback moves your character; it does not replay key presses or tool actions.", 46)

local macroBox = Instance.new("Frame")
macroBox.Size = UDim2.new(1, 0, 0, 34)
macroBox.BackgroundColor3 = C.panel
macroBox.BorderSizePixel = 0
macroBox.ZIndex = 101
macroBox.Parent = pMacro
corner(macroBox, 7)
ord(macroBox)

macroStatus = label(macroBox, "EMPTY", 12, C.dim, true)
macroStatus.Position = UDim2.new(0, 12, 0, 0)
macroStatus.Size = UDim2.new(1, -24, 1, 0)
macroStatus.ZIndex = 102

button(pMacro, "RECORD", function()
	local root = getRoot(player)
	if not root or not alive(player) then flash("Your character is not ready.", C.warn) return end
	if W.macroPlay then W.macroPlay = false W.setBody(false) end
	W.macro = {{0, root.CFrame}}
	W.macroT0 = os.clock()
	W.macroAcc = 0
	W.macroRec = true
	setMacroStatus()
	setStatus("Recording route")
end)
button(pMacro, "STOP", function()
	W.macroRec = false
	if W.macroPlay then W.macroPlay = false W.setBody(false) end
	setMacroStatus()
	setStatus("Route stopped")
end)
button(pMacro, "PLAY", function()
	if #W.macro < 2 or W.macro[#W.macro][1] <= 0 then flash("Record a route first.", C.warn) return end
	if not W.bodyAvailable("Route playback") then return end
	W.stopMotion("macro")
	W.macroRec = false
	W.macroPlay = true
	W.macroIdx = 1
	W.macroP0 = os.clock()
	W.setBody(true)
	setMacroStatus()
	setStatus("Playing route")
end)

toggle(pMacro, "Loop Playback", "Repeat the route until stopped.", function(v) W.macroLoop = v end)

button(pMacro, "CLEAR RECORDING", function()
	W.macro = {}
	W.macroRec = false
	if W.macroPlay then W.setBody(false) end
	W.macroPlay = false
	setMacroStatus()
	setStatus("macro cleared")
end)

local pUG = W.pages.Underground

local function ugRestore()
	if not W.ugJoints then return end
	for motor, base in pairs(W.ugJoints) do
		if motor.Parent then motor.C0 = base end
	end
	W.ugJoints = nil
end

local function ugCapture()
	local c = getChar(player)
	if not c then return false end
	W.ugJoints = {}
	for _, o in ipairs(c:GetDescendants()) do
		if o:IsA("Motor6D") then W.ugJoints[o] = o.C0 end
	end
	return true
end

local function ugAnimate()
	local c = getChar(player)
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not h or not W.ugJoints then return end

	local anim = h:FindFirstChildOfClass("Animator")
	if anim then
		for _, tr in ipairs(anim:GetPlayingAnimationTracks()) do tr:Stop(0) end
	end

	local t = os.clock() * W.ugFlail
	local fl = math.sin(t) * 1.5
	local fr = math.sin(t + math.pi * 0.6) * 1.5
	local spin = os.clock() * W.ugSpin
	local r15 = h.RigType == Enum.HumanoidRigType.R15

	for motor, base in pairs(W.ugJoints) do
		if motor.Parent then
			local n = motor.Name
			if n == "Left Shoulder" then
				motor.C0 = base * CFrame.Angles(fl, 0, 0)
			elseif n == "Right Shoulder" then
				motor.C0 = base * CFrame.Angles(fr, 0, 0)
			elseif n == "LeftShoulder" then
				motor.C0 = base * CFrame.Angles(0, 0, -fl - 1.4)
			elseif n == "RightShoulder" then
				motor.C0 = base * CFrame.Angles(0, 0, fr + 1.4)
			elseif n == "LeftElbow" then
				motor.C0 = base * CFrame.Angles(math.sin(t * 1.7) * 0.9 - 0.3, 0, 0)
			elseif n == "RightElbow" then
				motor.C0 = base * CFrame.Angles(math.sin(t * 1.7 + 1) * 0.9 - 0.3, 0, 0)
			elseif n == "Neck" then
				motor.C0 = r15 and base * CFrame.Angles(0, spin, 0)
					or base * CFrame.Angles(0, 0, spin)
			end
		end
	end
end

local function ugLock(on)
	W.setBody(on)
end

local function ugSafeY(y)
	return math.max(y, workspace.FallenPartsDestroyHeight + 40)
end

local function ugReset(reason)
	local previousNoclip = W.ugWasNoclip
	W.ugState = "SURFACE"
	W.ugHold, W.ugFrom, W.ugTo = nil, nil, nil
	ugRestore()
	ugLock(false)
	W.ugFollow = false
	W.setToggle("Stalk Under Target", false)
	if previousNoclip ~= nil then W.setToggle("Noclip", previousNoclip) end
	W.ugWasNoclip = nil
	if reason then dbg("Underground reset: " .. reason) end
end
W.ugReset = ugReset

local function ugDescend()
	if W.ugState ~= "SURFACE" then
		setStatus("busy, wait for it")
		return
	end
	local root = getRoot(player)
	if not root then setStatus("no character") return end
	if not W.bodyAvailable("Underground") then return end
	W.stopMotion("underground")
	W.ugWasNoclip = W.noclip
	if not ugCapture() then setStatus("Could not read your rig") return end

	local surface = W.ugAnchor or CFrame.new(root.Position)
	W.ugAnchor = surface

	if W.toggles["Noclip"] then W.toggles["Noclip"].Set(true) end
	W.noclip = true
	ugLock(true)

	W.ugFrom = CFrame.new(surface.Position)
	W.ugTo = CFrame.new(surface.Position.X, ugSafeY(surface.Position.Y - W.ugDepth), surface.Position.Z)
	W.ugDur = W.ugSink
	W.ugT0 = os.clock()
	W.ugState = "SINKING"

	setStatus("going under")
	dbg("UNDERGROUND: sinking " .. math.floor(W.ugDepth) .. " studs")
end

local function ugAscend()
	if W.ugState ~= "UNDER" then
		setStatus(W.ugState == "SURFACE" and "you aint under yet" or "busy, wait for it")
		return
	end
	local root = getRoot(player)
	if not root then ugReset("no character") return end

	local surface
	if W.ugFollow and W.target then
		local tr = getRoot(W.target)
		surface = tr and CFrame.new(tr.Position)
	end
	surface = surface or W.ugAnchor
		or CFrame.new(root.Position + Vector3.new(0, W.ugDepth, 0))

	W.ugFrom = W.ugHold or root.CFrame
	W.ugTo = surface
	W.ugDur = W.ugRise
	W.ugT0 = os.clock()
	W.ugState = "RISING"
	W.ugHold = nil

	setStatus("ARISE")
end

heading(pUG, "the underground")
note(pUG, "Sink below the map, hold position or follow a selected player, then return. Emergency Surface stops the sequence immediately.", 56)

button(pUG, "GO UNDER", ugDescend)
button(pUG, "ARISE", ugAscend)

function W.surfaceNow()
	local root = getRoot(player)
	local goal = W.ugAnchor or (root and root.CFrame + Vector3.new(0, W.ugDepth + 4, 0))
	ugReset("emergency")
	if root and goal then
		root.CFrame = goal + Vector3.new(0, 3, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end
button(pUG, "EMERGENCY SURFACE", function() W.surfaceNow() flash("Returned to the surface.", C.good) end)

heading(pUG, "spot")
button(pUG, "SET SPOT HERE", function()
	local root = getRoot(player)
	if root then
		W.ugAnchor = CFrame.new(root.Position)
		setStatus("spot set here")
	end
end)
button(pUG, "SET SPOT AT CURSOR", function()
	W.pickUGSpot = true
	W.setOpen(false)
	flash("Click a surface to set the spot. Escape cancels.", C.accent)
end)

button(pUG, "CLEAR SPOT", function()
	W.ugAnchor = nil
	setStatus("spot cleared, sinks where you stand")
end)

heading(pUG, "timing")
slider(pUG, "Depth", 4, 60, W.ugDepth, 0, function(v) W.ugDepth = v end)
slider(pUG, "Sink Time", 0.4, 15, W.ugSink, 1, function(v) W.ugSink = v end)
slider(pUG, "Rise Time", 0.4, 15, W.ugRise, 1, function(v) W.ugRise = v end)

heading(pUG, "the flail")
slider(pUG, "Arm Flail Speed", 0.5, 30, W.ugFlail, 1, function(v) W.ugFlail = v end)
slider(pUG, "Head Spin Speed", 0, 40, W.ugSpin, 1, function(v) W.ugSpin = v end)
button(pUG, "CALM PRESET", function()
	W.sliders["Arm Flail Speed"].Set(2)
	W.sliders["Head Spin Speed"].Set(1.5)
	setStatus("calm drift")
end)
button(pUG, "DEMONIC PRESET", function()
	W.sliders["Arm Flail Speed"].Set(18)
	W.sliders["Head Spin Speed"].Set(28)
	setStatus("DEMONIC")
end)

heading(pUG, "stalk from below")
note(pUG, "Pick someone on the Players page, flip this on, and you glide under the map staying beneath them. ARISE brings you up right where they are standing.", 46)
toggle(pUG, "Stalk Under Target", "Follow beneath the selected player.", function(v)
	if v and (W.ugState ~= "UNDER" or not W.requireTarget("Stalk Under Target")) then
		W.ugFollow = false
		W.toggles["Stalk Under Target"].Set(false, true)
		flash("Go underground and select a player first.", C.warn)
		return
	end
	W.ugFollow = v
end)

slider(pUG, "Stalk Smoothing", 0.02, 1, W.ugSmooth, 2, function(v) W.ugSmooth = v end)

function W.updateRoute(dt)
	local root = getRoot(player)
	local h = getHum(player)
	if not root or not h or h.Health <= 0 then
		if W.macroPlay then W.macroPlay = false W.setBody(false) end
		W.macroRec = false
		if W.ugState ~= "SURFACE" then ugReset("character unavailable") end
		return
	end
	if (W.macroPlay or W.ugState ~= "SURFACE") and (root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) or h.SeatPart or h.Sit or h.PlatformStand) then
		W.releaseMovement("Route stopped: character became anchored, seated or locked", false)
		return
	end
	if W.macroRec then
		W.macroAcc = W.macroAcc + dt
		if W.macroAcc >= W.macroRate then
			W.macroAcc = W.macroAcc % W.macroRate
			table.insert(W.macro, {os.clock() - W.macroT0, root.CFrame})
			if #W.macro >= 7200 then W.macroRec = false flash("Route reached its 7,200-sample limit.", C.warn) end
		end
	elseif W.macroPlay then
		if #W.macro < 2 then
			W.macroPlay = false
			W.setBody(false)
			return
		end
		local duration = W.macro[#W.macro][1]
		local t = (os.clock() - W.macroP0) * W.macroSpeed
		if t >= duration then
			if W.macroLoop and duration > 0 then
				t = t % duration
				W.macroP0 = os.clock() - t / W.macroSpeed
				W.macroIdx = 1
			else
				root.CFrame = W.macro[#W.macro][2]
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				W.macroPlay = false
				W.setBody(false)
				setMacroStatus()
				setStatus("Route complete")
				return
			end
		end
		while W.macroIdx < #W.macro - 1 and W.macro[W.macroIdx + 1][1] < t do W.macroIdx = W.macroIdx + 1 end
		local a, b = W.macro[W.macroIdx], W.macro[W.macroIdx + 1]
		if a and b then
			root.CFrame = a[2]:Lerp(b[2], math.clamp((t - a[1]) / math.max(b[1] - a[1], 0.001), 0, 1))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if W.ugState == "SURFACE" then return end
	ugAnimate()
	if W.ugState == "SINKING" or W.ugState == "RISING" then
		local a = math.clamp((os.clock() - W.ugT0) / math.max(W.ugDur, 0.05), 0, 1)
		local eased = a * a * (3 - 2 * a)
		local pos = W.ugFrom:Lerp(W.ugTo, eased).Position
		root.CFrame = CFrame.new(pos.X, ugSafeY(pos.Y), pos.Z)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if a >= 1 then
			if W.ugState == "SINKING" then
				W.ugHold = root.CFrame
				W.ugState = "UNDER"
				setStatus("Underground / holding position")
			else
				ugReset()
				setStatus("Returned to the surface")
			end
		end
	elseif W.ugState == "UNDER" then
		if W.ugFollow and W.target then
			local tr = getRoot(W.target)
			if tr and allowed(W.target) then
				local want = CFrame.new(tr.Position - Vector3.new(0, W.ugDepth, 0))
				local alpha = 1 - (1 - math.clamp(W.ugSmooth, 0.001, 1)) ^ (dt * 60)
				W.ugHold = W.ugHold and W.ugHold:Lerp(want, alpha) or want
				W.ugAnchor = CFrame.new(tr.Position)
			else W.setToggle("Stalk Under Target", false) end
		end
		if W.ugHold then
			local pos = W.ugHold.Position
			W.ugHold = CFrame.new(pos.X, ugSafeY(pos.Y), pos.Z)
			root.CFrame = W.ugHold
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local pExp = W.pages.Explorer

Boot.stage("Building inspection tools...")
local SERVICES = {
	{ "Workspace",        workspace },
	{ "Lighting",         Lighting },
	{ "Players",          Players },
	{ "ReplicatedStorage", game:GetService("ReplicatedStorage") },
	{ "ReplicatedFirst",  game:GetService("ReplicatedFirst") },
	{ "StarterGui",       game:GetService("StarterGui") },
	{ "StarterPack",      game:GetService("StarterPack") },
	{ "StarterPlayer",    game:GetService("StarterPlayer") },
	{ "SoundService",     Sound },
	{ "TeleportService",  game:GetService("TeleportService") },
	{ "PlayerGui",        playerGui },
	{ "Backpack",         player:FindFirstChildOfClass("Backpack") },
}

local function classTag(o)
	if o:IsA("Script") then                 return "SERVER", C.bad
	elseif o:IsA("LocalScript") then        return "LOCAL",  C.accent
	elseif o:IsA("ModuleScript") then       return "MODULE", C.warn
	elseif o:IsA("RemoteEvent") then        return "REMOTE", C.warn
	elseif o:IsA("RemoteFunction") then     return "RFUNC",  C.warn
	elseif o:IsA("BindableEvent") then      return "BIND",   C.dim
	elseif o:IsA("Folder") then             return "FOLDER", C.dim
	elseif o:IsA("Model") then              return "MODEL",  C.good
	elseif o:IsA("BasePart") then           return "PART",   C.text
	elseif o:IsA("Tool") then               return "TOOL",   C.good
	elseif o:IsA("Humanoid") then           return "HUMAN",  C.good
	elseif o:IsA("GuiObject") then          return "GUI",    C.dim
	elseif o:IsA("ValueBase") then          return "VALUE",  C.dim
	end
	return "OBJ", C.dim
end

local expCrumb, expList, expLayout, expInfo
local refreshExplorer

local function expPathString()
	if not W.expRoot then return "game" end
	local parts = {}
	local cur = W.expRoot
	while cur and cur ~= game do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return #parts > 0 and table.concat(parts, " > ") or "game"
end

local function describe(o)
	local lines = {}
	table.insert(lines, "PATH   " .. fullPath(o))
	table.insert(lines, "CLASS  " .. o.ClassName)
	table.insert(lines, "")

	if o:IsA("BasePart") then
		table.insert(lines, string.format("SIZE   %.2f, %.2f, %.2f", o.Size.X, o.Size.Y, o.Size.Z))
		table.insert(lines, string.format("POS    %.1f, %.1f, %.1f", o.Position.X, o.Position.Y, o.Position.Z))
		table.insert(lines, "MAT    " .. o.Material.Name)
		table.insert(lines, "COLLIDE " .. tostring(o.CanCollide))
		table.insert(lines, "ANCHOR " .. tostring(o.Anchored))
		table.insert(lines, string.format("TRANSP %.2f", o.Transparency))

	elseif o:IsA("LuaSourceContainer") then
		local kind = o:IsA("Script") and "server script"
			or o:IsA("LocalScript") and "local script" or "module"
		table.insert(lines, "TYPE   " .. kind)
		table.insert(lines, "ENABLED " .. (o:IsA("BaseScript") and tostring(o.Enabled) or "n/a"))
		table.insert(lines, "")

		table.insert(lines, "SOURCE  not readable from any LocalScript.")
		table.insert(lines, "        Open the script in Studio to view")
		table.insert(lines, "        or edit its source. This browser")
		table.insert(lines, "        only reads visible metadata.")

	elseif o:IsA("ValueBase") then
		table.insert(lines, "VALUE  " .. tostring(o.Value))

	elseif o:IsA("Humanoid") then
		table.insert(lines, string.format("HEALTH %d / %d", o.Health, o.MaxHealth))
		table.insert(lines, "SPEED  " .. o.WalkSpeed)
		table.insert(lines, "JUMP   " .. o.JumpPower)
		table.insert(lines, "RIG    " .. o.RigType.Name)
	end

	local kids = #o:GetChildren()
	table.insert(lines, "")
	table.insert(lines, "CHILDREN " .. kids)

	local counts = {}
	for _, c in ipairs(o:GetChildren()) do
		counts[c.ClassName] = (counts[c.ClassName] or 0) + 1
	end
	for cls, n in pairs(counts) do
		table.insert(lines, string.format("  %-22s %d", cls, n))
	end

	return table.concat(lines, "\n")
end

local function selectObject(o)
	expInfo.Text = describe(o)
	expInfo.TextColor3 = C.text

	if o:IsA("BasePart") then
		W.inspected = o
		hl.Adornee = o
		hl.Enabled = true
	elseif o:IsA("Model") then
		W.inspected = o
		hl.Adornee = o
		hl.Enabled = true
	end

	setStatus(o.Name .. "  (" .. o.ClassName .. ")")
end

refreshExplorer = function()
	for _, c in ipairs(expList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	expCrumb.Text = expPathString()

	local n = 0

	if W.expRoot and W.expRoot.Parent and W.expRoot.Parent ~= game then
		n = n + 1
		local up = Instance.new("TextButton")
		up.Size = UDim2.new(1, 0, 0, 26)
		up.BackgroundColor3 = C.raised
		up.BorderSizePixel = 0
		up.Font = Enum.Font.GothamBold
		up.Text = "  ..  up one level"
		up.TextSize = 11
		up.TextXAlignment = Enum.TextXAlignment.Left
		up.TextColor3 = C.dim
		up.AutoButtonColor = false
		up.LayoutOrder = 0
		up.ZIndex = 102
		up.Parent = expList
		corner(up, 5)
		up.MouseButton1Click:Connect(function()
			W.expRoot = W.expRoot.Parent
			W.expPage = 1
			refreshExplorer()
		end)
	end

	if not W.expRoot then
		expInfo.Text = "pick a service below"
		return
	end

	local kids = W.expRoot:GetChildren()
	table.sort(kids, function(a, b)
		if a.ClassName == b.ClassName then return a.Name < b.Name end
		return a.ClassName < b.ClassName
	end)

	local matches = {}
	for _, o in ipairs(kids) do
		if W.expFilter == "" or string.find(string.lower(o.Name), W.expFilter, 1, true) or string.find(string.lower(o.ClassName), W.expFilter, 1, true) then table.insert(matches, o) end
	end
	local totalPages = math.max(1, math.ceil(#matches / 100))
	W.expPage = math.clamp(W.expPage or 1, 1, totalPages)
	local shown = 0
	for idx = (W.expPage - 1) * 100 + 1, math.min(W.expPage * 100, #matches) do
		local o = matches[idx]
		local pass = W.expFilter == ""
			or string.find(string.lower(o.Name), W.expFilter, 1, true) ~= nil
			or string.find(string.lower(o.ClassName), W.expFilter, 1, true) ~= nil

		if pass and shown < 200 then
			shown = shown + 1
			n = n + 1

			local tag, col = classTag(o)
			local kidCount = #o:GetChildren()

			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 26)
			b.BackgroundColor3 = C.panel
			b.BorderSizePixel = 0
			b.Font = Enum.Font.Code
			b.Text = string.format("  %-7s %s%s", tag, o.Name,
				kidCount > 0 and ("   (" .. kidCount .. ")") or "")
			b.TextSize = 11
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.TextColor3 = col
			b.TextTruncate = Enum.TextTruncate.AtEnd
			b.AutoButtonColor = false
			b.LayoutOrder = n
			b.ZIndex = 102
			b.Parent = expList
			corner(b, 5)

			b.MouseEnter:Connect(function()
				b.BackgroundColor3 = C.raised
			end)
			b.MouseLeave:Connect(function()
				b.BackgroundColor3 = C.panel
			end)

			b.MouseButton1Click:Connect(function()
				beep(1.05)
				selectObject(o)
				if kidCount > 0 then
					W.expRoot = o
					W.expPage = 1
					refreshExplorer()
				end
			end)
		end
	end

	if shown == 0 then
		expInfo.Text = W.expFilter ~= "" and "nothing matches that filter" or "this one is empty"
		expInfo.TextColor3 = C.dim
	end

	setStatus(string.format("%d objects / page %d of %d / %s", #matches, W.expPage, totalPages, W.expRoot.Name))
end

heading(pExp, "game explorer")
note(pExp, "Read-only browser for client-visible instances. Click an object to inspect it; containers open their children. Script source is not available here.")

expCrumb = label(pExp, "game", 11, C.accent, true)
expCrumb.Size = UDim2.new(1, 0, 0, 24)
expCrumb.Font = Enum.Font.Code
expCrumb.TextTruncate = Enum.TextTruncate.AtEnd
expCrumb.ZIndex = 101
ord(expCrumb)

input(pExp, "filter by name or class, enter to apply", function(txt)
	W.expFilter = string.lower(txt or "")
	W.expPage = 1
	refreshExplorer()
end)

local expListBox = Instance.new("Frame")
expListBox.Size = UDim2.new(1, 0, 0, 230)
expListBox.BackgroundColor3 = C.bg
expListBox.BorderSizePixel = 0
expListBox.ZIndex = 101
expListBox.Parent = pExp
corner(expListBox, 7)
stroke(expListBox, C.raised, 1)
ord(expListBox)

expList = Instance.new("ScrollingFrame")
expList.Size = UDim2.new(1, -10, 1, -10)
expList.Position = UDim2.fromOffset(5, 5)
expList.BackgroundTransparency = 1
expList.BorderSizePixel = 0
expList.ScrollBarThickness = 3
expList.ScrollBarImageColor3 = C.accent2
expList.CanvasSize = UDim2.new()
expList.AutomaticCanvasSize = Enum.AutomaticSize.Y
expList.ZIndex = 102
expList.Parent = expListBox

expLayout = Instance.new("UIListLayout")
expLayout.SortOrder = Enum.SortOrder.LayoutOrder
expLayout.Padding = UDim.new(0, 3)
expLayout.Parent = expList

expInfo = readout(pExp, 210)
expInfo.Text = "pick a service below"

heading(pExp, "jump to service")

for _, entry in ipairs(SERVICES) do
	if entry[2] then
		button(pExp, string.upper(entry[1]), function()
			W.expRoot = entry[2]
			W.expFilter = ""
			refreshExplorer()
		end)
	end
end

heading(pExp, "shortcuts")
button(pExp, "GO TO MY CHARACTER", function()
	local c = getChar(player)
	if c then
		W.expRoot = c
		W.expFilter = ""
		refreshExplorer()
	else
		flash("NO CHARACTER", C.warn)
	end
end)

button(pExp, "GO TO SELECTED PART", function()
	if W.inspected and W.inspected.Parent then
		W.expRoot = W.inspected.Parent
		W.expFilter = ""
		refreshExplorer()
		selectObject(W.inspected)
	else
		flash("NOTHING SELECTED", C.warn)
	end
end)

button(pExp, "FIND ALL SCRIPTS IN HERE", function()
	if not W.expRoot then flash("PICK A SERVICE FIRST", C.warn) return end

	local found = {}
	for _, o in ipairs(W.expRoot:GetDescendants()) do
		if o:IsA("LuaSourceContainer") then
			local tag = classTag(o)
			table.insert(found, string.format("%-7s %s", tag, fullPath(o)))
			if #found >= 120 then break end
		end
	end

	if #found == 0 then
		expInfo.Text = "no scripts under " .. W.expRoot.Name
		expInfo.TextColor3 = C.dim
	else
		expInfo.Text = #found .. " scripts under " .. W.expRoot.Name .. "\n\n"
			.. table.concat(found, "\n")
		expInfo.TextColor3 = C.text
	end
	setStatus(#found .. " scripts found")
end)

button(pExp, "FIND ALL REMOTES IN HERE", function()
	if not W.expRoot then flash("PICK A SERVICE FIRST", C.warn) return end

	local found = {}
	for _, o in ipairs(W.expRoot:GetDescendants()) do
		if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
			table.insert(found, string.format("%-7s %s",
				o:IsA("RemoteEvent") and "REMOTE" or "RFUNC", fullPath(o)))
			if #found >= 120 then break end
		end
	end

	if #found == 0 then
		expInfo.Text = "no remotes under " .. W.expRoot.Name
		expInfo.TextColor3 = C.dim
	else
		expInfo.Text = #found .. " remotes under " .. W.expRoot.Name .. "\n\n"
			.. table.concat(found, "\n")
		expInfo.TextColor3 = C.text
	end
	setStatus(#found .. " remotes found")
end)

local pScan = W.pages["Deep Scan"]

local scanStatus, scanList, scanInfo, scanOut
local refreshScan

local PER_PAGE = 80

local function currentSet()
	if W.scanMode == "scripts" then return W.scanScripts, "scripts"
	elseif W.scanMode == "parts" then return W.scanParts, "parts"
	elseif W.scanMode == "remotes" then return W.scanRemotes, "remotes"
	else return W.scanNew, "new since load" end
end

local function describeEntry(o)
	local lines = {}
	table.insert(lines, o.Name)
	table.insert(lines, o.ClassName)
	table.insert(lines, "")
	table.insert(lines, fullPath(o))
	table.insert(lines, "")

	if o:IsA("LuaSourceContainer") then
		local kind = o:IsA("Script") and "server script"
			or o:IsA("LocalScript") and "local script" or "module script"
		table.insert(lines, "type      " .. kind)
		if o:IsA("BaseScript") then
			table.insert(lines, "enabled   " .. tostring(o.Enabled))
		end
		local plr = o.Parent and (Players:GetPlayerFromCharacter(o.Parent)
			or (o.Parent.Parent and Players:GetPlayerFromCharacter(o.Parent.Parent)))
		if plr then
			table.insert(lines, "owner     " .. plr.Name .. "  (@" .. plr.DisplayName .. ")")
		end
		table.insert(lines, "parent    " .. (o.Parent and o.Parent.ClassName or "?"))

	elseif o:IsA("BasePart") then
		table.insert(lines, string.format("size      %.1f, %.1f, %.1f", o.Size.X, o.Size.Y, o.Size.Z))
		table.insert(lines, string.format("pos       %.0f, %.0f, %.0f", o.Position.X, o.Position.Y, o.Position.Z))
		table.insert(lines, "material  " .. o.Material.Name)
		table.insert(lines, "collide   " .. tostring(o.CanCollide))
		table.insert(lines, "anchored  " .. tostring(o.Anchored))

		local scripts = {}
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("LuaSourceContainer") then
				table.insert(scripts, c.ClassName .. "  " .. c.Name)
			end
		end
		if #scripts > 0 then
			table.insert(lines, "")
			table.insert(lines, "holds " .. #scripts .. " script(s):")
			for _, s in ipairs(scripts) do
				table.insert(lines, "  " .. s)
			end
		end

	elseif o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
		table.insert(lines, "type      " .. (o:IsA("RemoteEvent") and "event" or "function"))
		table.insert(lines, "parent    " .. (o.Parent and o.Parent.Name or "?"))
	end

	return table.concat(lines, "\n")
end

refreshScan = function()
	for _, c in ipairs(scanList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local set, name = currentSet()

	local shown = {}
	for _, o in ipairs(set) do
		if o.Parent then
			local pass = W.scanFilter == ""
				or string.find(string.lower(o.Name), W.scanFilter, 1, true) ~= nil
				or string.find(string.lower(fullPath(o)), W.scanFilter, 1, true) ~= nil
			if pass then table.insert(shown, o) end
		end
	end

	local total = #shown
	local pages = math.max(1, math.ceil(total / PER_PAGE))
	W.scanPage = math.clamp(W.scanPage, 1, pages)

	local first = (W.scanPage - 1) * PER_PAGE + 1
	local last = math.min(first + PER_PAGE - 1, total)

	scanStatus.Text = string.format("%s      %d found      page %d of %d",
		string.upper(name), total, W.scanPage, pages)
	scanStatus.TextColor3 = total > 0 and C.accent or C.dim

	for idx = first, last do
		local o = shown[idx]
		local tag, col = classTag(o)
		local where = o.Parent and o.Parent.Name or "?"

		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 26)
		b.BackgroundColor3 = C.panel
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Code
		b.Text = string.format("  %-7s %s   <  %s", tag, o.Name, where)
		b.TextSize = 11
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextColor3 = col
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.AutoButtonColor = false
		b.LayoutOrder = idx
		b.ZIndex = 102
		b.Parent = scanList
		corner(b, 5)

		b.MouseEnter:Connect(function() b.BackgroundColor3 = C.raised end)
		b.MouseLeave:Connect(function() b.BackgroundColor3 = C.panel end)

		b.MouseButton1Click:Connect(function()
			beep(1.05)
			scanInfo.Text = describeEntry(o)
			scanInfo.TextColor3 = C.text
			setStatus(o.Name)

			if o:IsA("BasePart") then
				W.inspected = o
				hl.Adornee = o
				hl.Enabled = true
			elseif o.Parent and o.Parent:IsA("BasePart") then
				
				W.inspected = o.Parent
				hl.Adornee = o.Parent
				hl.Enabled = true
			end
		end)
	end

	if total == 0 then
		scanInfo.Text = W.scanFilter ~= ""
			and "nothing matches that filter"
			or "run a scan first"
		scanInfo.TextColor3 = C.dim
	end
end

local function runScan(deep)
	if W.scanning then
		flash("ALREADY SCANNING", C.warn)
		return
	end

	W.scanning = true
	W.scanToken = W.scanToken + 1
	local token = W.scanToken
	W.scanScripts = {}
	W.scanParts = {}
	W.scanRemotes = {}

	local roots = deep and {
		workspace, Lighting,
		game:GetService("ReplicatedStorage"),
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterGui"),
		game:GetService("StarterPack"),
		game:GetService("StarterPlayer"),
		player:FindFirstChild("PlayerGui"),
		player:FindFirstChild("Backpack"),
	} or { workspace }

	task.spawn(function()
		local seen = 0

		for _, root in ipairs(roots) do
			if root then
				for _, o in ipairs(root:GetDescendants()) do
					if not W.running or token ~= W.scanToken then return end
					seen = seen + 1

					if o:IsA("LuaSourceContainer") then
						table.insert(W.scanScripts, o)
					elseif o:IsA("BasePart") then
						table.insert(W.scanParts, o)
					elseif o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
						table.insert(W.scanRemotes, o)
					end

					if seen % 400 == 0 then
						scanStatus.Text = "scanning...   " .. seen .. " objects"
						scanStatus.TextColor3 = C.warn
						task.wait()
					end
				end
			end
		end

		if not W.running or token ~= W.scanToken then return end
		W.scanning = false
		W.scanPage = 1
		W.scanMode = "scripts"

		scanOut.Text = string.format(
			"scanned %d objects\n\nscripts   %d\nparts     %d\nremotes   %d",
			seen, #W.scanScripts, #W.scanParts, #W.scanRemotes)
		scanOut.TextColor3 = C.text

		refreshScan()
		flash(#W.scanScripts .. " SCRIPTS FOUND", C.good)
	end)
end

heading(pScan, "deep scan")
note(pScan, "Walks the game and lists every script, part and remote it can see. Everything shows up in this panel, no console needed.")

button(pScan, "SCAN WORKSPACE", function() runScan(false) end)
button(pScan, "SCAN WHOLE GAME", function() runScan(true) end)

scanOut = readout(pScan, 90)
scanOut.Text = "no scan yet"

heading(pScan, "show")

button(pScan, "SCRIPTS", function()
	W.scanMode = "scripts" W.scanPage = 1 refreshScan()
end)
button(pScan, "REMOTES", function()
	W.scanMode = "remotes" W.scanPage = 1 refreshScan()
end)
button(pScan, "PARTS", function()
	W.scanMode = "parts" W.scanPage = 1 refreshScan()
end)
button(pScan, "NEW SINCE LOAD", function()
	W.scanMode = "new" W.scanPage = 1 refreshScan()
end)

input(pScan, "filter by name or path, press enter", function(txt)
	W.scanFilter = string.lower(txt or "")
	W.scanPage = 1
	refreshScan()
end)

scanStatus = label(pScan, "run a scan first", 12, C.dim, true)
scanStatus.Font = Enum.Font.Code
scanStatus.Size = UDim2.new(1, 0, 0, 24)
scanStatus.ZIndex = 101
ord(scanStatus)

local scanBox = Instance.new("Frame")
scanBox.Size = UDim2.new(1, 0, 0, 300)
scanBox.BackgroundColor3 = C.bg
scanBox.BorderSizePixel = 0
scanBox.ZIndex = 101
scanBox.Parent = pScan
corner(scanBox, 7)
stroke(scanBox, C.raised, 1)
ord(scanBox)

scanList = Instance.new("ScrollingFrame")
scanList.Size = UDim2.new(1, -10, 1, -10)
scanList.Position = UDim2.fromOffset(5, 5)
scanList.BackgroundTransparency = 1
scanList.BorderSizePixel = 0
scanList.ScrollBarThickness = 3
scanList.ScrollBarImageColor3 = C.accent2
scanList.CanvasSize = UDim2.new()
scanList.AutomaticCanvasSize = Enum.AutomaticSize.Y
scanList.ZIndex = 102
scanList.Parent = scanBox

local scanLayout = Instance.new("UIListLayout")
scanLayout.SortOrder = Enum.SortOrder.LayoutOrder
scanLayout.Padding = UDim.new(0, 3)
scanLayout.Parent = scanList

button(pScan, "PREVIOUS PAGE", function()
	W.scanPage = W.scanPage - 1
	refreshScan()
end)
button(pScan, "NEXT PAGE", function()
	W.scanPage = W.scanPage + 1
	refreshScan()
end)

heading(pScan, "details")
scanInfo = readout(pScan, 230)
scanInfo.Text = "click anything in the list"

heading(pScan, "reading script code")
note(pScan, "This LocalScript lists script instances and metadata visible to your client. It does not read source code or access non-replicated server containers. Use Studio to inspect your actual scripts.")

heading(pScan, "live watch")
note(pScan, "Logs new script instances visible to your client while the watch is enabled. A new script is not evidence of cheating; normal game systems create scripts too.")

toggle(pScan, "Watch New Scripts", "logs anything added at runtime", function(v)
	W.watchNew = v

	if v then
		if W.watchConn then W.watchConn:Disconnect() W.watchConn = nil end
		W.scanNew = {}
		W.watchConn = game.DescendantAdded:Connect(function(o)
			if o:IsA("LuaSourceContainer") then
				task.wait()
				if not W.running or not W.watchNew or not o.Parent then return end
				if #W.scanNew >= 400 then table.remove(W.scanNew, 1) end
				table.insert(W.scanNew, o)
				flash("NEW SCRIPT: " .. o.Name, C.warn)
				scanOut.Text = "new script spotted\n\n" .. o.ClassName .. "  " .. o.Name
					.. "\n" .. fullPath(o)
				scanOut.TextColor3 = C.warn
				if W.scanMode == "new" then refreshScan() end
			end
		end)
		setStatus("watching for new scripts")
	else
		if W.watchConn then W.watchConn:Disconnect() W.watchConn = nil end
		setStatus("watch off")
	end
end)

button(pScan, "CLEAR WATCH LIST", function()
	W.scanNew = {}
	if W.scanMode == "new" then refreshScan() end
	setStatus("watch list cleared")
end)

heading(pScan, "players")

button(pScan, "SCAN ALL PLAYERS", function()
	local out = {}
	local found = {}

	for _, p in ipairs(Players:GetPlayers()) do
		local c = getChar(p)
		local bp = p:FindFirstChildOfClass("Backpack")
		local n = 0

		for _, holder in pairs({ c, bp }) do
			if holder then
				for _, o in ipairs(holder:GetDescendants()) do
					if o:IsA("LuaSourceContainer") then
						n = n + 1
						table.insert(found, o)
					end
				end
			end
		end

		table.insert(out, string.format("%-18s %s", p.Name,
			n == 0 and "0 visible scripts" or (n .. " visible script(s)")))
	end

	scanOut.Text = table.concat(out, "\n")
	scanOut.TextColor3 = C.text

	W.scanNew = found
	W.scanMode = "new"
	W.scanPage = 1
	refreshScan()

	setStatus(#found .. " scripts across " .. #Players:GetPlayers() .. " players")
end)

do
	local panel = W.new("Frame", content, {Name = "WoodSearch", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, ZIndex = 300})
	W.ui.palette = panel
	W.ui.searchPanel = panel
	local search = input(panel, "Find a setting, tool, or page...", function() end)
	search.Size, search.ZIndex = UDim2.new(1, -46, 0, 42), 302
	local close = W.smallButton(panel, "x", 34, 303, function() W.showPalette(false) end)
	close.Position = UDim2.new(1, -34, 0, 2)
	local meta = label(panel, "", 11, C.dim)
	meta.Position, meta.Size, meta.ZIndex = UDim2.fromOffset(1, 47), UDim2.new(1, 0, 0, 23), 302
	local results = W.new("ScrollingFrame", panel, {Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent2, ZIndex = 302})
	W.new("UIListLayout", results, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
	W.new("UIPadding", results, {PaddingRight = UDim.new(0, 7)})
	local first
	local function navigate(command)
		W.showPalette(false)
		showPage(command.page)
		local section = command.row and W.sectionForRow[command.row]
		if section then section.SetOpen(true) end
		if command.row then
			task.defer(function()
				if not W.running or not command.row.Parent or W.page ~= command.page then return end
				W.layoutSections(command.page)
				local page = W.pages[command.page]
				page.CanvasPosition = Vector2.new(0, math.max(0, page.CanvasPosition.Y + (command.row.AbsolutePosition.Y - page.AbsolutePosition.Y) / math.max(W.ui.targetScale or 1, 0.1) - 8))
			end)
		end
	end
	local function update()
		for _, child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		local query = string.lower(search.Text)
		local count = 0
		first = nil
		for _, command in ipairs(W.commands) do
			if command.page ~= "Home" and string.find(string.lower(command.title .. " " .. command.page), query, 1, true) then
				count = count + 1
				if count <= 45 then
					first = first or command
					local b = W.new("TextButton", results, {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panel, Text = "", BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 303, LayoutOrder = count})
					corner(b, 10)
					local title = label(b, W.pretty(command.title), 13, C.text, true)
					title.Position, title.Size, title.ZIndex = UDim2.fromOffset(13, 6), UDim2.new(1, -26, 0, 22), 304
					local sub = label(b, command.page .. " / " .. string.lower(command.kind), 11, C.dim)
					sub.Position, sub.Size, sub.ZIndex = UDim2.fromOffset(13, 29), UDim2.new(1, -26, 0, 17), 304
					b.Activated:Connect(function() navigate(command) end)
				end
			end
		end
		meta.Text = count == 0 and "Nothing found. Try another setting name." or (tostring(count) .. " results  /  Select a result to view it.")
		results.CanvasPosition = Vector2.zero
	end
	function W.showPalette(on)
		if on then
			if not W.open then W.setOpen(true) end
			panel.Visible = true
			search.Text = ""
			update()
		else
			panel.Visible = false
			if UIS:GetFocusedTextBox() == search then search:ReleaseFocus(false) end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(function() if W.running and panel.Visible then update() end end)
	search.FocusLost:Connect(function(enter) if enter and panel.Visible and first then navigate(first) end end)
end


do
	local home = W.pages.Home
	local welcome = W.new("Frame", home, {Name = "WoodWelcome", Size = UDim2.new(1, 0, 0, 85), BackgroundColor3 = C.panel,
		BorderSizePixel = 0, ZIndex = 102})
	corner(welcome, 12) ord(welcome)
	local stripe = W.new("Frame", welcome, {Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(3, 52), BackgroundColor3 = C.accent2, BorderSizePixel = 0, ZIndex = 103})
	corner(stripe, 2)
	local title = label(welcome, "Your workspace", 22, C.text, true)
	title.Position, title.Size, title.ZIndex = UDim2.fromOffset(18, 12), UDim2.new(1, -36, 0, 31), 104
	local sub = label(welcome, "Everything starts off. Choose a page to get started.", 12, C.dim)
	sub.Position, sub.Size, sub.ZIndex = UDim2.fromOffset(19, 49), UDim2.new(1, -38, 0, 22), 104
	local metrics = W.new("Frame", home, {Name = "Metrics", Size = UDim2.new(1, 0, 0, 63), BackgroundTransparency = 1, ZIndex = 102})
	ord(metrics)
	W.ui.metrics = {}
	for i, key in ipairs({"FPS", "PLAYERS", "ACTIVE"}) do
		local card = W.new("Frame", metrics, {Position = UDim2.new((i - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, -7, 1, 0),
			BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 103})
		corner(card, 10)
		local name = label(card, ({FPS = "Frame rate", PLAYERS = "Players", ACTIVE = "Active tools"})[key], 10, C.dim)
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(13, 8), UDim2.new(1, -26, 0, 17), 104
		local value = label(card, "0", 22, key == "ACTIVE" and C.accent or C.text, true)
		value.Position, value.Size, value.ZIndex = UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 28), 104
		W.ui.metrics[key] = value
	end
	heading(home, "Quick access")
	local quick = W.new("Frame", home, {Name = "QuickActions", Size = UDim2.new(1, 0, 0, 122), BackgroundTransparency = 1, ZIndex = 102})
	ord(quick)
	W.new("UIGridLayout", quick, {CellSize = UDim2.new(0.5, -5, 0, 56), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder})
	for i, item in ipairs({
		{"Presets", "Your saved setup", function() showPage("Presets") end},
		{"Pinned", "Your go-to settings", function() showPage("Favorites") end},
		{"Movement", "Flight and controls", function() showPage("Movement") end},
		{"Release controls", "Stop and restore input", function() W.emergencyRelease() end},
	}) do
		local b = W.new("TextButton", quick, {Name = "Quick" .. i, Text = "", BackgroundColor3 = C.panel,
			BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i, ZIndex = 103})
		corner(b, 10)
		local title = label(b, item[1], 13, i == 4 and C.warn or C.text, true)
		title.Position, title.Size, title.ZIndex = UDim2.fromOffset(14, 7), UDim2.new(1, -28, 0, 22), 104
		local detail = label(b, item[2], 10, C.dim)
		detail.Position, detail.Size, detail.ZIndex = UDim2.fromOffset(14, 32), UDim2.new(1, -28, 0, 16), 104
		W.bind(b.Activated, function() W.safe(item[3]) end)
	end
	heading(home, "Control status")
	W.ui.controlLive = readout(home, 100)
	W.ui.controlLive.Text = "Reading controls..."
	heading(home, "Session")
	W.ui.session, W.ui.active = readout(home, 110), readout(home, 78)
	W.ui.graphTitle = label(home, "", 11, C.dim)
	W.ui.graphTitle.Size, W.ui.graphTitle.ZIndex = UDim2.new(1, 0, 0, 23), 103
	ord(W.ui.graphTitle)
	W.ui.graphBars, W.samples = {}, {}
end

do
	heading(W.pages.Movement, "jump tuning")
	toggle(W.pages.Movement, "Custom Jump", "Uses your character's current jump mode.", function(v)
		W.jumpOn = v
		if v then W.applyJump() else W.restoreJump() end
	end)
	slider(W.pages.Movement, "Jump Power", 0, 160, W.jumpPower, 0, function(v) W.jumpPower = v W.applyJump() end)
	slider(W.pages.Movement, "Jump Height", 0, 100, W.jumpHeight, 1, function(v) W.jumpHeight = v W.applyJump() end)
	button(W.pages.Movement, "UNSTUCK / F8", function() W.emergencyRelease() end)
	toggle(W.pages.Movement, "Manual Movement Override", "WASD or your movement stick cancels Follow, Orbit, route playback and Underground.", function(v)
		W.manualOverride = v
	end).Set(true)
	W.ui.movementStatus = readout(W.pages.Movement, 95)
	W.ui.movementStatus.Text = "Movement diagnostics are starting. F8: emergency release."

	heading(W.pages.Vision, "overlay tuning")
	toggle(W.pages.Vision, "Silhouette", "A clean character highlight.", function(v) W.espGlow = v end)
	toggle(W.pages.Vision, "Hide Teammates", "Only affects visual overlays.", function(v) W.espTeamCheck = v end)
	slider(W.pages.Vision, "Overlay Range", 50, 5000, 1500, 0, function(v) W.espMaxDistance = v end)
	slider(W.pages.Vision, "Overlay Refresh Rate", 10, 60, 30, 0, function(v) W.espHz = v end)
	W.espMaxDistance = 1500
	W.espHz = 30
	heading(W.pages.Players, "follow tuning")
	slider(W.pages.Players, "Follow Smoothness", 1, 20, W.followSmooth, 1, function(v) W.followSmooth = v end)
	heading(W.pages.Positions, "navigation")
	button(W.pages.Positions, "UNDO LAST TELEPORT", W.undoTeleport)
	toggle(W.pages.Positions, "Saved Location Markers", "Labels your saved slots in the world.", function(v)
		W.showMarkers = v
		W.refreshMarkers()
	end)
	button(W.pages.Positions, "CLEAR TELEPORT HISTORY", function() W.teleportHistory = {} setStatus("Teleport history cleared") end)
	heading(W.pages.Macro, "playback tuning")
	slider(W.pages.Macro, "Playback Speed", 0.25, 3, W.macroSpeed, 2, function(v)
		if W.macroPlay then
			local elapsed = (os.clock() - W.macroP0) * W.macroSpeed
			W.macroP0 = os.clock() - elapsed / v
		end
		W.macroSpeed = v
	end)
	heading(W.pages.Camera, "framing")
	toggle(W.pages.Camera, "Custom FOV", "Keeps your chosen field of view.", function(v)
		W.fovOn = v
		if v then
			if not W.fovBak then W.fovBak = {camera = camera, value = camera.FieldOfView} end
			camera.FieldOfView = W.fov
		elseif W.fovBak then
			if W.fovBak.camera.Parent then W.fovBak.camera.FieldOfView = W.fovBak.value end
			W.fovBak = nil
		end
	end)
	slider(W.pages.Camera, "Field Of View", 40, 120, W.fov, 0, function(v) W.fov = v if W.fovOn then camera.FieldOfView = v end end)
	toggle(W.pages.Camera, "Crosshair", "A local visual guide, not an aim tool.", function(v) W.crosshair = v end)
	slider(W.pages.Camera, "Crosshair Length", 2, 20, W.crossSize, 0, function(v) W.crossSize = v end)
	slider(W.pages.Camera, "Crosshair Gap", 0, 15, W.crossGap, 0, function(v) W.crossGap = v end)
	W.ui.crosshair = W.new("Frame", hud, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1, Visible = false, ZIndex = 30,
	})
	W.ui.crossLines = {}
	for i = 1, 4 do W.ui.crossLines[i] = W.new("Frame", W.ui.crosshair, {BackgroundColor3 = C.text, BorderSizePixel = 0, ZIndex = 31}) end
	heading(W.pages.Inspector, "output")
	button(W.pages.Inspector, "PRINT SELECTION TO OUTPUT", function()
		if W.inspected and W.inspected.Parent then
			print("[WRAITH] " .. W.inspected:GetFullName())
			print(describe(W.inspected))
			flash("Selection printed to Output / F9.", C.good)
		else flash("Select an object first.", C.warn) end
	end)
	button(W.pages.Explorer, "PREVIOUS OBJECT PAGE", function() W.expPage = math.max(1, W.expPage - 1) refreshExplorer() end)
	button(W.pages.Explorer, "NEXT OBJECT PAGE", function() W.expPage = W.expPage + 1 refreshExplorer() end)
	button(W.pages["Deep Scan"], "CANCEL CURRENT SCAN", function()
		W.scanToken = W.scanToken + 1
		W.scanning = false
		scanOut.Text = "Scan cancelled. The results below may be partial."
		refreshScan()
		setStatus("Scan cancelled")
	end)
end

do
	local p = W.pages.World
	heading(p, "time of day")
	button(p, "DAYLIGHT", function() W.captureWorld() Lighting.ClockTime = 14 setStatus("Local daylight applied") end)
	button(p, "MIDNIGHT", function() W.captureWorld() Lighting.ClockTime = 0 setStatus("Local midnight applied") end)
	slider(p, "Clock Time", 0, 24, Lighting.ClockTime, 1, function(v) W.captureWorld() Lighting.ClockTime = v end)
	heading(p, "atmosphere")
	button(p, "CLEAR FOG", function()
		W.captureWorld()
		Lighting.FogStart = 0 Lighting.FogEnd = 100000
		for _, atmo in ipairs(Lighting:GetChildren()) do
			if atmo:IsA("Atmosphere") then
				if W.atmoBak[atmo] == nil then W.atmoBak[atmo] = atmo.Density end
				atmo.Density = 0
			end
		end
		setStatus("Local fog cleared")
	end)
	button(p, "HEAVY FOG", function() W.captureWorld() Lighting.FogStart = 0 Lighting.FogEnd = 250 setStatus("Local fog preview applied") end)
	slider(p, "Exposure", -2, 2, Lighting.ExposureCompensation, 1, function(v) W.captureWorld() Lighting.ExposureCompensation = v end)
	heading(p, "restore")
	button(p, "RESTORE ORIGINAL LIGHTING", function() W.restoreWorld() flash("Original local lighting restored.", C.good) end)
	note(p, "These previews affect your client, not the server's lighting settings.")
end

function W.changeAccent(primary, secondary)
	local oldA, oldB = C.accent, C.accent2
	C.accent, C.accent2 = primary, secondary
	for _, root in ipairs({ui, hud, W.worldFolder, Boot.topGui}) do
		for _, o in ipairs(root:GetDescendants()) do
			local props = {}
			if o:IsA("GuiObject") then table.insert(props, "BackgroundColor3") end
			if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then table.insert(props, "TextColor3") end
			if o:IsA("UIStroke") then table.insert(props, "Color") end
			if o:IsA("ScrollingFrame") then table.insert(props, "ScrollBarImageColor3") end
			if o:IsA("Highlight") then table.insert(props, "FillColor") table.insert(props, "OutlineColor") end
			for _, prop in ipairs(props) do
				if o[prop] == oldA then o[prop] = primary elseif o[prop] == oldB then o[prop] = secondary end
			end
		end
	end
	for _, t in pairs(W.toggles) do t.Render() end
	Boot.refreshTopButton()
	showPage(W.page)
end

function W.layoutSections(pageName)
	local page = W.pages[pageName]
	if not page or not W.sectionPages or not W.sectionPages[pageName] or W.layoutBusy then return end
	W.layoutBusy = true
	local ok, problem = xpcall(function()
		local width, y = math.max(120, (W.ui.contentWidth or 714) - 8), 0
		for _, section in ipairs(W.sectionPages[pageName]) do
			if section.group.Visible then
				section.group.Size = UDim2.fromOffset(width, section.group.Size.Y.Offset)
				local bodyHeight = section.open and section.layout.AbsoluteContentSize.Y / math.max(W.ui.targetScale or 1, 0.1) or 0
				local height = 48 + (section.open and bodyHeight + 16 or 0)
				section.body.Size = UDim2.new(1, -28, 0, bodyHeight)
				section.group.Position, section.group.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(width, height)
				y = y + height + 12
			end
		end
		page.CanvasSize = UDim2.fromOffset(0, y + 8)
	end, Boot.trace)
	W.layoutBusy = false
	if not ok then pcall(W.reportError, "Section layout", problem) end
end

function W.requestLayout(pageName)
	W.layoutQueued = W.layoutQueued or {}
	if W.layoutQueued[pageName] then return end
	W.layoutQueued[pageName] = true
	task.defer(function()
		W.layoutQueued[pageName] = nil
		if W.running then W.layoutSections(pageName) end
	end)
end
function W.buildSections()
	W.sectionPages = {}
	for pageName, page in pairs(W.pages) do
		if pageName ~= "Home" then
			local rows = {}
			for _, child in ipairs(page:GetChildren()) do
				if child:IsA("GuiObject") then table.insert(rows, child)
				elseif child:IsA("UIListLayout") or child:IsA("UIPadding") then child:Destroy() end
			end
			table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			page.AutomaticCanvasSize = Enum.AutomaticSize.None
			W.sectionPages[pageName] = {}
			local current
			for _, row in ipairs(rows) do
				if row:GetAttribute("SectionTitle") or not current then
					local headingRow = row:GetAttribute("SectionTitle") and row or heading(page, "Controls")
					local group = W.new("Frame", page, {Name = "Section", BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.fromOffset(340, 48), ZIndex = 101})
					corner(group, 12)
					stroke(group, C.line, 1, 0.65)
					headingRow.Parent, headingRow.Position, headingRow.Size = group, UDim2.fromOffset(16, 5), UDim2.new(1, -32, 0, 37)
					local body = W.new("Frame", group, {Name = pageName, Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 0), BackgroundTransparency = 1, ZIndex = 102})
					local layout = W.new("UIListLayout", body, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7)})
					local hit = W.new("TextButton", headingRow, {Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 105})
					local count = label(hit, "-", 17, C.dim)
					count.Position, count.Size, count.ZIndex = UDim2.new(1, -22, 0, 0), UDim2.fromOffset(22, 38), 106
					count.TextXAlignment = Enum.TextXAlignment.Right
					local section = {group = group, body = body, layout = layout, count = count, amount = 0, open = true, page = pageName, title = headingRow:GetAttribute("SectionTitle") or "Controls"}
					function section.SetOpen(on)
						section.open, body.Visible = on == true, on == true
						count.Text = section.open and "-" or "+"
						W.requestLayout(pageName)
					end
					hit.Activated:Connect(function() section.SetOpen(not section.open) end)
					layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() W.requestLayout(pageName) end)
					group:GetPropertyChangedSignal("Visible"):Connect(function() W.requestLayout(pageName) end)
					table.insert(W.sections, section)
					table.insert(W.sectionPages[pageName], section)
					current = section
					if headingRow ~= row then row.Parent = body current.amount = 1 W.sectionForRow[row] = current end
				else
					row.Parent = current.body
					current.amount = current.amount + 1
					W.sectionForRow[row] = current
				end
			end
			for index, section in ipairs(W.sectionPages[pageName]) do
				local title = string.lower(section.title)
				local open = index <= 2 or title == "targeting" or title == "vector aim" or title == "ground"
				if pageName == "Players" or pageName == "Favorites" then open = true end
				section.SetOpen(open)
			end
			W.requestLayout(pageName)
		end
	end
end


function W.diagnostics()
	local root, hum = getRoot(player), getHum(player)
	local rig = W.flyRig
	local assembly = root and root.AssemblyRootPart
	local parts = {
		"WRAITH + VECTOR 7 WOOD / LOCAL DIAGNOSTICS",
		"Aim engine: " .. W.vector.engine .. " / " .. W.vector.mode,
		"Tool trigger: " .. tostring(W.vector.trigger) .. " / " .. tostring(W.vector.triggerState),
		"Flight key scheme: " .. W.vector.flightScheme, "Place: " .. tostring(game.PlaceId),
		"Page: " .. W.page, "Panel open: " .. tostring(W.open),
		"Camera type: " .. tostring(camera and camera.CameraType),
		"Camera subject: " .. tostring(camera and camera.CameraSubject),
		"Fusion owns camera: " .. tostring(W.cameraOwned == true),
		"Fallback controls: " .. tostring(W.fallback and W.fallback.on or false),
		"PlayerModule initialized by Fusion: false",
		"Active connections: " .. tostring(#W.connections),
		"Mouse behavior: " .. tostring(UIS.MouseBehavior),
		"Focused text box: " .. tostring(UIS:GetFocusedTextBox()),
		"Freecam input owned: " .. tostring(W.freecamSinkOwned == true),
		"Character ready: " .. tostring(root ~= nil and hum ~= nil and hum.Health > 0),
		"Input available: " .. tostring(W.canMove and W.canMove()),
		"Fly: " .. tostring(W.fly), "Flight controller: LinearVelocity / no forced Physics state",
		"Flight rig: " .. tostring(rig ~= nil and rig.velocity ~= nil and rig.velocity.Parent ~= nil),
		"Input block: " .. tostring(W.inputBlockReason and W.inputBlockReason() or "None"),
		"Input source: " .. tostring(W.flightInputSource),
		"Input direction: " .. tostring(W.flightDirection),
		"Requested velocity: " .. tostring(W.flightRequested),
		"Applied velocity: " .. tostring(W.flightVelocity),
		"Flight tick age: " .. (W.lastFlightTick and string.format("%.3fs", os.clock() - W.lastFlightTick) or "Stopped"),
		"Observed displacement speed: " .. tostring(W.flightObservedSpeed),
		"Last flight issue: " .. tostring(W.lastFlightIssue or "None"),
		"Root anchored: " .. tostring(root and root.Anchored),
		"Assembly anchored: " .. tostring(assembly and assembly.Anchored),
		"Health: " .. tostring(hum and hum.Health), "Humanoid state: " .. tostring(hum and hum:GetState()),
		"Seated: " .. tostring(hum and hum.Sit), "PlatformStand: " .. tostring(hum and hum.PlatformStand),
		"Actual speed: " .. tostring(root and root.AssemblyLinearVelocity.Magnitude),
		"WalkSpeed: " .. tostring(hum and hum.WalkSpeed),
		"AutoRotate: " .. tostring(hum and hum.AutoRotate),
		"EvaluateStateMachine: " .. tostring(hum and hum.EvaluateStateMachine),
		"Manual override: " .. tostring(W.manualOverride),
		"Last release: " .. tostring(W.lastRelease),
		"Target flight speed: " .. tostring(W.flySpeed),
		"Follow: " .. tostring(W.follow) .. " / Orbit: " .. tostring(W.orbit),
		"Freecam: " .. tostring(W.freecam) .. " / Route: " .. tostring(W.macroPlay),
		"Underground: " .. W.ugState,
		"Aim: " .. tostring(W.kar.enabled) .. " / " .. W.kar.mode .. " / " .. tostring(W.kar.state),
		"Aim exclusions: " .. W.kar.count(W.kar.blacklist) .. " / squad " .. W.kar.count(W.kar.teammates),
		"Approach: " .. tostring(W.kar.approachOn),
		"Layout mode: " .. W.windowMode,
		"Auto: " .. tostring(W.auto and W.auto.running) .. " / " .. tostring(W.auto and W.auto.phase),
		"Auto status: " .. tostring(W.auto and W.auto.message),
		"Auto right mouse held: " .. tostring(W.auto and W.auto.mouseHeld),
		"Hotkey capture: " .. tostring(W.hotkeys and W.hotkeys.capture),
		"Last error: " .. (W.lastError or "None recorded"),
	}
	local ok, actions = pcall(function() return CAS:GetAllBoundActionInfo() end)
	if ok then
		local names = {}
		for name in pairs(actions) do table.insert(names, name) end
		table.sort(names)
		table.insert(parts, "Bound input actions: " .. table.concat(names, ", "))
	end
	return table.concat(parts, "\n")
end

W.profileSafeToggles = {
	["UI Sounds"] = true, ["Reduced Motion"] = true, ["Performance HUD"] = true,
	["Crosshair"] = true, ["Saved Location Markers"] = true,
	["Show Distance"] = true, ["Show HP Bar"] = true, ["Show Tools"] = true,
	["Death Check"] = true, ["Hide Teammates"] = true,
	["Aim Wall Check"] = true, ["Aim Team Check"] = true, ["Aim Selected Only"] = true,
	["Aim FOV Circle"] = true, ["Prediction Dot"] = true, ["ADV Center Cursor"] = true,
	["Proximity Ping Sound"] = true, ["KarGUI K Shortcut"] = true,
}
function W.exportProfile()
	local data = {version = 4, theme = W.themeId, placeId = game.PlaceId, sliders = {}, toggles = {}, positions = {}, accent = {C.accent.R, C.accent.G, C.accent.B}, accent2 = {C.accent2.R, C.accent2.G, C.accent2.B}}
	for name, obj in pairs(W.sliders) do data.sliders[name] = obj.Get() end
	for name in pairs(W.profileSafeToggles) do if W.toggles[name] then data.toggles[name] = W.toggles[name].Get() end end
	for i, cf in pairs(W.slots) do data.positions[tostring(i)] = {cf:GetComponents()} end
	data.platinum = W.kar.exportSettings()
	data.fusion = W.vector.exportSettings()
	if W.hotkeys then data.hotkeys = W.hotkeys.export() end
	if W.auto then data.auto = {returnAfter = W.auto.returnAfter} end
	return game:GetService("HttpService"):JSONEncode(data)
end
function W.importProfile(text)
	if type(text) ~= "string" or #text > 30000 then flash("Invalid or oversized profile.", C.warn) return end
	local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(text) end)
	if not ok or type(data) ~= "table" or data.version ~= 4 then flash("That is not a WRAITH V4 profile.", C.warn) return end
	W.reset(true)
	if type(data.sliders) == "table" then
		for name, value in pairs(data.sliders) do
			if W.sliders[name] and type(value) == "number" and value == value and math.abs(value) < math.huge then
				if name ~= "Clock Time" and name ~= "Exposure" then W.sliders[name].Set(value) end
			end
		end
	end
	if type(data.toggles) == "table" then
		for name, value in pairs(data.toggles) do if W.profileSafeToggles[name] and type(value) == "boolean" then W.setToggle(name, value) end end
	end
	local function color(a)
		if type(a) ~= "table" or #a ~= 3 then return nil end
		for _, v in ipairs(a) do if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return nil end end
		return Color3.new(a[1], a[2], a[3])
	end
	local a, b = color(data.accent), color(data.accent2)
	if a and b and data.theme == W.themeId then W.changeAccent(a, b) end
	if data.placeId == game.PlaceId and type(data.positions) == "table" then
		W.slots = {}
		for key, values in pairs(data.positions) do
			local index = tonumber(key)
			if index and index % 1 == 0 and index >= 1 and index <= 8 and type(values) == "table" and #values == 12 then
				local valid = true
				for _, v in ipairs(values) do if type(v) ~= "number" or v ~= v or math.abs(v) > 10000000 then valid = false break end end
				if valid then W.slots[index] = CFrame.new(table.unpack(values)) end
			end
		end
		refreshSlots()
		W.refreshMarkers()
	end
	W.kar.importSettings(data.platinum)
	W.vector.importSettings(data.fusion)
	if W.hotkeys and data.hotkeys ~= nil then W.hotkeys.import(data.hotkeys) end
	if W.auto and type(data.auto) == "table" and type(data.auto.returnAfter) == "boolean" then W.auto.returnAfter = data.auto.returnAfter end
	W.refreshChoices()
	flash("Profile loaded. Movement and aim tools stay off.", C.good)
end

do
	local p = W.pages.Profiles
	heading(p, "session profiles")
	note(p, "Slots survive a WRAITH reload in this session. Export the text to keep settings after leaving the game.")
	for i = 1, 3 do
		button(p, "SAVE PROFILE " .. i, function()
			W.profiles[i] = W.exportProfile()
			_G.__WRAITH_V4_PROFILES = W.profiles
			flash("Saved session profile " .. i .. ".", C.good)
		end)
		button(p, "LOAD PROFILE " .. i, function()
			if W.profiles[i] then W.importProfile(W.profiles[i]) else flash("Profile " .. i .. " is empty.", C.warn) end
		end)
	end
	heading(p, "export / import")
	local box = W.new("TextBox", p, {
		Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.panel, BorderSizePixel = 0,
		Text = "", PlaceholderText = "Export appears here. Paste a V4 profile to import.", PlaceholderColor3 = C.dim,
		TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false, MultiLine = true, ZIndex = 101,
	})
	W.ui.profileBox = box
	corner(box, 10)
	W.new("UIPadding", box, {PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
	ord(box)
	button(p, "EXPORT SETTINGS", function() box.Text = W.exportProfile() box:CaptureFocus() box.SelectionStart = 1 box.CursorPosition = #box.Text + 1 end)
	button(p, "IMPORT SETTINGS", function() W.importProfile(box.Text) end)
end

do
	local p = W.pages.System
	heading(p, "appearance")
	button(p, "SOFT OAK", function() W.changeAccent(Color3.fromRGB(205, 174, 133), Color3.fromRGB(91, 72, 51)) end)
	button(p, "WALNUT", function() W.changeAccent(Color3.fromRGB(187, 151, 110), Color3.fromRGB(78, 59, 43)) end)
	button(p, "DRIFTWOOD", function() W.changeAccent(Color3.fromRGB(198, 184, 159), Color3.fromRGB(84, 78, 63)) end)
	slider(p, "Interface Scale", 0.65, 1.25, 1, 2, function(v) W.interfaceScale = v W.fitWindow(false) end)
	toggle(p, "Reduced Motion", "Instant transitions instead of UI tweens.", function(v) W.reducedMotion = v end)
	toggle(p, "UI Sounds", "Subtle feedback for buttons and switches.", function(v) W.sounds = v end)
	toggle(p, "Performance HUD", "FPS and ping outside the panel.", function(v) W.perfHud = v end)
	button(p, "RECENTER WINDOW", function() W.fitWindow(true) end)
	heading(p, "diagnostics")
	toggle(p, "Debug Mode", "Additional messages in Output / F9.", function(v) W.debug = v end)
	W.ui.perfOut = readout(p, 93)
	button(p, "GENERATE DIAGNOSTICS", function()
		W.ui.diagnosticBox.Text = W.diagnostics()
		W.ui.diagnosticBox:CaptureFocus()
		W.ui.diagnosticBox.SelectionStart = 1
		W.ui.diagnosticBox.CursorPosition = #W.ui.diagnosticBox.Text + 1
	end)
	button(p, "LAST UNSTUCK REPORT", function()
		W.ui.diagnosticBox.Text = W.lastRecoveryReport or "No F8 recovery has been used this session."
		W.ui.diagnosticBox:CaptureFocus()
		W.ui.diagnosticBox.SelectionStart = 1
		W.ui.diagnosticBox.CursorPosition = #W.ui.diagnosticBox.Text + 1
	end)
	W.ui.diagnosticBox = W.new("TextBox", p, {
		Size = UDim2.new(1, 0, 0, 160), BackgroundColor3 = C.panel, BorderSizePixel = 0,
		Text = "", PlaceholderText = "Generate a report, then press Ctrl+C to copy it.", PlaceholderColor3 = C.dim,
		TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 12, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false, MultiLine = true, ZIndex = 101,
	})
	corner(W.ui.diagnosticBox, 10)
	W.new("UIPadding", W.ui.diagnosticBox, {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
	ord(W.ui.diagnosticBox)
	W.ui.logOut = readout(p, 220)
	button(p, "CLEAR SESSION LOG", function() W.logs = {} W.logDirty = true end)
	heading(p, "recovery")
	button(p, "STOP ALL ACTIVE TOOLS", function() W.reset() end)
	button(p, "RESTORE DEFAULT SETTINGS", function() W.restoreSettings() end)
	button(p, "UNLOAD WRAITH", function() if W.cleanup then W.cleanup() end end)
	note(p, "Click the small Menu button on the right to open or close the menu.  /  F8: stop tools\nClient-only tools. No account-ID restriction. Right Shift is not used.")
	W.ui.performance = label(hud, "", 11, C.text, true)
	W.ui.performance.AnchorPoint = Vector2.new(1, 0)
	W.ui.performance.Position = UDim2.new(1, -18, 0, 58)
	W.ui.performance.Size = UDim2.fromOffset(178, 31)
	W.ui.performance.BackgroundTransparency = 0.15
	W.ui.performance.BackgroundColor3 = C.bg
	W.ui.performance.TextXAlignment = Enum.TextXAlignment.Center
	W.ui.performance.ZIndex = 28
	W.ui.performance.Visible = false
	corner(W.ui.performance, 9)
	stroke(W.ui.performance, C.raised, 1)
end

function W.reset(quiet)
	W.releaseMovement("Tools stopped", true)
	W.kar.stopAim()
	W.windowResize = nil
	W.stopFlight()
	W.macroRec = false
	W.macroPlay = false
	W.pickUGSpot = false
	W.inspected = nil
	hl.Enabled = false
	if W.ugState ~= "SURFACE" and W.surfaceNow then W.surfaceNow() end
	for _, t in pairs(W.toggles) do
		if t.Get() and not W.profileSafeToggles[t.name] then t.Set(false) end
	end
	W.setToggle("Custom Jump", false)
	W.setToggle("Custom FOV", false)
	W.setToggle("Noclip", false)
	W.stopFlyRig()
	W.restoreCollisions()
	W.restoreSpeed()
	W.restoreJump()
	W.setBody(false)
	W.restoreWorld()
	if W.gravBak then workspace.Gravity = W.gravBak W.gravBak = nil end
	W.follow, W.orbit, W.fly, W.freecam = false, false, false, false
	W.restoreCamera()
	setMacroStatus()
	if not quiet then flash("Active tools stopped. Character and world restored.", C.good) end
end

Boot.stage("Registering shortcuts and presets...")
W.hotkeys = {items = {}, order = {}, held = {}, capture = nil, captureToken = 0, rows = {}}
W.presets = {
	name = "KARMA / LOCK + ESP",
	esp = {"Player Names", "Show Distance", "Show HP Bar", "Show Tools", "Box ESP", "Bone Rig", "Ground HP Bar", "Tracer Lines", "Silhouette", "World Player Beams"},
	alerts = {"Low HP Alert", "Own HP Alert", "Hunter Radar", "Directional Radar", "Proximity Ping Sound", "Hit Tracker", "Watch New Scripts"},
}
W.auto = {
	running = false, token = 0, phase = "IDLE", message = "ASSUME READY: start right-clicks immediately. Equipment is ignored.",
	queue = {}, index = 0, down = 0, skipped = 0, clicks = 0,
	distance = 3, height = 0, interval = 0.4, hold = 0.06, settle = 0.2, timeout = 10,
	returnAfter = true, transport = nil, mouseHeld = false, releaseError = nil,
}
W.motionToggles["Backstab Sweep"] = true

function W.refreshChoices()
	for _, refresh in ipairs(W.kar.choiceRefresh) do pcall(refresh) end
end

function W.captureDefaults()
	W.defaults = {sliders = {}, toggles = {}, page = {}}
	for name, object in pairs(W.sliders) do W.defaults.sliders[name] = object.default end
	for name, object in pairs(W.toggles) do W.defaults.toggles[name] = object.Get() end
	for _, command in ipairs(W.commands) do
		if command.kind == "TOGGLE" or command.kind == "VALUE" then W.defaults.page[command.title] = command.page end
	end
end

function W.restoreSettings(page, quiet)
	if not W.defaults then return false end
	W.auto.stop("Settings reset", false)
	W.hotkeys.cancelCapture()
	W.releaseTextFocus()
	local combat = page == "Combat"
	local function wanted(name)
		local p = W.defaults.page[name]
		return not page or p == page or (combat and (p == "Aim" or p == "Vision" or p == "Hunter" or name == "Watch New Scripts"))
	end
	if not page then W.reset(true)
	elseif page == "Movement" or page == "Camera" or page == "Players" then W.releaseMovement("Movement settings reset", false) end
	if not page or combat or page == "Aim" then W.kar.stopAim() end
	local skip, mates, teamSize, picking = W.kar.blacklist, W.kar.teammates, W.kar.teamSize, W.kar.teamPicking
	for name, object in pairs(W.toggles) do
		if wanted(name) then object.Set(false) end
	end
	for name, value in pairs(W.defaults.sliders) do
		if wanted(name) and name ~= "Clock Time" and name ~= "Exposure" then W.sliders[name].Set(value, false) end
	end
	for name, value in pairs(W.defaults.toggles) do
		if wanted(name) then W.setToggle(name, value) end
	end
	if not page or combat or page == "Aim" then
		W.vector.resetAim()
		W.kar.mode, W.kar.part, W.kar.activation = "Lock", "Head", "RMB"
		if W.sliders["Squad Size"] then W.sliders["Squad Size"].Set(teamSize, false) end
		W.kar.blacklist, W.kar.teammates, W.kar.teamSize, W.kar.teamPicking = skip, mates, teamSize, picking
		W.kar.clearTracking()
	end
	if not page or page == "World" then W.restoreWorld() end
	if not page then
		W.hiddenHUD = false
		W.windowMode = "MOVE"
		W.changeAccent(Color3.fromRGB(205, 174, 133), Color3.fromRGB(91, 72, 51))
		W.hotkeys.resetAll(true)
		W.auto.returnAfter = true
		W.vector.flightScheme, W.vector.tracerOrigin, W.vector.teamAttribute, W.vector.teleportActivation = "WRAITH", "Bottom", "", "Click"
		if W.vector.teamBox then W.vector.teamBox.Text = "" end
	end
	W.refreshChoices()
	W.auto.refresh()
	if W.rebuildPlayers then W.rebuildPlayers() end
	if not quiet then flash((page or "All") .. " settings reset. AIM / SKIP selections kept.", C.good) end
	return true
end

function W.presets.setGroup(names, value)
	for _, name in ipairs(names) do W.setToggle(name, value) end
end

function W.presets.toggleGroup(names)
	local allOn = true
	for _, name in ipairs(names) do
		if not W.toggles[name] or not W.toggles[name].Get() then allOn = false break end
	end
	W.presets.setGroup(names, not allOn)
end

function W.presets.apply()
	W.auto.stop("Preset applied", false)
	W.releaseTextFocus()
	W.hiddenHUD = false
	W.setToggle("Approach Assist", false)
	W.vector.setEngine("WRAITH")
	W.kar.mode, W.kar.activation = "Lock", "RMB"
	W.sliders["Aim FOV Radius"].Set(1000, false)
	W.sliders["Aim Smoothness"].Set(1, false)
	W.setToggle("Target Only", false)
	W.setToggle("Hide Teammates", false)
	W.setToggle("Through-wall Overlays", true)
	W.setToggle("Aim Selected Only", false)
	W.setToggle("Death Check", true)
	W.setToggle("Aim FOV Circle", true)
	W.presets.setGroup(W.presets.esp, true)
	W.presets.setGroup(W.presets.alerts, true)
	W.setToggle("Aim Assist", true)
	W.kar.clearTracking()
	W.refreshChoices()
	W.kar.refreshHUD()
	W.log("Karma preset: Lock / hold RMB / radius 1000 / smoothness 1 / all ESP and alerts", "PRESET")
	flash("KARMA preset applied. Hold RMB to aim / release to look freely.", C.good)
end

do
	local H = W.hotkeys
	H.reserved = {
		Unknown = true, Insert = true, Escape = true, Backspace = true, Return = true, KeypadEnter = true,
		W = true, A = true, S = true, D = true, Q = true, E = true, Space = true,
		Up = true, Down = true, Left = true, Right = true, LeftShift = true, RightShift = true,
		LeftControl = true, RightControl = true, LeftAlt = true, RightAlt = true,
		Tab = true, Slash = true, F7 = true, F8 = true, F9 = true, F11 = true, F12 = true, End = true,
	}
	function H.keyName(key)
		if not key then return "UNBOUND" end
		local names = {KeypadZero = "NUM 0", KeypadOne = "NUM 1", KeypadTwo = "NUM 2", KeypadThree = "NUM 3", KeypadFour = "NUM 4", KeypadFive = "NUM 5", KeypadSix = "NUM 6", KeypadSeven = "NUM 7", KeypadEight = "NUM 8", KeypadNine = "NUM 9", KeypadPlus = "NUM +", KeypadMinus = "NUM -", KeypadMultiply = "NUM *", KeypadDivide = "NUM /", KeypadPeriod = "NUM .", Insert = "INSERT"}
		return names[key.Name] or string.upper(key.Name)
	end
	function H.register(id, title, default, run, group)
		H.items[id] = {id = id, title = title, key = default, default = default, run = run, group = group or "Tools"}
		table.insert(H.order, id)
	end
	function H.refresh()
		for id, row in pairs(H.rows) do
			local item = H.items[id]
			row.key.Text = H.capture == id and "PRESS KEY" or H.keyName(item.key)
			row.key.TextColor3 = H.capture == id and C.warn or C.accent
		end
		if H.status then
			H.status.Text = H.capture and ("Binding " .. H.items[H.capture].title .. ": press a key. Esc cancels; Backspace clears.")
				or "Click a key to change it. DEFAULT restores that binding. F8 and End stay reserved."
		end
		if W.auto.keyLabel and H.items.auto then
			W.auto.keyLabel.Text = H.capture == "auto" and "PRESS A KEY FOR AUTO / Esc cancels / Backspace clears"
				or ("START / STOP: " .. H.keyName(H.items.auto.key) .. "     |     F8: emergency release")
		end
	end
	function H.export()
		local result = {}
		for id, item in pairs(H.items) do result[id] = item.key and item.key.Name or false end
		return result
	end
	function H.save()
		_G.__WRAITH_V6_HOTKEYS = H.export()
	end
	function H.valid(id, key)
		if not key then return true end
		if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then return false, "Use a keyboard key." end
		if key == Enum.KeyCode.RightShift then return false, "Right Shift is disabled for this script. Choose another key." end
		if key == Enum.KeyCode.Insert then return id == "menu", "Insert belongs to the panel." end
		if H.reserved[key.Name] then return false, "That key is reserved for movement, recovery or Roblox." end
		if key == Enum.KeyCode.K then return false, "K and Ctrl+K belong to the panel and search." end
		if string.sub(key.Name, 1, 6) == "Button" or string.sub(key.Name, 1, 10) == "Thumbstick" then return false, "Use a keyboard or keypad key." end
		return true
	end
	function H.assign(id, key, quiet)
		local item = H.items[id]
		if not item then return false end
		local valid, reason = H.valid(id, key)
		if not valid then if not quiet then flash(reason, C.warn) end return false end
		if key then
			for otherId, other in pairs(H.items) do
				if otherId ~= id and other.key == key then
					if not quiet then flash(H.keyName(key) .. " is already assigned to " .. other.title .. ".", C.warn) end
					return false
				end
			end
		end
		item.key = key
		H.save()
		H.refresh()
		return true
	end
	function H.cancelCapture()
		H.capture = nil
		H.captureToken = H.captureToken + 1
		H.refresh()
	end
	function H.captureKey(id)
		if not H.items[id] then return end
		W.auto.stop("Stopped to edit hotkeys", false)
		W.releaseTextFocus()
		H.captureToken = H.captureToken + 1
		local token = H.captureToken
		H.capture = id
		H.refresh()
		flash("Press a key for " .. H.items[id].title .. ". Esc cancels.", C.accent)
		task.delay(12, function()
			if W.running and H.capture and token == H.captureToken then H.cancelCapture() flash("Key binding cancelled: no key pressed.", C.dim) end
		end)
	end
	function H.resetOne(id)
		H.cancelCapture()
		local item = H.items[id]
		if item and H.assign(id, item.default) then flash(item.title .. " hotkey reset.", C.good) end
	end
	function H.resetAll(quiet)
		H.cancelCapture()
		for _, item in pairs(H.items) do item.key = item.default end
		H.held = {}
		H.save()
		H.refresh()
		if not quiet then flash("Default hotkeys restored.", C.good) end
	end
	function H.import(data)
		if type(data) ~= "table" then return end
		local proposal = {}
		local used = {}
		for _, id in ipairs(H.order) do
			local item, value = H.items[id], data[id]
			local key = item.default
			if value == false then key = nil
			elseif type(value) == "string" then
				local ok, parsed = pcall(function() return Enum.KeyCode[value] end)
				if ok and H.valid(id, parsed) then key = parsed end
			end
			if key and used[key] then key = nil end
			proposal[id] = key or false
			if key then used[key] = true end
		end
		for id, key in pairs(proposal) do H.items[id].key = key or nil end
		H.save()
		H.refresh()
	end
	function H.handle(i, processed)
		if i.UserInputType ~= Enum.UserInputType.Keyboard or i.KeyCode == Enum.KeyCode.RightShift then return false end
		if H.capture then
			local id = H.capture
			if i.KeyCode == Enum.KeyCode.Escape then H.cancelCapture() return true end
			if i.KeyCode == Enum.KeyCode.Backspace then H.assign(id, nil) H.cancelCapture() return true end
			if H.assign(id, i.KeyCode) then H.cancelCapture() end
			return true
		end
		if UIS:GetFocusedTextBox() or not W.running or not W.windowFocused then return false end
		local ok, menu = pcall(function() return W.GuiService.MenuIsOpen end)
		if ok and menu then return false end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
			or UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt) then return false end
		for _, id in ipairs(H.order) do
			local item = H.items[id]
			if item.key == i.KeyCode then
				if processed and id ~= "menu" then return false end
				if W.ui.palette.Visible and id ~= "menu" then return false end
				if H.held[i.KeyCode] then return true end
				H.held[i.KeyCode] = true
				local good, err = pcall(item.run)
				if not good then W.auto.stop("Hotkey error", false) W.reportError("Hotkey: " .. item.title, err) end
				return true
			end
		end
		return false
	end
end

do
	local A = W.auto
	function A.refresh()
		if not A.readout or not A.readout.Parent then return end
		local name = A.target and (A.target.player.DisplayName .. " @" .. A.target.player.Name) or "None"
		local text = string.format("NO WEAPON CHECK / ASSUME READY\n%s  |  %s\nTarget: %s\nDown: %d  |  Skipped: %d  |  Clicks: %d (%d startup)\n%s%s", A.running and "RUNNING" or "STOPPED", A.phase, name, A.down, A.skipped, A.clicks, A.startupClicks or 0, A.message, A.releaseError and ("\nRelease error: " .. A.releaseError) or "")
		if A.readout.Text ~= text then A.readout.Text = text end
	end
	function A.eligible(p)
		if not p or p == player or p.Parent ~= Players then return false end
		if W.kar.blacklist[p.UserId] or W.kar.teammates[p.UserId] then return false end
		if W.kar.teamCheck and W.vector.sameTeam(p) then return false end
		local h, r = getHum(p), getRoot(p)
		return h ~= nil and h.Health > 0 and r ~= nil and r:IsA("BasePart") and p.Character ~= nil
	end
	function A.findTransport()
		local press, release = mouse2press, mouse2release
		if type(press) == "function" and type(release) == "function" then
			return {name = "DIRECT RIGHT MOUSE", send = function(down)
				if down then return press() else return release() end
			end}
		end
		local ok, virtual = pcall(function() return UIS:CreateVirtualInput() end)
		if ok and virtual then
			return {name = "ROBLOX VIRTUAL INPUT", send = function(down, point)
				return virtual:SendMouseButton(point, Enum.UserInputType.MouseButton2, down, 0)
			end}
		end
		return nil, "Right-click input is unavailable in this runtime. No weapon lookup or movement was attempted."
	end
	function A.retryRelease(record)
		if record.released or record.retryScheduled or record.tries >= 8 then return end
		record.retryScheduled = true
		task.delay(0.15, function()
			record.retryScheduled = false
			if not record.released then A.releaseRecord(record) end
		end)
	end
	function A.releaseRecord(record)
		if not record or record.released then return true end
		if record.sending or record.releasing then record.releaseRequested = true return false end
		record.releasing = true
		local ok, result = pcall(record.transport.send, false, record.point)
		record.releasing = false
		if ok and result ~= false then
			record.released = true
			if A.pressRecord == record then A.pressRecord, A.mouseHeld, A.pressedTarget = nil, false, nil end
			if A.pendingRelease == record then A.pendingRelease, A.releaseError = nil, nil end
			if _G.__FUSION_AUTO_RELEASE == record then _G.__FUSION_AUTO_RELEASE = nil end
			A.lastReleaseAt = os.clock()
			W.kar.rightShotArmed = false
			pcall(W.kar.releaseCursor)
			return true
		end
		record.tries = record.tries + 1
		record.nextTry = os.clock() + 0.15
		A.pendingRelease, A.mouseHeld = record, true
		A.releaseError = ok and "Right-mouse release returned false" or tostring(result)
		_G.__FUSION_AUTO_RELEASE = record
		if record.tries == 1 or record.tries == 8 then
			pcall(W.log, "Auto could not release right mouse: " .. A.releaseError, "ERROR")
			warn("[FUSION 7 WOOD] Right-click release failed. Sweep stopped. Release right mouse manually if necessary.")
		end
		A.retryRelease(record)
		return false
	end
	function A.releaseMouse()
		local record = A.pressRecord or A.pendingRelease
		if not record then return not A.mouseHeld end
		return A.releaseRecord(record)
	end
	function A.syncSwitch(on)
		local object = W.toggles["Backstab Sweep"]
		if object then object.state = on pcall(object.Render) end
	end
	function A.restoreCamera()
		local saved = A.cameraSnapshot
		A.cameraSnapshot = nil
		if not saved then return end
		local owned = saved.camera
		if saved.kind == Enum.CameraType.Scriptable and owned and owned.Parent
			and owned.CameraType == saved.kind and saved.lastFrame and owned.CFrame == saved.lastFrame then
			pcall(function() owned.CFrame = saved.frame end)
		end
	end
	function A.stop(reason, completed)
		if A.stopping then return end
		A.stopping = true
		local wasRunning = A.running
		A.running = false
		A.token = A.token + 1
		local released = A.releaseMouse()
		A.phase = completed and released and "FINISHED" or "IDLE"
		A.message = reason or "Stopped. Normal movement remains available."
		if not released then A.message = A.message .. " / waiting for right-mouse release" end
		A.syncSwitch(false)
		if wasRunning then
			local root, hum = getRoot(player), getHum(player)
			if completed and released and A.moved and A.returnAfter and A.startCF and player.Character == A.startCharacter
				and root == A.startRoot and hum and hum.Health > 0 and not root.Anchored
				and not (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) and not hum.SeatPart then
				pcall(function()
					root.CFrame = A.startCF
					root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				end)
			end
			pcall(W.kar.clearTracking)
			pcall(setStatus, A.message)
		end
		pcall(A.restoreCamera)
		A.target, A.transport, A.queue = nil, nil, {}
		A.stopping = false
		pcall(A.refresh)
	end
	function A.preflight()
		if not W.running or W.initializing or W.unloading then return nil, "The panel is not ready." end
		local root, hum = getRoot(player), getHum(player)
		if not root or not root:IsA("BasePart") or not hum or hum.Health <= 0 then return nil, "Your character is not ready." end
		if root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) then return nil, "Your character is anchored. Auto has not moved you." end
		if hum.SeatPart or hum.Sit or hum.PlatformStand then return nil, "Leave the seated or locked character state before starting Auto." end
		if not workspace.CurrentCamera then return nil, "Waiting for the game camera." end
		if not W.windowFocused then return nil, "Click the game window before starting Auto." end
		local focused = UIS:GetFocusedTextBox()
		if focused and not W.ownsGui(focused) then return nil, "Close chat or the other text box before starting Auto." end
		local ok, menu = pcall(function() return W.GuiService.MenuIsOpen end)
		if ok and menu then return nil, "Close the Roblox menu before starting Auto." end
		if W.manualMovementHeld() then return nil, "Stop moving before starting Auto. Moving again cancels it." end
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return nil, "Release right mouse before starting Auto." end
		local transport, reason = A.findTransport()
		if not transport then return nil, reason end
		return {transport = transport, root = root, hum = hum}
	end
	function A.check()
		if A.running then A.refresh() return end
		local result, reason = A.preflight()
		A.message = result and ("Available: " .. result.transport.name .. ". No weapon detection. Start sends the first click; this check does not click.") or reason
		A.refresh()
		flash(A.message, result and C.good or C.warn)
	end
	function A.sanitize()
		local function value(number, fallback, low, high)
			if type(number) ~= "number" or number ~= number or math.abs(number) == math.huge then return fallback end
			return math.clamp(number, low, high)
		end
		A.distance, A.height = value(A.distance, 3, 1.5, 8), value(A.height, 0, -3, 3)
		A.hold = value(A.hold, 0.06, 0.02, 0.2)
		A.interval = value(A.interval, 0.4, A.hold + 0.05, 2)
		A.settle, A.timeout = value(A.settle, 0.2, 0.1, 1), value(A.timeout, 10, 2, 30)
	end
	function A.press(phase)
		if not A.running or not A.transport or A.pressRecord or A.pendingRelease then return false, "Right mouse is not ready." end
		if _G.__FUSION_AUTO_RELEASE and not _G.__FUSION_AUTO_RELEASE.released then return false, "A previous click still needs releasing." end
		if W.overUI(UIS:GetMouseLocation()) then return false, "Move the pointer away from the Menu button or overlay." end
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return false, "Release right mouse before using Auto." end
		local record = {transport = A.transport, point = UIS:GetMouseLocation(), target = A.target, token = A.token,
			tries = 0, sending = true, time = os.clock(), hold = A.hold, released = false}
		record.tryRelease = function() return A.releaseRecord(record) end
		A.pressRecord, A.mouseHeld, A.pressedTarget = record, true, A.target
		A.phase, A.deadline, A.nextAllowedPress = phase, record.time + record.hold, record.time + A.interval
		_G.__FUSION_AUTO_RELEASE = record
		local ok, result = pcall(record.transport.send, true, record.point)
		record.sending = false
		if not ok or result == false then
			A.releaseRecord(record)
			return false, "Right-click failed: " .. (ok and "input returned false" or tostring(result))
		end
		if record.releaseRequested or not A.running or A.token ~= record.token then
			A.releaseRecord(record)
			return false, "Sweep was cancelled while sending right-click."
		end
		A.clicks = A.clicks + 1
		if phase == "START_PRESS" then A.startupClicks = A.startupClicks + 1 end
		W.kar.lastFireTime = record.time
		task.delay(record.hold, function()
			if record.released then return end
			local released = A.releaseRecord(record)
			if not released and A.running and A.token == record.token then A.stop("Sweep stopped: right-mouse release failed", false) end
		end)
		return true
	end
	function A.start()
		if A.running then return true end
		if A.starting then return false end
		A.starting = true
		local ok, result = xpcall(function()
			if not A.releaseMouse() then A.message = "Right-click release is still pending. Use F8 or release the mouse manually." return false end
			local previous = _G.__FUSION_AUTO_RELEASE
			if previous and not previous.released then
				local released, answer = pcall(previous.tryRelease)
				if not released or answer ~= true then A.message = "A previous Fusion click could not be released. No new input was sent." return false end
			end
			local setup, reason = A.preflight()
			if not setup then A.message = reason return false end
			A.sanitize()
			W.hotkeys.cancelCapture()
			W.releaseTextFocus()
			W.stopMotion("Auto")
			W.setToggle("Camera Lock", false)
			W.setToggle("Spectate Target", false)
			W.setToggle("Click Teleport", false)
			W.setToggle("Inspect Mode", false)
			W.macroRec = false
			W.showPalette(false)
			W.setOpen(false)
			W.kar.clearTracking()
			W.setToggle("Tool Trigger", false)
			W.vector.trigger = false
			W.vector.releaseTool()
			W.vector.triggerState = "OFF"
			if player.Character ~= setup.root.Parent or getHum(player) ~= setup.hum then A.message = "Character changed during startup." return false end
			A.queue, A.index, A.down, A.skipped, A.clicks, A.startupClicks = {}, 0, 0, 0, 0, 0
			A.transport, A.startCharacter, A.startRoot, A.startCF = setup.transport, player.Character, setup.root, setup.root.CFrame
			A.target, A.moved, A.releaseError, A.lastReleaseAt, A.nextAllowedPress = nil, false, nil, nil, nil
			A.token = A.token + 1
			A.running, A.started, A.lastTick = true, os.clock(), os.clock()
			A.message = "Sending immediate right-click / " .. A.transport.name
			A.syncSwitch(true)
			local pressed, failure = A.press("START_PRESS")
			if not pressed then A.stop(failure, false) return false end
			local queue, origin = {}, setup.root.Position
			for _, p in ipairs(Players:GetPlayers()) do
				if A.eligible(p) then
					local targetRoot = getRoot(p)
					table.insert(queue, {player = p, character = p.Character, hum = getHum(p), root = targetRoot, distance = (targetRoot.Position - origin).Magnitude})
				end
			end
			table.sort(queue, function(a, b) return a.distance < b.distance end)
			A.queue = queue
			A.message = "First right-click sent. Sweeping " .. #queue .. " AIM players / " .. A.transport.name
			pcall(setStatus, A.message)
			A.refresh()
			return true
		end, Boot.trace)
		A.starting = false
		if not ok then A.stop("Auto startup error: " .. tostring(result), false) pcall(W.reportError, "Auto start", result) return false end
		if result ~= true then
			A.syncSwitch(false)
			A.refresh()
			flash(A.message, C.warn)
			return false
		end
		return true
	end
	function A.toggle()
		if A.running then A.stop("Sweep stopped", false) else W.setToggle("Backstab Sweep", true) end
	end
	function A.entryState(entry)
		if not entry or entry.player.Parent ~= Players or entry.player.Character ~= entry.character then return "skip" end
		if getRoot(entry.player) ~= entry.root or getHum(entry.player) ~= entry.hum then return "skip" end
		if entry.hum and entry.hum.Parent and entry.hum.Health <= 0 then return "down" end
		if not A.eligible(entry.player) then return "skip" end
		if entry.character:FindFirstChildOfClass("ForceField") then return "protected" end
		return "alive"
	end
	function A.finishTarget(state, reason)
		if not A.releaseMouse() then A.stop("Sweep stopped: right-mouse release failed", false) return false end
		if state == "down" then A.down = A.down + 1 else A.skipped = A.skipped + 1 end
		local name = A.target and A.target.player.Name or "Target"
		A.message = name .. ": " .. reason
		W.log(A.message, "AUTO")
		A.target, A.phase = nil, "ACQUIRE"
		A.refresh()
		return true
	end
	function A.behindFrame(root)
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.001 then look = Vector3.new(0, 0, -1) else look = look.Unit end
		local point = root.Position - look * A.distance + Vector3.new(0, A.height, 0)
		if point.X ~= point.X or point.Y ~= point.Y or point.Z ~= point.Z or point.Magnitude == math.huge or point.Y < workspace.FallenPartsDestroyHeight + 10 then return nil end
		return CFrame.lookAt(point, point + look)
	end
	function A.aimCamera()
		if not A.running or W.open or W.inputBlockReason() or not A.target or A.entryState(A.target) ~= "alive" then return end
		local current = workspace.CurrentCamera
		if not current then A.stop("Sweep stopped: camera unavailable", false) return end
		if A.cameraSnapshot and (A.cameraSnapshot.camera ~= current or A.cameraSnapshot.kind ~= current.CameraType) then A.stop("Sweep stopped: camera controller changed", false) return end
		local position = A.target.root.Position
		if (position - current.CFrame.Position).Magnitude <= 0.01 then return end
		if not A.cameraSnapshot then A.cameraSnapshot = {camera = current, kind = current.CameraType, frame = current.CFrame} end
		local frame = CFrame.lookAt(current.CFrame.Position, position)
		current.CFrame = frame
		A.cameraSnapshot.lastFrame = frame
	end
	function A.step()
		if not A.running then return end
		local now = os.clock()
		A.lastTick = now
		if not W.running then A.stop("Fusion stopped", false) return end
		local reason = W.inputBlockReason()
		if reason then A.stop("Sweep stopped: " .. reason, false) return end
		if W.open or W.hotkeys.capture then A.stop("Sweep stopped: panel opened", false) return end
		if W.manualMovementHeld() then A.stop("Manual movement: sweep cancelled", false) return end
		if player.Character ~= A.startCharacter then A.stop("Sweep stopped: character changed", false) return end
		local root, hum = getRoot(player), getHum(player)
		if root ~= A.startRoot or not hum or hum.Health <= 0 then A.stop("Sweep stopped: your character changed or died", false) return end
		if root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) or hum.SeatPart or hum.Sit or hum.PlatformStand then A.stop("Sweep stopped: character became anchored, seated or locked", false) return end
		if W.fly or W.freecam or W.camLock or W.spectate or W.follow or W.orbit or W.float or W.macroPlay or W.ugState ~= "SURFACE" or W.kar.approachOn or (W.fallback and W.fallback.on) then A.stop("Sweep stopped: another controller started", false) return end
		if A.pendingRelease then A.stop("Sweep stopped: right-click release pending", false) return end
		if now - A.started > math.min(300, #A.queue * (A.timeout + 2) + 5) then A.stop("Sweep stopped: run time limit reached", false) return end
		if A.phase == "START_PRESS" then
			if now < A.deadline then return end
			if not A.releaseMouse() then A.stop("Sweep stopped: initial right-click release failed", false) return end
			A.phase, A.nextClick = "ACQUIRE", math.max(now, A.started + A.interval)
			return
		end
		if A.phase == "ACQUIRE" then
			A.index = A.index + 1
			if A.index > #A.queue then
				A.stop(string.format("Sweep finished: %d observed down, %d skipped. Startup click sent; respawns are not re-targeted.", A.down, A.skipped), true)
				return
			end
			A.target = A.queue[A.index]
			local state = A.entryState(A.target)
			if state ~= "alive" then A.finishTarget(state, state == "down" and "already down" or "excluded, unavailable or protected") return end
			A.targetStarted = now
			A.nextClick = math.max(now + A.settle, A.nextClick or 0, A.nextAllowedPress or 0)
			A.phase, A.message = "SETTLE", "Behind " .. A.target.player.Name .. " / " .. A.index .. " of " .. #A.queue
			A.refresh()
		end
		local state = A.entryState(A.target)
		if state ~= "alive" then A.finishTarget(state, state == "down" and "death observed" or "excluded, unavailable or protected") return end
		if now - A.targetStarted > A.timeout then A.finishTarget("skip", "target timed out; moving on") return end
		if W.overUI(UIS:GetMouseLocation()) then A.stop("Sweep stopped: pointer is over a Fusion control", false) return end
		local cf = A.behindFrame(A.target.root)
		if not cf then A.finishTarget("skip", "invalid position or below the map limit") return end
		root.CFrame = cf
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		A.moved = true
		if A.phase == "PRESS" then
			if now >= A.deadline then
				if not A.releaseMouse() then A.stop("Sweep stopped: mouse release failed", false) return end
				A.phase, A.nextClick = "COOLDOWN", now + math.max(0.05, A.interval - A.hold)
			end
			return
		end
		if now < (A.nextClick or 0) then return end
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			if A.lastReleaseAt and now - A.lastReleaseAt < 0.15 then return end
			A.stop("Sweep stopped: right mouse is being held", false)
			return
		end
		A.aimCamera()
		if not A.running then return end
		local pressed, errorMessage = A.press("PRESS")
		if not pressed then A.stop(errorMessage, false) end
	end
	function A.watch()
		if A.running and os.clock() - (A.lastTick or 0) > 0.75 then A.stop("Sweep stopped: movement updates stalled", false) end
	end
end

do
	local V, K = W.vector, W.kar

	function V.sameTeam(other)
		if not other then return false end
		if V.teamAttribute ~= "" then
			local mine = player:GetAttribute(V.teamAttribute)
			local theirs = other:GetAttribute(V.teamAttribute)
			if mine == nil and player.Character then mine = player.Character:GetAttribute(V.teamAttribute) end
			if theirs == nil and other.Character then theirs = other.Character:GetAttribute(V.teamAttribute) end
			return mine ~= nil and theirs ~= nil and mine == theirs
		end
		return not player.Neutral and not other.Neutral and player.Team ~= nil and player.Team == other.Team
	end

	function V.holdKeyDown()
		local binding = W.hotkeys and W.hotkeys.items.aim_hold
		return binding ~= nil and binding.key ~= nil and UIS:IsKeyDown(binding.key)
	end

	function V.originPoint()
		return V.origin == "Mouse" and UIS:GetMouseLocation() or camera.ViewportSize / 2
	end

	function V.tracerPoint()
		if V.tracerOrigin == "Mouse" then return UIS:GetMouseLocation() end
		local vp = camera.ViewportSize
		return V.tracerOrigin == "Center" and vp / 2 or Vector2.new(vp.X / 2, vp.Y)
	end

	function V.partFor(p)
		local char = getChar(p)
		if not char then return end
		local names = V.part == "Root" and {"HumanoidRootPart"}
			or V.part == "Chest" and {"UpperTorso", "Torso", "HumanoidRootPart"}
			or V.part == "Auto" and {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
			or {"Head", "HumanoidRootPart"}
		for _, name in ipairs(names) do
			local part = char:FindFirstChild(name)
			if part and part:IsA("BasePart") and (not K.wallCheck or K.canSee(part)) then return part end
		end
	end

	function V.candidate(p)
		if not K.isAllowed(p) then return end
		local part = V.partFor(p)
		if not part then return end
		local point, on = camera:WorldToViewportPoint(part.Position)
		if not on or point.Z <= 0.1 then return end
		local screenDistance = (Vector2.new(point.X, point.Y) - V.originPoint()).Magnitude
		if screenDistance > K.fov then return end
		local hum, root = getHum(p), getRoot(p)
		local score = screenDistance
		if V.priority == "Distance" then score = (part.Position - camera.CFrame.Position).Magnitude end
		if V.priority == "Low health" then score = hum.Health end
		return {player = p, part = part, root = root, hum = hum, score = score}
	end

	function V.chooseTarget()
		if V.sticky and K.currentPlayer then
			local keep = V.candidate(K.currentPlayer)
			if keep then return keep end
		end
		local best
		for _, p in ipairs(Players:GetPlayers()) do
			local target = V.candidate(p)
			if target and (not best or target.score < best.score or (target.score == best.score and p.UserId < best.player.UserId)) then best = target end
		end
		return best
	end

	function V.stepAim(dt)
		dt = math.clamp(dt, 0, 0.1)
		local origin = V.originPoint()
		K.fovCircle.Position = UDim2.fromOffset(origin.X, origin.Y)
		K.fovCircle.Size = UDim2.fromOffset(K.fov * 2, K.fov * 2)
		K.fovCircle.Visible = K.enabled and K.fovCircleOn and not W.hiddenHUD
		K.state = K.blockReason()
		if K.state then K.clearTracking() return end
		local target = V.chooseTarget()
		if not target then K.state = "SEARCHING" K.clearTracking() return end
		if V.targetRoot ~= target.root then V.velocity, V.targetRoot = Vector3.zero, target.root end
		local velocity = target.root.AssemblyLinearVelocity
		if velocity.Magnitude > 220 then velocity = velocity.Unit * 220 end
		V.velocity = V.velocity:Lerp(velocity, 1 - math.exp(-12 * dt))
		local position = target.part.Position + V.velocity * V.lead
		K.currentPlayer, K.currentPart, K.predictedPosition = target.player, target.part, position
		K.lastAimUserId, K.lastAimTime, K.lastConf, K.state = target.player.UserId, os.clock(), 0, "TRACKING"
		K.watchTarget(target.player)
		if (position - camera.CFrame.Position).Magnitude > 0.01 then
			local desired = CFrame.lookAt(camera.CFrame.Position, position)
			if V.origin == "Mouse" then
				local ray = camera:ViewportPointToRay(origin.X, origin.Y)
				local localRay = camera.CFrame:VectorToObjectSpace(ray.Direction)
				desired = desired * CFrame.lookAt(Vector3.zero, localRay):Inverse()
			end
			local response = V.response
			if V.mode == "Adaptive" then response = response * (0.75 + math.clamp(V.velocity.Magnitude / 55, 0, 1.5)) end
			local alpha = V.mode == "Lock" and 1 or 1 - math.exp(-response * dt)
			camera.CFrame = camera.CFrame:Lerp(desired, alpha)
		end
		if K.predDotOn and not W.hiddenHUD then
			if not K.predOrb or not K.predOrb.Parent then K.predOrb = K.makeOrb("FusionPrediction", 0.7, 0.25) end
			K.predOrb.Position, K.predOrb.Color = position, C.accent
		elseif K.predOrb then K.predOrb:Destroy() K.predOrb = nil end
		K.releaseCursor()
	end

	function V.releaseTool()
		local tool = V.toolActive
		V.toolActive, V.triggerTarget, V.triggerSince, V.triggerTool = nil, nil, nil, nil
		if tool then pcall(function() tool:Deactivate() end) end
	end

	function V.triggerBlock()
		if not V.trigger then return "OFF" end
		if W.open then return "PANEL OPEN" end
		if W.auto.running then return "AUTO OWNS INPUT" end
		if W.freecam or W.camLock or W.spectate then return "OTHER CAMERA MODE" end
		if W.ugState ~= "SURFACE" or W.macroPlay then return "MOVEMENT PLAYBACK" end
		local reason = W.inputBlockReason()
		if reason then return reason end
		if W.overUI(UIS:GetMouseLocation()) then return "POINTER OVER UI" end
		local hum = getHum(player)
		if not hum or hum.Health <= 0 then return "WAITING FOR CHARACTER" end
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return "MANUAL FIRE" end
	end

	function V.stepTrigger()
		local now = os.clock()
		local block = V.triggerBlock()
		if block then V.releaseTool() V.triggerState = block return end
		if V.toolActive and now >= (V.toolUntil or 0) then
			local tool = V.toolActive
			V.toolActive = nil
			pcall(function() tool:Deactivate() end)
		end
		local char = getChar(player)
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool or not tool.Enabled then V.releaseTool() V.triggerState = "EQUIP AN ENABLED TOOL" return end
		if V.triggerTool ~= tool then V.releaseTool() V.triggerTool = tool end
		local point = V.engine == "VECTOR" and V.originPoint() or camera.ViewportSize / 2
		local ray = camera:ViewportPointToRay(point.X, point.Y)
		local params = RaycastParams.new()
		params.FilterType, params.IgnoreWater = Enum.RaycastFilterType.Exclude, true
		params.FilterDescendantsInstances = {char, camera, W.worldFolder}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * V.distance, params)
		local found
		if hit then
			for _, p in ipairs(Players:GetPlayers()) do
				if K.isAllowed(p) and hit.Instance:IsDescendantOf(p.Character) then found = p break end
			end
		end
		if not found then V.releaseTool() V.triggerState = "WAITING FOR CROSSHAIR TARGET" return end
		if V.triggerTarget ~= found then V.triggerTarget, V.triggerSince = found, now end
		V.triggerState = "TRACKING / " .. found.DisplayName
		if now - V.triggerSince < V.triggerDelay or now - V.lastTrigger < V.triggerInterval then return end
		V.lastTrigger = now
		V.toolActive, V.toolUntil = tool, now + math.min(0.045, V.triggerInterval * 0.4)
		tool:Activate()
		K.lastFireTime = now
		V.triggerState = "TOOL ACTIVATED / " .. found.DisplayName
	end

	function V.drawArrow(arrow, root, color)
		local _, on = camera:WorldToViewportPoint(root.Position)
		arrow.Visible = false
		if on then return end
		local relative = camera.CFrame:PointToObjectSpace(root.Position)
		local direction = Vector2.new(relative.X, -relative.Y)
		if relative.Z > 0 then direction = -direction end
		if direction.Magnitude < 0.01 then direction = Vector2.new(0, 1) end
		direction = direction.Unit
		local vp = camera.ViewportSize
		local radius = math.max(20, math.min(vp.X, vp.Y) * 0.38)
		local point = vp / 2 + direction * radius
		arrow.Position, arrow.Rotation = UDim2.fromOffset(point.X, point.Y), math.deg(math.atan2(direction.Y, direction.X)) + 90
		arrow.TextColor3, arrow.Visible = color, true
	end

	function V.stepBunnyHop()
		if not V.bunnyHop or not W.canMove() or W.open or W.auto.running or W.fly or W.freecam or W.follow or W.orbit or W.float or W.macroPlay or W.ugState ~= "SURFACE" then return end
		local hum = getHum(player)
		if not hum or hum.Health <= 0 or hum.SeatPart or hum.PlatformStand then return end
		if UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
	end

	function V.own(owner, object, property, value)
		if not object or not object.Parent then return end
		local group = V.owners[owner]
		if not group then group = setmetatable({}, {__mode = "k"}) V.owners[owner] = group end
		local properties = group[object]
		if not properties then properties = {} group[object] = properties end
		local current = object[property]
		local entry = properties[property]
		if not entry then entry = {original = current} properties[property] = entry
		elseif entry.last ~= nil and current ~= entry.last then entry.original = current end
		if current ~= value then object[property] = value end
		entry.last = value
	end

	function V.releaseOwner(owner)
		local group = V.owners[owner]
		if not group then return end
		V.owners[owner] = nil
		for object, properties in pairs(group) do
			for property, entry in pairs(properties) do
				pcall(function() if object.Parent and object[property] == entry.last then object[property] = entry.original end end)
			end
		end
	end

	function V.stepVisuals()
		if V.noFog and not W.bright then
			V.own("fog", Lighting, "FogStart", 100000)
			V.own("fog", Lighting, "FogEnd", 100000)
			for _, atmosphere in ipairs(Lighting:GetChildren()) do
				if atmosphere:IsA("Atmosphere") then
					V.own("fog", atmosphere, "Density", 0)
					V.own("fog", atmosphere, "Haze", 0)
					V.own("fog", atmosphere, "Glare", 0)
				end
			end
		else V.releaseOwner("fog") end
		if V.clockLock and not W.bright then V.own("clock", Lighting, "ClockTime", V.clockTime % 24)
		else V.releaseOwner("clock") end
	end

	function V.restoreVisuals()
		V.noFog, V.clockLock = false, false
		V.releaseOwner("fog") V.releaseOwner("clock")
		W.syncOff({"No Fog", "Lock Clock"})
	end

	function V.stepAlerts()
		if not V.nearbyAlert or os.clock() - V.lastNearby < 8 then return end
		local mine = getRoot(player)
		if not mine or not alive(player) then return end
		local nearest, distance
		for _, p in ipairs(Players:GetPlayers()) do
			local root = getRoot(p)
			if root and alive(p) and p ~= player and not K.blacklist[p.UserId] and not K.teammates[p.UserId] and not V.sameTeam(p) then
				local d = (root.Position - mine.Position).Magnitude
				if d <= V.nearbyRadius and (not distance or d < distance) then nearest, distance = p, d end
			end
		end
		if nearest then V.lastNearby = os.clock() flash(string.format("Nearby: %s / %d studs", nearest.DisplayName, math.floor(distance)), C.warn) end
	end

	function V.applyEngineUI()
		for _, command in ipairs(W.commands) do
			if command.row and command.page == "Aim" then
				local name = command.title
				if name == "Aim Smoothness" or name == "Target Stick Margin" or string.sub(name, 1, 9) == "Aim Mode:" or string.sub(name, 1, 9) == "Aim Part:" then command.row.Visible = V.engine == "WRAITH" end
			end
		end
		for _, section in ipairs(W.sections) do
			local title = string.lower(section.title)
			if section.page == "Aim" then
				if title == "vector aim" then section.group.Visible = V.engine == "VECTOR"
				elseif title == "advanced prediction" then section.group.Visible = V.engine == "WRAITH" end
			end
		end
		if W.ui.engineChip then W.ui.engineChip.Text = V.engine .. " ENGINE" end
	end

	function V.setEngine(engine)
		if engine ~= "WRAITH" and engine ~= "VECTOR" then return end
		V.releaseTool()
		K.clearTracking()
		V.engine = engine
		V.applyEngineUI()
		W.refreshChoices()
	end

	function V.resetAim()
		V.mode, V.origin, V.priority, V.part = "Smooth", "Center", "Crosshair", "Head"
		V.setEngine("WRAITH")
	end

	function V.exportSettings()
		local favorites = {}
		for name, enabled in pairs(V.favorites) do if enabled then table.insert(favorites, name) end end
		table.sort(favorites)
		return {version = 1, engine = V.engine, mode = V.mode, origin = V.origin, priority = V.priority, part = V.part,
			flightScheme = V.flightScheme, teleportActivation = V.teleportActivation, tracerOrigin = V.tracerOrigin, teamAttribute = V.teamAttribute, favorites = favorites}
	end

	function V.importSettings(data)
		if type(data) ~= "table" then V.resetAim() return end
		local choices = {engine = {"WRAITH", "VECTOR"}, mode = {"Smooth", "Lock", "Adaptive"}, origin = {"Center", "Mouse"},
			priority = {"Crosshair", "Distance", "Low health"}, part = {"Head", "Chest", "Root", "Auto"},
			teleportActivation = {"Click", "Alt+Click"}, flightScheme = {"WRAITH", "VECTOR"}, tracerOrigin = {"Bottom", "Center", "Mouse"}}
		for key, valid in pairs(choices) do if table.find(valid, data[key]) then V[key] = data[key] end end
		if type(data.teamAttribute) == "string" and #data.teamAttribute <= 64 then V.teamAttribute = data.teamAttribute end
		if type(data.favorites) == "table" then
			V.favorites = {}
			for index, name in ipairs(data.favorites) do
				if index > 40 then break end
				if type(name) == "string" and #name <= 120 then V.favorites[name] = true end
			end
		end
		V.setEngine(V.engine)
		if V.teamBox then V.teamBox.Text = V.teamAttribute end
		V.refreshFavorites()
	end

	function V.applyPreset(name)
		W.reset(true)
		W.hiddenHUD = false
		V.setEngine("VECTOR")
		V.mode, V.origin, V.part, V.priority = "Smooth", "Center", "Head", "Crosshair"
		K.activation = "RMB"
		local settings = {
			["VECTOR SMOOTH"] = {response = 8, radius = 180, lead = 0.02, throughWalls = false},
			["VECTOR LOCK"] = {mode = "Lock", response = 12, radius = 300, lead = 0, throughWalls = true},
			["VECTOR OVERLAY"] = {response = 12, radius = 180, lead = 0.025, throughWalls = true, extras = true},
			["VECTOR FULL"] = {mode = "Adaptive", response = 12, radius = 300, lead = 0.025, throughWalls = true, extras = true},
		}
		local cfg = settings[name]
		if not cfg then return end
		V.mode = cfg.mode or "Smooth"
		for title, value in pairs({["Aim FOV Radius"] = cfg.radius, ["VECTOR Response"] = cfg.response, ["VECTOR Lead"] = cfg.lead, ["Aim Distance"] = 1500}) do W.sliders[title].Set(value, false) end
		for _, title in ipairs({"Aim Wall Check", "Aim Team Check", "Aim Shield Check", "VECTOR Sticky Target", "Aim FOV Circle", "Target Card", "Death Check"}) do W.setToggle(title, true) end
		for _, title in ipairs({"Player Names", "Show Distance", "Show HP Bar", "Health Text", "Box ESP", "Silhouette", "Off-screen Arrows", "Hide Teammates"}) do W.setToggle(title, true) end
		W.setToggle("Through-wall Overlays", cfg.throughWalls)
		W.setToggle("Crosshair", cfg.extras == true)
		if cfg.extras then
			for _, title in ipairs({"Bone Rig", "Tracer Lines", "Show Tools", "Hunter Radar", "Crosshair", "Own HP Alert", "Nearby Alert", "Join / Leave Alerts"}) do W.setToggle(title, true) end
		end
		W.setToggle("Aim Assist", name ~= "VECTOR OVERLAY")
		W.refreshChoices()
		V.applyEngineUI()
		flash(name .. " applied. Flight and trigger remain off.", C.good)
	end

	function V.importVector(text)
		if type(text) ~= "string" or #text > 30000 then flash("Invalid profile text.", C.warn) return false end
		local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(text) end)
		if not ok or type(data) ~= "table" or data.version ~= 1 or type(data.settings) ~= "table" then flash("Paste a VECTOR v1 profile first.", C.warn) return false end
		W.reset(true)
		W.restoreSettings(nil, true)
		local cfg = data.settings
		local sliders = {AimRadius = "Aim FOV Radius", AimSpeed = "VECTOR Response", AimLead = "VECTOR Lead", AimDistance = "Aim Distance",
			TriggerDelay = "Trigger Delay", TriggerInterval = "Trigger Interval", EspDistanceLimit = "Overlay Range", EspRefresh = "Overlay Refresh Rate",
			RadarRange = "Ping Range", FlySpeed = "Fly Speed", FlyBoost = "Flight Boost", WalkSpeed = "Walk Speed", JumpHeight = "Jump Height",
			Gravity = "Gravity", VelocityLimit = "Anti-Fling Limit", FreecamSpeed = "Free Cam Speed", FreecamSensitivity = "Freecam Sensitivity",
			CameraFov = "Field Of View", ClockTime = "Locked Clock Time", CrosshairSize = "Crosshair Length", LowHealthPercent = "HP Threshold %", NearbyRadius = "Nearby Radius", UiScale = "Interface Scale"}
		for old, name in pairs(sliders) do if type(cfg[old]) == "number" and W.sliders[name] then W.sliders[name].Set(cfg[old], false) end end
		local safe = {AimWallCheck = "Aim Wall Check", AimTeamCheck = "Aim Team Check", AimShieldCheck = "Aim Shield Check", AimSticky = "VECTOR Sticky Target",
			ShowFov = "Aim FOV Circle", TargetCard = "Target Card", EspDistance = "Show Distance", EspHealth = "Show HP Bar", EspTools = "Show Tools",
			EspThroughWalls = "Through-wall Overlays", EspTeamCheck = "Hide Teammates", EspTeamColors = "Team Colors", Crosshair = "Crosshair", Hud = "Performance HUD"}
		for old, name in pairs(safe) do if type(cfg[old]) == "boolean" then W.setToggle(name, cfg[old]) end end
		V.importSettings({engine = "VECTOR", mode = cfg.AimMode, origin = cfg.AimOrigin, priority = cfg.AimPriority, part = cfg.AimPart, flightScheme = "VECTOR", teleportActivation = "Alt+Click", tracerOrigin = cfg.TracerOrigin, teamAttribute = cfg.TeamAttribute})
		K.activation = cfg.AimActivation == "Always" and "Always" or "RMB"
		V.healthText = cfg.EspHealth ~= false
		W.setToggle("Health Text", V.healthText)
		W.refreshChoices()
		flash("VECTOR settings imported. Active tools stay off; Fusion hotkeys are kept.", C.good)
		return true
	end

	function V.commandByTitle(title)
		for _, command in ipairs(W.commands) do
			if command.title == title and command.page ~= "Favorites" and command.page ~= "Home" then return command end
		end
	end

	function V.refreshFavorites()
		if not V.favoritesHolder then return end
		for _, child in ipairs(V.favoritesHolder:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		V.favoriteRows = {}
		local titles = {}
		for title, on in pairs(V.favorites) do if on and V.commandByTitle(title) then table.insert(titles, title) end end
		table.sort(titles)
		for index, title in ipairs(titles) do
			local command = V.commandByTitle(title)
			local row = W.new("Frame", V.favoritesHolder, {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panel, BorderSizePixel = 0, LayoutOrder = index, ZIndex = 101})
			corner(row, 10)
			local run = W.new("TextButton", row, {Size = UDim2.new(1, -43, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 102})
			local titleLabel = label(run, title, 12, C.text, true)
			titleLabel.Position, titleLabel.Size, titleLabel.ZIndex = UDim2.fromOffset(13, 5), UDim2.new(1, -26, 0, 22), 103
			local state = label(run, command.page, 10, C.dim)
			state.Position, state.Size, state.ZIndex = UDim2.fromOffset(13, 28), UDim2.new(1, -26, 0, 16), 103
			local remove = W.smallButton(row, "x", 28, 104, function() V.favorites[title] = nil V.refreshFavorites() end)
			remove.Position, remove.Size = UDim2.new(1, -36, 0.5, -14), UDim2.fromOffset(28, 28)
			run.Activated:Connect(function()
				if command.kind == "VALUE" then
					showPage(command.page)
					local section = W.sectionForRow[command.row]
					if section then section.SetOpen(true) end
					task.defer(function()
						if not W.running or not command.row.Parent then return end
						local page = W.pages[command.page]
						page.CanvasPosition = Vector2.new(0, math.max(0, page.CanvasPosition.Y + (command.row.AbsolutePosition.Y - page.AbsolutePosition.Y) / math.max(W.ui.targetScale or 1, 0.1) - 8))
						W.safe(command.run)
					end)
				else W.safe(command.run) end
			end)
			table.insert(V.favoriteRows, {command = command, label = state})
		end
		if #titles == 0 then
			local empty = label(V.favoritesHolder, "No pinned tools. Search below to add one.", 12, C.dim)
			empty.Size, empty.ZIndex = UDim2.new(1, 0, 0, 38), 102
		end
	end

	function V.searchFavorites()
		if not V.favoriteResults then return end
		for _, child in ipairs(V.favoriteResults:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		if V.favoriteQuery == "" then return end
		local count, seen = 0, {}
		for _, command in ipairs(W.commands) do
			local title = command.title
			if count < 12 and command.page ~= "Home" and command.page ~= "Favorites" and command.kind ~= "PAGE" and not seen[title]
				and string.find(string.lower(title .. " " .. command.page), V.favoriteQuery, 1, true) then
				seen[title], count = true, count + 1
				local b = W.smallButton(V.favoriteResults, "+  " .. title, 200, 102, function()
					local total = 0 for _, on in pairs(V.favorites) do if on then total = total + 1 end end
					if total >= 40 then flash("Favorites is limited to 40 tools.", C.warn) return end
					V.favorites[title] = true V.refreshFavorites() flash("Pinned " .. title, C.good)
				end)
				b.Size, b.LayoutOrder, b.TextXAlignment = UDim2.new(1, 0, 0, 38), count, Enum.TextXAlignment.Left
				W.new("UIPadding", b, {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)})
				b.TextTruncate = Enum.TextTruncate.AtEnd
			end
		end
	end

	function V.stepHUD()
		local target = K.currentPlayer
		local hum, root = target and getHum(target), target and getRoot(target)
		V.card.Visible = V.targetCard and K.enabled and hum ~= nil and root ~= nil and hum.Health > 0 and not W.open and not W.hiddenHUD
		if V.card.Visible then
			local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			V.cardName.Text = target.DisplayName
			V.cardInfo.Text = string.format("%d HP / %d studs / %s", math.ceil(hum.Health), math.floor((root.Position - camera.CFrame.Position).Magnitude), V.engine)
			V.cardFill.Size = UDim2.fromScale(ratio, 1)
		end
		if V.triggerReadout then V.triggerReadout.Text = V.triggerState or "OFF" end
		if W.ui.engineChip then W.ui.engineChip.Text = V.engine .. " ENGINE" end
		for _, entry in ipairs(V.favoriteRows) do
			local command = entry.command
			local value = command.object and command.object.Get and command.object.Get()
			entry.label.Text = command.page .. "  /  " .. (command.kind == "TOGGLE" and (value and "ON" or "OFF") or command.kind == "VALUE" and tostring(value) or "RUN")
			entry.label.TextColor3 = command.kind == "TOGGLE" and value and C.accent or C.dim
		end
		if W.fly and V.flightScheme == "VECTOR" then
			W.ui.flightStatus.Text = string.gsub(W.ui.flightStatus.Text, "Shift or Q down", "Ctrl/Q down; Shift boosts")
		end
	end

	function V.finishUI()
		V.favorites = { ["Aim Assist"] = true, ["Fly"] = true, ["Tool Trigger"] = true, ["Off-screen Arrows"] = true, ["Free Cam"] = true }
		V.refreshFavorites()
		local shutdown = W.new("BindableFunction", ui, {Name = "Shutdown"})
		shutdown.OnInvoke = function() W.cleanup() return true end
		W.ui.engineChip = nil
		V.loaded = true
	end

	V.card = W.new("Frame", hud, {Name = "FusionTargetCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -66), Size = UDim2.fromOffset(290, 72), BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, ZIndex = 26})
	corner(V.card, 12) stroke(V.card, C.accent, 1, 0.45)
	V.cardName = label(V.card, "", 13, C.text, true)
	V.cardName.Position, V.cardName.Size, V.cardName.ZIndex = UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 21), 27
	V.cardInfo = label(V.card, "", 10, C.dim)
	V.cardInfo.Position, V.cardInfo.Size, V.cardInfo.ZIndex = UDim2.fromOffset(14, 31), UDim2.new(1, -28, 0, 18), 27
	local rail = W.new("Frame", V.card, {Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 4), BackgroundColor3 = C.raised, BorderSizePixel = 0, ZIndex = 27})
	corner(rail, 2)
	V.cardFill = W.new("Frame", rail, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, ZIndex = 28})
	corner(V.cardFill, 2)

	do
		local p = W.pages.Aim
		heading(p, "vector aim")
		K.choice(p, "VECTOR Mode", {{"Smooth", "SMOOTH"}, {"Lock", "LOCK"}, {"Adaptive", "ADAPTIVE"}}, function() return V.mode end, function(value) V.mode = value K.clearTracking() end)
		K.choice(p, "VECTOR Aim Origin", {{"Center", "CENTER"}, {"Mouse", "MOUSE"}}, function() return V.origin end, function(value) V.origin = value K.clearTracking() end)
		K.choice(p, "VECTOR Priority", {{"Crosshair", "CROSSHAIR"}, {"Distance", "DISTANCE"}, {"Low health", "LOW HP"}}, function() return V.priority end, function(value) V.priority = value K.clearTracking() end)
		K.choice(p, "VECTOR Aim Part", {{"Head", "HEAD"}, {"Chest", "CHEST"}, {"Root", "ROOT"}, {"Auto", "AUTO"}}, function() return V.part end, function(value) V.part = value K.clearTracking() end)
		slider(p, "VECTOR Response", 1, 40, V.response, 1, function(value) V.response = value end)
		slider(p, "VECTOR Lead", 0, 0.3, V.lead, 3, function(value) V.lead = value end)
		toggle(p, "VECTOR Sticky Target", "Keep an eligible target until it leaves the aim radius.", function(value) V.sticky = value end).Set(true)
		note(p, "Response is turn speed: higher responds faster. VECTOR Lock snaps immediately. Adaptive adjusts speed from observed motion; it is a heuristic, not trained AI.")
		heading(p, "shared filters and display")
		slider(p, "Aim Distance", 25, 5000, V.distance, 0, function(value) V.distance = value K.clearTracking() end)
		toggle(p, "Aim Shield Check", "Skip characters with a visible ForceField instance.", function(value) V.shieldCheck = value K.clearTracking() end).Set(true)
		toggle(p, "Target Card", "Show the current aim target, health and distance.", function(value) V.targetCard = value end).Set(true)
		V.teamBox = input(p, "Optional team attribute name; blank uses Roblox teams", function(value)
			V.teamAttribute = string.sub(string.match(value, "^%s*(.-)%s*$") or "", 1, 64)
			K.clearTracking()
		end)
		note(p, "An attribute can be on the Player or Character. The same team filter is used by both aim engines and player overlays.")
		heading(p, "tool trigger")
		toggle(p, "Tool Trigger", "Activate the equipped standard Tool when a valid player is under the crosshair.", function(value) V.trigger = value if not value then V.releaseTool() end end)
		slider(p, "Trigger Delay", 0, 1, V.triggerDelay, 2, function(value) V.triggerDelay = value end)
		slider(p, "Trigger Interval", 0.06, 2, V.triggerInterval, 2, function(value) V.triggerInterval = value end)
		V.triggerReadout = readout(p, 64)
		note(p, "Hotkeys also includes an optional keyboard hold key. It works alongside RMB in HOLD RMB activation mode.")
		note(p, "Uses Tool:Activate(), not game-specific weapon remotes. Auto, manual fire, menus and camera modes pause it. A custom weapon may not respond.")
	end

	do
		local p = W.pages.Vision
		heading(p, "vector overlays")
		toggle(p, "Off-screen Arrows", "Direction markers for players outside the camera view.", function(value) V.arrows = value end)
		toggle(p, "Through-wall Overlays", "Off limits overlays to targets visible to the camera.", function(value) V.throughWalls = value end).Set(true)
		toggle(p, "Team Colors", "Use Roblox team colors instead of distance colors.", function(value) V.teamColors = value end)
		toggle(p, "Health Text", "Include a numeric health value in player name cards.", function(value) V.healthText = value end).Set(true)
		K.choice(p, "Tracer Origin", {{"Bottom", "BOTTOM"}, {"Center", "CENTER"}, {"Mouse", "MOUSE"}}, function() return V.tracerOrigin end, function(value) V.tracerOrigin = value end)
		heading(W.pages.Movement, "vector movement")
		toggle(W.pages.Movement, "Bunny Hop", "Hold Space to jump on landing. Pauses during automated movement.", function(value) V.bunnyHop = value end)
		K.choice(W.pages.Movement, "Flight Keys", {{"WRAITH", "WRAITH"}, {"VECTOR", "VECTOR"}}, function() return V.flightScheme end, function(value) V.flightScheme = value W.flightKeys = {} end)
		note(W.pages.Movement, "WRAITH: Space/E up, Shift/Q down. VECTOR: Space/E up, Ctrl/Q down, Shift boost. Both use WRAITH's single flight controller.")
		K.choice(W.pages.Movement, "Click Teleport Input", {{"Click", "CLICK"}, {"Alt+Click", "ALT + CLICK"}}, function() return V.teleportActivation end, function(value) V.teleportActivation = value end)
		slider(W.pages.Movement, "Flight Boost", 1, 4, V.flightBoost, 1, function(value) V.flightBoost = value end)
		slider(W.pages.Movement, "Anti-Fling Limit", 30, 600, W.flingCap, 0, function(value) W.flingCap = value end)
		heading(W.pages.Camera, "vector camera")
		slider(W.pages.Camera, "Freecam Sensitivity", 0.05, 1, V.freecamSensitivity, 3, function(value) V.freecamSensitivity = value end)
		heading(W.pages.World, "persistent overrides")
		toggle(W.pages.World, "No Fog", "Keep fog cleared locally. Fullbright takes priority while enabled.", function(value)
			V.noFog = value if not value then V.releaseOwner("fog") else V.stepVisuals() end
		end)
		toggle(W.pages.World, "Lock Clock", "Keep one local time of day. Fullbright takes priority while enabled.", function(value)
			V.clockLock = value if not value then V.releaseOwner("clock") else V.stepVisuals() end
		end)
		slider(W.pages.World, "Locked Clock Time", 0, 24, V.clockTime, 1, function(value) V.clockTime = value if V.clockLock then V.stepVisuals() end end)
		heading(W.pages.Hunter, "vector alerts")
		toggle(W.pages.Hunter, "Nearby Alert", "Warn about the nearest non-teammate within your selected radius.", function(value) V.nearbyAlert = value end)
		slider(W.pages.Hunter, "Nearby Radius", 5, 300, V.nearbyRadius, 0, function(value) V.nearbyRadius = value end)
		toggle(W.pages.Hunter, "Join / Leave Alerts", "Small notices when a player joins or leaves.", function(value) V.joinAlert = value end)
	end

	do
		local p = W.pages.Favorites
		heading(p, "pinned tools")
		V.favoritesHolder = W.new("Frame", p, {Name = "PinnedTools", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 101})
		W.new("UIListLayout", V.favoritesHolder, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7)}) ord(V.favoritesHolder)
		heading(p, "add a tool")
		local search = input(p, "Search a toggle, setting or action to pin...", function() end)
		search:GetPropertyChangedSignal("Text"):Connect(function() V.favoriteQuery = string.lower(search.Text) V.searchFavorites() end)
		V.favoriteResults = W.new("Frame", p, {Name = "PinSearch", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 101})
		W.new("UIListLayout", V.favoriteResults, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}) ord(V.favoriteResults)
		note(p, "Favorites are included in Fusion profile exports. Value controls open their original page before editing.")
	end

	do
		local p = W.pages.Presets
		heading(p, "vector presets")
		for _, name in ipairs({"VECTOR SMOOTH", "VECTOR LOCK", "VECTOR OVERLAY", "VECTOR FULL"}) do
			button(p, name, function() V.applyPreset(name) end)
		end
		note(p, "VECTOR presets preserve player exclusions. They never start flight, Auto or the tool trigger.")
		heading(W.pages.Profiles, "vector v1 migration")
		button(W.pages.Profiles, "IMPORT VECTOR V1 PROFILE", function() V.importVector(W.ui.profileBox.Text) end)
		note(W.pages.Profiles, "Paste VECTOR's exported JSON into the box above. Numeric settings and passive filters are migrated. Fusion keeps its collision-free hotkeys; active tools stay off.")
	end

	for _, name in ipairs({"Off-screen Arrows", "Health Text"}) do table.insert(W.presets.esp, name) end
	for _, name in ipairs({"Nearby Alert", "Join / Leave Alerts"}) do table.insert(W.presets.alerts, name) end
	for _, name in ipairs({"Aim Shield Check", "VECTOR Sticky Target", "Target Card", "Through-wall Overlays", "Team Colors", "Health Text"}) do W.profileSafeToggles[name] = true end




end


W.fallback = {on = false, distance = 12, sensitivity = 0.0035}
function W.stopFallback()
	local state = W.fallback
	if not state or not state.on then return end
	state.on = false
	if state.hum and state.hum.Parent then pcall(function() state.hum:Move(Vector3.zero, false) end) end
	state.hum, state.root = nil, nil
	W.restoreCamera()
	local toggleObject = W.toggles["Fallback Controls"]
	if toggleObject then toggleObject.state = false pcall(toggleObject.Render) end
end
function W.startFallback()
	local root, hum = getRoot(player), getHum(player)
	if not root or not hum or hum.Health <= 0 then flash("Wait for your character before using fallback controls.", C.warn) return false end
	if root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) then flash("The game has anchored your character. Fallback does not remove game-owned anchors.", C.warn) return false end
	if hum.SeatPart or hum.PlatformStand or hum.WalkSpeed <= 0 or hum.EvaluateStateMachine == false then
		flash("Game movement is disabled or seated. See Dashboard > Control status; fallback has not changed it.", C.warn)
		return false
	end
	W.releaseMovement("Fallback controller enabled", true)
	W.closeInput()
	W.captureCamera()
	local look = camera.CFrame.LookVector
	W.fallback.yaw, W.fallback.pitch = math.atan2(-look.X, -look.Z), math.asin(math.clamp(look.Y, -1, 1))
	W.fallback.root, W.fallback.hum, W.fallback.on = root, hum, true
	W.ownCameraType(Enum.CameraType.Scriptable)
	W.ownMouse(Enum.MouseBehavior.LockCenter)
	setStatus("Fallback active / WASD + mouse / Space jump / F7 or F8 exit")
	return true
end
function W.toggleFallback()
	if W.fallback.on then W.stopFallback() else W.setToggle("Fallback Controls", true) end
end
function W.stepFallback(dt)
	local state = W.fallback
	if not state.on then return end
	local root, hum = getRoot(player), getHum(player)
	if root ~= state.root or hum ~= state.hum or not hum or hum.Health <= 0 or W.open or W.inputBlockReason() then W.stopFallback() return end
	if root.Anchored or hum.SeatPart or hum.PlatformStand or hum.WalkSpeed <= 0 then W.stopFallback() return end
	local delta = UIS:GetMouseDelta()
	state.yaw, state.pitch = state.yaw - delta.X * state.sensitivity, math.clamp(state.pitch - delta.Y * state.sensitivity, -1.3, 1.3)
	local yaw = CFrame.Angles(0, state.yaw, 0)
	hum:Move(W.readMoveVector(yaw), false)
	if UIS:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true end
	local pivot = root.Position + Vector3.new(0, 2, 0)
	local direction = CFrame.fromEulerAnglesYXZ(state.pitch, state.yaw, 0).LookVector
	local offset = -direction * state.distance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character, W.worldFolder}
	params.IgnoreWater = true
	local hit = workspace:Raycast(pivot, offset, params)
	local position = hit and (hit.Position + hit.Normal * 0.35) or (pivot + offset)
	W.ownCameraType(Enum.CameraType.Scriptable)
	W.ownCameraFrame(CFrame.lookAt(position, pivot + direction * 4))
	camera.Focus = CFrame.new(pivot)
	W.ownMouse(Enum.MouseBehavior.LockCenter)
end
function W.refreshControlStatus()
	if not W.ui.controlLive then return end
	local root, h = getRoot(player), getHum(player)
	local owner = W.fallback.on and "FALLBACK" or W.fly and "FLIGHT" or W.freecam and "FREECAM" or W.auto.running and "AUTO" or W.follow and "FOLLOW" or W.orbit and "ORBIT" or W.macroPlay and "ROUTE" or W.ugState ~= "SURFACE" and "UNDERGROUND" or "GAME / NATIVE"
	local reason = W.inputBlockReason()
	if root and (root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored)) then reason = "Game-owned anchor is active"
	elseif h and h.PlatformStand then reason = "Humanoid PlatformStand is active"
	elseif h and h.WalkSpeed <= 0 then reason = "Game WalkSpeed is zero"
	elseif h and h.EvaluateStateMachine == false then reason = "Humanoid state machine disabled"
	elseif h and h.SeatPart then reason = "Character is seated" end
	W.ui.controlLive.Text = string.format("%s  |  Camera: %s\nWASD: %s  |  Speed: %s  |  State: %s\n%s", owner,
		camera and camera.CameraType.Name or "None", W.manualMovementHeld() and "received" or "idle", h and tostring(h.WalkSpeed) or "--",
		h and h:GetState().Name or "No character", reason or "No obvious local lock. F8 stops tools; F7 uses fallback controls.")
	W.ui.controlLive.TextColor3 = reason and C.warn or C.dim
end
heading(W.pages.Movement, "Recovery controls")
toggle(W.pages.Movement, "Fallback Controls", "F7 explicitly replaces local movement input and camera. No PlayerModule is imported. F7/F8 stops it; game-owned anchors and state restrictions are respected.", function(on)
	if on then return W.startFallback() end
	W.stopFallback()
	return true
end)
slider(W.pages.Movement, "Fallback Camera Distance", 3, 30, 12, 1, function(v) W.fallback.distance = v end)
button(W.pages.Movement, "STOP CONTROLLERS / F8", W.emergencyRelease)
W.motionToggles["Fallback Controls"] = true


W.hotkeys.register("menu", "Open / close panel", Enum.KeyCode.Insert, function() W.setOpen(not W.open) end, "Actions")
W.hotkeys.register("preset", "Apply Karma preset", Enum.KeyCode.F6, W.presets.apply, "Actions")
W.hotkeys.register("aim_hold", "Hold aim: keyboard alternative", nil, function() end, "Actions")
W.hotkeys.register("auto", "Backstab Sweep: start / stop", Enum.KeyCode.KeypadZero, W.auto.toggle, "Actions")
W.hotkeys.register("esp", "All ESP: on / off", Enum.KeyCode.H, function() W.presets.toggleGroup(W.presets.esp) end, "Actions")
W.hotkeys.register("alerts", "All alerts: on / off", nil, function() W.presets.toggleGroup(W.presets.alerts) end, "Actions")
W.hotkeys.register("reset_combat", "Reset aim, ESP and alerts", nil, function() W.restoreSettings("Combat") end, "Actions")
W.hotkeys.register("reset_movement", "Reset movement settings", nil, function() W.restoreSettings("Movement") end, "Actions")
W.hotkeys.register("reset_all", "Reset all settings", nil, function() W.restoreSettings() end, "Actions")
W.hotkeys.register("unload", "Unload Fusion", Enum.KeyCode.F10, function() W.cleanup() end, "Actions")
for _, command in ipairs(W.commands) do
	if command.kind == "TOGGLE" and command.title ~= "Backstab Sweep" then
		local object, name = command.object, command.title
		local default = name == "Fly" and Enum.KeyCode.F or name == "Aim Assist" and Enum.KeyCode.Z or name == "Free Cam" and Enum.KeyCode.F4 or name == "Fullbright" and Enum.KeyCode.F3 or nil
		W.hotkeys.register("toggle:" .. name, name, default, function() object.Set(not object.Get()) end, command.page)
	end
end

do
	local p = W.pages.Presets
	heading(p, "one preset")
	note(p, "KARMA / LOCK + ESP\nAim ON  /  LOCK  /  HOLD RIGHT MOUSE\nFOV circle ON  /  radius 1000 pixels  /  smoothness 1\nEvery ESP layer and every alert enabled.")
	button(p, "APPLY KARMA PRESET", W.presets.apply)
	note(p, "Hold RMB activates this preset; releasing it returns manual look. Smoothness 1 is instant aim. The FOV radius is kept at 1000 even when the circle extends beyond your screen. AIM / SKIP and MATE exclusions are preserved.")
	heading(p, "resets")
	button(p, "RESET AIM + ESP + ALERTS", function() W.restoreSettings("Combat") end)
	button(p, "RESET MOVEMENT SETTINGS", function() W.restoreSettings("Movement") end)
	button(p, "RESET ALL SETTINGS", function() W.restoreSettings() end)
	note(p, "Resets stop Auto, release its right-click and keep your saved positions, recordings and player exclusions. Reset All also restores default hotkeys.")
end

do
	local p, A = W.pages.Auto, W.auto
	heading(p, "backstab sweep")
	toggle(p, "Backstab Sweep", "Assume ready: right-click immediately, then sweep. Held equipment is ignored.", function(on)
		if on then return A.start() end
		A.stop(A.running and "Sweep stopped" or A.message, false)
		return true
	end)
	A.keyLabel = note(p, "START / STOP: NUM 0     |     F8: emergency release")
	A.readout = readout(p, 162)
	button(p, "CHANGE SWEEP HOTKEY", function() W.hotkeys.captureKey("auto") end)
	note(p, "No knife, Tool, Backpack, weapon name or equipped-state checks. Start right-clicks immediately, then continues the sweep. Changing or removing equipment does not stop Auto. AIM players are included; SKIP and MATE are excluded. Moving or opening the panel cancels.")
	heading(p, "timing and positioning")
	slider(p, "Backstab Distance", 1.5, 8, A.distance, 1, function(v) A.distance = v end)
	slider(p, "Backstab Height Offset", -3, 3, A.height, 1, function(v) A.height = v end)
	slider(p, "Backstab Click Interval", 0.15, 2, A.interval, 2, function(v) A.interval = v end)
	slider(p, "Backstab Settle Time", 0.1, 1, A.settle, 2, function(v) A.settle = v end)
	slider(p, "Backstab Target Timeout", 2, 30, A.timeout, 0, function(v) A.timeout = v end)
	W.kar.choice(p, "After finishing", {{true, "RETURN"}, {false, "STAY"}}, function() return A.returnAfter end, function(v) A.returnAfter = v end)
	note(p, "Return happens only after a completed sweep, never after manual cancellation. Auto does not change WalkSpeed, PlatformStand, anchoring or the humanoid's state.")
	heading(p, "direct right-click")
	note(p, "Auto only sends right-click input; it does not equip or activate a Tool. The separate Tool Trigger switches OFF when a sweep starts and stays off afterward. Your game decides what right-click does. Missing input support still stops Auto before movement.")
	A.refresh()
end

do
	local p, H = W.pages.Hotkeys, W.hotkeys
	heading(p, "key bindings")
	H.status = note(p, "")
	note(p, "F8: emergency recovery  /  End: stop active tools\nK: panel shortcut  /  Ctrl+K: search\nBindings do not fire while you type. Movement keys cannot be assigned.")
	button(p, "RESET ALL HOTKEYS", function() H.resetAll() end)
	local previousGroup
	for _, id in ipairs(H.order) do
		local item = H.items[id]
		if item.group ~= previousGroup then heading(p, item.group) previousGroup = item.group end
		local row = W.new("Frame", p, {Name = "HotkeyRow", Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 101})
		corner(row, 10)
		stroke(row, C.raised, 1, 0.6)
		ord(row)
		local title = label(row, item.title, 12, C.text, true)
		title.Position, title.Size, title.ZIndex = UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 21), 102
		local key = W.smallButton(row, H.keyName(item.key), 110, 104, function() H.captureKey(id) end)
		key.Position, key.Size = UDim2.fromOffset(12, 32), UDim2.new(0.42, -16, 0, 26)
		local reset = W.smallButton(row, "DEFAULT", 79, 104, function() H.resetOne(id) end)
		reset.Position, reset.Size = UDim2.new(0.42, 2, 0, 32), UDim2.new(0.30, -8, 0, 26)
		local clear = W.smallButton(row, "CLEAR", 65, 104, function() H.cancelCapture() H.assign(id, nil) end)
		clear.Position, clear.Size = UDim2.new(0.72, 2, 0, 32), UDim2.new(0.28, -14, 0, 26)
		H.rows[id] = {key = key, row = row}
	end
	H.refresh()
end

W.bind(RunService.PreSimulation, function()
	if not W.running or not W.auto.running then return end
	local ok, err = pcall(W.auto.step)
	if not ok then W.auto.stop("Auto error: " .. tostring(err), false) W.reportError("Auto", err) end
end)
W.bind(RunService.Heartbeat, function()
	if W.running then
		W.auto.watch()
		if W.auto.running then W.auto.refresh() end
	end
end)

function W.inputBlockReason()
	if not W.running then return "STOPPED" end
	local focus = UIS:GetFocusedTextBox()
	if focus then return "TYPING / " .. focus.Name end
	local ok, menu = pcall(function() return W.GuiService.MenuIsOpen end)
	if ok and menu then return "ROBLOX MENU OPEN" end
	if not W.windowFocused then return "WINDOW UNFOCUSED" end
	return nil
end
function W.canMove() return W.inputBlockReason() == nil end
function W.key(code) return W.canMove() and UIS:IsKeyDown(code) end
function W.canLook() return W.canMove() and not W.open end
function W.readMoveVector(cf)
	if not W.canMove() then return Vector3.zero end
	local x, z = 0, 0
	if UIS:IsKeyDown(Enum.KeyCode.W) or UIS:IsKeyDown(Enum.KeyCode.Up) then z = z - 1 end
	if UIS:IsKeyDown(Enum.KeyCode.S) or UIS:IsKeyDown(Enum.KeyCode.Down) then z = z + 1 end
	if UIS:IsKeyDown(Enum.KeyCode.A) or UIS:IsKeyDown(Enum.KeyCode.Left) then x = x - 1 end
	if UIS:IsKeyDown(Enum.KeyCode.D) or UIS:IsKeyDown(Enum.KeyCode.Right) then x = x + 1 end
	if x == 0 and z == 0 and UIS.GamepadEnabled then
		pcall(function() for _, item in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if item.KeyCode == Enum.KeyCode.Thumbstick1 and Vector2.new(item.Position.X, item.Position.Y).Magnitude > 0.15 then x, z = item.Position.X, -item.Position.Y end
		end end)
	end
	if x == 0 and z == 0 and UIS.TouchEnabled then local h = getHum(player) if h then return h.MoveDirection end end
	local move = cf.RightVector * x - cf.LookVector * z
	return move.Magnitude > 1 and move.Unit or move
end


function W.flightKey(code)
	local ok, held = pcall(function() return UIS:IsKeyDown(code) end)
	if ok then
		W.flightKeys[code] = held and true or nil
		return held
	end
	return W.flightKeys[code] == true
end

function W.readFlightVector()
	W.flightBlockReason = W.inputBlockReason()
	W.flightInputSource = "IDLE"
	if W.flightBlockReason then return Vector3.zero end
	local cf = camera.CFrame
	local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if forward.Magnitude < 0.001 then forward = Vector3.new(cf.RightVector.Z, 0, -cf.RightVector.X) end
	if forward.Magnitude < 0.001 then forward = Vector3.new(0, 0, -1) end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local ahead = W.flightKey(Enum.KeyCode.W) or W.flightKey(Enum.KeyCode.Up)
	local back = W.flightKey(Enum.KeyCode.S) or W.flightKey(Enum.KeyCode.Down)
	local left = W.flightKey(Enum.KeyCode.A) or W.flightKey(Enum.KeyCode.Left)
	local rightHeld = W.flightKey(Enum.KeyCode.D) or W.flightKey(Enum.KeyCode.Right)
	local ascend = W.flightKey(Enum.KeyCode.Space) or W.flightKey(Enum.KeyCode.E)
	local descend = W.flightKey(W.vector.flightScheme == "VECTOR" and Enum.KeyCode.LeftControl or Enum.KeyCode.LeftShift) or W.flightKey(Enum.KeyCode.Q)
	local x = (rightHeld and 1 or 0) - (left and 1 or 0)
	local z = (ahead and 1 or 0) - (back and 1 or 0)
	local keyboard = ahead or back or left or rightHeld
	local gamepadUp, gamepadDown = false, false
	if keyboard or ascend or descend then W.flightInputSource = "KEYBOARD" end
	if UIS.GamepadEnabled then
		pcall(function()
			for _, item in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
				if item.KeyCode == Enum.KeyCode.Thumbstick1 and not keyboard then
					local stick = Vector2.new(item.Position.X, item.Position.Y)
					if stick.Magnitude > 0.15 then
						local scaled = stick.Unit * math.clamp((stick.Magnitude - 0.15) / 0.85, 0, 1)
						x, z = scaled.X, scaled.Y
						W.flightInputSource = "GAMEPAD"
					end
				elseif item.KeyCode == Enum.KeyCode.ButtonR1 then
					gamepadUp = item.UserInputState ~= Enum.UserInputState.End
						and item.UserInputState ~= Enum.UserInputState.Cancel and item.Position.Z > 0
				elseif item.KeyCode == Enum.KeyCode.ButtonL1 then
					gamepadDown = item.UserInputState ~= Enum.UserInputState.End
						and item.UserInputState ~= Enum.UserInputState.Cancel and item.Position.Z > 0
				end
			end
		end)
	end
	local move = right * x + forward * z
	if not keyboard and move.Magnitude < 0.001 and UIS.TouchEnabled then
		local h = getHum(player)
		if h then move = Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z) end
		if move.Magnitude > 0.01 then W.flightInputSource = "TOUCH" end
	end


	local up = ascend or W.touchUp or gamepadUp
	local down = descend or W.touchDown or gamepadDown
	if W.touchUp or W.touchDown then W.flightInputSource = "TOUCH" end
	if gamepadUp or gamepadDown then W.flightInputSource = "GAMEPAD" end
	move = move + Vector3.yAxis * ((up and 1 or 0) - (down and 1 or 0))
	if move.Magnitude > 1 then move = move.Unit end
	return move
end

W.controlModule = nil


function W.updateStats(elapsed)
	W.fps = math.floor(W.frameCount / math.max(elapsed, 0.001) + 0.5)
	local frameMs = elapsed / math.max(W.frameCount, 1) * 1000
	W.frameCount = 0
	W.ping = "--"
	pcall(function() W.ping = math.floor(player:GetNetworkPing() * 1000 + 0.5) .. " ms" end)
	local active = {}
	for _, name in ipairs({"Fly", "Lock Walkspeed", "Noclip", "Infinite Jump", "Hold-Jump Float", "Click Teleport", "Custom Gravity", "Anti-Fling", "Follow", "Orbit Target", "Player Names", "Box ESP", "Bone Rig", "Ground HP Bar", "Tracer Lines", "Silhouette", "Hunter Radar", "Free Cam", "Camera Lock", "Spectate Target", "Fullbright", "Custom Jump", "Custom FOV", "Inspect Mode", "Watch New Scripts", "Aim Assist", "Approach Assist", "Hit Tracker", "World Player Beams", "3D Cursor Orb", "Directional Radar"}) do
		if W.toggles[name] and W.toggles[name].Get() then table.insert(active, name) end
	end
	if W.macroPlay then table.insert(active, "Route playback") end
	if W.macroRec then table.insert(active, "Route recording") end
	if W.ugState ~= "SURFACE" then table.insert(active, "Underground") end
	for _, name in ipairs({"Tool Trigger", "Off-screen Arrows", "Bunny Hop", "No Fog", "Lock Clock", "Nearby Alert", "Join / Leave Alerts", "Backstab Sweep"}) do
		if W.toggles[name] and W.toggles[name].Get() then table.insert(active, name) end
	end
	local count = #Players:GetPlayers()
	local uptime = math.floor(os.clock() - W.sessionStart)
	local timeText = string.format("%02d:%02d", math.floor(uptime / 60), uptime % 60)
	W.ui.metrics.FPS.Text = tostring(W.fps)
	W.ui.metrics.PLAYERS.Text = tostring(count)
	W.ui.metrics.ACTIVE.Text = tostring(#active)
	W.ui.footerStats.Text = W.ui.compact and (W.fps .. " FPS") or (W.fps .. " FPS / WOOD")
	W.ui.session.Text = string.format("PLAYER   %s\nSESSION  %s\nPLACE    %s\nTARGET   %s", player.DisplayName, timeText, tostring(game.PlaceId), W.target and W.target.DisplayName or "None")
	W.ui.active.Text = #active == 0 and "No active tools.\nUse the sidebar or search to get started." or table.concat(active, "  /  ")
	W.ui.active.TextColor3 = #active == 0 and C.dim or C.accent
	W.ui.perfOut.Text = string.format("FPS       %d\nFRAME     %.1f ms\nPING      %s\nSESSION   %s", W.fps, frameMs, W.ping, timeText)
	W.ui.performance.Text = W.fps .. " FPS  /  " .. W.ping
	W.ui.graphTitle.Text = string.format("%.1f ms / frame   |   latest 32 samples", frameMs)
	table.insert(W.samples, frameMs)
	if #W.samples > 32 then table.remove(W.samples, 1) end
	for i, bar in ipairs(W.ui.graphBars) do
		local sample = W.samples[i]
		bar.Size = UDim2.new(1 / 32, -2.5, 0, sample and math.clamp(sample / 50 * 46, 2, 46) or 2)
		bar.BackgroundColor3 = sample and sample > 33.4 and C.warn or C.accent2
	end
	if W.logDirty and (W.page == "System" or W.page == "Home") then
		local lines = {}
		for _, entry in ipairs(W.logs) do table.insert(lines, string.format("%6.1fs  %-6s %s", entry.t, entry.level, entry.text)) end
		W.ui.logOut.Text = #lines > 0 and table.concat(lines, "\n") or "The session log is empty."
		W.logDirty = false
	end
end

function W.updateFlight(dt, root, hum)
	local body = W.flightBody
	if not body or body.root ~= root or body.hum ~= hum then
		W.stopFlight("Flight stopped: character changed.") return
	end
	local assembly = root.AssemblyRootPart
	if root.Anchored or (assembly and assembly.Anchored) then
		W.stopFlight("Flight stopped: your character is anchored by the game.") return
	end
	if hum.SeatPart or hum.PlatformStand then
		W.stopFlight("Flight stopped: the character became seated or locked. F8 releases WRAITH.") return
	end
	local mass = root.AssemblyMass
	if mass ~= mass or mass <= 0 or mass == math.huge then error("Invalid character assembly mass.") end
	local direction = W.readFlightVector()
	if W.flightBlockReason then
		W.stopFlight("Flight released: " .. W.flightBlockReason)
		return
	end
	local rig = W.makeFlyRig(root)
	W.flightDirection = direction
	local boost = W.vector.flightScheme == "VECTOR" and W.flightKey(Enum.KeyCode.LeftShift) and W.vector.flightBoost or 1
	local requested = direction * math.clamp(W.flySpeed, 10, 400) * boost
	if not W.flightBlockReason and os.clock() < (W.flightTakeoffUntil or 0) then
		requested = requested + Vector3.yAxis * 12
	end
	W.flightRequested = requested
	W.flightVelocity = requested.Magnitude < 0.01 and Vector3.zero
		or W.flightVelocity:Lerp(requested, 1 - math.exp(-20 * math.clamp(dt, 0, 0.1)))
	rig.velocity.MaxForce = math.max(100000, mass * (workspace.Gravity + 4000))
	rig.velocity.VectorVelocity = W.flightVelocity
	rig.velocity.Enabled = true
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.001 then rig.facing.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit) end
	local observed = (root.Position - rig.previousPosition).Magnitude / math.max(dt, 0.001)
	W.flightObservedSpeed = observed
	if requested.Magnitude > 3 and observed < 0.25 then
		W.flightBlockedTime = (W.flightBlockedTime or 0) + dt
	else W.flightBlockedTime = 0 end
	rig.previousPosition = root.Position
	W.lastFlightTick = os.clock()
	if W.flightBlockedTime > 2 then
		W.stopFlight("Flight stopped: input was received but the character did not move. Check collisions or another controller.")
	end
end

function W.stepFlight(dt)
	if not W.fly then return end
	local ok, err = xpcall(function()
		local root, hum = getRoot(player), getHum(player)
		if not W.running or not root or not hum or hum.Health <= 0 then
			W.stopFlight()
			return
		end
		W.updateFlight(math.clamp(dt, 0, 0.1), root, hum)
	end, debug.traceback)
	if not ok then
		W.stopFlight()
		W.lastFlightIssue = tostring(err)
		pcall(W.reportError, "Flight", err)
	end
end

function W.watchFlight()
	if not W.fly then return end
	if not W.lastFlightTick or os.clock() - W.lastFlightTick > 0.75 then
		W.stopFlight("Flight stopped: movement updates stalled. Character released.")
	end
end

function W.updateMovement(dt)
	if W.fly then return end
	local root, hum = getRoot(player), getHum(player)
	if root and hum and hum.Health > 0 then
		if root.Anchored or (root.AssemblyRootPart and root.AssemblyRootPart.Anchored) or hum.SeatPart or hum.Sit or hum.PlatformStand then
			W.releaseMovement("Movement stopped: character became anchored, seated or locked", false)
			return
		end
		if W.macroPlay or W.ugState ~= "SURFACE" then
		elseif W.orbit then
			local tr = W.target and getRoot(W.target)
			if tr and allowed(W.target) then
				W.setBody(true)
				W.orbitA = W.orbitA + W.orbitS * dt
				local off = Vector3.new(math.cos(W.orbitA) * W.orbitR, W.orbitH, math.sin(W.orbitA) * W.orbitR)
				root.CFrame = CFrame.lookAt(tr.Position + off, tr.Position)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			else W.setToggle("Orbit Target", false) end
		elseif W.follow then
			local tr = W.target and getRoot(W.target)
			if tr and allowed(W.target) then
				W.setBody(true)
				local goal = tr.Position - tr.CFrame.LookVector * W.followD + Vector3.new(0, W.followH, 0)
				root.CFrame = CFrame.lookAt(root.Position:Lerp(goal, 1 - math.exp(-W.followSmooth * dt)), tr.Position)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			else W.setToggle("Follow", false) end
		end
		if W.float and not W.fly and not W.macroPlay and W.ugState == "SURFACE" and not W.orbit and not W.follow and W.canMove() then
			if W.key(Enum.KeyCode.Space) or os.clock() < W.jumpUntil then
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, W.floatPow, v.Z)
			end
		end
	end
end

function W.watchOwnedControls()
	if not W.freecam and W.freecamSinkOwned then
		W.freecamSinkOwned = false
		pcall(function() CAS:UnbindAction("FUSION6_Freecam") end)
		pcall(function() CAS:UnbindAction("W_FreecamSink") end)
	end
	if not W.fly and W.flyRig then W.stopFlyRig() end
	if not W.freecam and not W.camLock and not W.spectate and not (W.fallback and W.fallback.on) and (W.cameraOwned or W.cameraBak) then W.restoreCamera() end
end

function W.updateCamera(dt)
	if W.freecam then
		if W.inputBlockReason() then W.setToggle("Free Cam", false) return end
		if not W.cameraBak or W.cameraBak.camera ~= camera then W.setToggle("Free Cam", false) return end
		local delta = UIS:GetMouseDelta()
		W.fcYaw = W.fcYaw - delta.X * math.rad(W.vector.freecamSensitivity)
		W.fcPitch = math.clamp(W.fcPitch - delta.Y * math.rad(W.vector.freecamSensitivity), -1.45, 1.45)
		local rot = CFrame.fromEulerAnglesYXZ(W.fcPitch, W.fcYaw, 0)
		local move = W.readMoveVector(rot)
		if W.key(Enum.KeyCode.E) then move = move + Vector3.yAxis end
		if W.key(Enum.KeyCode.Q) then move = move - Vector3.yAxis end
		local desired = move / math.max(1, move.Magnitude) * W.fcSpeed * (W.key(Enum.KeyCode.LeftShift) and 3 or 1)
		W.fcVelocity = W.fcVelocity:Lerp(desired, 1 - math.exp(-11 * dt))
		W.fcPos = W.fcPos + W.fcVelocity * dt
		W.ownCameraType(Enum.CameraType.Scriptable)
		W.ownCameraFrame(CFrame.new(W.fcPos) * rot)
		camera.Focus = camera.CFrame * CFrame.new(0, 0, -16)
		W.ownMouse(Enum.MouseBehavior.LockCenter)
	elseif W.camLock then
		local root = W.target and getRoot(W.target)
		if root and allowed(W.target) then
			W.ownCameraType(Enum.CameraType.Scriptable)
			W.ownCameraFrame(camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, root.Position), 1 - math.exp(-11.9 * dt)))
		else W.setToggle("Camera Lock", false) end
	elseif W.spectate then
		local h = W.target and getHum(W.target)
		if h and allowed(W.target) then
			W.ownCameraType(Enum.CameraType.Custom)
			if camera.CameraSubject ~= h then camera.CameraSubject = h end
			if W.cameraBak then W.cameraBak.lastSubject = h end
		else W.setToggle("Spectate Target", false) end
	end
	if W.fovOn then camera.FieldOfView = W.fov end
end


function W.updateHUD()
	if W.refreshControlStatus then W.refreshControlStatus() end
	if W.ui.movementStatus then
		local h, r = getHum(player), getRoot(player)
		local owner = W.auto.running and "BACKSTAB SWEEP" or W.fly and "FLIGHT" or W.freecam and "FREECAM" or W.follow and "FOLLOW"
			or W.orbit and "ORBIT" or W.macroPlay and "ROUTE" or W.ugState ~= "SURFACE" and "UNDERGROUND"
			or W.kar.approachBody and "APPROACH" or "NORMAL MOVEMENT"
		W.ui.movementStatus.Text = string.format("%s  |  F8: release\nState: %s  |  WalkSpeed: %s\nAnchored: %s  |  PlatformStand: %s\n%s",
			owner, h and h:GetState().Name or "No character", h and tostring(h.WalkSpeed) or "--",
			tostring(r and r.Anchored or false), tostring(h and h.PlatformStand or false),
			W.lastRelease or "Aim controls the camera only; approach is separate.")
	end
	setMacroStatus()
	W.ui.crosshair.Visible = W.crosshair and not W.open and not W.hiddenHUD
	local lines, size, gap = W.ui.crossLines, W.crossSize, W.crossGap
	lines[1].Position = UDim2.fromOffset(-gap - size, -1) lines[1].Size = UDim2.fromOffset(size, 2)
	lines[2].Position = UDim2.fromOffset(gap, -1) lines[2].Size = UDim2.fromOffset(size, 2)
	lines[3].Position = UDim2.fromOffset(-1, -gap - size) lines[3].Size = UDim2.fromOffset(2, size)
	lines[4].Position = UDim2.fromOffset(-1, gap) lines[4].Size = UDim2.fromOffset(2, size)
	W.ui.performance.Visible = W.perfHud == true and not W.hiddenHUD
	W.ui.touchFlight.Visible = UIS.TouchEnabled and W.fly and not W.hiddenHUD
	local root = getRoot(player)
	if W.fly then
		local speed = root and root.AssemblyLinearVelocity.Magnitude or 0
		local reason = W.inputBlockReason()
		local blocked = (W.flightBlockedTime or 0) > 0.8
		local state = reason and "PAUSED" or (blocked and "BLOCKED" or (speed > 2 and "MOVING" or "HOVERING"))
		local hint = reason or (blocked and "Input received; a wall or another controller may be stopping movement.")
			or "WASD move  /  Space or E up  /  Shift or Q down"
		W.ui.flightStatus.Text = string.format("FLIGHT %s  |  %s  |  %.0f studs/s\n%s", state, W.flightInputSource or "IDLE", speed, hint)
		W.ui.flightStatus.TextColor3 = (reason or blocked) and C.warn or C.accent
	else
		W.ui.flightStatus.Text = "FLIGHT OFF\n" .. (W.lastFlightIssue or "WASD move / Space-E up / Shift-Q down / F8 release")
		W.ui.flightStatus.TextColor3 = C.dim
	end
end

W.visualAcc, W.slowAcc, W.statsAcc = 0, 0, 0
W.bind(RunService.PreSimulation, function(dt)
	if not W.running or W.initializing then return end
	dt = math.clamp(dt, 0, 0.1)
	if W.noclip then W.guard("Noclip", W.updateCollisions) end
	if W.follow or W.orbit or W.macroPlay or W.ugState ~= "SURFACE" then W.guard("Manual override", W.checkManualOverride) end
	if W.macroRec or W.macroPlay or W.ugState ~= "SURFACE" then
		if not W.guard("Route", W.updateRoute, dt) then W.releaseMovement("Route stopped after an error", true) end
	end
	if W.vector.bunnyHop then W.guard("Bunny hop", W.vector.stepBunnyHop) end
	if W.follow or W.orbit or W.float then
		if not W.guard("Movement", W.updateMovement, dt) then W.releaseMovement("Movement stopped after an error", true) end
	end
	if W.fly then W.stepFlight(dt) end
end)
W.renderName = "WRAITH_VECTOR_V6_Camera"
RunService:UnbindFromRenderStep(W.renderName)
RunService:BindToRenderStep(W.renderName, Enum.RenderPriority.Last.Value + 1, function(dt)
	if not W.running or W.initializing then return end
	local current = workspace.CurrentCamera
	if not current then return end
	camera = current
	W.frameCount, W.statsAcc, W.visualAcc = W.frameCount + 1, W.statsAcc + dt, W.visualAcc + dt
	if W.fallback and W.fallback.on then
		if not W.guard("Fallback", W.stepFallback, math.min(dt, 0.1)) then W.stopFallback() end
	elseif W.freecam or W.camLock or W.spectate or W.fovOn then
		if not W.guard("Camera", W.updateCamera, math.min(dt, 0.1)) then W.releaseMovement("Camera stopped after an error", true) end
	end
	if W.kar.enabled then if not W.guard("Aim", W.kar.updateAim, dt) then W.kar.stopAim() end end
	if W.vector.trigger then if not W.guard("Tool trigger", W.vector.stepTrigger) then W.setToggle("Tool Trigger", false) W.vector.releaseTool() end end
	if W.auto.running then if not W.guard("Auto camera", W.auto.aimCamera) then W.auto.stop("Camera error", false) end end
	if W.kar.approachOn then if not W.guard("Approach", W.kar.updateApproach) then W.setToggle("Approach Assist", false) end end
	if W.visualAcc >= 1 / (W.espHz or 30) then
		local elapsed = W.visualAcc
		W.visualAcc = 0
		W.guard("Overlays", updateESP)
		if W.radar then W.guard("Radar", updateRadar, elapsed) end
		W.guard("Visual extras", W.kar.updateExtras)
	end
	if W.statsAcc >= 1 then local elapsed = W.statsAcc W.statsAcc = 0 W.guard("Statistics", W.updateStats, elapsed) end
end)
W.bind(RunService.Heartbeat, function(dt)
	if not W.running or W.initializing then return end
	if W.fly then W.watchFlight() end
	if W.kar.enabled then W.guard("Motion profiles", W.kar.sampleProfiles, dt) end
	W.slowAcc = W.slowAcc + dt
	if W.slowAcc < 0.15 then return end
	W.slowAcc = 0
	if W.speedLock then W.guard("Walk speed", W.applySpeed) end
	if W.jumpOn then W.guard("Jump settings", W.applyJump) end
	if W.bright and W.forceBright then W.guard("Lighting", pushBright) end
	W.guard("Owned cleanup", W.watchOwnedControls)
	W.guard("World", W.vector.stepVisuals)
	W.guard("Target card", W.vector.stepHUD)
	W.guard("Alerts", W.vector.stepAlerts)
	W.guard("HUD", W.updateHUD)
	W.guard("Aim HUD", W.kar.refreshHUD)
end)


W.bind(RunService.Heartbeat, function()
	local root, hum = getRoot(player), getHum(player)
	if W.antiFling and root and hum and not W.fly and not W.macroPlay and not W.follow and not W.orbit and W.ugState == "SURFACE" then
		if root.AssemblyLinearVelocity.Magnitude > W.flingCap then root.AssemblyLinearVelocity = Vector3.zero end
		if root.AssemblyAngularVelocity.Magnitude > W.flingCap then root.AssemblyAngularVelocity = Vector3.zero end
	end
	if W.selfHp and hum and hum.Health > 0 then
		local pct = hum.Health / math.max(hum.MaxHealth, 1) * 100
		if pct <= W.lowHpPct and os.clock() - W.hpFlash > 3 then W.hpFlash = os.clock() flash(string.format("Your health: %d%%", math.floor(pct)), C.bad) end
	end
end)

W.ui.touchFlight = W.new("Frame", ui, {
	Position = UDim2.new(1, -86, 0.5, -55), Size = UDim2.fromOffset(64, 116),
	BackgroundTransparency = 1, Visible = false, ZIndex = 220,
})
for index, title in ipairs({"UP", "DOWN"}) do
	local b = W.smallButton(W.ui.touchFlight, title, 64, 221)
	b.Size = UDim2.fromOffset(64, 50)
	b.Position = UDim2.fromOffset(0, (index - 1) * 59)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			if index == 1 then W.touchUp = true W.touchInputUp = i else W.touchDown = true W.touchInputDown = i end
		end
	end)
end

W.bind(radar.InputBegan, function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		W.radarDrag = {input = i, touch = i.UserInputType == Enum.UserInputType.Touch, start = Vector2.new(i.Position.X, i.Position.Y), pos = radar.Position}
	end
end)
W.bind(UIS.JumpRequest, function()
	if not W.canMove() then return end
	W.jumpUntil = os.clock() + 0.28
	if W.infJump and not W.freecam and not W.fly and not W.auto.running and not W.macroPlay and W.ugState == "SURFACE" then local h = getHum(player) if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)
W.bind(UIS.InputBegan, function(i, processed)
	if i.KeyCode == Enum.KeyCode.RightShift then return end
	if i.KeyCode == Enum.KeyCode.Insert then
		if W.hotkeys and W.hotkeys.held[i.KeyCode] then return end
		local shouldOpen = not W.open or not main.Visible or not ui.Enabled
			or (W.hotkeys and W.hotkeys.capture ~= nil)
		W.windowFocused = true
		if W.hotkeys then pcall(W.hotkeys.cancelCapture) end
		pcall(W.releaseTextFocus)
		W.setOpen(shouldOpen)
		if shouldOpen then pcall(W.fitWindow, true) end
		if W.hotkeys then W.hotkeys.held[i.KeyCode] = true end
		return
	end
	if i.KeyCode == Enum.KeyCode.F8 then W.emergencyRelease() return end
	if i.KeyCode == Enum.KeyCode.F7 and not UIS:GetFocusedTextBox() then W.toggleFallback() return end
	W.windowFocused = true
	local focus = UIS:GetFocusedTextBox()
	local menuKey = W.hotkeys.items.menu and W.hotkeys.items.menu.key
	local controlHeld = UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
	local isMenuKey = i.KeyCode == menuKey or (i.KeyCode == Enum.KeyCode.K and W.kar.kShortcut and not controlHeld and not focus)
	if isMenuKey and not W.hotkeys.capture and (not focus or W.ownsGui(focus)) then
		if not W.hotkeys.held[i.KeyCode] then
			W.setOpen(not W.open)
			W.hotkeys.held[i.KeyCode] = true
		end
		return
	end
	if W.hotkeys.capture then W.hotkeys.handle(i, processed) return end
	if i.KeyCode ~= Enum.KeyCode.Unknown then W.flightKeys[i.KeyCode] = true end
	if i.KeyCode == Enum.KeyCode.Escape and W.pickUGSpot then W.pickUGSpot = false W.setOpen(true) return end
	if i.KeyCode == Enum.KeyCode.Escape and W.ui.palette.Visible then W.showPalette(false) return end
	if i.KeyCode == Enum.KeyCode.Escape and W.auto.running then W.auto.stop("Sweep cancelled", false) return end
	if i.KeyCode == Enum.KeyCode.End then
		local focus = UIS:GetFocusedTextBox()
		if not focus or focus:IsDescendantOf(ui) then W.releaseTextFocus() W.reset() return end
	end
	if UIS:GetFocusedTextBox() then return end
	if i.KeyCode == Enum.KeyCode.K and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then W.showPalette(not W.ui.palette.Visible) return end
	if W.hotkeys.handle(i, processed) then return end
	if processed then return end
	if i.KeyCode == Enum.KeyCode.K and W.kar.kShortcut then W.setOpen(not W.open) return end
	if i.KeyCode == Enum.KeyCode.Slash and W.open then W.showPalette(true) end
end)
W.bind(UIS.InputChanged, function(i)
	if W.dragging and ((not W.dragTouch and i.UserInputType == Enum.UserInputType.MouseMovement) or i == W.dragInput) then W.dragging(i.Position.X) end


	if W.radarDrag and ((not W.radarDrag.touch and i.UserInputType == Enum.UserInputType.MouseMovement) or i == W.radarDrag.input) then
		local drag = W.radarDrag
		local delta = Vector2.new(i.Position.X, i.Position.Y) - drag.start
		local pos = drag.pos + UDim2.fromOffset(delta.X, delta.Y)
		local vp, half = camera.ViewportSize, W.radarSize / 2 + 8
		local x = math.clamp(pos.X.Scale * vp.X + pos.X.Offset, half, math.max(half, vp.X - half))
		local y = math.clamp(pos.Y.Scale * vp.Y + pos.Y.Offset, half, math.max(half, vp.Y - half))
		radar.Position = UDim2.fromOffset(x, y)
	end
end)
W.bind(UIS.InputEnded, function(i)
	W.hotkeys.held[i.KeyCode] = nil
	W.flightKeys[i.KeyCode] = nil
	local mouseUp = i.UserInputType == Enum.UserInputType.MouseButton1
	if i == W.dragInput or (mouseUp and not W.dragTouch) then
		W.dragging, W.dragInput = nil, nil
		if W.dragPage and W.dragPage.Parent then W.dragPage.ScrollingEnabled = true end
		W.dragPage = nil
	end
	if W.windowDrag and (i == W.windowDrag.input or (mouseUp and not W.windowDrag.touch)) then W.windowDrag = nil end
	if W.radarDrag and (i == W.radarDrag.input or (mouseUp and not W.radarDrag.touch)) then W.radarDrag = nil end
	if i == W.touchInputUp or mouseUp then W.touchUp = false W.touchInputUp = nil end
	if i == W.touchInputDown or mouseUp then W.touchDown = false W.touchInputDown = nil end
end)
W.bind(UIS.WindowFocusReleased, function()
	if W.fallback and W.fallback.on then pcall(W.stopFallback) end
	W.auto.stop("Sweep stopped: window focus lost", false)
	W.hotkeys.held = {}
	W.hotkeys.cancelCapture()
	if W.fly then W.stopFlight("Flight stopped: game window lost focus.") end
	if W.freecam or W.follow or W.orbit or W.macroPlay or W.ugState ~= "SURFACE" then
		W.releaseMovement("Window focus lost / automatic movement stopped", false)
	end
	W.windowFocused = false
	W.flightKeys = {}
	W.flightVelocity = Vector3.zero
	W.flightTakeoffUntil = 0
	W.dragging, W.dragInput, W.windowDrag, W.radarDrag = nil, nil, nil, nil
	W.touchUp, W.touchDown = false, false
	if W.dragPage and W.dragPage.Parent then W.dragPage.ScrollingEnabled = true end
	W.dragPage = nil
end)
W.bind(UIS.WindowFocused, function() W.windowFocused = true W.flightKeys = {} end)
function W.worldClick(point, target, position)
	if UIS:GetFocusedTextBox() or W.overUI(point) then return end
	local overControl = false
	pcall(function()
		for _, object in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y)) do
			if object:IsA("GuiButton") or object:IsA("TextBox") then overControl = true break end
		end
	end)
	if overControl then return end
	if W.pickUGSpot and target and position then
		W.pickUGSpot = false
		W.ugAnchor = CFrame.new(position + Vector3.new(0, 3, 0))
		showPage("Underground")
		W.setOpen(true)
		flash("Underground spot selected.", C.good)
		return
	end
	if W.inspect and target and target:IsA("BasePart") then inspectPart(target) return end
	if W.clickTP and (W.vector.teleportActivation == "Click" or UIS:IsKeyDown(Enum.KeyCode.LeftAlt) or UIS:IsKeyDown(Enum.KeyCode.RightAlt)) and position and target then if W.teleport(CFrame.new(position + Vector3.new(0, 4, 0))) then setStatus("Click teleport / undo available") end end
end
W.bind(mouse.Button1Down, function()
	if W.ui.palette.Visible then return end
	W.worldClick(UIS:GetMouseLocation(), mouse.Target, mouse.Hit and mouse.Hit.Position)
end)
W.bind(UIS.TouchTapInWorld, function(point, processed)
	if processed or W.ui.palette.Visible or W.overUI(point) or (not W.inspect and not W.clickTP and not W.pickUGSpot) then return end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = {W.worldFolder}
	if player.Character then table.insert(excluded, player.Character) end
	params.FilterDescendantsInstances = excluded
	local result = workspace:Raycast(ray.Origin, ray.Direction * 8000, params)
	if result then W.worldClick(point, result.Instance, result.Position) end
end)
closeBtn.Activated:Connect(function() W.setOpen(false) end)

W.bind(Players.PlayerAdded, function(p)
	W.log(p.Name .. " joined", "PLAYER")
	if W.vector.joinAlert then flash(p.DisplayName .. " joined.", C.good) end
	task.defer(function() if W.running then rebuildList() end end)
end)
W.bind(Players.PlayerRemoving, function(p)
	if W.kar.currentPlayer == p or W.kar.hitTarget == p then W.kar.clearTracking() end
	W.kar.profiles[p.UserId], W.kar.blacklist[p.UserId], W.kar.teammates[p.UserId] = nil, nil, nil
	W.kar.teamPicking = W.kar.count(W.kar.teammates) < W.kar.teamSize
	local beam = W.kar.beams[p]
	if beam then beam.beam:Destroy() beam.target:Destroy() W.kar.beams[p] = nil end
	killRig(p)
	if W.dots[p] then W.dots[p]:Destroy() W.dots[p] = nil end
	W.lastAlert[p] = nil
	if W.target == p then W.clearTarget() end
	W.log(p.Name .. " left", "PLAYER")
	if W.vector.joinAlert then flash(p.DisplayName .. " left.", C.dim) end
	task.defer(function() if W.running then rebuildList() end end)
end)
W.characterGeneration = 0
W.bind(player.CharacterRemoving, function(char)
	W.releaseMovement("Character changed / movement tools stopped", false)
	W.kar.clearTracking()
	W.setToggle("Approach Assist", false)
	W.stopFlight()
	W.characterGeneration = W.characterGeneration + 1
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then W.deathCF = root.CFrame end
	W.macroRec, W.macroPlay = false, false
	W.setToggle("Follow", false)
	W.setToggle("Orbit Target", false)
	if W.ugState ~= "SURFACE" then ugReset("respawn") end
	W.setToggle("Fly", false)
	W.stopFlyRig()
	W.setBody(false)
	W.restoreCollisions()
	if W.speedConn then W.speedConn:Disconnect() W.speedConn = nil end
	if W.deathConn then W.deathConn:Disconnect() W.deathConn = nil end
end)
function W.onCharacter(char, returning)
	W.characterGeneration = W.characterGeneration + 1
	local generation = W.characterGeneration
	task.spawn(function()
		local h = char:WaitForChild("Humanoid", 8)
		local root = char:WaitForChild("HumanoidRootPart", 8)
		if not W.running or generation ~= W.characterGeneration or char ~= player.Character or not h or not root then return end
		if replacingWraith then replacingWraith = false pcall(W.clearFlightRemnants, root) end


		if W.deathConn then W.deathConn:Disconnect() end
		W.deathConn = h.Died:Connect(function()
			W.auto.stop("Sweep stopped: your character died", false)
			W.kar.calibration = 0.45
			W.kar.clearTracking()
			W.setToggle("Approach Assist", false)
			W.stopFlight()
			if root.Parent then W.deathCF = root.CFrame end
			W.macroRec, W.macroPlay = false, false
			W.setToggle("Fly", false)
			W.setToggle("Follow", false)
			W.setToggle("Orbit Target", false)
			W.stopFlyRig()
			if W.ugState ~= "SURFACE" then ugReset("character died") end
		end)
		W.hookSpeed()
		W.applyJump()
		if W.fly and W.flightBody and W.flightBody.hum ~= h then W.stopFlight() end
		applyGravity()

		if returning and (W.retDeath or W.retSlot) then
			task.wait(W.respawnD)
			if not W.running or generation ~= W.characterGeneration or char ~= player.Character or h.Health <= 0 then return end
			local goal = W.retDeath and W.deathCF or (W.retSlot and W.slots[W.autoSlot])
			if goal and W.teleport(goal, false) then flash("Returned to saved respawn position.", C.accent) end
		end
	end)
end
W.bind(player.CharacterAdded, function(char) W.onCharacter(char, true) end)
if player.Character then W.onCharacter(player.Character, false) end

function W.hookViewport()
	if W.viewportConn then W.viewportConn:Disconnect() W.viewportConn = nil end
	W.viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if W.running then W.fitWindow(false) end
	end)
end
W.bind(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	local nextCamera = workspace.CurrentCamera
	if not nextCamera or nextCamera == camera then return end
	W.auto.stop("Sweep stopped: camera changed", false)
	for _, name in ipairs({"Free Cam", "Camera Lock", "Spectate Target", "Aim Assist"}) do W.setToggle(name, false) end
	if W.fovBak and W.fovBak.camera.Parent then W.fovBak.camera.FieldOfView = W.fovBak.value end
	camera = nextCamera
	if W.fovOn then W.fovBak = {camera = camera, value = camera.FieldOfView} camera.FieldOfView = W.fov else W.fovBak = nil end
	W.hookViewport()
	W.fitWindow(false)
end)
W.hookViewport()
W.bind(ui.Destroying, function()
	pcall(W.releaseMovement, "Panel removed / owned controls released", false)
	pcall(W.closeInput)
end)
W.bind(ui:GetPropertyChangedSignal("Enabled"), function()
	if W.running and not ui.Enabled then
		if W.auto and W.auto.running then pcall(W.auto.stop, "Panel layer disabled", false) end
		pcall(W.closeInput)
	end
end)

function W.cleanup()
	W.unloading = true
	pcall(W.closeInput)
	if W.vector.releaseTool then pcall(W.vector.releaseTool) end
	if W.vector.restoreVisuals then pcall(W.vector.restoreVisuals) end
	if W.auto then pcall(W.auto.stop, "Unloading", false) end
	if W.hotkeys then pcall(W.hotkeys.cancelCapture) end
	if not W.running then return end
	pcall(W.releaseMovement, "Unloading / movement released", false)
	W.running = false
	W.scanToken = W.scanToken + 1
	W.characterGeneration = W.characterGeneration + 1
	pcall(function() RunService:UnbindFromRenderStep(W.renderName) end)
	for _, conn in ipairs(W.connections) do pcall(function() conn:Disconnect() end) end
	W.connections = {}
	for _, name in ipairs({"watchConn", "speedConn", "deathConn", "viewportConn"}) do
		local conn = W[name]
		W[name] = nil
		if conn then pcall(function() conn:Disconnect() end) end
	end
	for _, tween in pairs(W.activeTweens) do pcall(function() tween:Cancel() end) end
	pcall(W.reset, true)
	pcall(W.kar.cleanup)
	pcall(function() CAS:UnbindAction("W_FreecamSink") end)
	pcall(W.restoreCollisions)
	pcall(W.stopFlyRig)
	pcall(W.setBody, false)
	for motor, base in pairs(W.ugJoints or {}) do
		pcall(function() if motor.Parent then motor.C0 = base end end)
	end
	W.ugJoints = nil
	pcall(function() W.worldFolder:Destroy() end)
	pcall(function() hud:Destroy() end)
	pcall(function() ui:Destroy() end)
	Boot.removeTopButton()
	Boot.dismiss()
	if _G.__WRAITH_CLEANUP == W.cleanup then _G.__WRAITH_CLEANUP = nil end
	if _G.__WRAITH_VECTOR == W then _G.__WRAITH_VECTOR = nil end
	print("[WRAITH + VECTOR 7 WOOD] Unloaded.")
end

Boot.stage("Finishing menu layout...")
W.vector.finishUI()
W.captureDefaults()
W.hotkeys.import(_G.__WRAITH_V6_HOTKEYS)
_G.__WRAITH_CLEANUP = W.cleanup
_G.__WRAITH_VECTOR = W
showPage("Home")
rebuildList()
refreshSlots()
setMacroStatus()
W.expRoot = workspace
refreshExplorer()
W.buildSections()
W.vector.applyEngineUI()
W.fitWindow(true)
W.setOpen(true)
W.initializing = false
setStatus("Ready. The small Menu button stays on the right.")
W.updateHUD()
W.kar.refreshHUD()
W.updateStats(1)
Boot.done = true
Boot.refreshTopButton()
Boot.dismiss()
print("[WRAITH] Ready. Click the small Menu button on the right to open or close the menu. No menu key needed.")
end, Boot.trace)
if not bootOK then Boot.fail(bootError) end
end