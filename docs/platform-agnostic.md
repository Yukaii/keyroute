# Platform-Agnostic Direction

Keyroute's model is platform-agnostic, but the current implementation is
macOS-first.

This document records the direction for making Keyroute compose cleanly with
productivity tools on other platforms later.

The current plan is to keep implementing Keyroute in Swift. Swift is a good fit
for the current macOS-first path, especially for native macOS adapters that need
AppKit or Accessibility APIs. A Rust core may become interesting later if
packaging, static distribution, or Windows support becomes the primary
constraint, but it is not the current implementation target.

## Current State

Portable today:

- Config loading.
- XDG-compatible config and state paths.
- Aliases.
- Target/profile/keymap resolution.
- Active profile state.
- `command` adapter.
- `external` adapter contract.
- Most of the `tmux` adapter behavior.
- The package builds and tests on macOS and Linux.
- `doctor` reports the current platform.

macOS-specific today:

- `macos-window` uses AppKit and Accessibility APIs.
- `tmux` optionally activates a host app by macOS bundle id.
- Examples use macOS bundle ids such as `com.mitchellh.ghostty`.

Language direction:

- Keep the core and official adapters in Swift for now.
- Design adapter boundaries so future adapters can be implemented in any
  language.
- Treat Rust as a possible future portable core or adapter implementation, not
  as an immediate rewrite.

## Goal

Keyroute should become a portable resolver with optional platform adapters.

```text
keyroute core
  config
  aliases
  targets
  profiles
  keymaps
  state
  CLI
  adapter protocol
  external adapter
  command adapter

platform adapters
  macOS app/window adapter
  Linux desktop/window adapter
  Windows app/window adapter
  browser-specific adapters
```

The core should not need to know whether a target is a macOS window, a Linux
workspace, a Windows virtual desktop, a browser profile, or an app-specific
workspace. It should resolve names and delegate execution.

The platform sequence is:

1. macOS first.
2. Linux second.
3. Windows last.

This order matches the practical adapter surface. macOS gives Keyroute the
current native productivity workflow. Linux can share much of the CLI, tmux, and
external adapter behavior. Windows should come after the core is cleanly
portable because its window, terminal, and desktop APIs will likely need
separate adapter semantics.

## Design Principles

- Keep Keyroute deterministic. It resolves named targets; it does not infer user
  intent from window order.
- Keep input outside Keyroute. Ghostty, tmux, BetterTouchTool, Karabiner,
  launchers, and desktop environments own key gestures.
- Keep platform-specific APIs isolated.
- Prefer `external` adapters for early integrations.
- Promote an adapter into the built-in tree only when the behavior is stable,
  broadly useful, and easier to maintain centrally.

## Paths

Keyroute uses XDG-style paths for portable CLI state:

```text
config: $XDG_CONFIG_HOME/keyroute/config.yaml
state:  $XDG_STATE_HOME/keyroute/state.json
```

When the XDG variables are unset or relative, Keyroute falls back to:

```text
config: ~/.config/keyroute/config.yaml
state:  ~/.local/state/keyroute/state.json
```

This keeps the current macOS setup unchanged while matching Linux conventions.

## Package Split

Current SwiftPM shape:

```text
Sources/KeyrouteCore/
  Config.swift
  TargetConfig.swift
  ProfileState.swift
  Adapter.swift
  ExternalAdapter.swift
  CommandAdapter.swift
  ChromiumAdapter.swift
  EmbeddedExamples.swift

Sources/KeyrouteTmux/
  TmuxAdapter.swift

Sources/KeyrouteMacOS/
  MacOSWindowAdapter.swift
  MacOSSystemStatus.swift

Sources/keyroute/
  main.swift
  AdapterRegistry.swift
```

The boundary is:

- `KeyrouteCore` owns config, resolution, state, output helpers, embedded
  examples, and portable adapters. It does not import AppKit or
  ApplicationServices.
- `KeyrouteTmux` owns tmux behavior. It conditionally uses AppKit on macOS only
  for optional host-app activation.
