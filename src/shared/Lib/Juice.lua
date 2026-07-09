--!strict
-- Juice — procedural game-feel: springs, shake, pops, recoil.
-- This is where Phantom-Forces-style feel comes from: code, not keyframes.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Juice = {}

-- Critically-dampable spring (position + velocity), step per frame.
local Spring = {}
Spring.__index = Spring
export type Spring = typeof(setmetatable(
	{} :: { pos: number, vel: number, target: number,
		stiffness: number, damping: number }, Spring))

function Juice.spring(initial: number?, stiffness: number?, damping: number?): Spring
	return setmetatable({ pos = initial or 0, vel = 0, target = initial or 0,
		stiffness = stiffness or 170, damping = damping or 22 }, Spring)
end

function Spring.step(self: Spring, dt: number): number
	local force = (self.target - self.pos) * self.stiffness
	self.vel += (force - self.vel * self.damping) * dt
	self.pos += self.vel * dt
	return self.pos
end

function Spring.impulse(self: Spring, v: number)
	self.vel += v
end

-- Camera/model shake: intensity decays over duration.
function Juice.shake(camera: Camera, intensity: number, duration: number)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - t0
		if elapsed >= duration then conn:Disconnect() return end
		local decay = 1 - (elapsed / duration)
		local mag = intensity * decay
		camera.CFrame = camera.CFrame * CFrame.Angles(
			(math.random() - 0.5) * mag * 0.02,
			(math.random() - 0.5) * mag * 0.02,
			(math.random() - 0.5) * mag * 0.01)
	end)
end

-- GUI pop (scale bounce) — hover/click feedback.
function Juice.pop(gui: GuiObject, scale: number?, time_: number?)
	local s = scale or 1.12
	local t = time_ or 0.12
	local orig = gui.Size
	local big = UDim2.new(orig.X.Scale * s, orig.X.Offset * s,
		orig.Y.Scale * s, orig.Y.Offset * s)
	local up = TweenService:Create(gui, TweenInfo.new(t / 2,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = big })
	up.Completed:Once(function()
		TweenService:Create(gui, TweenInfo.new(t / 2,
			Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = orig }):Play()
	end)
	up:Play()
end

-- Weapon recoil: kick a spring, caller applies .pos to camera pitch offset.
function Juice.recoilKick(spring: Spring, vertical: number)
	spring:impulse(vertical)
end

-- Quick tween presets
local PRESETS = {
	snappy = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	smooth = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	dramatic = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}
function Juice.tween(inst: Instance, preset: string, props: { [string]: any }): Tween
	local tw = TweenService:Create(inst, PRESETS[preset] or PRESETS.smooth, props)
	tw:Play()
	return tw
end

return Juice
