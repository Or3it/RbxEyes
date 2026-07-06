-- LockerService: hide-in-locker with hinged door swing animation.
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage:WaitForChild("Config"))

local LockerService = {}
local Ragdoll = nil

local DOOR_OPEN_ANGLE = 100 -- degrees; flip sign if a locker swings the wrong way
local DOOR_SWING_TIME = 0.4

local function setupLocker(lockerModel)
	if not lockerModel.PrimaryPart then return end
	local prompt = lockerModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then return end
	local occupant = nil

	-- Hinge on the door's left edge: rotating around the door's own center is
	-- the classic mistake that makes doors swing into walls.
	local door = lockerModel:FindFirstChild("Door")
	local cycleDoor = function() end
	if door then
		local closedCFrame = door.CFrame
		local hingeCFrame = closedCFrame * CFrame.new(-door.Size.X / 2, 0, 0)
		local hingeOffset = hingeCFrame:ToObjectSpace(closedCFrame)
		local openCFrame = hingeCFrame * CFrame.Angles(0, math.rad(DOOR_OPEN_ANGLE), 0) * hingeOffset
		local openTween = TweenService:Create(door,
			TweenInfo.new(DOOR_SWING_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{CFrame = openCFrame})
		local closeTween = TweenService:Create(door,
			TweenInfo.new(DOOR_SWING_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{CFrame = closedCFrame})
		cycleDoor = function()
			openTween:Play()
			task.delay(DOOR_SWING_TIME + 0.15, function()
				closeTween:Play()
			end)
		end
	end

	prompt.Triggered:Connect(function(player)
		local role = player:FindFirstChild("Role")
		if not role or role.Value ~= "Survivor" then return end
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChild("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		-- Can't climb into a locker while ragdolled on the floor
		if Ragdoll and Ragdoll.isPlayingDead(player) then return end

		if occupant == nil then
			occupant = player
			char:SetAttribute("InLocker", true)
			hrp.CFrame = lockerModel.PrimaryPart.CFrame
			hrp.Anchored = true
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hrp.CanCollide = false
			prompt.ActionText = "Exit"
			cycleDoor()
			print(player.Name .. " hiding in locker")
		elseif occupant == player then
			occupant = nil
			char:SetAttribute("InLocker", false)
			hrp.Anchored = false
			hrp.CFrame = lockerModel.PrimaryPart.CFrame * CFrame.new(0, 0, -4)
			local legHit = char:FindFirstChild("LegHit")
			hum.WalkSpeed = legHit and Config.CRAWL_SPEED or Config.WALK_SPEED
			hum.JumpPower = legHit and 0 or Config.JUMP_POWER
			hrp.CanCollide = true
			prompt.ActionText = "Hide"
			cycleDoor()
			print(player.Name .. " exited locker")
		end
	end)
	print("Locker setup: " .. lockerModel.Name)
end

function LockerService.init(ragdollService)
	Ragdoll = ragdollService
	task.spawn(function()
		task.wait(0.5)
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and obj:FindFirstChild("LockerTag") then
				setupLocker(obj)
			end
		end
	end)
	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("StringValue") and obj.Name == "LockerTag" then
			local lockerModel = obj.Parent
			if not lockerModel.PrimaryPart then task.wait(1) end
			setupLocker(lockerModel)
		end
	end)
end

return LockerService
