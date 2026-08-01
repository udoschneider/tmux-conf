#!/bin/sh
# Regenerate docs/screenshot.png.
#
#   docs/screenshot.sh
#
# Builds the demo session (docs/demo-setup.sh), records it with VHS
# (docs/demo.tape), takes the last frame, and wraps it in window chrome
# (docs/window-chrome.py).
#
# Needs: vhs + ttyd + ffmpeg + a Chrome/Chromium binary, and uv (for Pillow).
# The repo must be checked out at ~/.tmux, because tmux.conf refers to the
# scripts by that path.

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Record in a temp directory rather than in the repo. Two VHS quirks make this
# the path of least resistance, and both fail *silently* -- "parser: N error(s)"
# or nothing at all, always with exit status 0:
#
#   1. Its tape lexer accepts only a narrow character set in a path. `frames/`
#      parses; `_frames/` does not. `vhs validate demo.tape` is the only way to
#      see that.
#   2. Frame output only materialises under /tmp here. Pointed anywhere below
#      $HOME it writes nothing, sandbox or no sandbox -- presumably the snap
#      confinement on the Chromium it drives.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM HUP
cp "$here/demo.tape" "$work/"

(cd "$work" && vhs demo.tape)

last=$(ls "$work"/frames/frame-text-*.png 2>/dev/null | sort | tail -1) || last=""
[ -n "$last" ] || {
	echo "no frames captured -- try: cd $work && vhs validate demo.tape" >&2
	exit 1
}

"$here/window-chrome.py" "$last" "$here/screenshot.png" 'webapp — tmux'
tmux -L tmuxdemo kill-server 2>/dev/null || true
