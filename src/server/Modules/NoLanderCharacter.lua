-- NoLanderCharacter: builds the custom skinned NoLander body and applies it to
-- the NoLander player, then drives its animations off movement state.
--
-- WHY THIS IS NOLANDER-ONLY:
-- The uploaded body is an "S1" rig -- ONE skinned MeshPart with 16 Bones and
-- ZERO Motor6Ds. Survivor mechanics cannot run on it:
--   RagdollService builds BallSocketConstraints by walking Motor6D joints. On
--   this body it would find none, create no sockets, and play dead would do
--   nothing at all -- silently, with no error.
--   DamageService routes hits by BasePart name (Head / UpperTorso / "Leg" /
--   "Arm"). This body has one part named Body, so every hit would fall through
--   to the vital-hit branch and instantly eliminate.
-- The NoLander never ragdolls (RagdollService gates on Role == "Survivor") and
-- is never shot at, so none of that applies to it. Survivors must stay on the
-- stock R15 rig.
--
-- HEAD PROXY: DamageService reads shooter.Character.Head for the laser origin.
-- An S1 body has a Head *Bone*, not a BasePart, so we weld an invisible Head
-- part at the head bone. This keeps DamageService working unmodified.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local InsertService = game:GetService("InsertService")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))
local AnimationIds = require(game.ReplicatedStorage:WaitForChild("AnimationIds"))

local NoLanderCharacter = {}

local cachedBody = nil

-- Pull the skinned mesh out of the uploaded Model asset once and reuse it.
local function getBodyTemplate()
	if cachedBody then return cachedBody end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(AnimationIds.CharacterModelId)
	end)
	if not ok or not asset then
		warn("[NoLanderCharacter] LoadAsset failed: " .. tostring(asset))
		return nil
	end
	for _, d in ipairs(asset:GetDescendants()) do
		if d:IsA("MeshPart") then
			cachedBody = d:Clone()
			break
		end
	end
	asset:Destroy()
	return cachedBody
end

local function boneMap(root)
	local t = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Bone") then t[d.Name] = d end
	end
	return t
end

-- Build a complete, Humanoid-driven character model around the skinned mesh.
function NoLanderCharacter.build()
	local template = getBodyTemplate()
	if not template then return nil end

	local model = Instance.new("Model")
	model.Name = "NoLanderBody"

	local mesh = template:Clone()
	mesh.Name = "Body"
	mesh.CanCollide = false     -- HumanoidRootPart owns collision
	mesh.Massless = true
	mesh.Parent = model

	local bones = boneMap(mesh)
	if not bones.HumanoidRootPart or not bones.LeftFoot then
		warn("[NoLanderCharacter] body is missing expected bones; aborting")
		return nil
	end
	-- Unscaled rise from feet to root bone. Drives HipHeight so the Humanoid
	-- plants the body on the floor instead of sinking or hovering.
	local rise = bones.HumanoidRootPart.WorldPosition.Y - bones.LeftFoot.WorldPosition.Y

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Parent = model
	model.PrimaryPart = hrp

	mesh.CFrame = hrp.CFrame * CFrame.new(0, -rise, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = mesh
	weld.Parent = hrp

	-- Head proxy so DamageService's laser origin keeps working (see note above).
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1, 1)
	head.Transparency = 1
	head.CanCollide = false
	head.Massless = true
	head.Parent = model
	if bones.Head then
		head.CFrame = hrp.CFrame * CFrame.new(0, bones.Head.WorldPosition.Y - bones.HumanoidRootPart.WorldPosition.Y, 0)
	end
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = hrp
	headWeld.Part1 = head
	headWeld.Parent = hrp

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.AutomaticScalingEnabled = false
	hum.Parent = model
	Instance.new("Animator").Parent = hum

	-- Model:ScaleTo scales bones correctly (MeshPart has no ScaleTo -- that call
	-- errors). GOTCHA: it ALSO scales HumanoidRootPart.Size, WalkSpeed and
	-- JumpPower. At scale 3.2 WalkSpeed silently became 51.2. Reset them after.
	model:ScaleTo(Config.NOLANDER_SCALE)
	hrp.Size = Vector3.new(2, 2, 1)
	hum.WalkSpeed = Config.NOLANDER_WALK_SPEED
	hum.JumpPower = Config.JUMP_POWER

	-- HipHeight MUST be measured after scaling, not computed from the unscaled
	-- rise. ScaleTo scales about the model pivot, so the weld offset does not
	-- end up as a clean rise * SCALE -- computing it sank the feet 1.39 studs
	-- into the floor. Measure the real foot-bone-to-HRP-bottom gap instead:
	-- when the Humanoid holds the HRP bottom that far up, the feet land on it.
	local footBone = boneMap(mesh).LeftFoot
	if footBone then
		hum.HipHeight = (hrp.Position.Y - hrp.Size.Y / 2) - footBone.WorldPosition.Y
	else
		hum.HipHeight = rise * Config.NOLANDER_SCALE
	end

	return model
end

-- Swap a player onto the custom body.
function NoLanderCharacter.apply(player)
	local model = NoLanderCharacter.build()
	if not model then return nil end

	local old = player.Character
	local spawnCFrame = CFrame.new(0, 30, 0)
	if old and old.PrimaryPart then
		spawnCFrame = old.PrimaryPart.CFrame
	end

	model.Name = player.Name
	model:PivotTo(spawnCFrame)
	model.Parent = workspace
	player.Character = model
	if old then old:Destroy() end

	NoLanderCharacter.driveAnimations(model)
	return model
end

-- Movement-state animation driver. Runs on the server because the NoLander body
-- is server-built; the tracks replicate to clients through the Animator.
function NoLanderCharacter.driveAnimations(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	-- Character set ONLY. The Avatar set is built on the stock R15 clavicle
	-- chain; played here it animates the legs and leaves both arms and the head
	-- at exactly 0.00 deg, with no error.
	local tracks = {}
	for name, id in pairs(AnimationIds.Character) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok then
			track.Looped = (name ~= "collapse")
			track.Priority = Enum.AnimationPriority.Core
			tracks[name] = track
		end
	end
	if not next(tracks) then return end

	local current = nil
	local function switchTo(name)
		if current == name or not tracks[name] then return end
		if current and tracks[current] then tracks[current]:Stop(0.2) end
		tracks[name]:Play(0.2)
		current = name
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent or hum.Health <= 0 then
			conn:Disconnect()
			for _, t in pairs(tracks) do t:Stop(0) end
			return
		end
		-- Measure actual horizontal velocity, NOT Humanoid.MoveDirection.
		-- MoveDirection reads 0.000 server-side while the body is demonstrably
		-- moving under MoveTo, which pinned the driver in idle forever.
		-- Velocity is also correct once a real player owns the character, and
		-- stays correct when the NoLander flies.
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed < 1 then
			switchTo("idle")
		elseif speed > Config.NOLANDER_WALK_SPEED * 1.35 then
			switchTo("sprint")
		else
			switchTo("walk")
		end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent and conn.Connected then conn:Disconnect() end
	end)
end

return NoLanderCharacter
