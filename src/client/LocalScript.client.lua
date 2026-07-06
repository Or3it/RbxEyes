local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local laserFiredEvent = game.ReplicatedStorage:WaitForChild("LaserFired")
local windupEvent = game.ReplicatedStorage:WaitForChild("WindupStarted")
local playDeadEvent = game.ReplicatedStorage:WaitForChild("PlayDead")

-- Default movement controls (needed for ragdoll: the client owns character
-- physics, so IT must stop driving the character, not the server)
local controls = nil
pcall(function()
	local pm = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	controls = pm:GetControls()
end)

-- Beam (all clients)
laserFiredEvent.OnClientEvent:Connect(function(a, b)
	-- Defensive guard: beams must arrive as two Vector3s
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return end
	local startPos, endPos = a, b
	local beamLength = (endPos - startPos).Magnitude
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(0.1, 0.1, beamLength)
	beam.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -beamLength / 2)
	beam.Anchored = true
	beam.CanCollide = false
	beam.BrickColor = BrickColor.new("Bright red")
	beam.Material = Enum.Material.Neon
	beam.Parent = workspace
	game:GetService("Debris"):AddItem(beam, 0.5)
end)

-- Windup glow (all clients)
windupEvent.OnClientEvent:Connect(function(headPart)
	if not headPart then return end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 0, 0)
	glow.Brightness = 5
	glow.Range = 20
	glow.Parent = headPart
	game:GetService("Debris"):AddItem(glow, 1.5)
end)

local function getRole()
	local r = localPlayer:FindFirstChild("Role")
	return r and r.Value or nil
end
local function isReleased()
	local rel = localPlayer:FindFirstChild("Released")
	return rel ~= nil and rel.Value == true
end

localPlayer.ChildAdded:Connect(function(child)
	if child.Name == "Role" then
		task.wait(0.1)
		print("You are: " .. tostring(child.Value))
	end
end)

local flying = false
local laserCooldown = false
local flySpeed = 80
local verticalSpeed = 40
local flightCeiling = 100
local windupTime = 1.5
local isPlayingDead = false -- authoritative value comes back from the server

-- ============================================================
-- RAGDOLL (client side)
-- The Humanoid state machine is CLIENT-authoritative for player characters.
-- Server-side ChangeState is a no-op and the client locomotion controller
-- keeps holding the body upright -- the exact "hangs off the HRP and never
-- falls" bug. So: server flips the joints (replicates), then confirms here,
-- and the client enters Physics state, releases controls, and applies the
-- topple impulse (client owns the physics, so impulses must come from here).
-- ============================================================
playDeadEvent.OnClientEvent:Connect(function(isDead)
	if typeof(isDead) ~= "boolean" then return end
	isPlayingDead = isDead
	local char = localPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	if isDead then
		if controls then pcall(function() controls:Disable() end) end
		-- The default Animate script reacts to Humanoid state (the sliding
		-- ragdoll reads as "Running"), so it plays run/walk cycles on the limp
		-- body. Client-played animations can't be stopped from the server --
		-- disable Animate and kill any playing tracks HERE.
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = true end
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		-- Randomized fall: shove from a random horizontal direction with spin,
		-- then kick each limb individually so the body sprawls and bumps into
		-- things instead of tipping over as a frozen plank.
		local angle = math.rad(math.random(0, 359))
		local shoveDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local upperTorso = char:FindFirstChild("UpperTorso")
		if upperTorso then
			upperTorso.AssemblyLinearVelocity = (shoveDir * Config.TOPPLE_PUSH) + Vector3.new(0, Config.TOPPLE_LIFT, 0)
			local spin = Config.TOPPLE_SPIN
			upperTorso.AssemblyAngularVelocity = Vector3.new(
				math.random(-spin, spin), math.random(-spin, spin), math.random(-spin, spin)
			)
		end
		local kick = Config.LIMB_KICK
		for _, limbName in ipairs({"LeftHand", "RightHand", "LeftFoot", "RightFoot", "Head"}) do
			local limb = char:FindFirstChild(limbName)
			if limb then
				limb.AssemblyLinearVelocity = Vector3.new(
					math.random(-kick, kick),
					math.random(0, kick),
					math.random(-kick, kick)
				)
			end
		end
	else
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		if controls then pcall(function() controls:Enable() end) end
	end
end)

