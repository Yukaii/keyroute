# Keyroute

Keyroute is a deterministic session and window router for macOS.

It is designed to sit underneath input tools like BetterTouchTool, Leader Key,
Karabiner, Raycast, Alfred, or shell scripts. Those tools own key gestures and
menus; Keyroute owns resolving a named target to the app, session, window, tab,
or workspace that should be focused.

```sh
keyroute go tmux.project-alpha
keyroute go browser.primary.docs
keyroute profile project-alpha
```

See [docs/design.md](docs/design.md) for the initial design.
