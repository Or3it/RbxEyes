--!strict
-- Zones — tagged BasePart volumes with player enter/exit signals.
-- Tag any part "zone" + set attribute ZoneName. Poll-based (reliable,
-- cheap at low Hz) rather than Touched (flaky for volumes).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Zones = {}
local TAG = "zone"
local HZ = 6

local entered = Instance.new("BindableEvent")  -- (player, zoneName)
local exited = Instance.new("BindableEvent")   -- (player, zoneName)
Zones.PlayerEntered = entered.Event
Zones.PlayerExited = exited.Event

local inside: { [Player]: { [string]: boolean } } = {}
local overlapParams = OverlapParams.new()

local function zoneName(part: BasePart): string
	return (part:GetAttribute("ZoneName") :: string?) or part.Name
end

function Zones.playersIn(name: string): { Player }
	local out = {}
	for p, zs in pairs(inside) do
		if zs[name] then table.insert(out, p) end
	end
	return out
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / HZ then return end
	acc = 0
	local nowIn: { [Player]: { [string]: boolean } } = {}
	for _, part in ipairs(CollectionService:GetTagged(TAG)) do
		if part:IsA("BasePart") then
			local parts = workspace:GetPartBoundsInBox(part.CFrame, part.Size,
				overlapParams)
			local seen: { [Player]: boolean } = {}
			for _, hit in ipairs(parts) do
				local char = hit:FindFirstAncestorOfClass("Model")
				local plr = char and Players:GetPlayerFromCharacter(char)
				if plr and not seen[plr] then
					seen[plr] = true
					nowIn[plr] = nowIn[plr] or {}
					nowIn[plr][zoneName(part)] = true
				end
			end
		end
	end
	for plr, zs in pairs(nowIn) do
		for z in pairs(zs) do
			if not (inside[plr] and inside[plr][z]) then
				entered:Fire(plr, z)
			end
		end
	end
	for plr, zs in pairs(inside) do
		for z in pairs(zs) do
			if not (nowIn[plr] and nowIn[plr][z]) then
				exited:Fire(plr, z)
			end
		end
	end
	inside = nowIn
end)

Players.PlayerRemoving:Connect(function(p) inside[p] = nil end)

return Zones
