-- RagdollService: joint swap (Motor6D <-> BallSocketConstraint) for play dead
-- and per-arm limp visuals.
--
-- KEY ARCHITECTURE NOTE: player characters are NETWORK-OWNED BY THEIR CLIENT.
-- The Humanoid state machine is client-authoritative, so ChangeState() and the
-- topple impulse MUST happen on the client (see LocalScript). The server's job
-- here is only what replicates cleanly: joints, collision, humanoid properties.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local RagdollService = {}

local RAGDOLL_GROUP = "RagdollNoCollide"
-- Separate pcalls: registration errors on repeat sessions (group already
-- exists) must not abort the collidable rule.
pcall(function() PhysicsService:RegisterCollisionGroup(RAGDOLL_GROUP) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(RAGDOLL_GROUP, RAGDOLL_GROUP, false) end)

local ragdollData = {}   -- character -> {motors, sockets, originalCanCollide, allParts, enforceConn}
local playingDead = {}   -- player -> bool

local function getJointLimits(motorName)
	for key, limits in pairs(Config.JOINT_LIMITS) do
		if motorName:find(key) then return limits end
	end
	return Config.DEFAULT_LIMITS
end

local function buildRagdoll(char)
	if ragdollData[char] then return ragdollData[char] end
	local motors, sockets = {}, {}
	local originalCanCollide, allParts = {}, {}
	for _, motor in ipairs(char:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local limits = getJointLimits(motor.Name)
			local a0 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a0.Name = motor.Name .. "_A0"
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = motor.C1
			a1.Name = motor.Name .. "_A1"
			a1.Parent = motor.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = motor.Name .. "_Ragdoll"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			-- Limits OFF: attachment axes copied from Motor6D C0/C1 don't align
			-- with anatomical bend directions, so enabled limits end up LOCKING
			-- most joints near the standing pose (the "tensed up plank" bug).
			-- Free ball joints = guaranteed floppy corpse.
			socket.LimitsEnabled = false
			socket.TwistLimitsEnabled = false
			socket.MaxFrictionTorque = limits.friction
			socket.Enabled = false
			socket.Parent = motor.Part1
			table.insert(motors, motor)
			table.insert(sockets, socket)
		end
	end
	-- Hands/feet ship with CanCollide=false (prevents snagging while walking).
	-- Invisible until physics is the only thing holding the body up -- then
	-- they pass through the floor. Capture originals to restore on standup.
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			originalCanCollide[part] = part.CanCollide
			table.insert(allParts, part)
		end
	end
	ragdollData[char] = {motors = motors, sockets = sockets, originalCanCollide = originalCanCollide, allParts = allParts}
	char.Destroying:Connect(function()
		local d = ragdollData[char]
		if d and d.enforceConn then d.enforceConn:Disconnect() end
		ragdollData[char] = nil
	end)
	return ragdollData[char]
end

function RagdollService.setRagdollEnabled(char, enabled)
	local data = buildRagdoll(char)
	for _, motor in ipairs(data.motors) do
		motor.Enabled = not enabled
	end
	for _, socket in ipairs(data.sockets) do
		socket.Enabled = enabled
	end
	for _, part in ipairs(data.allParts) do
		if part.Parent then
			part.CollisionGroup = enabled and RAGDOLL_GROUP or "Default"
			if part.Name == "HumanoidRootPart" then
				-- The HRP is an invisible box at the torso. If it collides, the
				-- corpse drapes over it and hovers above the floor.
				part.CanCollide = false
			elseif enabled then
				part.CanCollide = true
			else
				local original = data.originalCanCollide[part]
				if original == nil then original = true end
				part.CanCollide = original
			end
		end
	end
	-- The engine silently reverts CanCollide on hands/feet shortly after we
	-- set it. Re-assert every frame while ragdolled (verified via logs).
	if data.enforceConn then
		data.enforceConn:Disconnect()
		data.enforceConn = nil
	end
	if enabled then
		data.enforceConn = RunService.Heartbeat:Connect(function()
			for _, part in ipairs(data.allParts) do
				if part.Parent and not part.CanCollide and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
		end)
	end
end

local ARM_JOINT_NAMES = {
	Left = {LeftShoulder = true, LeftElbow = true, LeftWrist = true},
	Right = {RightShoulder = true, RightElbow = true, RightWrist = true},
}

function RagdollService.setArmLimp(char, side, limp)
	local names = ARM_JOINT_NAMES[side]
	if not names then return end
	local data = buildRagdoll(char)
	for i, motor in ipairs(data.motors) do
		if names[motor.Name] then
			motor.Enabled = not limp
			data.sockets[i].Enabled = limp
			local part1 = motor.Part1
			if part1 then
				part1.CollisionGroup = limp and RAGDOLL_GROUP or "Default"
				if limp then
					part1.CanCollide = true
				else
					local original = data.originalCanCollide[part1]
					if original == nil then original = true end
					part1.CanCollide = original
				end
			end
		end
	end
end

function RagdollService.isPlayingDead(player)
	return playingDead[player] == true
end

function RagdollService.resetAll()
	for player in pairs(playingDead) do
		playingDead[player] = nil
	end
end

function RagdollService.init(remotes)
	remotes.PlayDead.OnServerEvent:Connect(function(player, isDead)
		isDead = isDead == true
		local role = player:FindFirstChild("Role")
		if not role or role.Value ~= "Survivor" then return end
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChild("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		-- Can't play dead while hiding in a locker
		if isDead and char:GetAttribute("InLocker") then return end

		playingDead[player] = isDead

		if isDead then
			hum.PlatformStand = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.AutoRotate = false
			RagdollService.setRagdollEnabled(char, true)
			local animator = hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end
			end
			if Config.DEBUG_LOGS then
				print(string.format("[RAGDOLL] %s down. HRP Y=%.2f", player.Name, hrp.Position.Y))
				task.delay(1, function()
					if hrp and hrp.Parent then
						local foot = char:FindFirstChild("LeftFoot")
						print(string.format("[RAGDOLL t=1s] HRP Y=%.2f Vel=%s FootCanCollide=%s",
							hrp.Position.Y, tostring(hrp.AssemblyLinearVelocity),
							foot and tostring(foot.CanCollide) or "n/a"))
					end
				end)
				-- Pose recorder: reconstructs the settled death pose from logs.
				-- Flatness ~0.0 = lying flat like a corpse, ~1.0 = still upright.
				task.delay(2, function()
					if not char or not char.Parent then return end
					local upperTorso = char:FindFirstChild("UpperTorso")
					if upperTorso then
						print(string.format("[POSE t=2s] flatness=%.2f (0=flat corpse, 1=upright)",
							math.abs(upperTorso.CFrame.UpVector.Y)))
					end
					for _, partName in ipairs({"Head", "UpperTorso", "LowerTorso", "LeftHand", "RightHand", "LeftFoot", "RightFoot"}) do
						local part = char:FindFirstChild(partName)
						if part then
							print(string.format("[POSE t=2s] %s Y=%.2f", partName, part.Position.Y))
						end
					end
				end)
			end
		else
			RagdollService.setRagdollEnabled(char, false)
			hum.PlatformStand = false
			hum.AutoRotate = true
			-- Recenter upright above wherever the ragdoll settled
			hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
			local legHit = char:FindFirstChild("LegHit")
			hum.WalkSpeed = legHit and Config.CRAWL_SPEED or Config.WALK_SPEED
			hum.JumpPower = legHit and 0 or Config.JUMP_POWER
		end

		-- CRITICAL: confirm back to the owning client. The client performs
		-- ChangeState(Physics), disables its controls, and applies the topple
		-- impulse -- none of which work from the server for a client-owned
		-- character.
		remotes.PlayDead:FireClient(player, isDead)
		print(player.Name .. (isDead and " playing dead" or " got up"))
	end)

	Players.PlayerRemoving:Connect(function(player)
		playingDead[player] = nil
	end)
end

return RagdollService
