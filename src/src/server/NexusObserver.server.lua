--!strict
-- NexusObserver — streams game state to the local bridge.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

if not RunService:IsServer() then return end

local BRIDGE = script:GetAttribute("BridgeUrl") or "http://127.0.0.1:7791/ingest"
local HZ = tonumber(script:GetAttribute("Hz")) or 3
local TAG = "observe"
local MAX_EVENTS_PER_TICK = 40

local session = HttpService:GenerateGUID(false)
local clock0 = os.clock()
local pendingEvents: { { [string]: any } } = {}
local touchDebounce: { [string]: number } = {}
local consecutiveFails = 0
local skipUntil = 0

local function now(): number
	return os.clock() - clock0
end

local function pushEvent(ev: { [string]: any })
	if #pendingEvents < MAX_EVENTS_PER_TICK then
		ev.t = now()
		table.insert(pendingEvents, ev)
	end
end

local function primaryPart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local hooked: { [Instance]: boolean } = {}

local function hook(inst: Instance)
	if hooked[inst] then return end
	hooked[inst] = true
	local part = primaryPart(inst)
	if part then
		part.Touched:Connect(function(other: BasePart)
			local key = inst:GetFullName() .. "|" .. other:GetFullName()
			local t = now()
			if (touchDebounce[key] or -1) + 0.25 < t then
				touchDebounce[key] = t
				pushEvent({ kind = "touched", a = inst:GetFullName(),
					b = other:GetFullName() })
			end
		end)
	end
	local hum = inst:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
			pushEvent({ kind = "humanoid_state", a = inst:GetFullName(),
				state = new.Name })
		end)
	end
end

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do hook(inst) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)

local function snapshot(): { [string]: any }
	local ents = {}
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		local part = primaryPart(inst)
		if part then
			local cf, vel = part.CFrame, part.AssemblyLinearVelocity
			local rx, ry, rz = cf:ToEulerAnglesXYZ()
			local hum = inst:FindFirstChildOfClass("Humanoid")
			table.insert(ents, {
				id = inst:GetFullName(),
				class = inst.ClassName,
				cf = { cf.X, cf.Y, cf.Z, rx, ry, rz },
				vel = { vel.X, vel.Y, vel.Z },
				humanoid = hum and hum:GetState().Name or nil,
			})
		end
	end
	local events = pendingEvents
	pendingEvents = {}
	return {
		t = now(),
		session = session,
		entities = ents,
		physics = { fps = workspace:GetRealPhysicsFPS() },
		events = events,
	}
end

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	if script:GetAttribute("Enabled") == false then return end
	acc += dt
	if acc < 1 / HZ then return end
	acc = 0
	if now() < skipUntil then return end
	local body = HttpService:JSONEncode(snapshot())
	local ok = pcall(function()
		HttpService:PostAsync(BRIDGE, body, Enum.HttpContentType.ApplicationJson)
	end)
	if ok then
		consecutiveFails = 0
	else
		consecutiveFails += 1
		skipUntil = now() + math.min(30, 2 ^ consecutiveFails)
	end
end)

print(("[NexusObserver] session %s -> %s @ %dHz, tag '%s'"):format(
	session, BRIDGE, HZ, TAG))
