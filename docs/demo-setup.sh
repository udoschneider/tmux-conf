#!/bin/sh
# Build the throwaway session that docs/screenshot.png is taken of.
#
#   docs/demo-setup.sh          -> create the demo, print the attach command
#
# Everything lives in a scratch directory and a private tmux server socket, so
# this never touches the real sessions you are working in. Re-running it wipes
# and rebuilds from scratch.
#
# The point of scripting it rather than screenshotting a real session is that
# the picture stays reproducible: it shows every indicator at once (worktree
# marker, all three state glyphs, the Claude Code tool label), which no real
# session obliges you by doing on demand.

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
conf="$repo/tmux.conf"
sock=tmuxdemo
demo="${TMPDIR:-/tmp}/tmux-conf-demo"

tmux -L "$sock" kill-server 2>/dev/null || true
rm -rf "$demo"
mkdir -p "$demo"

main="$demo/webapp"
wt="$demo/webapp-search"

# --- a project that declares a palette ------------------------------------
mkdir -p "$main/src" "$main/scripts"
cat >"$main/.tmux-theme" <<'EOF'
# .tmux-theme -- the palette lives in the project, not in ~/.tmux
bar=colour23     # status bar background (dark)
soft=colour152   # bar + inactive window text (light)
badge=colour30   # session badge / clock
accent=colour44  # current window highlight + hostname
dim=colour29     # inactive pane border
bright=colour51  # active pane border
EOF

git -C "$main" init -q -b main
git -C "$main" config user.email demo@example.com
git -C "$main" config user.name 'Demo'
git -C "$main" add -A
git -C "$main" commit -qm 'Initial commit'
git -C "$main" worktree add -q -b feature/search "$wt"

# --- fixed pane content ---------------------------------------------------
# Each pane runs a script that prints its lines and then blocks, so the
# screenshot is deterministic: no shell prompt, no timestamps, no scrollback.
pane_script() {
	f="$demo/p$1.sh"
	shift
	{
		echo '#!/bin/sh'
		for line in "$@"; do printf 'printf %%s\\\\n %s\n' "'$line'"; done
		echo 'exec sleep 100000'
	} >"$f"
	chmod +x "$f"
	echo "$f"
}

p0=$(pane_script 0 \
	'$ npm test -- search' \
	'' \
	' PASS  src/search.test.ts (2.1s)' \
	'   ✓ ranks exact matches first' \
	'   ✓ falls back to fuzzy' \
	'' \
	'$ ')
p1=$(pane_script 1 \
	'$ ./scripts/build.sh' \
	'→ build lock acquired' \
	'  compiling 214 modules…')
p2=$(pane_script 2 \
	'$ ./scripts/deploy.sh staging' \
	'→ uploading bundle…')
p3=$(pane_script 3 \
	'$ ./scripts/build.sh' \
	'… waiting for the build lock')

# --- the session ----------------------------------------------------------
t() { tmux -L "$sock" "$@"; }

t -f "$conf" new-session -d -s webapp -n edit -c "$main" -x 210 -y 52 "$p0"
t split-window -h -t webapp:0.0 -l 44% -c "$wt" "$p1"
t split-window -v -t webapp:0.1 -l 62% -c "$main" "$p2"
t split-window -v -t webapp:0.2 -l 50% -c "$main" "$p3"
t new-window -d -t webapp: -n logs -c "$main"
t select-pane -t webapp:0.0

# --- state a project would publish ----------------------------------------
# Each pane's own process is the pid, which is exactly what a real writer
# records -- so the liveness check in pane-status.sh passes for real reasons.
state="$main/.git/tmux-state"
mkdir -p "$state"

pane_id() { t display-message -p -t "webapp:0.$1" '#{pane_id}'; }
pane_pid() { t display-message -p -t "webapp:0.$1" '#{pane_pid}'; }

printf 'hold %s\n' "$(pane_pid 1)" >"$state/$(pane_id 1).gate" # 🔒 holds it
printf '%s\n' "$(pane_pid 2)" >"$state/$(pane_id 2).land"      # ⬇️ deploying
printf 'wait %s\n' "$(pane_pid 3)" >"$state/$(pane_id 3).gate" # ⏳ waiting

# The one pushed indicator: what Claude Code is running in pane 0.
t set -p -t "$(pane_id 0)" @pane_cmd 'Edit(src/search.ts)'

echo "tmux -L $sock attach -t webapp"
