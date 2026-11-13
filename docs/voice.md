# Local dictation

hyperion enables `modules.voice.enable`. Pi's voice extension records locally
and sends clips to Parakeet at `http://127.0.0.1:8178`. `pi-setup` installs the
extension; the Nix launch agent keeps the model loaded. This requires Apple
silicon and MLX.

Nix supplies Python 3.13, uv and ffmpeg. The Python dependencies are pinned in
`config/voice/{server,bench}.py.lock`; uv installs the wheels into its cache on
first use. The model also downloads on first use (about 1–2 GB), then loads
from the Hugging Face cache without a network check. The model revision itself
is not pinned. No model is downloaded while evaluating or building the flake.

- `voice-serve` runs the same server in the foreground; stop the launch agent
  first to free the port.
- `voice-bench [N]` compares engines using recent clips; it can download extra
  models. Run it deliberately, not as a system check.
- Restart after editing `config/voice/server.py`:
  `launchctl kickstart -k gui/$(id -u)/org.nixos.voice-stt`.
- `config/voice/config.toml` reloads on the next request. Host and port changes
  require a restart.
- Check readiness with `curl -fsS http://127.0.0.1:8178/health`.

Logs are in `~/Library/Logs/voice-stt.log`. The server keeps the last 300
recordings and transcripts under `~/.cache/voice/clips`; logs also contain
transcripts. Treat both as private. Pi continues to use its existing microphone
permission; the service exposes no remote endpoint by default.

Update dependencies with `uv lock --script config/voice/server.py --upgrade`
(and `bench.py` for the benchmark), review the lock changes and restart. The
launch wrapper uses `--locked`, so a changed dependency header cannot silently
resolve a new environment at login.

When coming from dotfiles, stop and move aside `dev.mise.voice-stt` before
switching, as described in [the Mac install guide](install-mac.md). Do not run
both launch agents on port 8178.