-- Safety: dying or respawning while ragdolled must never leave controls off
localPlayer.CharacterAdded:Connect(function(char)
	isPlayingDead = false
	if controls then pcall(function() controls:Enable() end) end
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Connect(function()
			if controls then pcall(function() controls:Enable() end) end
		end)
	end
end)

-- Ground clearance (prevents legs clipping through terrain while flying)
local minGroundClearance = 6
local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Play dead toggle (G key) - server validates, client applies physics on confirm
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.G then return end
	if getRole() ~= "Survivor" then return end
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end
	playDeadEvent:FireServer(not isPlayingDead)
end)

-- Flight toggle
UserInputService.InputBegan:Connect(function(input)
	if getRole() ~= "NoLander" then return end
	if not isReleased() then return end
	if input.KeyCode == Enum.KeyCode.F then
		flying = not flying
		local char = localPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if hum then hum.PlatformStand = flying end
	end
end)

-- Laser fire
UserInputService.InputBegan:Connect(function(input)
	if getRole() ~= "NoLander" then return end
	if not isReleased() then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if laserCooldown then return end
	laserCooldown = true

	local char = localPlayer.Character
	local head = char and char:FindFirstChild("Head")
	if not head then laserCooldown = false return end

	windupEvent:FireServer()
	task.wait(windupTime)

	char = localPlayer.Character
	head = char and char:FindFirstChild("Head")
	if not head then laserCooldown = false return end

	local mouseHit = localPlayer:GetMouse().Hit.Position
	local direction = (mouseHit - head.Position).Unit

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {char}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(head.Position, direction * 500, rayParams)
	local hitPosition = rayResult and rayResult.Position or (head.Position + direction * 500)

	-- Local beam for the NoLander (other clients get theirs via the remote)
	local beamLength = (hitPosition - head.Position).Magnitude
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(0.1, 0.1, beamLength)
	beam.CFrame = CFrame.new(head.Position, hitPosition) * CFrame.new(0, 0, -beamLength / 2)
	beam.Anchored = true
	beam.CanCollide = false
	beam.BrickColor = BrickColor.new("Bright red")
	beam.Material = Enum.Material.Neon
	beam.Parent = workspace
	game:GetService("Debris"):AddItem(beam, 0.5)

	laserFiredEvent:FireServer(head.Position, hitPosition)

	task.wait(3)
	laserCooldown = false
end)

-- Flight movement
RunService.Heartbeat:Connect(function()
	if getRole() ~= "NoLander" then flying = false return end
	if not flying or not isReleased() then return end
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local camCFrame = camera.CFrame
	local forward = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z).Unit
	local right = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z).Unit
	local moveDirection = Vector3.new(0, 0, 0)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= right end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += right end

	local vertical = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		vertical = verticalSpeed
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		vertical = -verticalSpeed
	end

	groundRayParams.FilterDescendantsInstances = {char}
	local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -(minGroundClearance + 50), 0), groundRayParams)
	local clearance = groundRay and (hrp.Position.Y - groundRay.Position.Y) or math.huge
	if clearance < minGroundClearance then
		vertical = verticalSpeed
	end

	if hrp.Position.Y < flightCeiling or vertical < 0 then
		hrp.Velocity = (moveDirection * flySpeed) + Vector3.new(0, vertical, 0)
	else
		hrp.Velocity = moveDirection * flySpeed
	end

	if clearance < minGroundClearance * 0.5 then
		hrp.CFrame = hrp.CFrame + Vector3.new(0, minGroundClearance - clearance, 0)
	end
end)
