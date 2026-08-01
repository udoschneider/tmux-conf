#!/bin/sh
# Resolve the pane-border status chunk for one pane.
#
#   pane-status.sh <pane-id> <pane-path>
#
# Called from tmux.conf's pane-border-format via #(), once per pane per
# status-interval. Emits, in order and each optional:
#
#   🔀        the pane sits in a *linked* git worktree (not the primary)
#   <branch>  current branch
#   │ <glyph> at most one state glyph the project has published
#
# STATE PROTOCOL — a project's only obligation (see README.md):
#
#   $(git rev-parse --git-common-dir)/tmux-state/
#     <pane-id>.gate    "wait <pid>" | "hold <pid>"
#     <pane-id>.land    "<pid>"
#
# One file *per concern*, never a shared one. That is the whole point: each
# writer creates and unlinks only its own file and never has to know another
# writer exists. Precedence is resolved here, in one place, instead of being
# negotiated between writers via save-and-restore on a shared slot.
#
# The pid is a liveness proof. A file whose pid is gone is ignored and swept,
# so a `kill -9` self-heals on the next repaint rather than stranding a glyph
# until some later run cleans up. (This sweep is the one write on an otherwise
# pure read path — it only ever removes a file whose owning process is dead.)
#
# Best-effort throughout: any failure prints nothing rather than garbage, so a
# non-git pane, a missing state dir, or a malformed file all render as silence.

set -u

pane="${1:-}"
path="${2:-}"

[ -n "$pane" ] && [ -d "$path" ] || exit 0

common=$(git -C "$path" rev-parse --git-common-dir 2>/dev/null) || exit 0
[ -n "$common" ] || exit 0

# --git-common-dir may come back relative to the working dir; make it absolute.
case "$common" in
/*) ;;
*) common=$(cd "$path" && cd "$common" 2>/dev/null && pwd) || exit 0 ;;
esac

out=""

# 🔀 marks a linked worktree: its git-dir lives under .git/worktrees/, the
# primary checkout's does not. Path-derived, so it stays correct for a plain
# `cd` into a worktree — no writer, nothing to keep in sync.
gitdir=$(git -C "$path" rev-parse --git-dir 2>/dev/null) || gitdir=""
case "$gitdir" in
*/worktrees/*) out="🔀 " ;;
esac

branch=$(git -C "$path" branch --show-current 2>/dev/null) || branch=""
out="${out}${branch}"

state_dir="$common/tmux-state"

# A pid is alive if we can signal it. Non-numeric or stale -> not alive.
alive() {
	[ -n "${1:-}" ] || return 1
	kill -0 "$1" 2>/dev/null
}

# Read "<token> <pid>" from a state file. $(...) strips the trailing newline,
# so this works whether or not the writer terminated the line.
read_state() {
	line=$(cat "$1" 2>/dev/null) || line=""
	token=${line%% *}
	pid=${line##* }
}

glyph=""

# Gate takes precedence over land: a land that stops to run the gate should
# show the gate. When the gate releases, the land file is still there and the
# ⬇️ comes back on its own — no restore logic anywhere.
gate_file="$state_dir/$pane.gate"
if [ -f "$gate_file" ]; then
	read_state "$gate_file"
	if alive "$pid"; then
		case "$token" in
		hold) glyph="🔒" ;;
		wait) glyph="⏳" ;;
		esac
	else
		rm -f "$gate_file" 2>/dev/null
	fi
fi

if [ -z "$glyph" ]; then
	land_file="$state_dir/$pane.land"
	if [ -f "$land_file" ]; then
		read_state "$land_file"
		if alive "$pid"; then
			glyph="⬇️"
		else
			rm -f "$land_file" 2>/dev/null
		fi
	fi
fi

[ -z "$glyph" ] || out="${out} │ ${glyph}"

printf '%s' "$out"
