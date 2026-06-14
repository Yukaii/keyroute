# tmux and Ghostty Quick Session Switching

This example shows a layered setup for jumping to common tmux sessions without
opening a session picker and typing a name every time.

It is useful when most session switches are between a small set of known
workspaces. A picker is still useful for uncommon sessions, but this path makes
frequent jumps deterministic:

```text
Ghostty key table -> tmux key table -> Keyroute profile keymap -> tmux session
```

## Workflow

Manual tmux flow:

```text
prefix y 1   # slot 1 in the active Keyroute profile
prefix y 2   # slot 2 in the active Keyroute profile
prefix y w   # set active profile to work
prefix y p   # set active profile to personal
prefix y s   # show active profile
```

Ghostty flow:

```text
ctrl+cmd+k, 1   # slot 1 in the active Keyroute profile
ctrl+cmd+k, 2   # slot 2 in the active Keyroute profile
ctrl+cmd+k, w   # set active profile to work
ctrl+cmd+k, p   # set active profile to personal
ctrl+cmd+k, s   # show active profile
ctrl+cmd+k, esc # cancel Ghostty's key table
```

The same number can point to different sessions depending on the active
profile. That keeps the terminal shortcut stable while the profile changes the
meaning.

## Keyroute Config

Save this as `~/.config/keyroute/config.yaml`.

The names below are generic. Replace the `session` values with your tmux session
names and the `app` bundle id with your terminal app if you are not using
Ghostty.

```yaml
aliases:
  tmux: profile.work
  editor: target.tmux.editor
  notes: target.tmux.notes

targets:
  tmux.api:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: api
    create: false

  tmux.web:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: web
    create: false

  tmux.infra:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: infra
    create: false

  tmux.docs:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: docs
    create: false

  tmux.release:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: release
    create: false

  tmux.support:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: support
    create: false

  tmux.dotfiles:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: dotfiles
    create: false

  tmux.notes:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: notes
    create: false

  tmux.tools:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: tools
    create: false

  tmux.side-project:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: side-project
    create: false

  tmux.editor:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: editor
    create: false

profiles:
  work:
    targets:
      - tmux.api
      - tmux.web
      - tmux.infra
      - tmux.docs
      - tmux.release
      - tmux.support
    default: tmux.api
    mode: sequential
    keymaps:
      tmux:
        "1": tmux.api
        "2": tmux.web
        "3": tmux.infra
        "4": tmux.docs
        "5": tmux.release
        "6": tmux.support

  personal:
    targets:
      - tmux.dotfiles
      - tmux.notes
      - tmux.tools
      - tmux.side-project
      - tmux.editor
    default: tmux.dotfiles
    mode: sequential
    keymaps:
      tmux:
        "1": tmux.dotfiles
        "2": tmux.notes
        "3": tmux.tools
        "4": tmux.side-project
        "5": tmux.editor
```

Set the initial active profile:

```sh
keyroute profile set work
```

## tmux Config

Add this to `~/.tmux.conf`.

This example assumes your tmux prefix is `C-q`. If your prefix is different,
the tmux config does not need to change, but the Ghostty `text:` prefix bytes in
the next section do.

```tmux
# Keyroute tmux session slots. Prefix y enters a quiet numeric switch table.
bind-key y switch-client -T keyroute-switch
bind-key -T keyroute-switch 1 run-shell -b "keyroute --quiet key tmux 1"
bind-key -T keyroute-switch 2 run-shell -b "keyroute --quiet key tmux 2"
bind-key -T keyroute-switch 3 run-shell -b "keyroute --quiet key tmux 3"
bind-key -T keyroute-switch 4 run-shell -b "keyroute --quiet key tmux 4"
bind-key -T keyroute-switch 5 run-shell -b "keyroute --quiet key tmux 5"
bind-key -T keyroute-switch 6 run-shell -b "keyroute --quiet key tmux 6"
bind-key -T keyroute-switch 7 run-shell -b "keyroute --quiet key tmux 7"
bind-key -T keyroute-switch 8 run-shell -b "keyroute --quiet key tmux 8"
bind-key -T keyroute-switch 9 run-shell -b "keyroute --quiet key tmux 9"
bind-key -T keyroute-switch w run-shell -b "keyroute --quiet profile set work && tmux display-message 'Keyroute profile: work'"
bind-key -T keyroute-switch p run-shell -b "keyroute --quiet profile set personal && tmux display-message 'Keyroute profile: personal'"
bind-key -T keyroute-switch s run-shell -b "tmux display-message \"Keyroute profile: $(keyroute profile current 2>/dev/null || echo none)\""
```

Reload tmux:

```sh
tmux source-file ~/.tmux.conf
```

## Ghostty Config

Add this to `~/.config/ghostty/config`.

This keeps Ghostty layered instead of making each Ghostty shortcut run a
specific session. `ctrl+cmd+k` sends the tmux prefix and `y`, then activates a
one-shot Ghostty table. The next key is passed through to tmux as the table
entry.

```ini
# Keyroute tmux session slots. Ctrl+Cmd+K sends tmux prefix C-q and enters
# the tmux Keyroute table y; the next key is passed through separately.
keybind = ctrl+cmd+k=text:\x11y
keybind = chain=activate_key_table_once:keyroute
keybind = keyroute/escape=deactivate_key_table
keybind = keyroute/1=text:1
keybind = keyroute/2=text:2
keybind = keyroute/3=text:3
keybind = keyroute/4=text:4
keybind = keyroute/5=text:5
keybind = keyroute/6=text:6
keybind = keyroute/7=text:7
keybind = keyroute/8=text:8
keybind = keyroute/9=text:9
keybind = keyroute/w=text:w
keybind = keyroute/p=text:p
keybind = keyroute/s=text:s
```

For a different tmux prefix, change `\x11`:

```text
C-q = \x11
C-a = \x01
C-b = \x02
```

Reload Ghostty config after editing.

## Why Not Use Ghostty to Run Keyroute Directly?

Ghostty's keybind actions include `text`, key tables, panes, tabs, windows, and
other terminal actions, but not a general shell command action. That means the
portable route is to let Ghostty send keys, let tmux own the terminal key table,
and let tmux run `keyroute`.

This preserves the layers:

- Ghostty owns the GUI shortcut and a one-shot key table.
- tmux owns terminal-local key dispatch.
- Keyroute owns profile and target resolution.

## Validation

Useful checks:

```sh
keyroute doctor
keyroute list
keyroute profile current
keyroute key --profile work tmux 1 --dry-run
keyroute key --profile personal tmux 1 --dry-run
tmux list-keys -T keyroute-switch
/Applications/Ghostty.app/Contents/MacOS/ghostty +list-keybinds | rg 'keyroute'
```

Ghostty config validation can fail for unrelated reasons, such as a missing
theme. To isolate keybind syntax, validate a temporary config with any local
theme references adjusted.
