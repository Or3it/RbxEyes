--!strict
-- AnimBridge: build & play KeyframeSequences from raw joint rotation data.
-- No Animation Editor, no 3D Importer, no upload. Studio-only playback.
--
-- Verified 2026-07-26 against Blender-authored R15_idle:
--   Waist X swing -2.48..+2.39 deg (source +/-2.49), Neck -1.47..+1.43 (source -1.47..+1.50),
--   LeftShoulder Z held 4.00 (source 4.00).
--
-- GOTCHAS (learned the hard way, do not "simplify" these away):
--  1. Pose hierarchy must mirror the rig's ACTUAL joint graph. On modern R15 avatar
--     rigs the arms route UpperTorso > Spine > Chest > LeftClavicle > LeftUpperArm.
--     Using the classic UpperTorso > LeftUpperArm chain silently applies NOTHING.
--     Call AnimBridge.buildHierarchy(rig) to derive it instead of hardcoding.
--  2. AnimationTrack.Length reads 0.000 right after LoadAnimation -- for stock
--     Roblox animations too. It is NOT a failure signal. Ignore it.
--  3. Animation.AnimationId takes the RAW hash from RegisterKeyframeSequence.
--     Prefixing "rbxassetid://" errors with "assetid does not start with a number".
--  4. RegisterActiveKeyframeSequence is Play-mode ("Solo") only.
--     RegisterKeyframeSequence works in Edit, but tracks do not tick in Edit --
--     playback verification requires Play mode.
--  5. Registration is content-addressed: identical data returns an identical hash,
--     and it survives the Edit -> Play transition.
--  6. Blender -> Roblox basis change is (bx,by,bz) -> (-bx, bz, by). Roblox left
--     limbs sit at -X; the Blender rig has them at +X. Rotations must be conjugated:
--     R_roblox = B * R_blender * B^-1. Euler pairing is Blender to_euler('XYZ')
--     <-> Luau CFrame.fromEulerAnglesXYZ.

local KSP = game:GetService("KeyframeSequenceProvider")
local AnimBridge = {}

-- Derive the Pose hierarchy from a rig's real joints (Motor6D or AnimationConstraint).
function AnimBridge.buildHierarchy(rig: Instance): ({[string]: {string}}, string)
	local children: {[string]: {string}} = {}
	local hasParent: {[string]: boolean} = {}
	local seen: {[string]: boolean} = {}
	for _, d in ipairs(rig:GetDescendants()) do
		local a, b
		if d:IsA("Motor6D") then
			a, b = d.Part0, d.Part1
		elseif d:IsA("AnimationConstraint") then
			a = d.Attachment0 and d.Attachment0.Parent
			b = d.Attachment1 and d.Attachment1.Parent
		end
		if a and b then
			children[a.Name] = children[a.Name] or {}
			table.insert(children[a.Name], b.Name)
			hasParent[b.Name] = true
			seen[a.Name] = true; seen[b.Name] = true
		end
	end
	-- Bridge bone-parented joints back to their nearest BasePart ancestor.
	-- Modern R15 rigs anchor LeftShoulder/Neck on Bones (LeftClavicle, Chest) that
	-- are NOT themselves joints, so the joint graph alone leaves the arms and head
	-- orphaned from the root. Walk Instance parentage to reconnect them.
	local byName = {}
	for _, d in ipairs(rig:GetDescendants()) do
		if byName[d.Name] == nil then byName[d.Name] = d end
	end
	local function link(a: string, b: string)
		children[a] = children[a] or {}
		for _, v in ipairs(children[a]) do if v == b then return end end
		table.insert(children[a], b)
		hasParent[b] = true
	end
	local parents = {}
	for k in pairs(children) do table.insert(parents, k) end
	for _, name in ipairs(parents) do
		local inst = byName[name]
		if inst and inst:IsA("Bone") then
			local cur = inst
			while cur and cur.Parent and cur.Parent ~= rig do
				local par = cur.Parent
				link(par.Name, cur.Name)
				if par:IsA("BasePart") then break end
				cur = par
			end
		end
	end

	local root
	for name in pairs(seen) do
		if not hasParent[name] then root = name break end
	end
	return children, root or "HumanoidRootPart"
end

-- frames: { { t = <seconds>, p = { [partName] = CFrame } }, ... }
function AnimBridge.build(rig: Instance, frames, loop: boolean?): Instance
	local hier, root = AnimBridge.buildHierarchy(rig)
	local ks = Instance.new("KeyframeSequence")
	ks.Loop = if loop == nil then true else loop
	local function pose(name, map, parent)
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = map[name] or CFrame.identity
		p.Weight = 1
		p.EasingStyle = Enum.PoseEasingStyle.Linear
		p.Parent = parent
		for _, c in ipairs(hier[name] or {}) do pose(c, map, p) end
		return p
	end
	for _, f in ipairs(frames) do
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		pose(root, f.p, kf)
		kf.Parent = ks
	end
	return ks
end

function AnimBridge.register(ks: Instance): string
	return KSP:RegisterKeyframeSequence(ks)
end

function AnimBridge.play(rig: Instance, frames, opts)
	opts = opts or {}
	local animator = rig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	local ks = AnimBridge.build(rig, frames, opts.loop)
	local anim = Instance.new("Animation")
	anim.AnimationId = AnimBridge.register(ks)
	local track = animator:LoadAnimation(anim)
	track.Looped = if opts.loop == nil then true else opts.loop
	track.Priority = opts.priority or Enum.AnimationPriority.Action
	track:Play(opts.fade or 0)
	return track, ks
end

-- Read live joint rotations back, for numeric verification instead of eyeballing.
function AnimBridge.sample(rig: Instance, jointNames: {string}): {[string]: {number}}
	local out = {}
	local byName = {}
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then byName[d.Name] = d end
	end
	for _, n in ipairs(jointNames) do
		local j = byName[n]
		if j then
			local x, y, z = j.Transform:ToEulerAnglesXYZ()
			out[n] = { math.deg(x), math.deg(y), math.deg(z) }
		end
	end
	return out
end

return AnimBridge
