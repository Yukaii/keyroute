# Adapters

Adapters are the boundary between Keyroute's resolver and the thing that does
the focusing work.

```text
target config -> adapter -> app/session/window/workspace
```

Built-in adapters live as separate source files:

```text
Sources/KeyrouteCore/CommandAdapter.swift
Sources/KeyrouteCore/ChromiumAdapter.swift
Sources/KeyrouteCore/ExternalAdapter.swift
Sources/KeyrouteTmux/TmuxAdapter.swift
Sources/KeyrouteMacOS/MacOSWindowAdapter.swift
```

See [adapter-status.md](adapter-status.md) for the current implementation status
and known gaps of each official adapter.

Shared adapter types live in:

```text
Sources/KeyrouteCore/Adapter.swift
Sources/KeyrouteCore/CommandRunner.swift
Sources/KeyrouteCore/TargetConfig.swift
Sources/KeyrouteCore/ConfigValue.swift
Sources/keyroute/AdapterRegistry.swift
```

The executable target owns adapter composition. This keeps the core package
portable while allowing platform-specific modules to be linked only where they
are available.

## External Adapter

Use `adapter: external` when the adapter should be implemented outside
Keyroute, for example as a shell, Python, Ruby, JavaScript, or Swift script.

Example target:

```yaml
targets:
  custom.editor.project:
    adapter: external
    run: ~/.config/keyroute/adapters/focus-editor
    cwd: ~/work/project
    args:
      - --mode
      - focus
    env:
      EDITOR_FLAVOR: stable
    bundleID: com.example.Editor
    titleContains: project
```

All target fields are preserved. Built-in Keyroute fields such as `adapter`,
`run`, `args`, `cwd`, and `env` are available, and custom fields such as
`bundleID` and `titleContains` are passed through unchanged.

### Script Input

The external adapter receives a JSON payload on stdin:

```json
{
  "runtime": {
    "dryRun": false,
    "quiet": false,
    "verbose": false
  },
  "target": {
    "adapter": "external",
    "bundleID": "com.example.Editor",
    "run": "~/.config/keyroute/adapters/focus-editor",
    "titleContains": "project"
  },
  "targetID": "custom.editor.project"
}
```

The script also receives environment variables:

```text
KEYROUTE_TARGET=custom.editor.project
KEYROUTE_ADAPTER=external
KEYROUTE_DRY_RUN=0
KEYROUTE_VERBOSE=0
KEYROUTE_QUIET=0
```

Target `env` entries are merged into the inherited process environment.

On `keyroute --dry-run`, Keyroute reports the external command it would run but
does not execute the script. This matches the built-in adapters: dry-run should
not move focus, spawn sessions, or run user code.

### Exit Codes

External adapters should use Keyroute's exit-code meanings:

| Code | Meaning |
|------|---------|
| 0 | Success. |
| 3 | Target not found. |
| 4 | Adapter error. |
| 5 | Permission denied. |

Other non-zero exit codes are returned as adapter failures.

Stdout is used as the success message. Stderr is used as the error message. In
quiet mode, output is captured so it does not flash in tmux or terminal UIs.

External adapters may also emit structured JSON on stdout or stderr:

```json
{
  "status": "success",
  "message": "focused workspace",
  "exitCode": 0
}
```

Supported `status` values are `success`, `not-found`, `permission-denied`, and
`error`. `message` and `exitCode` are optional. If `status` is present, Keyroute
uses it instead of inferring status only from the process exit code.

### Shell Example

```sh
#!/bin/sh
set -eu

payload=$(cat)
target_id=${KEYROUTE_TARGET:-unknown}

if [ "${KEYROUTE_DRY_RUN:-0}" = "1" ]; then
  echo "would focus $target_id"
  exit 0
fi

bundle_id=$(printf '%s' "$payload" | jq -r '.target.bundleID // empty')
title_part=$(printf '%s' "$payload" | jq -r '.target.titleContains // empty')

if [ -z "$bundle_id" ] || [ -z "$title_part" ]; then
  echo "bundleID and titleContains are required" >&2
  exit 4
fi

osascript <<APPLESCRIPT
tell application id "$bundle_id" to activate
APPLESCRIPT

echo "focused $target_id"
```

Save it somewhere executable:

```sh
chmod +x ~/.config/keyroute/adapters/focus-editor
```

## Shipped Examples

Keyroute embeds small reference adapters that can be printed or installed from
the CLI:

```sh
keyroute example list
keyroute example show tmux-shell
keyroute example install
```

`keyroute example install` creates the default adapters directory
(`~/.config/keyroute/adapters`) and writes every embedded example there,
skipping files that already exist. A custom directory can be passed as an
argument.

The examples are reference implementations, not hidden behavior. They are
intended to be copied, edited, and owned by the user.

### tmux Shell Adapter

The `tmux-shell` example implements the same basic contract as the built-in
`tmux` adapter through `adapter: external`.

Install it:

```sh
mkdir -p ~/.config/keyroute/adapters
keyroute example show tmux-shell > ~/.config/keyroute/adapters/tmux
chmod +x ~/.config/keyroute/adapters/tmux
```

Use it:

```yaml
targets:
  tmux.project:
    adapter: external
    run: ~/.config/keyroute/adapters/tmux
    session: project
    cwd: ~/Projects/project
    create: true
```

The script expects `jq` and `tmux` to be available in `PATH`.

### Chromium Helper

The `switch-chromium` example is a standalone shell script that switches
profiles or workspaces in Chromium-based browsers via macOS menu items. It is
used by the built-in `chromium` adapter when no `command` is configured.

Install it:

```sh
mkdir -p ~/.config/keyroute/adapters
keyroute example show switch-chromium > ~/.config/keyroute/adapters/switch-chromium
chmod +x ~/.config/keyroute/adapters/switch-chromium
```

Use it:

```yaml
targets:
  browser.chrome.work:
    adapter: chromium
    browser: chrome
    workspace: work

  browser.brave.personal:
    adapter: chromium
    browser: brave
    profile: personal
    lang: en
```

## Adding Built-In Adapters

For adapters that should ship with Keyroute:

1. Add a new file under the module that owns the behavior:
   `Sources/KeyrouteCore`, `Sources/KeyrouteTmux`, or
   `Sources/KeyrouteMacOS`.
2. Implement `Adapter`.
3. Register it in `AdapterRegistry.swift`.
4. Add config validation in `Config.swift`.

Use an external adapter first unless the adapter needs native macOS APIs,
shared behavior, or a stable built-in contract.