- `KeyrouteMacOS` owns AppKit and Accessibility behavior.
- `keyroute` owns CLI parsing and adapter composition.

## Adapter Contract

The `external` adapter is the cross-platform baseline.

```yaml
targets:
  desktop.editor.project:
    adapter: external
    run: ~/.config/keyroute/adapters/focus-editor
    workspace: project
```

External adapters receive:

- Full target config as JSON on stdin.
- `KEYROUTE_*` environment variables.
- Exit-code based status reporting.

This lets users build integrations in shell, Python, JavaScript, Swift, Go, or
any other language without changing Keyroute itself.

This contract should also make a future mixed-language implementation possible.
For example, Keyroute could remain a Swift CLI while invoking shell, Python, or
Rust adapters. Or a future Rust core could invoke Swift helper binaries for
macOS-only AppKit and Accessibility behavior.

```text
keyroute                 # Swift today, possibly Rust later
keyroute-adapter-macos   # Swift helper for macOS APIs
keyroute-adapter-tmux    # Swift, shell, or Rust helper
keyroute-adapter-linux   # shell or Rust helper
```

The important boundary is process-level compatibility, not shared in-process
language runtime.

## tmux Portability

The tmux adapter should be split into portable and platform-specific behavior.

Portable fields:

```yaml
session: project
cwd: ~/work/project
create: true
```

macOS-only field:

```yaml
app: com.mitchellh.ghostty
```

Future direction:

- Keep session existence, creation, and `switch-client` portable.
- Treat host app activation as optional platform behavior.
- Consider a separate field such as `hostApp` or `activateApp` if `app` becomes
  too macOS-specific.

On non-macOS platforms, the `app` field is ignored by the built-in tmux adapter.
Dry-runs report that app activation will be skipped.

## Platform Adapter Ideas

macOS:

- `macos-window`
- app bundle activation
- Accessibility window matching

Linux:

- external scripts for `wmctrl`, `xdotool`, `hyprctl`, `swaymsg`, `qdbus`, or
  desktop-specific APIs
- native adapters only after stable contracts emerge
- XDG config and state paths are supported
- shipped example adapters are available through `keyroute example show`

Example Linux-first external target:

```yaml
targets:
  desktop.editor:
    adapter: external
    run: ~/.config/keyroute/adapters/focus-editor
    workspace: editor

profiles:
  linux:
    keymaps:
      desktop:
        "1": desktop.editor
```

The adapter script owns the desktop-specific details, such as `swaymsg`,
`hyprctl`, `wmctrl`, or `xdotool`.

Windows:

- external PowerShell adapters first
- optional native window activation later

Browsers:

- keep `chromium` as script-wrapper until native browser workspace semantics are
  proven
- browser-specific external adapters can evolve independently

## Migration Plan

1. Keep `external` documented as the portable adapter path.
2. Move macOS-only helpers behind `#if os(macOS)`. Done for current AppKit and
   Accessibility usage.
3. Stop importing AppKit from shared files. Done for the CLI entrypoint and
   shared helpers.
4. Make `tmux` build without macOS app activation on non-macOS platforms. Done;
   app activation is a no-op outside macOS.
5. Add CI for at least macOS and Linux once non-macOS build support exists.
   Done for build and test.
6. Split source modules when the platform boundary is stable. Done for
   `KeyrouteCore`, `KeyrouteTmux`, `KeyrouteMacOS`, and the executable target.
7. Add platform-specific docs and examples. Started with Linux external adapter
   examples.
8. Revisit Rust only if packaging or distribution becomes a larger problem than
   implementation momentum.

## Open Questions

- Should adapter names include platform prefixes, such as `macos-window`,
  `linux-window`, and `windows-window`, or should generic names route to
  platform implementations?
- Should `app` remain the common app identity field, or should platform-specific
  fields be explicit?
- Should built-in adapters be compiled conditionally or distributed as separate
  plugin executables?
