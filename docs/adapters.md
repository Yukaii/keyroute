# Adapters

Adapters are the boundary between Keyroute's resolver and the thing that does
the focusing work.

```text
target config -> adapter -> app/session/window/workspace
```

Built-in adapters live as separate source files:

```text
Sources/keyroute/CommandAdapter.swift
Sources/keyroute/ChromiumAdapter.swift
Sources/keyroute/TmuxAdapter.swift
Sources/keyroute/MacOSWindowAdapter.swift
Sources/keyroute/ExternalAdapter.swift
```

See [adapter-status.md](adapter-status.md) for the current implementation status
and known gaps of each official adapter.

Shared adapter types live in:

```text
Sources/keyroute/Adapter.swift
Sources/keyroute/AdapterRegistry.swift
Sources/keyroute/CommandRunner.swift
Sources/keyroute/TargetConfig.swift
Sources/keyroute/ConfigValue.swift
```

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

## Adding Built-In Adapters

For adapters that should ship with Keyroute:

1. Add a new `Sources/keyroute/<Name>Adapter.swift` file.
2. Implement `Adapter`.
3. Register it in `AdapterRegistry.swift`.
4. Add config validation in `Config.swift`.

Use an external adapter first unless the adapter needs native macOS APIs,
shared behavior, or a stable built-in contract.
