-- PropService: draggable props with client network ownership + rope tether.
local PropService = {}

local MAX_DRAG_DISTANCE = 18

local function setupDragOwnership(part)
	local dd = part:FindFirstChildWhichIsA("DragDetector")
	if not dd then return end
	local rope, a0, a1 = nil, nil, nil
	dd.DragStart:Connect(function(player)
		pcall(function() part:SetNetworkOwner(player) end)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		a0 = Instance.new("Attachment")
		a0.Parent = hrp
		a1 = Instance.new("Attachment")
		a1.Parent = part
		rope = Instance.new("RopeConstraint")
		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Length = MAX_DRAG_DISTANCE
		rope.Restitution = 0
		rope.Visible = false
		rope.Parent = part
	end)
	dd.DragEnd:Connect(function()
		if rope then rope:Destroy() rope = nil end
		if a0 then a0:Destroy() a0 = nil end
		if a1 then a1:Destroy() a1 = nil end
		pcall(function() part:SetNetworkOwnershipAuto() end)
	end)
end

function PropService.init()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:FindFirstChild("Movable") then
			setupDragOwnership(obj)
		end
	end
	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("StringValue") and obj.Name == "Movable" then
			local part = obj.Parent
			if part and part:IsA("BasePart") then
				setupDragOwnership(part)
			end
		end
	end)
end

return PropService
