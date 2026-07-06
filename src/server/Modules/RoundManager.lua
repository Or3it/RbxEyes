-- RoundManager: role assignment, hide/hunt phases, win conditions, reset.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local RoundManager = {}

local remotes = nil
local Ragdoll = nil
local Health = nil
local currentNoLander = nil

local function assignRoles()
	local players = Players:GetPlayers()
	if #players == 0 then return end

	if Config.DEBUG_FORCE_ROLE then
		currentNoLander = nil
		for _, player in ipairs(players) do
			local role = Instance.new("StringValue")
			role.Name = "Role"
			role.Value = Config.DEBUG_FORCE_ROLE
			role.Parent = player
			print(player.Name .. " forced to " .. Config.DEBUG_FORCE_ROLE .. " (DEBUG_FORCE_ROLE active)")
		end
		return
	end

	local noLander = players[math.random(1, #players)]
	currentNoLander = noLander
	local role = Instance.new("StringValue")
	role.Name = "Role"
	role.Value = "NoLander"
	role.Parent = noLander
	local released = Instance.new("BoolValue")
	released.Name = "Released"
	released.Value = false
	released.Parent = noLander
	print("NoLander is: " .. noLander.Name)
	for _, player in ipairs(players) do
		if player ~= noLander then
			local r = Instance.new("StringValue")
			r.Name = "Role"
			r.Value = "Survivor"
			r.Parent = player
			print("Survivor: " .. player.Name)
		end
	end
end

local function holdAndScatter()
	if currentNoLander and currentNoLander.Character then
		local hrp = currentNoLander.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(0, 500, 0)
			hrp.Anchored = true
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= currentNoLander and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(math.random(-100, 100), 5, math.random(-100, 100))
			end
		end
	end
end

local function releaseNoLander()
	if currentNoLander and currentNoLander.Character then
		local hrp = currentNoLander.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
			hrp.CFrame = CFrame.new(0, 30, 0)
		end
		local released = currentNoLander:FindFirstChild("Released")
		if released then released.Value = true end
	end
	print("NoLander RELEASED!")
end

local function startHidePhase()
	local timeLeft = Config.HIDE_TIME
	while timeLeft > 0 do
		remotes.UpdateTimer:FireAllClients("HIDE", timeLeft)
		task.wait(1)
		timeLeft -= 1
	end
	remotes.UpdateTimer:FireAllClients("HIDE", 0)
end

local function getSurvivorCount()
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p:FindFirstChild("Role")
		if r and r.Value == "Survivor" then
			local char = p.Character
			local hum = char and char:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 then
				count += 1
			end
		end
	end
	return count
end

local startHuntPhase

local function resetRound()
	task.wait(5)

	-- Round debris cleanup
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "BloodPool" or obj.Name == "BurnMark" or obj.Name == "BloodDrip" then
			obj:Destroy()
		end
	end
	-- Dead character models
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0 then
			char:Destroy()
		end
	end
	-- Role tags + service state
	for _, player in ipairs(Players:GetPlayers()) do
		local role = player:FindFirstChild("Role")
		if role then role:Destroy() end
		local released = player:FindFirstChild("Released")
		if released then released:Destroy() end
	end
	Ragdoll.resetAll()
	Health.resetAll()
	currentNoLander = nil

	-- Respawn everyone, tracking each player individually
	local respawnDone = {}
	for _, player in ipairs(Players:GetPlayers()) do
		respawnDone[player] = false
		local conn
		conn = player.CharacterAdded:Connect(function(char)
			char:WaitForChild("HumanoidRootPart")
			respawnDone[player] = true
			conn:Disconnect()
		end)
		player:LoadCharacter()
	end
	local deadline = tick() + 10
	repeat
		task.wait(0.2)
	until tick() > deadline or (function()
		for _, player in ipairs(Players:GetPlayers()) do
			if not respawnDone[player] then return false end
		end
		return true
	end)()

	assignRoles()
	holdAndScatter()
	startHidePhase()
	releaseNoLander()
	startHuntPhase()
end

startHuntPhase = function()
	local timeLeft = Config.HUNT_TIME
	while timeLeft > 0 do
		remotes.UpdateTimer:FireAllClients("HUNT", timeLeft)
		if getSurvivorCount() == 0 then
			remotes.UpdateTimer:FireAllClients("END", 0)
			remotes.RoundResult:FireAllClients("NoLander Wins!")
			resetRound()
			return
		end
		task.wait(1)
		timeLeft -= 1
	end
	remotes.UpdateTimer:FireAllClients("END", 0)
	remotes.RoundResult:FireAllClients("Survivors Win!")
	resetRound()
end

local function waitForPlayers()
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		Players.PlayerAdded:Wait()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character then player.CharacterAdded:Wait() end
		player.Character:WaitForChild("HumanoidRootPart")
	end
	task.wait(1)
end

function RoundManager.init(r, ragdollService, healthService)
	remotes = r
	Ragdoll = ragdollService
	Health = healthService
end

function RoundManager.start()
	task.spawn(function()
		waitForPlayers()
		assignRoles()
		holdAndScatter()
		startHidePhase()
		releaseNoLander()
		startHuntPhase()
	end)
end

return RoundManager
