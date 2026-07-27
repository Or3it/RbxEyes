# Animation Pipeline — GUI bottleneck removed, end to end

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

## Shipping path — PROVEN

Hand-generated `.rbxmx` uploads through Open Cloud and produces a working, permanent
animation asset. Roblox's docs warn that `.rbxmx` edited outside Studio "might not
upload or function" — for a KeyframeSequence built by `tools/anim_upload.py`, it does
both.

R15_idle -> asset **136922974979522**, moderation Approved, state Active. Loaded on a
live rig by real `rbxassetid://`, `GetAnimationClipAsync` returned a 15-keyframe
KeyframeSequence, and playback measured Waist -2.44..2.46 (source +/-2.49),
Neck -1.47..1.45 (source -1.47..+1.50), LeftShoulder Z 4.00 exact.

`RegisterKeyframeSequence` remains the fast iteration loop (no upload, no quota,
instant); Open Cloud is the ship step. Nothing in the pipeline needs a GUI.

Send `.rbxmx` as content type `model/x-rbxm` — `model/x-rbxmx` returns 400.

### API key scope
The key needs the **Asset** permission, read and write. Without it *every* asset
endpoint — including read-only `asset-quotas` — returns
`403 PERMISSION_DENIED: "User not authenticated"`. That message is misleading: the key
authenticates fine against `/cloud/v2/users/{id}`. If asset calls 403 but user calls
200, it is scope, not the key.

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


## Full animation set — all six verified live (2026-07-26)

Every clip run through the pipeline onto `workspace.Rig` and measured against its
Blender source. Angle metric is the true rotation angle `acos((trace-1)/2)`, not
euler magnitude — euler magnitude stops equalling rotation angle past 90 deg and
cower reaches 108.

| clip | bones | peak angle | worst delta | root translation |
|---|---|---|---|---|
| idle | 4 | 5.0 deg | ~0.1 deg | — |
| walk | 7 | 28.5 deg | 0.02 deg | — |
| sprint | 10 | 55.0 deg | 1.51 deg | — |
| crouch_walk | 8 | 45.0 deg | 0.01 deg | -1.024 exact |
| cower | 11 | 107.8 deg | 0.06 deg | -1.630 exact |
| collapse | 9 | 75.0 deg | 0.01 deg | -4.191 exact (animated) |

Sprint's 1.51 deg is sampling aliasing, not conversion error: it is the shortest clip
(0.79s) with the fastest limbs, and live peaks land **under** Blender peaks on exactly
the joints whose peak occurs at a single instant. Joints that hold their peak across
keyframes match to 0.00. Left/right stay perfectly symmetric (40.85/40.85, 46.68/46.68),
which a bad basis change would break.

### Root translation

Blender root `location` maps onto the **LowerTorso pose position** (the `Root` joint),
not the HumanoidRootPart pose — the root pose maps to no joint and is ignored.
No code change needed; pass a `CFrame` with a position component.

Scale factor **4.6565** studs per Blender unit, measured from clean rest geometry
(head-to-foot 6.053 studs vs 1.300 Blender units). Blender `z` -> Roblox `y`.

Clean rest also confirms the X flip: LeftUpperArm sits at -0.90, RightUpperArm at +0.90.

### Two more gotchas

9. **Blender pose state leaks between actions.** Assigning a new action does not clear
   channels that action does not animate. Sprint has no `location` fcurves but read
   back -0.90 on HumanoidRootPart — the leftover final value from collapse. Reset every
   pose bone (`location`, `rotation_euler`, `rotation_quaternion`, `scale`) before
   switching actions, or you export another clip's root motion by accident.
10. **Assert row length when hand-carrying pose data.** A single dropped identity
    quaternion shifts every later bone by one and produces plausible-looking wrong
    output — deltas of 3-12 deg that read like a conversion bug rather than a typo.
    `#row == 2 + 4*#bones` catches it instantly.

## Skinned character — works, with a trap

`nolander_character_skinned.fbx` uploaded as a **Model** via the same Assets API
(content type `model/fbx`) -> asset **139055569803844**, Approved. Skinning survived
with no 3D Importer involvement: one MeshPart plus all 16 Bones, correct R15 names and
parentage. The uploaded animations drive its Bones directly through an
AnimationController/Animator.

### The trap: hierarchy is per-rig and mismatches are silent

An animation carries its pose tree. Play an avatar-hierarchy clip on the custom
character and the legs animate perfectly while **both arms and the head sit at exactly
0.00 deg** — no error, no warning, track playing, time advancing. It reads like a bad
animation. It is a rig mismatch.

Two sets are therefore maintained in `src/storage/AnimationIds.lua`:
`Avatar` (clavicle chain, stock R15 players) and `Character` (16-bone, NoLanderBody).
`tools/anim_upload.py` takes an explicit `hier=` argument;
`hierarchy_from_armature()` derives the character tree from the Blender rig.

Character set verified on NoLanderBody, worst delta vs Blender source: idle 0.01,
walk 0.17, crouch_walk 0.05, cower 0.43, collapse 0.00, sprint 2.69.

### Verification note

Peak-by-sampling needs several full loops. A single pass of 45 samples reported
LeftLowerLeg at 3.78 deg against a source of 28 — the left knee only bends in the back
half of the walk cycle and the window missed it. Sampling 300 frames over ~4 loops gave
27.85. Always sample multiple loops before believing an asymmetry.

## Still open

- Sprint at step=1 if the 2.69 deg decimation gap matters.
- Wiring the character + Character animation set into an actual playable NoLander.
