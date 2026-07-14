--!strict
local RS = game:GetService("ReplicatedStorage")
local Zones = require(RS.Lib.Zones)
local SoundKit = require(RS.Lib.SoundKit)
local ZoneAudio = {}
function ZoneAudio.init(zoneToSoundId: { [string]: string })
	Zones.PlayerEntered:Connect(function(player, zoneName)
		local soundId = zoneToSoundId[zoneName]
		if soundId then
			SoundKit.ambientBed(soundId, 2)
			print("[ZoneAudio] " .. player.Name .. " entered " .. zoneName .. " -> bed switched")
		end
	end)
end
return ZoneAudio
