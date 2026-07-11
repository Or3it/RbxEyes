# CLAUDE.md — NoLander (Hiding from NoLander)

Roblox asymmetric horror hide-and-seek, filesystem-first via Rojo. This repo
is the source of truth; Studio is the runtime.

## Commands
- `rojo serve` here + Rojo plugin Connect in Studio = live sync
- Eyes/QA: bridge at ~/Documents/rbx-eyes (`.venv/bin/python -m bridge.server`),
  dashboard http://127.0.0.1:7791/
- Feature verification: `python ~/Documents/rbx-eyes/loop/run_feature.py <spec>.yaml`

## Library suite (ReplicatedStorage.Lib / ServerStorage)
Net (ALL remotes — validation+rate limits; raw RemoteEvents banned) ·
ProfileService (ALL player data; raw DataStores banned) · StateMachine ·
Zones · VFXKit · Juice · Telemetry · Forge · AnimForge · KitPlacer

## Working agreements (non-negotiable)
1. Before any physics/networking-adjacent system: SEARCH known Roblox gotchas
   first (see rbx-eyes/SYSTEM_MANUAL.md gotchas ledger).
2. Physics/visual bugs: diagnostic prints first, read via console/eyes, then fix.
3. Edit in Edit mode only; Studio MCP is unreliable during Play.
4. Player characters are CLIENT network-owned — server physics on them no-ops.
5. Acceptance criteria are eyes predicates (loop/specs pattern).

Full docs: rbx-eyes/SYSTEM_MANUAL.md · STATUS.md · PRODUCTION_ROADMAP.md
