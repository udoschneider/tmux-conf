# tmux configuration

Version-controlled tmux setup: a per-project colour scheme driven by files that live
**in each project**, plus the pane-border status line.

The design goal is that this repo owns every *visual* decision, and a project only ever
declares *data*. Nothing here hardcodes a list of projects, and no project needs to know
how any of it is rendered.

## Install

```sh
git clone <this-repo> ~/.tmux
printf 'source-file ~/.tmux/tmux.conf\n' > ~/.tmux.conf
tmux source-file ~/.tmux.conf     # or just start tmux
```

The `~/.tmux.conf` stub is the one file that cannot live in this repo: tmux only looks for
a user config at `~/.tmux.conf` or `$XDG_CONFIG_HOME/tmux/tmux.conf`, and neither path is
inside `~/.tmux`. It is two lines and never changes.

Plugins are managed by [TPM](https://github.com/tmux-plugins/tpm) and land in
`~/.tmux/plugins/` (gitignored). On a fresh host:

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# then inside tmux: prefix + I
```

## Contents

| File                | Role                                                          |
| ------------------- | ------------------------------------------------------------- |
| `tmux.conf`         | The configuration proper — roles, formats, hooks              |
| `project-theme.sh`  | Resolves a session's palette by walking up for `.tmux-theme`  |
| `.gitignore`        | Excludes TPM's `plugins/`                                     |

## How a project sets its colours

Drop a `.tmux-theme` file in the project root. `project-theme.sh` walks up from a session's
working directory and applies the first one it finds. **Adding a project requires no change
to this repo** — and a project with no `.tmux-theme` inherits a neutral grey default, so it
reads as "no palette yet" rather than impersonating another project.

```ini
# .tmux-theme
bar=colour17     # status bar background (dark)
soft=colour117   # bar + inactive window text (light)
badge=colour33   # session badge / clock / message background
accent=colour39  # current window highlight + hostname
dim=colour24     # inactive pane border
bright=colour45  # active pane border
```

Any subset of the six roles may be given; the rest inherit the defaults in `tmux.conf`.
Values are tmux colour names, `colourN`, or `#rrggbb`. A `#` **after whitespace** starts a
comment; a `#` flush against a value is a hex colour, so `accent=#ff8800  # amber` parses
correctly.

The file is **parsed, never sourced**, and both keys and values are whitelisted —
unrecognised lines are dropped silently. This is load-bearing, not defensive: the script
runs against whatever directory a session happens to sit in, and the values are interpolated
into tmux styles and formats. A hostile `.tmux-theme` cannot execute anything.

### Why track it rather than gitignore it

Committing `.tmux-theme` means every **git worktree** of a repo carries the same palette.
Colour then identifies the *project*, while the `🔀` marker in the pane border identifies
*which worktree* a pane is in — two independent axes. It also means the session *name* is
irrelevant: a session called `21` sitting in the project directory themes correctly.

### Light palettes invert one thing

`accent` is the current-window *background*, painted with `bar` as its foreground. So a
light `bar` needs a **dark** `accent` — and a dark `badge` too, since the status-left and
status-right badges hardcode white text.

## How it works

Palettes are published as six `@thm_*` user options per session. Every **format** option
(`status-left`, `window-status-*`, …) reads them directly via `#{@thm_...}`, so those need
no per-project variants.

**Style** options (`status-style`, `message-style`, `pane-*-border-style`) are *not*
format-expanded — per `tmux(1)` STYLES, styles may be embedded in formats, not the reverse.
Writing `#{@thm_bar}` into one stores it verbatim as a broken style. That asymmetry is the
entire reason `project-theme.sh` exists rather than a purely declarative config: it resolves
the roles and assigns the style options imperatively.

Four hooks re-apply on any event that can change which project a session shows. The two
*creation* hooks pass `#{session_path}` explicitly, because when they fire the new pane has
no shell yet and `#{pane_current_path}` reads back empty — or, worse, stale.

## Troubleshooting

- **Everything is default grey** — no `.tmux-theme` was found. Check the walk:
  `tmux display-message -t <session> -p '#{pane_current_path}'`, then look up that path.
- **One role didn't take** — it failed the whitelist (typo'd colour, or an inline `#`
  comment with no space before it, which reads as a hex value). Re-run
  `~/.tmux/project-theme.sh <session>` and compare
  `tmux display-message -t <session> -p '#{@thm_bar}'` against the file.
- **Bar right, pane borders wrong** — border styles are *window* options applied per window;
  a window created outside the `after-new-window` hook won't have them. Re-run the script
  for that session.
- **A worktree shows the default** — `.tmux-theme` isn't committed, so that checkout lacks it.
