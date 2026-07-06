# Game repo setup (one time, ~10 min)

1. Install Rojo CLI:  `brew install rojo`
   (no Homebrew? https://brew.sh first, or use Aftman)
2. Install the **Rojo plugin** inside Studio (Toolbox > search "Rojo" by
   evaera/rojo-rbx, or rojo.space).
3. Populate the repo from your live game:
   - restart bridge v2, then have Claude run Exporter.lua via MCP
   - exported files land in rbx-eyes/game-src/ -> move src/ folders here
4. `git init && git add -A && git commit -m "NoLander initial export"`
5. Live sync: `rojo serve` here, then Studio > Rojo plugin > Connect.
   From now on: edit files (you or Claude Code) -> Studio updates live.
   Studio is the runtime; the repo is the truth.
