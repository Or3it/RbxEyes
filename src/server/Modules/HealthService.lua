-- HealthService: bleeding from limb hits, teammate bandaging, controlled regen.
-- Roblox's default character "Health" script regenerates 1%/sec and would
-- fight this system -- an empty script named "Health" in
-- StarterCharacterScripts overrides it (created by the build).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local HealthService = {}

-- player -> {clotAt = tick, char = char, anchor = part}
local bleeding = {}
-- player -> tick when bleeding last stopped (gates regen delay)
local lastBleedStop = {}
local onBleedDeath = nil -- callback wired by Main (DamageService.keepBodyOnDeath)

local function spawnDrip(hrp, char)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -12, 0), params)
	if not ray then return end
	local drip = Instance.new("Part")
	drip.Name = "BloodDrip"
	drip.Size = Vector3.new(0.7, 0.05, 0.7)
	drip.Position = ray.Position + Vector3.new(math.random(-10,10)/10, 0.03, math.random(-10,10)/10)
	drip.Anchored = true
	drip.CanCollide = false
	drip.BrickColor = BrickColor.new("Bright red")
	drip.Material = Enum.Material.SmoothPlastic
	drip.Transparency = 0.35
	drip.Parent = workspace
	game:GetService("Debris"):AddItem(drip, 25)
end

function HealthService.stopBleeding(player, bandaged)
	local state = bleeding[player]
	if not state then return end
	bleeding[player] = nil
	lastBleedStop[player] = tick()
	if state.anchor and state.anchor.Parent then
		state.anchor:Destroy()
	end
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if bandaged and hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + Config.BANDAGE_HEAL)
		print(player.Name .. " bandaged (+" .. Config.BANDAGE_HEAL .. " HP)")
	else
		print(player.Name .. "'s wound clotted")
	end
end

function HealthService.startBleeding(player, char)
	local existing = bleeding[player]
	if existing then
		-- New wound refreshes the clot timer
		existing.clotAt = tick() + Config.BLEED_CLOT_TIME
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local state = {clotAt = tick() + Config.BLEED_CLOT_TIME, char = char, nextDrip = 0}

	-- Invisible welded anchor carrying the Bandage prompt (same pattern as revive)
	local anchor = Instance.new("Part")
	anchor.Name = "BandageAnchor"
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Massless = true
	anchor.CFrame = hrp.CFrame
	anchor.Parent = char
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = hrp
	weld.Parent = anchor

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Bandage"
	prompt.ObjectText = player.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.BANDAGE_HOLD
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(helper)
		local hRole = helper:FindFirstChild("Role")
		if not hRole or hRole.Value ~= "Survivor" then return end
		if helper == player then return end
		HealthService.stopBleeding(player, true)
	end)

	state.anchor = anchor
	bleeding[player] = state
	print(player.Name .. " is bleeding!")
end

function HealthService.isBleeding(player)
	return bleeding[player] ~= nil
end

function HealthService.resetAll()
	for player in pairs(bleeding) do
		local state = bleeding[player]
		if state and state.anchor and state.anchor.Parent then
			state.anchor:Destroy()
		end
		bleeding[player] = nil
	end
	for player in pairs(lastBleedStop) do
		lastBleedStop[player] = nil
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "BloodDrip" then obj:Destroy() end
	end
end

function HealthService.init(deps)
	onBleedDeath = deps and deps.onBleedDeath

	RunService.Heartbeat:Connect(function(dt)
		local now = tick()
		-- Bleed drain + drips
		for player, state in pairs(bleeding) do
			local char = player.Character
			local hum = char and char:FindFirstChild("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not char or not hum or hum.Health <= 0 or char ~= state.char then
				bleeding[player] = nil
			elseif now >= state.clotAt then
				HealthService.stopBleeding(player, false)
			else
				hum.Health = math.max(0, hum.Health - Config.BLEED_RATE * dt)
				if hrp and now >= state.nextDrip then
					state.nextDrip = now + Config.DRIP_INTERVAL
					spawnDrip(hrp, char)
				end
				if hum.Health <= 0 then
					print(player.Name .. " bled out")
					bleeding[player] = nil
					if onBleedDeath then onBleedDeath(player) end
				end
			end
		end
		-- Controlled regen (only alive, not bleeding, past the delay window)
		for _, player in ipairs(Players:GetPlayers()) do
			if not bleeding[player] then
				local char = player.Character
				local hum = char and char:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
					local stoppedAt = lastBleedStop[player]
					if not stoppedAt or (now - stoppedAt) >= Config.REGEN_DELAY then
						hum.Health = math.min(hum.MaxHealth, hum.Health + Config.REGEN_RATE * dt)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		bleeding[player] = nil
		lastBleedStop[player] = nil
	end)
end

return HealthService
