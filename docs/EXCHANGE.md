# The exchange folder — how Blender and Studio share files

`~/Documents/rbx-eyes/exchange/` is the single shared path both sides read
and write. Before this existed, every Blender->Studio handoff required a
human to move a file out of /tmp. Now Blender writes here directly and
Studio/the bridge read from here.

## What lives here (built + verified 2026-07-13)
- `nolander_rig.blend` — the source of truth: R15_WalkRig (16 bones,
  Roblox part naming), NoLanderBody (skinned, 1920 verts), 6 actions.
  Reopen this to author more animations; don't rebuild the rig from scratch.
- `nolander_character_skinned.fbx` — custom body, bind pose, all 1920 verts
  weighted across 16 R15-named groups. Deformation VERIFIED numerically
  (tracked vertex moved 0.337 units under a 45deg leg swing).
- `r15_{idle,walk,sprint,crouch_walk,cower,collapse}.fbx` — animation set.

## Which paths are automated vs GUI-bound (important)
- **Meshes: FULLY AUTOMATED.** Blender -> exchange -> `tools/mesh2spec.py`
  -> bridge -> Studio fetches via HttpService -> Forge builds EditableMesh.
  No GUI. This is how the treasure chest landed in-game.
- **Animations: GUI-BOUND.** Studio's Animation Editor import
  (Avatar > Clip Editor > ... > Import > From File) has no scripting API.
  A human or a computer-use session must click it. Open Cloud upload with
  assetType=Animation is the untested alternative path — worth trying, but
  do not assume it works until verified.
- **Skinned characters: GUI-BOUND.** Studio's 3D Importer is also GUI-only.

So "one-shot autonomous tool creation" is real for static meshes today,
and blocked on GUI for anything rigged/animated until either Open Cloud
animation upload is proven or a computer-use session drives the clicks.

## Gotcha found the hard way (2026-07-13)
Blender's FBX exporter defaults to `bake_anim_use_all_actions=True`, which
bundles EVERY action in the file into EVERY export. Six exports grew
110KB -> 530KB, ~84KB per accumulated action. Always pass
`bake_anim_use_all_actions=False` and `bake_anim_use_nla_strips=False`
when exporting one animation at a time. Correct single-action size for
this rig is ~105KB; anything climbing per-export means the bug is back.
