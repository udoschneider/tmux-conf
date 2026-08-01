# VHS tape for docs/screenshot.png -- run it via docs/screenshot.sh, which
# copies this into a temp directory, runs it there, picks the final frame out
# of frames/ and adds the window chrome. Hence the absolute path below: this
# tape does not execute next to the script it calls.
#
# Frames rather than a GIF on purpose: VHS composites its own window bar only
# while assembling the GIF, and a GIF is quantised to 256 colours. The raw
# frames are lossless PNGs of exactly the terminal, which is what we want to
# hand to docs/window-chrome.py.

Output frames/

Set Shell bash
Set FontSize 15
Set Width 1400
Set Height 580
Set Padding 12
Set Margin 0

# Only the last frame is kept, so 10fps is plenty -- and it keeps the frame
# directory to a few hundred files instead of several thousand.
Set Framerate 10

# No Hide/Show around the setup: tmux takes the alternate screen when it
# attaches, so the setup scrollback is gone from the final frame anyway.
# (Hide suppresses frame capture entirely with a frames-directory output.)
Type "~/.tmux/docs/demo-setup.sh >/dev/null && exec tmux -L tmuxdemo attach -t webapp"
Enter

# Pane borders re-run their #() once per status-interval (5s) and serve the
# previous result while the new one runs, so the glyphs need two intervals to
# appear. Wait out four to be safe.
Sleep 20s

