-- DamageService: server-authoritative laser validation, raycast damage,
-- limb-specific effects, body persistence.
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local DamageService = {}

local Ragdoll = nil -- wired in init
local Health = nil  -- wired in init

local function spawnBloodPool(position)
	local pool = Instance.new("Part")
	pool.Name = "BloodPool"
	pool.Size = Vector3.new(4, 0.05, 4)
	pool.Position = position + Vector3.new(0, 0.05, 0)
	pool.Anchored = true
	pool.CanCollide = false
	pool.BrickColor = BrickColor.new("Bright red")
	pool.Material = Enum.Material.SmoothPlastic
	pool.Transparency = 0.3
	pool.Parent = workspace
end

local function spawnBurnMark(position, normal)
	local mark = Instance.new("Part")
	mark.Name = "BurnMark"
	mark.Size = Vector3.new(0.8, 0.8, 0.05)
	mark.CFrame = CFrame.new(position, position + normal)
	mark.Anchored = true
	mark.CanCollide = false
	mark.BrickColor = BrickColor.new("Black")
	mark.Material = Enum.Material.Neon
	mark.Transparency = 0.4
	mark.Parent = workspace
end

-- Public so HealthService can call it when someone bleeds out
function DamageService.keepBodyOnDeath(player)
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local hum = char:FindFirstChild("Humanoid")
	if hum then
		hum.Health = 0
		hum.BreakJointsOnDeath = false
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		spawnBloodPool(hrp.Position)
	end
end

local function applyLegHit(hitPlayer, hitChar, hum)
	if not hitChar:FindFirstChild("LegHit") then
		local legState = Instance.new("BoolValue")
		legState.Name = "LegHit"
		legState.Value = true
		legState.Parent = hitChar
		hum.WalkSpeed = Config.CRAWL_SPEED
		hum.JumpPower = 0
		print(hitPlayer.Name .. " hit in leg - crawling!")

		local recovered = false
		local function recover(byTeammate)
			if recovered then return end
			recovered = true
			if legState then legState:Destroy() end
			local rv = hitChar:FindFirstChild("ReviveValue")
			if rv then rv:Destroy() end
			if hum and hum.Health > 0 then
				hum.WalkSpeed = Config.WALK_SPEED
				hum.JumpPower = Config.JUMP_POWER
				if byTeammate then
					-- A teammate revive also patches you up
					Health.stopBleeding(hitPlayer, true)
					print(hitPlayer.Name .. " revived by teammate!")
				else
					print(hitPlayer.Name .. " recovered")
				end
			end
		end

		local anchor = hitChar:FindFirstChild("HumanoidRootPart")
		if anchor then
			local rv = Instance.new("Part")
			rv.Name = "ReviveValue"
			rv.Size = Vector3.new(2, 2, 2)
			rv.Transparency = 1
			rv.CanCollide = false
			rv.Massless = true
			rv.Parent = hitChar
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rv
			weld.Part1 = anchor
			weld.Parent = rv
			rv.CFrame = anchor.CFrame

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Revive"
			prompt.ObjectText = hitPlayer.Name
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = Config.REVIVE_HOLD
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = rv

			prompt.Triggered:Connect(function(reviver)
				local rRole = reviver:FindFirstChild("Role")
				if not rRole or rRole.Value ~= "Survivor" then return end
				if reviver == hitPlayer then return end
				recover(true)
			end)
		end

		task.delay(Config.SELF_RECOVER_TIME, function()
			if hitChar and hitChar.Parent and not recovered and hum and hum.Health > 0 then
				recover(false)
			end
		end)
	end
	-- Every leg hit opens (or refreshes) a bleeding wound
	Health.startBleeding(hitPlayer, hitChar)
end

local function applyArmHit(hitPlayer, hitChar, partName)
	local side = partName:find("Left") and "Left" or "Right"
	local armState = hitChar:FindFirstChild("ArmHit")
	if not armState then
		armState = Instance.new("StringValue")
		armState.Name = "ArmHit"
		armState.Value = ""
		armState.Parent = hitChar
	end
	if armState.Value ~= side and armState.Value ~= "Both" then
		armState.Value = (armState.Value == "") and side or "Both"
		Ragdoll.setArmLimp(hitChar, side, true)
		print(hitPlayer.Name .. " hit in " .. side .. " arm")
	end
	-- Every arm hit opens (or refreshes) a bleeding wound
	Health.startBleeding(hitPlayer, hitChar)
end

local function processDamage(shooter, startPos, endPos)
	local r = shooter:FindFirstChild("Role")
	if not r or r.Value ~= "NoLander" then return end
	local shooterChar = shooter.Character
	if not shooterChar then return end
	local direction = (endPos - startPos)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {shooterChar}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayResult = workspace:Raycast(startPos, direction, rayParams)
	if not rayResult then return end
	local hitPart = rayResult.Instance
	local hitChar = hitPart and hitPart.Parent
	if not hitChar then return end
	local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
	if not hitPlayer or hitPlayer == shooter then return end
	local hum = hitChar:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	spawnBurnMark(rayResult.Position, rayResult.Normal)

	-- Playing dead: any hit is an instant kill
	if Ragdoll.isPlayingDead(hitPlayer) then
		DamageService.keepBodyOnDeath(hitPlayer)
		print(hitPlayer.Name .. " killed while playing dead")
		return
	end

	local part = hitPart.Name
	if part == "Head" or part == "UpperTorso" or part == "LowerTorso" or part == "Torso" or part == "HumanoidRootPart" then
		DamageService.keepBodyOnDeath(hitPlayer)
		print(hitPlayer.Name .. " eliminated (vital: " .. part .. ")")
	elseif part:find("Leg") or part:find("Foot") then
		applyLegHit(hitPlayer, hitChar, hum)
	elseif part:find("Arm") or part:find("Hand") then
		applyArmHit(hitPlayer, hitChar, part)
	else
		DamageService.keepBodyOnDeath(hitPlayer)
		print(hitPlayer.Name .. " eliminated (hit: " .. part .. ")")
	end
end

function DamageService.init(remotes, ragdollService, healthService)
	Ragdoll = ragdollService
	Health = healthService

	local laserCooldowns = {}
	local windupTimes = {}

	remotes.WindupStarted.OnServerEvent:Connect(function(shooter)
		local r = shooter:FindFirstChild("Role")
		if not r or r.Value ~= "NoLander" then return end
		windupTimes[shooter] = tick()
		local head = shooter.Character and shooter.Character:FindFirstChild("Head")
		if not head then return end
		for _, player in ipairs(Players:GetPlayers()) do
			remotes.WindupStarted:FireClient(player, head)
		end
	end)

	remotes.LaserFired.OnServerEvent:Connect(function(shooter, startPos, endPos)
		local r = shooter:FindFirstChild("Role")
		if not r or r.Value ~= "NoLander" then return end
		if typeof(startPos) ~= "Vector3" or typeof(endPos) ~= "Vector3" then return end

		local now = tick()
		if laserCooldowns[shooter] and (now - laserCooldowns[shooter]) < Config.SERVER_COOLDOWN then
			return
		end
		local windupStart = windupTimes[shooter]
		if not windupStart or (now - windupStart) < Config.MIN_WINDUP then
			return
		end
		laserCooldowns[shooter] = now
		windupTimes[shooter] = nil

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= shooter then
				remotes.LaserFired:FireClient(player, startPos, endPos)
			end
		end
		processDamage(shooter, startPos, endPos)
	end)

	Players.PlayerRemoving:Connect(function(player)
		laserCooldowns[player] = nil
		windupTimes[player] = nil
	end)
end

return DamageService
