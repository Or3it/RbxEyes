# Animation Pipeline — GUI bottleneck removed

Status: **animation half of T02 is solved without the Animation Editor.**
Verified live in Studio 2026-07-26 on `workspace.Rig` (R15).

## What works

Blender action -> joint-local rotation matrices -> `KeyframeSequence` built in Luau ->
`KeyframeSequenceProvider:RegisterKeyframeSequence` -> `Animation.AnimationId` ->
`Animator:LoadAnimation` -> plays on a live rig. Zero GUI, fully scriptable over MCP.

Implementation: `src/storage/AnimBridge.lua`.

### Verification (R15_idle, not eyeballed)

| joint | live measured | Blender source |
|---|---|---|
| Waist X | -2.48 .. +2.39 deg | +/- 2.49 |
| Neck X | -1.47 .. +1.43 deg | -1.47 .. +1.50 |
| LeftShoulder Z | held 4.00 deg | 4.00 |

Sampled values fall just inside source extremes because sampling misses the exact
interpolation peaks. That is the expected signature of correct playback, not error.

## Hard limit

`RegisterKeyframeSequence` IDs are **temporary and Studio-only**. They do not work in
a published game. For shipping, the same generated `KeyframeSequence` must be
serialized and uploaded. Open Cloud accepts Animation uploads (since Oct 2025) but
only from `.rbxm`/`.rbxmx` — never from FBX. Send `.rbxmx` XML with content type
`model/x-rbxm`; `model/x-rbxmx` returns 400. **This upload path is not yet tested.**

## Gotchas found

1. **Pose hierarchy must mirror the rig's real joint graph.** Modern R15 avatar rigs
   route arms `UpperTorso > Spine > Chest > LeftClavicle > LeftUpperArm`. The classic
   `UpperTorso > LeftUpperArm` chain applies **nothing, silently** — no error, track
   plays, time advances, transforms stay identity.
2. Those intermediate links are `Bone` instances, not joints, so deriving the tree
   from Motor6D/AnimationConstraint alone orphans the arms and head. `buildHierarchy`
   walks Instance parentage to reconnect them.
3. `AnimationTrack.Length` reads `0.000` right after `LoadAnimation` — including for
   stock Roblox animations. Not a failure signal.
4. `Animation.AnimationId` takes the **raw hash**. `rbxassetid://<hash>` errors.
5. `RegisterActiveKeyframeSequence` is Play-mode only. `RegisterKeyframeSequence`
   works in Edit, but tracks do not tick there — verification needs Play.
6. Registration is content-addressed: same data -> same hash, and it survives
   Edit -> Play.
7. `require()` caches ModuleScripts across `execute_luau` calls. After editing a
   module, clone it to force a fresh require or you will test stale code.
8. Blender -> Roblox basis change is `(bx,by,bz) -> (-bx, bz, by)`. Roblox left limbs
   sit at -X, the Blender rig has them at +X. Conjugate: `R = B * R_blender * B^-1`.
   Pair Blender `to_euler('XYZ')` with Luau `CFrame.fromEulerAnglesXYZ`.

## Still open

- Remaining 5 animations (walk, sprint, crouch_walk, cower, collapse) — same path,
  not yet run through.
- Skinned character (`nolander_character_skinned.fbx`) — separate problem. It is a
  Model; Open Cloud takes FBX for Models directly, but whether skin weights survive
  without the 3D Importer's settings panel is untested.
- Open Cloud `.rbxmx` animation upload — untested.
