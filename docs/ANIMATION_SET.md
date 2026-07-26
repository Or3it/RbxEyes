# NoLander animation set — built + verified 2026-07-13

Authored procedurally in Blender (no Mixamo dependency — mixamo.com was
unreliable, see session notes). Chosen for NoLander's actual gameplay
loop, not generic filler.

| anim | frames | loop | motion signature (verified) |
|---|---|---|---|
| idle | 30 | yes | no leg motion; +-2deg torso breathing, subtle head drift |
| walk | 30 | yes | legs +-30deg, arms +-20deg counter-phase, knee lift |
| sprint | 20 | yes | legs +-48deg, 14deg constant forward lean, elbows bent 55deg |
| crouch_walk | 40 | yes | lowered root -0.22, knees -45deg, 22deg lean, damped swing |
| cower | 30 | yes | root -0.35, knees -88deg, arms up -105deg, 6Hz fear tremble |
| collapse | 25 | no | ease-in fall: torso 0->75deg, root drops 0.9 over the clip |

Verification method: sampled each action's fcurve ranges directly
(`legX`/`torsoX` min..max in degrees) to confirm the six are genuinely
distinct rather than duplicated data. Ranges above are measured, not
intended values.

## Craft caveat (honest)
These are procedural curves — mathematically clean, which reads slightly
robotic next to hand-authored or mocap motion. They are a real, usable
baseline that beats default Roblox animations for a horror game, not a
substitute for an animator. `cower` and `collapse` hold up best (pose-driven);
`walk`/`sprint` are the most obviously procedural (pure sine).

## Adding more
Open `exchange/nolander_rig.blend`, add an action, keyframe with the same
`key(bone, frame, rx=..)` helper pattern, export with
`bake_anim_use_all_actions=False`.
