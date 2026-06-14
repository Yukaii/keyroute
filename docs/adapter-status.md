# Adapter Implementation Status

This tracks the current implementation state of Keyroute's official adapters.
It distinguishes implemented behavior from design intent so users know what is
safe to depend on.

## Summary

| Adapter | Status | Notes |
|---------|--------|-------|
| `tmux` | MVP implemented | Can check, create, activate terminal app, and switch attached tmux clients. |
| `command` | MVP implemented | Runs a configured command with args, cwd, and env. |
| `external` | MVP implemented | Runs custom adapter scripts with target JSON on stdin. |
| `macos-window` | Partial native implementation | Uses Accessibility window matching and raise; no launch/create behavior. |
| `chromium` | Script-wrapper only | Requires a user-provided `command`; no built-in browser/workspace switching yet. |

## `tmux`

Source: `Sources/keyroute/TmuxAdapter.swift`

Implemented:

- Requires `session`.
- Checks session existence with `tmux has-session`.
- Creates missing sessions when `create: true`.
- Uses `cwd` when creating a new session.
- Activates the configured host app by bundle id when `app` is set.
- Switches an attached client with `tmux switch-client`.
- Supports `--dry-run`.
- Supports `--quiet` by suppressing command output.

Known gaps:

- Does not open a new terminal command when no attached tmux client exists.
- Does not verify that the requested session became focused after switching.
- Does not distinguish "tmux not installed" from other tmux command failures in
  a rich way.
- Does not support alternate tmux binary paths.

## `command`

Source: `Sources/keyroute/CommandAdapter.swift`

Implemented:

- Runs `run` or `command`.
- Passes `args`.
- Applies `cwd`.
- Merges configured `env` with the inherited environment.
- Returns the command exit code directly.
- Supports `--dry-run`.
- Supports `--quiet`.

Known gaps:

- Does not pass structured target JSON to the command. Use `external` for that.
- Does not provide timeout handling.

## `external`

Source: `Sources/keyroute/ExternalAdapter.swift`

Implemented:

- Runs `run` or `command`.
- Passes `args`.
- Applies `cwd`.
- Merges configured `env` with the inherited environment.
- Preserves arbitrary target config fields.
- Sends a structured JSON payload on stdin.
- Sets `KEYROUTE_TARGET`, `KEYROUTE_ADAPTER`, `KEYROUTE_DRY_RUN`,
  `KEYROUTE_VERBOSE`, and `KEYROUTE_QUIET`.
- Maps exit code `0` to success, `3` to not found, `5` to permission denied, and
  other non-zero codes to adapter errors.
- Captures stdout/stderr so quiet mode does not flash terminal output.

Known gaps:

- `--dry-run` does not execute the script. This is intentional for now, but it
  means custom scripts cannot produce their own dry-run details.
- Does not provide timeout handling.
- Does not validate a script's JSON output because external adapters currently
  communicate result status by exit code plus stdout/stderr.

## `macos-window`

Source: `Sources/keyroute/MacOSWindowAdapter.swift`

Implemented:

- Requires `app`.
- Requires one window match rule: `title`, `titleContains`, `titleRegex`, or
  `windowIndex`.
- Checks Accessibility permission with `AXIsProcessTrusted`.
- Finds running apps by bundle id.
- Reads Accessibility windows.
- Matches by exact title, case-insensitive title substring, regular expression,
  or 1-based window index.
- Raises the matched window with `kAXRaiseAction`.
- Activates the app.
- Supports `--dry-run`.

Known gaps:

- Does not launch the app if it is not running.
- Does not use private window identity APIs such as `_AXUIElementGetWindow`.
- Does not verify the raised window became focused.
- Regex flavor is whatever Swift's regular expression option provides, not a
  separately documented POSIX mode.
- Window ordering for `windowIndex` depends on Accessibility's returned order.

## `chromium`

Source: `Sources/keyroute/ChromiumAdapter.swift`

Implemented:

- Requires `browser`.
- Requires `workspace`.
- Requires `command`.
- Executes the configured command as:

```sh
<command> --browser <browser> --workspace <workspace>
```

- Supports `--dry-run`.
- Supports `--quiet`.

Current limitation:

This is not a built-in Chromium workspace adapter yet. It is only the
script-wrapper path from the MVP design. Keyroute does not currently ship
browser-specific AppleScript, URL-handler, profile, or workspace switching
logic.

Known gaps:

- No default command mapping per browser.
- No native Chrome/Chromium/Arc/Brave profile or workspace switching.
- No browser app activation beyond whatever the helper script does.
- No verification that the requested browser workspace became active.

Recommended usage today:

```yaml
targets:
  browser.primary.docs:
    adapter: chromium
    browser: primary
    workspace: docs
    command: ~/.config/keyroute/adapters/switch-chromium
```

For anything beyond this wrapper contract, use `adapter: external` until a
native browser adapter is implemented.
