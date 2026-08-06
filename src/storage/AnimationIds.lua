--!strict
-- Uploaded animation asset IDs (tools/anim_upload.py -> Open Cloud).
--
-- TWO SETS, NOT INTERCHANGEABLE. An animation carries its pose hierarchy baked
-- in. Play one built for the wrong rig and it fails SILENTLY: no error, the
-- track plays, time advances, and the mismatched limbs sit at exactly 0.00 deg.
--
--   Avatar    = stock R15 player rigs. Arms route
--               UpperTorso > Spine > Chest > LeftClavicle > LeftUpperArm.
--   Character = NoLanderBody, the custom S1 skinned mesh. Arms and head hang
--               directly off UpperTorso (16 bones, no clavicles).
--
-- Measured: an Avatar clip on the Character rig animates the legs correctly
-- (29.83 vs 30 deg) while BOTH ARMS READ 0.00. That is a hierarchy mismatch,
-- not a broken animation.
--
-- Character set verified on NoLanderBody, worst delta vs Blender source:
--   idle 0.01, walk 0.17, crouch_walk 0.05, cower 0.43, collapse 0.00,
--   sprint 2.69 (step=2 export decimation on the shortest clip)

return {
	CharacterModelId = 139055569803844,

	Avatar = {
		idle        = "rbxassetid://136922974979522",
		walk        = "rbxassetid://112861278318208",
		sprint      = "rbxassetid://117210452016466",
		crouch_walk = "rbxassetid://98634882700002",
		cower       = "rbxassetid://80486801044642",
		collapse    = "rbxassetid://102592630951395",
	},

	Character = {
		idle        = "rbxassetid://92491560011365",
		walk        = "rbxassetid://103067077784002",
		sprint      = "rbxassetid://135298672739890",
		crouch_walk = "rbxassetid://110886792381284",
		cower       = "rbxassetid://120144297571361",
		collapse    = "rbxassetid://77207458693687",
	},
}
