#!/bin/sh
# Apply a per-project colour theme to a tmux session.
#
#   project-theme.sh                    -> apply to every existing session
#   project-theme.sh <session>          -> apply to one session
#   project-theme.sh <session> <path>   -> ...looking up the theme from <path>
#
# I work several projects at once, one tmux session each, and want the bar to
# tint per project so they are distinguishable at a glance.
#
# THE PALETTE LIVES IN THE PROJECT, NOT HERE. This script resolves the
# session's working directory and walks up for a `.tmux-theme` file; the first
# one found supplies the colours. A project with no such file inherits the
# @thm_* defaults set globally in .tmux.conf, so an unthemed project renders in
# the blue default rather than uncoloured. Adding a project is therefore a file
# in that project -- this script never needs editing.
#
# `.tmux-theme` format -- `role=colour`, one per line. A `#` preceded by
# whitespace (or at the start of a line) begins a comment; a `#` flush against
# a value is a hex colour, so `accent=#ff8800  # amber` parses correctly. Any
# subset of roles may be given; unlisted ones fall back to the global default.
#
#   bar    status bar background (dark)
#   soft   status bar + inactive window text (light)
#   badge  session badge / clock / message background (mid)
#   accent current window highlight + hostname (bright)
#   dim    inactive pane border
#   bright active pane border (brightest)
#
# Colours are tmux colour names, `colourN`, or `#rrggbb`.

set -eu

# No argument: fan out over every session.
if [ $# -eq 0 ]; then
	tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r s; do
		"$0" "$s"
	done
	exit 0
fi

session="$1"
roles="bar soft badge accent dim bright"

# --- locate the project's theme file -------------------------------------
# Walk up from the session's working directory. Directory walk rather than
# `git rev-parse --show-toplevel` on purpose: not every project I keep a
# session for is a git repo, and a git worktree resolves to its own toplevel
# anyway -- the theme file is tracked, so every worktree of a repo carries the
# same colours, which is what I want (colour identifies the project, the 🔀
# glyph in pane-border-format identifies the worktree).
#
# The caller may pass the path explicitly, because #{pane_current_path} is not
# yet meaningful when the `session-created` / `after-new-window` hooks fire --
# the pane has no shell yet, so it reads back empty or stale. Those hooks pass
# #{session_path} instead; steady-state callers pass nothing and get the live
# pane path, which correctly follows a session that has cd'd elsewhere.
dir="${2:-}"
[ -n "$dir" ] || dir=$(tmux display-message -t "$session" -p '#{pane_current_path}' 2>/dev/null || true)
[ -d "$dir" ] || dir=$(tmux display-message -t "$session" -p '#{session_path}' 2>/dev/null || true)
theme_file=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
	if [ -f "$dir/.tmux-theme" ]; then
		theme_file="$dir/.tmux-theme"
		break
	fi
	dir=$(dirname "$dir")
done

# --- reset to defaults ---------------------------------------------------
# Clear any session-local overrides first, so tmux's own option inheritance
# supplies the global default for every role the theme file does not name.
# This is also the whole fallback path when no theme file exists at all.
for role in $roles; do
	tmux set -ut "$session" "@thm_$role" 2>/dev/null || true
done

# --- apply the theme file ------------------------------------------------
# Parsed, never sourced. These values are interpolated into #[...] styles and
# #{...} formats, and this script runs against whatever directory a session
# happens to sit in -- so both keys and values are whitelisted rather than
# trusted. An unrecognised line is skipped silently.
if [ -n "$theme_file" ]; then
	while IFS= read -r line || [ -n "$line" ]; do
		# Strip a trailing comment, then all whitespace. The comment marker is
		# only honoured after whitespace so that a hex value (`accent=#ff8800`)
		# survives while a trailing `  # note` does not.
		line=$(printf '%s' "$line" | sed 's/[[:space:]]\{1,\}#.*$//')
		line=$(printf '%s' "$line" | tr -d '[:space:]')
		case "$line" in
		'' | '#'*) continue ;;
		esac

		key=${line%%=*}
		val=${line#*=}
		[ "$key" != "$line" ] || continue # no '=' on the line

		case " $roles " in
		*" $key "*) ;;
		*) continue ;;
		esac

		case "$val" in
		colour[0-9] | colour[0-9][0-9] | colour[0-9][0-9][0-9]) ;;
		'#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
		black | red | green | yellow | blue | magenta | cyan | white | default) ;;
		bright[a-z]*) ;;
		*) continue ;;
		esac

		tmux set -t "$session" "@thm_$key" "$val"
	done <"$theme_file"
fi

# --- push roles into the style options -----------------------------------
# STYLE options (status-style, message-style, pane-*-border-style) are NOT
# format-expanded by tmux -- see tmux(1) "STYLES": styles may be embedded in
# formats, not the reverse -- so #{@thm_...} would be stored verbatim as a
# broken style and has to be resolved imperatively here. The FORMAT options in
# .tmux.conf (status-left, window-status-*, ...) read the roles directly and
# need nothing.
#
# display-message resolves through the session -> global inheritance chain, so
# this picks up defaults for any role the theme file omitted.
resolve() { tmux display-message -t "$session" -p "#{@thm_$1}"; }

bar=$(resolve bar)
soft=$(resolve soft)
badge=$(resolve badge)
accent=$(resolve accent)
dim=$(resolve dim)
bright=$(resolve bright)

tmux set -t "$session" status-style "bg=$bar,fg=$soft"
tmux set -t "$session" message-style "bg=$badge,fg=colour231"

# Pane border styles are WINDOW options, so they apply per window, not once
# per session.
tmux list-windows -t "$session" -F '#{window_id}' | while read -r win; do
	tmux setw -t "$win" pane-border-style "fg=$dim"
	tmux setw -t "$win" pane-active-border-style "fg=$bright"
done
