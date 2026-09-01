# Regenerating the screenshot

`screenshot.png` in this directory is the picture at the top of the [main README](../README.md).
It is generated rather than captured, so it can show every indicator at once — a worktree
marker, all four state glyphs and the Claude Code tool label — which no real session obliges
you by doing on demand.

**None of this is needed to use the config.** It is only needed to rebuild the picture.

```sh
docs/screenshot.sh
```

## The pipeline

| Step                | What it does                                                          |
| ------------------- | --------------------------------------------------------------------- |
| `demo-setup.sh`     | Builds a throwaway project, a linked worktree and the state files in a scratch directory, then starts a tmux session for them |
| `demo.tape`         | Records that session with [VHS](https://github.com/charmbracelet/vhs) and keeps the raw frames |
| `window-chrome.py`  | Wraps the final frame in a rounded window, title bar and drop shadow   |
| `screenshot.sh`     | Runs the three in order and cleans up after them                      |

The demo session runs on its **own tmux server socket** (`-L tmuxdemo`) in a scratch
directory, so it never touches the sessions you are working in and never writes into a real
project. Re-running wipes and rebuilds it.

To change what the picture shows — the palette, the pane layout, the fake command output, or
which pane publishes which state glyph — edit `demo-setup.sh`; it is all in one place there.

## What it needs

| Needs                     |                                                                 |
| ------------------------- | --------------------------------------------------------------- |
| `vhs`, `ttyd`             | Both ship static binaries — `~/.local/bin`, no root needed       |
| `ffmpeg`, Chrome/Chromium | VHS drives a headless browser and encodes through ffmpeg         |
| `uv`                      | `window-chrome.py` pulls Pillow in on demand via its shebang     |
| a colour emoji font       | e.g. Noto Color Emoji, or the glyphs render as boxes             |

The repo has to be checked out at `~/.tmux`, since `tmux.conf` refers to the scripts by that
path and the tape starts tmux with that config.

The emoji font is the one dependency that degrades quietly instead of failing: without it the
glyphs render as empty boxes and the screenshot merely looks broken.

## Two VHS traps

Both fail *silently*, with exit status 0 and no output, so they cost more time than they
should. Worth knowing before editing `demo.tape`:

- **Its tape lexer rejects ordinary-looking paths.** `Output frames/` parses; `Output
  _frames/` does not. In run mode the parse error surfaces only as `parser: N error(s)`.
  `vhs validate demo.tape` prints the actual position and reason.
- **Frame output only materialises under `/tmp`.** Pointed anywhere below `$HOME` it writes
  nothing at all — presumably the snap confinement on the Chromium it drives. That is why
  `screenshot.sh` copies the tape into a `mktemp -d` and records there rather than in the repo.

The window chrome is drawn by `window-chrome.py` rather than by VHS's own `Set WindowBar` for
related reasons: VHS's `Screenshot` command is a no-op in v0.11.0, and its window bar is
composited only while assembling the GIF — which is quantised to 256 colours, enough to band
the emoji. Taking the lossless frame and drawing the frame separately avoids both.
