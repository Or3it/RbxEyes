--!strict
-- Forge (ModuleScript, ServerStorage) — procedural asset creation.
-- Build meshes/textures from Luau specs or pull big specs from the bridge.
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local Forge = {}
local BRIDGE = "http://127.0.0.1:7791"

export type MeshSpec = {
	verts: { { number } },          -- [[x,y,z], ...]
	tris: { { number } },           -- 1-based vert indices [[a,b,c], ...]
	uvs: { { number } }?,           -- [[u,v], ...]
	face_uvs: { { number } }?,      -- per-tri uv indices [[i,j,k], ...]
	image: { w: number, h: number, px_b64: string }?, -- RGBA bytes, base64
}

function Forge.buildImage(w: number, h: number, writePixel: (x: number, y: number) -> (number, number, number, number)): EditableImage
	local ei = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	local buf = buffer.create(w * h * 4)
	local i = 0
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b, a = writePixel(x, y)
			buffer.writeu8(buf, i, r); buffer.writeu8(buf, i + 1, g)
			buffer.writeu8(buf, i + 2, b); buffer.writeu8(buf, i + 3, a)
			i += 4
		end
	end
	ei:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	return ei
end

function Forge.buildMesh(spec: MeshSpec): MeshPart
	local em = AssetService:CreateEditableMesh()
	local vids = table.create(#spec.verts)
	for i, v in ipairs(spec.verts) do
		vids[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
	end
	local uvids = nil
	if spec.uvs then
		uvids = table.create(#spec.uvs)
		for i, uv in ipairs(spec.uvs) do
			uvids[i] = em:AddUV(Vector2.new(uv[1], uv[2]))
		end
	end
	for ti, t in ipairs(spec.tris) do
		local fid = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
		if uvids and spec.face_uvs and spec.face_uvs[ti] then
			local fu = spec.face_uvs[ti]
			em:SetFaceUVs(fid, { uvids[fu[1]], uvids[fu[2]], uvids[fu[3]] })
		end
	end
	return AssetService:CreateMeshPartAsync(Content.fromObject(em))
end

function Forge.applyTexture(part: MeshPart, ei: EditableImage): string
	-- Try direct TextureContent first, fall back to SurfaceAppearance.
	local ok = pcall(function()
		(part :: any).TextureContent = Content.fromObject(ei)
	end)
	if ok then return "TextureContent" end
	local sa = Instance.new("SurfaceAppearance")
	local ok2, err = pcall(function()
		(sa :: any).ColorMapContent = Content.fromObject(ei)
		sa.Parent = part
	end)
	return ok2 and "SurfaceAppearance" or ("failed: " .. tostring(err))
end

function Forge.fetchSpec(id: string): MeshSpec
	local meta = HttpService:JSONDecode(
		HttpService:GetAsync(BRIDGE .. "/forge/spec/" .. id .. "/meta"))
	local parts = table.create(meta.chunks)
	for i = 0, meta.chunks - 1 do
		parts[i + 1] = HttpService:GetAsync(
			BRIDGE .. "/forge/spec/" .. id .. "/chunk/" .. i)
	end
	return HttpService:JSONDecode(table.concat(parts))
end

return Forge
