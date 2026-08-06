# NoLander custom body — wiring notes

The uploaded skinned character is a live, Humanoid-driven character that walks,
grounds correctly, and animates off movement state. Built by
`src/server/Modules/NoLanderCharacter.lua`, wired in through `RoundManager.assignRoles`.

## It is NoLander-only, and that is not a preference

The body is an **S1** rig: ONE skinned MeshPart, 16 Bones, **zero Motor6Ds**. Two
survivor systems cannot run on it, and both fail *silently* rather than erroring:

- `RagdollService` builds BallSocketConstraints by walking `Motor6D` joints. On this
  body it finds none, creates no sockets, and **play dead does nothing at all**.
- `DamageService` routes hits by BasePart name (`Head`, `UpperTorso`, `"Leg"`,
  `"Arm"`). This body has a single part named `Body`, so every hit falls through to
  the vital branch and instantly eliminates.

Neither applies to the NoLander: `RagdollService` gates on `Role == "Survivor"`, and
the NoLander is never shot at. **Survivors must stay on the stock R15 rig.**

### Head proxy

`DamageService` reads `shooter.Character.Head` for the laser origin. An S1 body has a
Head *Bone*, not a BasePart. `build()` welds an invisible `Head` part at the head bone
so DamageService keeps working **unmodified** — no game logic was edited for this.

## Gotchas found while wiring

1. **`MeshPart:ScaleTo` does not exist.** It is a *Model* method. Calling it on the
   mesh errors; setting `MeshPart.Size` directly scales the visual but leaves the
   bones at their original span (1.304 while the part reads 5.03 studs).
   `Model:ScaleTo` scales mesh and bones together correctly.
2. **`Model:ScaleTo` also scales Humanoid properties.** At scale 3.2, `WalkSpeed`
   silently became 51.2 and `HumanoidRootPart.Size` became 6.4 x 6.4 x 3.2. Reset
   size, WalkSpeed and JumpPower *after* scaling.
3. **HipHeight must be measured, not computed.** `ScaleTo` scales about the model
   pivot, so the weld offset does not land at a clean `rise * SCALE`. Computing it
   sank the feet **1.39 studs into the floor**. Measuring the real
   foot-bone-to-HRP-bottom gap after scaling puts the feet at 0.000.
4. **`Humanoid.MoveDirection` reads 0.000 server-side** while the body is
   demonstrably moving under `MoveTo` — it pinned the animation driver in idle
   forever. The driver uses `AssemblyLinearVelocity` instead, which is also correct
   once a player owns the character and stays correct when the NoLander flies.

## Verified live in Studio

| check | result |
|---|---|
| foot bone Y after settle | 0.000 (target 0) |
| Humanoid state | Running |
| HRP collision box | 2 x 2 x 1 |
| WalkSpeed after scale | 20 |
| idle (speed 0.00) | idle clip |
| walking (speed 19.99) | walk clip |
| sprinting (speed 39.99) | sprint clip |
| stopped (speed 0.00) | idle clip |

Visual check confirmed correct humanoid proportions and planted feet — no collapsed
or "tensed plank" deformation.

## Still open

- NoLander flight (`Released` flag exists; flight itself is Phase 4 work).
- `DEBUG_FORCE_ROLE = "Survivor"` means the round loop never assigns a NoLander, so
  the body does not appear in normal solo playtesting. Set it to `nil` (or
  `"NoLander"`) to exercise this path.
