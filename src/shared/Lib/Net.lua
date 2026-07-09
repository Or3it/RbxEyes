--!strict
-- Net — validated, rate-limited networking. Generalizes the laser fix:
-- every remote gets schema validation + per-player token buckets, so agents
-- composing features never ship an unvalidated remote again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = {}
local folder: Folder

local function remotes(): Folder
	if folder then return folder end
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

type Schema = { string }  -- ordered arg types: "number"|"string"|"boolean"|"Vector3"|"CFrame"|"Instance"|"table"

local function validate(schema: Schema, args: { any }): (boolean, string?)
	if #args > #schema then return false, "too many args" end
	for i, ty in ipairs(schema) do
		local v = args[i]
		if v == nil then return false, "missing arg " .. i end
		if typeof(v) ~= ty then
			return false, ("arg %d: expected %s got %s"):format(i, ty, typeof(v))
		end
	end
	return true, nil
end

-- Token bucket per player
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}
Players.PlayerRemoving:Connect(function(p) buckets[p] = nil end)

local function allow(player: Player, name: string, ratePerSec: number,
		burst: number): boolean
	local pb = buckets[player]
	if not pb then pb = {}; buckets[player] = pb end
	local b = pb[name]
	local now = os.clock()
	if not b then b = { tokens = burst, last = now }; pb[name] = b end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * ratePerSec)
	b.last = now
	if b.tokens >= 1 then b.tokens -= 1 return true end
	return false
end

export type EventDef = {
	name: string, schema: Schema,
	ratePerSec: number?, burst: number?,
}

-- SERVER: define + handle with validation and rate limiting baked in.
function Net.onServer(def: EventDef, handler: (Player, ...any) -> ())
	assert(RunService:IsServer(), "Net.onServer is server-only")
	local ev = remotes():FindFirstChild(def.name) :: RemoteEvent
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = def.name
		ev.Parent = remotes()
	end
	local rate = def.ratePerSec or 10
	local burst = def.burst or math.max(3, rate)
	ev.OnServerEvent:Connect(function(player, ...)
		if not allow(player, def.name, rate, burst) then
			warn(("[Net] rate-limited %s from %s"):format(def.name, player.Name))
			return
		end
		local args = { ... }
		local ok, err = validate(def.schema, args)
		if not ok then
			warn(("[Net] rejected %s from %s: %s"):format(def.name, player.Name, err :: string))
			return
		end
		handler(player, ...)
	end)
	return ev
end

-- CLIENT: fire (waits for the remote to exist)
function Net.fire(name: string, ...: any)
	assert(RunService:IsClient(), "Net.fire is client-only")
	local ev = remotes():WaitForChild(name, 10) :: RemoteEvent?
	assert(ev, "no remote " .. name)
	ev:FireServer(...)
end

-- SERVER -> clients
function Net.fireClient(name: string, player: Player, ...: any)
	local ev = remotes():FindFirstChild(name) :: RemoteEvent
	if ev then ev:FireClient(player, ...) end
end
function Net.fireAll(name: string, ...: any)
	local ev = remotes():FindFirstChild(name) :: RemoteEvent
	if ev then ev:FireAllClients(...) end
end

return Net
