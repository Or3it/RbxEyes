# Job queue — the "always progressing" mechanism

Each `*.yaml` here is a ticket a session can pick up and drain without
you typing anything beyond the ticket itself. This is the buildable
version of "always alive": long autonomous runs you kick off, NOT a
daemon working while you sleep (Roblox blocks unattended input injection
by design, and MCP connections drop — both proven this session).

## Ticket format
```yaml
id: TICKET-ID
goal: one sentence, concrete
status: open | in_progress | blocked | done
acceptance:          # predicates/checks that must pass to mark done
  - "what must be numerically or visually true"
notes: |
  findings, gotchas, what was ruled out
```

## Rules for a session draining this queue
1. Pick the top `open` ticket. Set `in_progress`.
2. Do the work. Verify against `acceptance` with real evidence
   (numbers first, framed capture second — see docs/VISION_PROTOCOL.md).
3. Mark `done` ONLY if acceptance passes. Otherwise `blocked` + write the
   real reason in `notes` so the next session doesn't rediscover it.
4. Never mark done on "no errors thrown" — that has produced false
   positives repeatedly (IsPlaying=true with dead joints; a Sound
   reporting IsPlaying with TimeLength=0).
