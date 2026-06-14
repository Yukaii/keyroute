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

See [docs/tmux-ghostty.md](docs/tmux-ghostty.md) for a detailed example of
using Keyroute as a fast tmux session switcher underneath Ghostty.

See [docs/adapters.md](docs/adapters.md) for the built-in adapter layout and
the external adapter contract for custom scripts.

See [docs/adapter-status.md](docs/adapter-status.md) for the current
implementation status of each official adapter.

## Development

Build the CLI with SwiftPM:

```sh
swift build
```

Run commands from the package checkout:

```sh
swift run keyroute list
swift run keyroute inspect tmux.project-alpha
swift run keyroute go tmux.project-alpha --dry-run
```

The MVP reads config from `~/.config/keyroute/config.yaml`.

## License

Keyroute is released under the [MIT License](LICENSE).
