#!/usr/bin/env bash
# Writes the tool Claude is currently running into the tmux pane border.
# Reads the hook event JSON on stdin; stores a short label in the pane-local
# user option @pane_cmd, which ~/.tmux.conf's pane-border-format renders.
#   arg1: "cmd"  -> derive label from the PreToolUse payload
#         "idle" -> clear (Stop hook)
set -u
[ -z "${TMUX_PANE:-}" ] && exit 0   # not inside tmux; nothing to do

mode="${1:-cmd}"
label=""

if [ "$mode" != "idle" ]; then
  json="$(cat)"
  tool="$(printf '%s' "$json" | jq -r '.tool_name // empty')"
  case "$tool" in
    Bash)
      cmd="$(printf '%s' "$json" | jq -r '.tool_input.command // empty' | tr '\n' ' ')"
      label="\$ ${cmd}"
      ;;
    Edit|Write|Read|NotebookEdit)
      f="$(printf '%s' "$json" | jq -r '.tool_input.file_path // empty')"
      label="${tool} ${f##*/}"
      ;;
    "") label="" ;;
    *)  label="$tool" ;;
  esac
fi

# '#' is special in tmux format strings; strip it so the value can't be
# re-interpreted when the border renders. Trim to keep the border tidy.
label="$(printf '%s' "$label" | tr -d '#')"
label="${label:0:50}"

tmux set -p -t "$TMUX_PANE" @pane_cmd "$label" 2>/dev/null
tmux refresh-client 2>/dev/null
exit 0
