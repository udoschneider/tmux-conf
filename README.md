# tmux configuration

Version-controlled tmux setup: a per-project colour scheme driven by files that live
**in each project**, plus the pane-border status line.

![A tmux session tinted by its project's palette. Each pane border carries its index and git
branch; one pane is in a linked worktree running the gate it holds the build lock for,
another is landing a deploy, a third is queued for the build lock, a fourth is queued to
land. The active pane's border also shows the tool Claude Code is running.](docs/screenshot.png)

<sub>Everything at once, which no real session obliges you by doing: pane 1 sits in a linked
worktree (`🔀`) running the gate it holds the build lock for (`⚙️`), pane 2 is landing a
deploy (`⬇️`), pane 3 is queued for the build lock (`⏳`), pane 4 is queued to land (`🅿️`),
and pane 0 shows Claude Code's current tool. It is generated rather than captured — see
[docs/](docs/README.md).</sub>

## What it does

- **Per-project colours** — the status bar, window list and pane borders tint per project, so
  several sessions side by side are distinguishable at a glance. The palette is declared by a
  `.tmux-theme` file in the project itself; a project without one gets a neutral grey.
- **Branch and worktree in the pane border** — each pane shows its index, its current git
  branch, and a `🔀` when it sits in a *linked* worktree rather than the primary checkout.
- **State glyphs a project publishes** — one grammar, two concerns: `⏳` queued for the build
  lock and `⚙️` running under it, `🅿️` queued to land and `⬇️` landing. The pairs split by
  *state*, not by concern — `⏳`/`🅿️` are stopped, `⚙️`/`⬇️` are working — so a glance reads
  "is it moving?" first. A project drops a file in its git dir; it never calls tmux.
- **Mouse on** — click to focus a pane or window, drag a border to resize, wheel to scroll.
- **Session name as the tab title** — `set-titles` pushes the session name as the terminal
  window title, so iTerm shows one tab per session (see [iTerm tab title](#iterm-tab-title)).
- **Copies reach the machine you're sitting at** — `set-clipboard on` plus tmux-yank forward
  yanks over OSC 52, so copying inside tmux on a remote box lands in the local pasteboard
  with no `DISPLAY` or `xclip` in the path.
- **Optional Claude Code tool label** — the tool Claude Code is running right now, shown at
  the end of the border of the pane it's running in.

The design goal is that this repo owns every *visual* decision, and a project only ever
declares *data*. Nothing here hardcodes a list of projects, and no project needs to know
how any of it is rendered.

## Install

```sh
git clone git@github.com:udoschneider/tmux-conf.git ~/.tmux
echo 'source-file ~/.tmux/tmux.conf' > ~/.tmux.conf
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

| File                   | Role                                                             |
| ---------------------- | ---------------------------------------------------------------- |
| `tmux.conf`            | The configuration proper — roles, formats, hooks                 |
| `project-theme.sh`     | Resolves a session's palette by walking up for `.tmux-theme`     |
| `pane-status.sh`       | Resolves the pane-border chunk — worktree marker, branch, glyph  |
| `claude-tool-label.sh` | Optional: shows the tool Claude Code is running (see below)      |
| `docs/`                | The screenshot above, and [how it is generated](docs/README.md) |
| `.gitignore`           | Excludes TPM's `plugins/`                                        |
| `LICENSE`              | MIT — the terms this repo is published under                     |

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

## How a project shows status in the pane border

A project can surface transient state — "this pane holds the build lock", "a deploy is
running here" — by dropping files in its git **common** dir, so every worktree shares one
namespace. It never calls tmux, and this repo never learns the project's name.

```
$(git rev-parse --git-common-dir)/tmux-state/
  <pane-id>.gate    # "wait <pid>"  -> ⏳     "hold <pid>"  -> ⚙️
  <pane-id>.land    # "wait <pid>"  -> 🅿️    "hold <pid>"  -> ⬇️
```

`<pane-id>` is `$TMUX_PANE`, which is an ordinary environment variable — reading it is not a
tmux call, so a project stays entirely tmux-ignorant. `pane-status.sh` polls these files once
per `status-interval` and renders at most one glyph, `gate` before `land`.

**Both concerns share one grammar — `wait` is queued behind someone, `hold` is doing the
thing.** That is what lets a reader learn the protocol once: the glyph pairs follow the
*state* split rather than the concern, so `⏳`/`🅿️` both mean stopped and `⚙️`/`⬇️` both
mean working.

A `.land` file carrying an unrecognized token — including the bare `"<pid>"` that writers
predating this grammar published — renders as `⬇️`. Adding the `wait` state was therefore
backward compatible in both directions: `read_state` splits on the *last* space, so an old
resolver reads a new two-token body's pid correctly, and a new resolver falls back for an old
one-token body. No flag day was needed on either side.

Two properties are worth understanding, because they are the reason for the shape:

**One file per concern, never a shared one.** Each writer creates and unlinks only its own
file. It never has to know another writer exists, never has to save-and-restore a value it
found, and can never stomp someone else's. Precedence lives in exactly one place — the
resolver — instead of being negotiated pairwise between writers. Concretely: if a long
deploy publishes `.land` and then pauses to take the build lock, the lock's `.gate` file
simply outranks it; when the lock releases and `.gate` is unlinked, the `⬇️` reappears on its
own. No restore logic exists anywhere.

**The pid is a liveness proof.** A file whose pid no longer exists is ignored and swept on
the next repaint, so a `kill -9` self-heals rather than stranding a glyph until some later
cleanup pass. Writers should still unlink on exit — the pid is the backstop, not the plan.

A minimal writer is three lines:

```sh
state="$(git rev-parse --git-common-dir)/tmux-state"
mkdir -p "$state" && printf 'hold %s\n' "$$" > "$state/$TMUX_PANE.gate"
trap 'rm -f "$state/$TMUX_PANE.gate"' EXIT INT TERM HUP
```

Guard on `$TMUX_PANE` being set if the tool also runs outside tmux; everything here is
best-effort by design, and a missing or malformed file renders as silence.

## Optional: the Claude Code tool label

`claude-tool-label.sh` writes the tool Claude Code is currently running into the pane-local
user option `@pane_cmd`, which `tmux.conf` renders at the end of the border. This is the one
indicator that must be **pushed** rather than polled — "the tool running right now" has no
representation on disk for a reader to find.

It is wired as a Claude Code hook. Because it is the *only* writer of `@pane_cmd`, it needs
no coordination with anything else: it sets the slot on `PreToolUse` and clears it on `Stop`.

```jsonc
// ~/.claude/settings.json
"hooks": {
  "PreToolUse": [{ "matcher": "*", "hooks": [
    { "type": "command", "command": "$HOME/.claude/hooks/tmux_status.sh cmd" }
  ]}],
  "Stop": [{ "hooks": [
    { "type": "command", "command": "$HOME/.claude/hooks/tmux_status.sh idle" }
  ]}]
}
```

The hook path above is a symlink into this repo, which keeps `settings.json` stable while the
script stays version-controlled:

```sh
ln -s ~/.tmux/claude-tool-label.sh ~/.claude/hooks/tmux_status.sh
```

Pointing `settings.json` straight at `~/.tmux/claude-tool-label.sh` works just as well. The
script needs `jq`, no-ops outside tmux, and skipping it entirely just means no tool label.

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

## iTerm tab title

`tmux.conf` sets `set-titles on` and `set-titles-string "#{session_name}"`, which makes tmux
write its session name to the terminal as a title escape sequence (OSC 0). iTerm treats OSC 0
as an update to the session's **Session Name**, so two profile settings gate whether it shows:

1. **Settings → Profiles → your profile → General → "Applications in terminal may change the
   title"** — enable it, otherwise iTerm ignores the OSC title tmux sends entirely.
2. **Settings → Profiles → your profile → General → Title** — include **Session Name** in the
   composition. The tab title is built from these checkbox elements; OSC 0 feeds Session Name.
   If the tab shows `slogin`, that is the **Job** element (the ssh command), which is what
   appears when Session Name is not in the title — untick Job, or order Session Name first.

With both set, each iTerm tab reflects the tmux session it is attached to, and renames live
when a session is renamed or you switch which session that tab is attached to. You must reload
after adding the two tmux lines (`tmux source-file ~/.tmux.conf`) for the OSC title to start.

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
