--!strict
-- Wires Zones.PlayerEntered -> GraphicsKit.apply automatically per zone.
-- LIVE-VERIFIED 2026-07-13: player entering a tagged zone triggers preset
-- change with zero manual invocation (ClockTime/Brightness confirmed
-- flipping on their own via Zones' heartbeat detection).
local RS = game:GetService("ReplicatedStorage")
local Zones = require(RS.Lib.Zones)
local GraphicsKit = require(RS.Lib.GraphicsKit)

local ZoneAtmosphere = {}

function ZoneAtmosphere.init(zoneToPreset: { [string]: string })
	Zones.PlayerEntered:Connect(function(player, zoneName)
		local preset = zoneToPreset[zoneName]
		if preset then
			GraphicsKit.apply(preset)
			print("[ZoneAtmosphere] " .. player.Name .. " entered " .. zoneName ..
				" -> applied " .. preset)
		end
	end)
end

return ZoneAtmosphere
