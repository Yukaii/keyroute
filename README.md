# Keyroute

Keyroute is a deterministic session and window router with a portable Swift
core and optional platform adapters.

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

See [docs/platform-agnostic.md](docs/platform-agnostic.md) for the
platform-agnostic architecture and roadmap.

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
swift run keyroute example list
```

The CLI reads config from `~/.config/keyroute/config.yaml`, or from
`$XDG_CONFIG_HOME/keyroute/config.yaml` when `XDG_CONFIG_HOME` is set.

Package layout:

```text
KeyrouteCore   portable resolver, config, state, and external adapters
KeyrouteTmux   tmux adapter
KeyrouteMacOS  AppKit and Accessibility adapters
keyroute       executable CLI and adapter registry
```

## License

Keyroute is released under the [MIT License](LICENSE).
