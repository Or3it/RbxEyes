# Vision protocol — how the automated system SEES reliably
Live-verified 2026-07-13 (walk-cycle visual confirmation).

## The problem this solves
Screen captures of an uncontrolled viewport are unreliable evidence: the
camera shows whatever it happens to show, scenes often contain multiple
humanoids (player + rigs), and "describe the screen" prompts return
ambiguous answers. Several captures in a row misidentified the subject
before this protocol; the first framed capture succeeded.

## The protocol (3 steps, every visual verification)
1. **Frame** — CLIENT datamodel:
   `require(game.ReplicatedStorage.Lib.VisionKit).frameLocalPlayer()`
   (or `frameSubject(workspace.Thing)` for non-character subjects)
2. **Capture with specific questions** — screen_capture subagent task must
   ask verifiable yes/no or comparative questions:
   - GOOD: "Is one leg forward and the other backward, or are both
     vertical? Which arm is higher?"
   - BAD: "Describe the character" (invites subject confusion)
3. **Release** — `VisionKit.release()` when done, or the player's camera
   stays locked.

## Motion verification (animations)
Numbers first, then eyes: sample joint world rotation over ~1s via
execute_luau (oscillation = playing; flat = not, regardless of
IsPlaying=true — live-proven failure mode). Then one framed capture
mid-cycle for pose confirmation. For explicit motion evidence, two framed
captures ~0.5s apart, asking what changed between limbs.

## Bridge alternative
`/frames/burst?n=&fps=` captures real frames but returns base64 a text
session can't view — use it for archiving failure evidence (harness
already saves failure frames to disk), not for live judgment. The
subagent + framing is the live-judgment path.
