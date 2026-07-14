--!strict
local Lighting = game:GetService("Lighting")
local GraphicsKit = {}
local PRESETS = {
	horror_night = {
		lighting = { ClockTime = 0, Brightness = 1, ExposureCompensation = -0.3,
			Ambient = Color3.fromRGB(15, 18, 22),
			OutdoorAmbient = Color3.fromRGB(25, 30, 40) },
		atmosphere = { Density = 0.55, Offset = 0.2,
			Color = Color3.fromRGB(60, 70, 80),
			Decay = Color3.fromRGB(30, 35, 45) },
		colorCorrection = { Contrast = 0.15, Saturation = -0.3,
			TintColor = Color3.fromRGB(200, 220, 225) },
		bloom = { Intensity = 0.3, Size = 24, Threshold = 1.2 },
	},
}
local function ensure(className)
	local inst = Lighting:FindFirstChildOfClass(className)
	if not inst then inst = Instance.new(className); inst.Parent = Lighting end
	return inst
end
local function applyProps(inst, props)
	for k, v in pairs(props) do (inst :: any)[k] = v end
end
function GraphicsKit.apply(presetName)
	local p = PRESETS[presetName] or error("no preset " .. presetName)
	applyProps(Lighting, p.lighting)
	if p.atmosphere then applyProps(ensure("Atmosphere"), p.atmosphere) end
	if p.bloom then applyProps(ensure("BloomEffect"), p.bloom) end
	if p.colorCorrection then applyProps(ensure("ColorCorrectionEffect"), p.colorCorrection) end
end
return GraphicsKit
