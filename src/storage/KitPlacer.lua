--!strict
-- KitPlacer — modular map assembly from curated marketplace kits.
-- Manifest = list of { assetId, cf (CFrame components), name? }. Jailbreak-
-- scale maps are kit-bashed, not generated: curate once, compose forever.
local InsertService = game:GetService("InsertService")

local KitPlacer = {}

export type Placement = { assetId: number, cf: { number }, name: string? }

function KitPlacer.place(manifest: { Placement }, parent: Instance?): (number, { string })
	local target = parent or workspace
	local placed, failed = 0, {}
	for _, p in ipairs(manifest) do
		local ok, err = pcall(function()
			local model = InsertService:LoadAsset(p.assetId)
			local child = model:GetChildren()[1]
			child.Parent = target
			if p.name then child.Name = p.name end
			if child:IsA("Model") then
				child:PivotTo(CFrame.new(table.unpack(p.cf)))
			elseif child:IsA("BasePart") then
				child.CFrame = CFrame.new(table.unpack(p.cf))
			end
			model:Destroy()
			placed += 1
		end)
		if not ok then
			table.insert(failed, tostring(p.assetId) .. ": " .. tostring(err))
		end
	end
	return placed, failed
end

function KitPlacer.grid(assetId: number, origin: Vector3, cols: number,
		rows: number, spacing: number): { Placement }
	local out = {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			table.insert(out, { assetId = assetId,
				cf = { origin.X + c * spacing, origin.Y,
					origin.Z + r * spacing } })
		end
	end
	return out
end

return KitPlacer
