--!strict
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local SoundKit = {}
local GROUPS = { "Master", "Music", "SFX", "Ambience", "UI" }
local groups: { [string]: SoundGroup } = {}

function SoundKit.init()
	local master: SoundGroup? = nil
	for _, name in ipairs(GROUPS) do
		local g = SoundService:FindFirstChild(name) :: SoundGroup?
		if not g then
			g = Instance.new("SoundGroup"); g.Name = name
			g.Parent = (name == "Master") and SoundService or master
		end
		groups[name] = g :: SoundGroup
		if name == "Master" then master = g end
	end
end

local currentBed: Sound? = nil
function SoundKit.ambientBed(soundId: string, fadeTime: number?)
	local ft = fadeTime or 2
	if currentBed then
		local old = currentBed
		TweenService:Create(old, TweenInfo.new(ft), { Volume = 0 })
			.Completed:Once(function() old:Destroy() end)
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId; s.Looped = true; s.Volume = 0
	if groups.Ambience then s.SoundGroup = groups.Ambience end
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(ft), { Volume = 0.5 }):Play()
	currentBed = s
	return s
end

function SoundKit.currentBedSound(): Sound? return currentBed end
return SoundKit
