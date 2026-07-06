-- Main: bootstrap. Creates remotes, wires modules, starts the round loop.
-- All logic lives in ServerScriptService.Modules; all tuning in
-- ReplicatedStorage.Config.
print("Hiding from NoLander - server starting")

local RS = game:GetService("ReplicatedStorage")
local Modules = script.Parent:WaitForChild("Modules")

-- getOrCreate guard: duplicate RemoteEvents across sessions cause silent bugs
local function getOrCreate(name)
	local existing = RS:FindFirstChild(name)
	if existing then return existing end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = RS
	return re
end

local remotes = {
	LaserFired = getOrCreate("LaserFired"),
	WindupStarted = getOrCreate("WindupStarted"),
	PlayDead = getOrCreate("PlayDead"),
	UpdateTimer = getOrCreate("UpdateTimer"),
	RoundResult = getOrCreate("RoundResult"),
}

local RagdollService = require(Modules.RagdollService)
local HealthService = require(Modules.HealthService)
local DamageService = require(Modules.DamageService)
local LockerService = require(Modules.LockerService)
local PropService = require(Modules.PropService)
local RoundManager = require(Modules.RoundManager)

RagdollService.init(remotes)
HealthService.init({onBleedDeath = DamageService.keepBodyOnDeath})
DamageService.init(remotes, RagdollService, HealthService)
LockerService.init(RagdollService)
PropService.init()
RoundManager.init(remotes, RagdollService, HealthService)
RoundManager.start()
