--!strict
-- VFXKit — parameterized particle/beam/trail composers with presets.
-- Shindo-style ability volume = composing these, not hand-building emitters.
local Debris = game:GetService("Debris")

local VFXKit = {}

type PresetDef = { [string]: any }
local PRESETS: { [string]: PresetDef } = {
	hit_spark = { Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)),
		Lifetime = NumberRange.new(0.15, 0.3), Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.35),
		Light = 2, Count = 14 },
	blood_mist = { Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 12, 12)),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1) }), Count = 10 },
	muzzle_flash = { Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)),
		Lifetime = NumberRange.new(0.04, 0.09), Speed = NumberRange.new(1, 3),
		Size = NumberSequence.new(0.8), Light = 4, Count = 6 },
	smoke_puff = { Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(140, 140, 140)),
		Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 2.5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 2.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1) }), Count = 8 },
	heal_glow = { Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(110, 255, 140)),
		Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(1.5, 3),
		Size = NumberSequence.new(0.3), Light = 1.5, Count = 12 },
}

local function attach(parent: Instance): (Attachment, BasePart?)
	if parent:IsA("Attachment") then return parent, nil end
	if parent:IsA("BasePart") then
		local a = Instance.new("Attachment")
		a.Parent = parent
		return a, nil
	end
	error("VFXKit: parent must be BasePart or Attachment")
end

-- One-shot burst at a part/attachment. overrides merge onto the preset.
function VFXKit.burst(parent: Instance, preset: string,
		overrides: PresetDef?): ()
	local def = table.clone(PRESETS[preset] or error("no preset " .. preset))
	if overrides then
		for k, v in pairs(overrides) do def[k] = v end
	end
	local a = attach(parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Texture = def.Texture
	pe.Color = def.Color
	pe.Lifetime = def.Lifetime
	pe.Speed = def.Speed
	pe.SpreadAngle = def.SpreadAngle or Vector2.new(30, 30)
	pe.Size = def.Size
	if def.Transparency then pe.Transparency = def.Transparency end
	pe.LightEmission = def.Light or 0.5
	pe.Parent = a
	pe:Emit(def.Count or 10)
	Debris:AddItem(pe, (def.Lifetime.Max or 1) + 0.5)
end

function VFXKit.beam(a0: Attachment, a1: Attachment, color: Color3,
		width: number?, lifetime: number?): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Width0 = width or 0.3
	b.Width1 = (width or 0.3) * 0.6
	b.FaceCamera = true
	b.LightEmission = 1
	b.Parent = a0
	if lifetime then Debris:AddItem(b, lifetime) end
	return b
end

function VFXKit.trail(part: BasePart, color: Color3, lifetime: number?): Trail
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.3, 0); a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.3, 0); a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(color)
	tr.Lifetime = lifetime or 0.35
	tr.LightEmission = 0.8
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = part
	return tr
end

return VFXKit
