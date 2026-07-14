--!strict
-- VisionKit — deterministic camera framing for automated visual verification.
-- LIVE-VERIFIED 2026-07-13: uncontrolled viewport framing was the entire
-- cause of unreliable screen-capture verification; locking the camera on the
-- subject before capture fixed it in one step (walk-cycle stride confirmed
-- visually on first framed attempt after multiple unframed failures).
--
-- Protocol for any Claude session verifying visuals:
--   1) CLIENT: VisionKit.frameSubject(char)  -- lock camera on subject
--   2) capture via screen_capture subagent, asking SPECIFIC verifiable
--      questions ("is one leg forward of the other?"), never "describe it"
--   3) VisionKit.release()  -- hand camera back to the player
-- For motion: two captures ~0.5s apart, ask what CHANGED between limbs.

local Players = game:GetService("Players")

local VisionKit = {}

-- Lock the camera on a subject (Model with PrimaryPart/HRP, or BasePart).
-- offset: camera position relative to subject (default: front-side 3/4 view,
-- full body in frame — the angle verified to give unambiguous limb reads).
function VisionKit.frameSubject(subject: Instance, offset: Vector3?): ()
	local cam = workspace.CurrentCamera
	local target: Vector3
	if subject:IsA("Model") then
		local part = (subject :: Model).PrimaryPart
			or subject:FindFirstChild("HumanoidRootPart")
			or subject:FindFirstChildWhichIsA("BasePart", true)
		assert(part, "VisionKit: subject has no BasePart")
		target = (part :: BasePart).Position
	elseif subject:IsA("BasePart") then
		target = subject.Position
	else
		error("VisionKit: subject must be Model or BasePart")
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.new(target + (offset or Vector3.new(6, 1, 6)), target)
end

-- Frame the local player's character (most common QA case).
function VisionKit.frameLocalPlayer(offset: Vector3?): ()
	local plr = Players.LocalPlayer
	assert(plr, "VisionKit.frameLocalPlayer is client-only")
	local char = plr.Character or plr.CharacterAdded:Wait()
	VisionKit.frameSubject(char, offset)
end

-- Return camera control to the player.
function VisionKit.release(): ()
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

return VisionKit
