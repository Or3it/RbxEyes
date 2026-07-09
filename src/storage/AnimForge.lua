--!strict
-- AnimForge (ModuleScript, ServerStorage) — programmatic animation authoring.
-- Build KeyframeSequences in code, register for instant playback (temp id,
-- valid this session). Publishing as a permanent asset = Studio save step.
local KFSP = game:GetService("KeyframeSequenceProvider")

local AnimForge = {}

export type PoseSpec = { part: string, cf: CFrame, weight: number? }
export type FrameSpec = { time: number, poses: { PoseSpec } }

-- rig-relative pose tree: Poses nest by joint hierarchy; for R15/R6 the
-- flat "HumanoidRootPart > children" convention works for simple clips.
function AnimForge.build(name: string, frames: { FrameSpec },
		priority: Enum.AnimationPriority?, looped: boolean?): KeyframeSequence
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Priority = priority or Enum.AnimationPriority.Action
	ks.Loop = looped or false
	for _, f in ipairs(frames) do
		local kf = Instance.new("Keyframe")
		kf.Time = f.time
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		kf:AddPose(root)
		for _, p in ipairs(f.poses) do
			local pose = Instance.new("Pose")
			pose.Name = p.part
			pose.CFrame = p.cf
			pose.Weight = p.weight or 1
			root:AddSubPose(pose)
		end
		kf.Parent = ks
	end
	return ks
end

function AnimForge.register(ks: KeyframeSequence): string
	return KFSP:RegisterKeyframeSequence(ks)
end

function AnimForge.play(rig: Model, tempId: string): AnimationTrack
	local hum = rig:FindFirstChildOfClass("Humanoid")
	assert(hum, "rig has no Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator")
		or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = tempId
	local track = animator:LoadAnimation(anim)
	track:Play()
	return track
end

return AnimForge
