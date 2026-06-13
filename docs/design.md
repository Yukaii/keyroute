# Keyroute Design

## Purpose

Keyroute is a deterministic session and window router for macOS. It lets input
tools like BetterTouchTool, Leader Key, Karabiner, Raycast, Alfred, or shell
scripts route directly to named work contexts.

Keyroute is not an app switcher. It is a target resolver.

```sh
keyroute go tmux.default-browser
keyroute go zen.github
keyroute go codex.default-browser
```

Input stays outside Keyroute:

```text
Leader Key / BTT / hotkey
        |
        v
keyroute go <target>
        |
        v
target config
        |
        v
adapter
        |
        v
focused app/session/window/tab
```

This keeps Keyroute small and deterministic. BetterTouchTool owns gestures.
Leader Key owns key sequences. Keyroute owns routing.

## Core Model

Keyroute has three levels:

- `target`: one exact thing to focus.
- `profile`: a named workspace made from several targets.
- `adapter`: how a target is reached.

A profile is not just a config preset. It is a user-authored workspace where
macOS apps, windows, browser workspaces, and terminal sessions are treated as
workspace units.

### Target Identity and Namespacing

Target IDs are globally unique strings. The recommended convention is a dotted
name where the first segment indicates the adapter family:

```text
<adapter-family>.<context>.<name>
```

Examples:

```text
tmux.default-browser         # adapter family: tmux
browser.zen.github           # adapter family: browser, browser: zen
macos-window.codex.default   # adapter family: macos-window
command.opencode.default     # adapter family: command
```

The first segment is a convention, not enforced syntax. The actual adapter is
determined by the `adapter` field. This lets users keep stable names even if the
implementation adapter changes.

All targets, profiles, and aliases live in the same namespace. A name cannot be
reused across categories.

## Configuration

Initial versions use one explicit config file:

```text
~/.config/keyroute/config.yaml
```

The single-file model is intentional for now. It keeps the behavior easy to
audit and easy to bind from BetterTouchTool or Leader Key.

Example:

```yaml
aliases:
  db: profile.default-browser
  reef: profile.reef
  zgh: browser.zen.github
  tdb: tmux.default-browser

targets:
  tmux.default-browser:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: default-browser
    cwd: ~/projects/default-browser
    create: true

  browser.helium.default-browser:
    adapter: chromium
    browser: helium
    workspace: default-browser

  browser.zen.github:
    adapter: chromium
    browser: zen
    workspace: github

  codex.default-browser:
    adapter: macos-window
    app: com.openai.codex
    titleContains: default-browser

profiles:
  default-browser:
    targets:
      - browser.helium.default-browser
      - tmux.default-browser
      - codex.default-browser
    default: tmux.default-browser
    mode: sequential
```

## CLI

Commands should remain explicit:

```sh
keyroute go tmux.default-browser
keyroute go zgh
keyroute profile default-browser
keyroute list
keyroute inspect tmux.default-browser
keyroute doctor
keyroute config path
```

No implicit `keyroute tmux.default-browser` command is planned for the initial
design.

### Output Formats

`keyroute list` and `keyroute inspect` default to human-readable text. For
tooling integrations, `--format json` and `--format yaml` should be supported.

Example `keyroute list --format json`:

```json
{
  "aliases": {
    "db": "profile.default-browser",
    "tdb": "target.tmux.default-browser"
  },
  "targets": ["tmux.default-browser", "browser.helium.default-browser"],
  "profiles": ["default-browser"]
}
```

`keyroute inspect <target>` should emit the resolved target config including the
adapter and all fields.

Aliases can resolve to targets or profiles. To avoid ambiguity, aliases should
use prefixed references:

```yaml
aliases:
  t1: target.tmux.default-browser
  z1: target.browser.zen.github
  db: profile.default-browser
```

Resolution rules:

1. `target.<target-id>` resolves to the named target.
2. `profile.<profile-id>` resolves to the named profile.
3. Bare names are resolved by first checking targets, then profiles, then aliases
   (aliases cannot reference other aliases).
4. Circular alias references are an error at load time.

## Adapters

Adapters share a simple contract:

```text
resolve target -> ensure app/session exists -> focus target -> verify best effort
```

### Adapter Interface

Adapters receive a normalized target configuration and a runtime context. They
return a structured result:

```text
Input:
  - target config (YAML map)
  - runtime context (dry-run flag, verbose flag, shell environment)

Output:
  - status: success | not-found | permission-denied | error
  - message: human-readable string
  - exit-code: 0 for success, non-zero for failure
```

Behavioral rules:

- An adapter must be idempotent where possible. Calling `keyroute go <target>`
  when the target is already focused should leave the system in the same state.
- An adapter must fail loudly. If the target cannot be reached, it returns a
  non-zero exit code and writes a diagnostic message to stderr.
- "Verify best effort" means the adapter may check that the requested window,
  session, or workspace is now active, but it must not block indefinitely.
- Adapters are expected to be re-entrant. Two rapid invocations should not
  corrupt state, though the final focused target may reflect the last completed
  call.

### tmux Adapter

The tmux adapter is the primary deterministic development workflow adapter.

```yaml
targets:
  tmux.reef:
    adapter: tmux
    app: com.mitchellh.ghostty
    session: reef
    cwd: ~/projects/reef
    create: true
```

Behavior:

1. Check if the tmux session exists.
2. Create the session if `create: true`.
3. Activate the terminal app.
4. Switch the attached tmux client to the session if possible.
5. If no attached client exists, open the terminal command.

Likely tmux primitives:

```sh
tmux has-session -t reef
tmux new-session -d -s reef -c /path
tmux switch-client -t reef
```

### chromium Adapter

The chromium adapter delegates to deterministic browser mechanisms when they
exist. It is designed around the idea that each supported browser already has
its own workspace/profile switching primitive, so Keyroute should not try to
infer windows.

Configuration:

```yaml
targets:
  browser.helium.default-browser:
    adapter: chromium
    browser: helium
    workspace: default-browser
    command: /path/to/switch-chromium
```

Fields:

- `browser` (required): the browser identifier (e.g. `helium`, `zen`, `chrome`).
- `workspace` (required): the workspace or profile name to activate.
- `command` (optional): path to a helper script. If omitted, Keyroute uses a
  built-in default per browser.

Execution with `command`:

```sh
/path/to/switch-chromium --browser helium --workspace default-browser
```

Execution without `command` uses an internal mapping from `browser` to the
appropriate AppleScript, URL handler, or CLI command. The MVP only needs to
support the script-wrapper path.

### macos-window Adapter

The macos-window adapter is for apps with stable window titles or other
accessible metadata.

```yaml
targets:
  codex.default-browser:
    adapter: macos-window
    app: com.openai.codex
    titleContains: default-browser
```

Behavior:

1. Find the running app by bundle id.
2. Query Accessibility windows.
3. Match by title rule.
4. Raise the matched window.
5. Activate the app.

Supported match rules should include:

```yaml
title: Exact Title
titleContains: substring
titleRegex: regex
windowIndex: 1   # 1-based index among the app's windows
```

`titleRegex` uses the system's POSIX extended regex flavor unless otherwise
noted. `windowIndex` is 1-based.

Accessibility:

- This adapter requires Accessibility permission for Keyroute. If permission is
  denied, the adapter returns `permission-denied` with instructions for granting
  it.
- Private Accessibility APIs are acceptable initially if they provide more
  stable window identity, especially `_AXUIElementGetWindow` for `CGWindowID`.
  The design still prefers durable config rules like title matching over storing
  raw runtime window ids as the only identity.
- If the app is not running, the adapter fails unless a future `launch: true`
  option is added.

### command Adapter

The command adapter is the escape hatch.

```yaml
targets:
  opencode.default:
    adapter: command
    run: /path/to/opencode-focus
    args:
      - default-browser
    cwd: ~/projects
    env:
      KEYROUTE_TARGET: opencode.default
```

Fields:

- `run` (required): command to execute.
- `args` (optional): list of arguments.
- `cwd` (optional): working directory; defaults to the user's home directory.
- `env` (optional): environment variables to set or override.

The command inherits the user's shell environment plus any `env` entries. The
adapter returns the command's exit code directly. Stdout and stderr are passed
through unless `--quiet` is set.

### Config Schema Summary

Top-level keys:

```yaml
aliases: { string: string }
targets: { string: target-config }
profiles: { string: profile-config }
```

`target-config` fields by adapter:

| Field | Adapters | Required | Description |
|-------|----------|----------|-------------|
| `adapter` | all | yes | One of `tmux`, `chromium`, `macos-window`, `command`. |
| `app` | tmux, macos-window | yes* | Bundle id of the host app. |
| `session` | tmux | yes | tmux session name. |
| `cwd` | tmux, command | no | Working directory for creation or command. |
| `create` | tmux | no | Create the session if missing. Defaults to `false`. |
| `browser` | chromium | yes | Browser identifier. |
| `workspace` | chromium | yes | Workspace or profile name. |
| `command` | chromium, command | no* | External command path. Required for `command`. |
| `args` | command | no | Command arguments. |
| `env` | command | no | Environment variables. |
| `title` | macos-window | no* | Exact window title. |
| `titleContains` | macos-window | no* | Substring match. |
| `titleRegex` | macos-window | no* | Regex match. |
| `windowIndex` | macos-window | no* | 1-based window index. |

At least one match rule is required for `macos-window`.

`profile-config` fields:

```yaml
targets: [target-id, ...]
default: target-id
mode: sequential
keymaps:
  <namespace>:
    "<key>": target-id
```

## Profiles

Profiles are deterministic macOS workspaces composed from targets.

```yaml
profiles:
  default-browser:
    targets:
      - browser.helium.default-browser
      - tmux.default-browser
      - codex.default-browser
    default: tmux.default-browser
    mode: sequential
```

Profile activation:

1. Ensure each target in `targets` exists if it has `create: true`.
2. Ensure the `default` target exists if it has `create: true`.
3. Activate each target in `targets` in the order listed. For browser-family
   targets this means switching to the named workspace; for terminal-family
   targets it means ensuring the session exists and attaching if needed.
4. Focus the `default` target.

The `default` target must be either a member of `targets` or a valid target
elsewhere in config. The `targets` list defines activation order; `default`
defines where focus lands.

`mode: sequential` means targets are activated in the order listed. Future modes
might include `parallel` for simultaneous activation where safe.

Commands:

```sh
keyroute profile default-browser
keyroute profile default-browser --focus codex.default-browser
keyroute profile default-browser --focus default
keyroute profile list
```

This borrows the useful part of prior workspace tools but changes the primitive.
Those tools remap app slots; Keyroute profiles assemble deterministic workspace
targets.

### Profile-Scoped Keymaps

Profiles can also provide scoped keymaps. In this model, a profile is a
workspace mode, target set, and keymap.

```text
profile = workspace mode + target set + keymap
```

This is useful when the same physical shortcut should route to different
deterministic sessions depending on the current mode. For example, while in a
`working` profile, tmux slot `1` might mean a work API repo. In a
`side-projects` profile, tmux slot `1` might mean Keyroute itself.

```yaml
profiles:
  working:
    default: tmux.work-api
    targets:
      - tmux.work-api
      - tmux.work-web
      - tmux.work-infra
      - browser.zen.work
    keymaps:
      tmux:
        "1": tmux.work-api
        "2": tmux.work-web
        "3": tmux.work-infra
        "4": tmux.work-notes
      browser:
        "1": browser.zen.work
        "2": browser.helium.dashboard

  side-projects:
    default: tmux.keyroute
    targets:
      - tmux.keyroute
      - tmux.default-browser
      - tmux.side-project
      - browser.zen.github
    keymaps:
      tmux:
        "1": tmux.keyroute
        "2": tmux.default-browser
        "3": tmux.side-project
      browser:
        "1": browser.zen.github
        "2": browser.helium.default-browser
```

The input layer can stay stable:

```text
Ghostty Ctrl+1 -> keyroute key tmux 1
Ghostty Ctrl+2 -> keyroute key tmux 2

Browser Ctrl+1 -> keyroute key browser 1
Browser Ctrl+2 -> keyroute key browser 2

Leader -> p -> w -> keyroute profile working
Leader -> p -> s -> keyroute profile side-projects
```

If the input layer already knows the current mode, it can pass the profile
explicitly:

```text
Leader mode: working
  t -> 1  keyroute key --profile working tmux 1
  t -> 2  keyroute key --profile working tmux 2

Leader mode: side-projects
  t -> 1  keyroute key --profile side-projects tmux 1
  t -> 2  keyroute key --profile side-projects tmux 2
```

Keyroute supports two keymap resolution styles.

The deterministic style names the profile explicitly:

```sh
keyroute key --profile working tmux 1
# resolves to tmux.work-api

keyroute key --profile side-projects tmux 1
# resolves to tmux.keyroute
```

This is the best fit when Leader Key, BetterTouchTool, or another input layer
already owns modes. The binding can pass the profile directly, so the command
has no hidden state.

The stateful style omits the profile and falls back to the active profile:

```sh
keyroute key tmux 1
# active profile: working
# resolves to tmux.work-api

keyroute key tmux 1
# active profile: side-projects
# resolves to tmux.keyroute
```

This is useful for high-frequency workflows where the same physical shortcut
should mean "slot 1 in my current workspace mode." The tradeoff is hidden state,
so active profile inspection must be cheap.

In the stateful style, `<namespace>` is a keymap group defined by the profile
(`tmux`, `browser`, etc.). The namespace is user-defined in config. `keyroute key`
validates that the namespace exists in the active profile and that the key is
mapped. Keys map only to targets, not to other profiles or aliases.

This generalizes the prior profile idea:

```text
Prior tool:
profile changes number -> app binding

Keyroute:
profile changes namespace + key -> deterministic target binding
```

Direct target calls remain absolute and are not affected by the active profile:

```sh
keyroute go tmux.keyroute
keyroute go browser.zen.github
```

Only profile-relative key commands depend on active profile state:

```sh
keyroute key tmux 1
keyroute key browser 2
```

Profile-relative key commands can avoid active state by passing `--profile`:

```sh
keyroute key --profile working tmux 1
keyroute key --profile side-projects browser 2
```

Profile-scoped keymaps create a discoverability problem, so Keyroute should
provide cheap inspection commands:

```sh
keyroute profile current
keyroute profile set working
keyroute keymap tmux
keyroute keymap browser
keyroute keymap --profile side-projects tmux
keyroute list --profile working --namespace tmux
```

Example terminal output:

```text
Profile: working
Namespace: tmux

1  tmux.work-api     ~/work/api
2  tmux.work-web     ~/work/web
3  tmux.work-infra   ~/work/infra
4  tmux.work-notes   ~/work/notes
```

## Integration

BetterTouchTool can call shell commands directly:

```sh
/opt/homebrew/bin/keyroute go tmux.default-browser
/opt/homebrew/bin/keyroute go browser.zen.github
/opt/homebrew/bin/keyroute profile default-browser
```

App-specific BTT triggers can bind different keys based on the frontmost app:

```text
When Zen is active:
Cmd+1 -> keyroute go browser.zen.workspace-1
Cmd+2 -> keyroute go browser.zen.workspace-2

When Ghostty is active:
Cmd+1 -> keyroute go tmux.default-browser
Cmd+2 -> keyroute go tmux.reef
```

Leader Key can stay simple:

```text
leader -> t -> 1  keyroute go tmux.default-browser
leader -> t -> 2  keyroute go tmux.reef
leader -> b -> z  keyroute go browser.zen.main
leader -> c -> d  keyroute go codex.default-browser
```

### Ghostty and tmux

Keyroute can also be called from inside the active app's own control system.
For example, when using tmux inside Ghostty, Ghostty can own app-specific
shortcuts, delegate them into tmux prefix shortcuts, and tmux can call Keyroute
to switch sessions deterministically.

```text
Ghostty app-specific shortcut
        |
        v
tmux prefix/key binding
        |
        v
keyroute go tmux.<session>
        |
        v
deterministic tmux session switch
```

Example tmux bindings:

```tmux
bind-key 1 run-shell 'keyroute go tmux.default-browser'
bind-key 2 run-shell 'keyroute go tmux.reef'
bind-key 3 run-shell 'keyroute go tmux.personal'
```

Then the user-facing workflow can be:

```text
When Ghostty/tmux is active:
Ctrl+1 -> default-browser session
Ctrl+2 -> reef session
Ctrl+3 -> personal session
```

The tmux adapter can still handle create-if-missing behavior:

```sh
tmux has-session -t default-browser \
  || tmux new-session -d -s default-browser -c ~/projects/default-browser

tmux switch-client -t default-browser
```

This keeps Ghostty responsible only for delivering deterministic key input,
keeps tmux responsible for terminal session context, and keeps Keyroute
responsible for routing policy.

## State

The base version avoids state where possible. Profile-scoped keymaps are the
main exception because the stateful style needs an active profile.

Active profile state is stored in:

```text
~/.local/state/keyroute/state.json
```

It is updated whenever `keyroute profile <name>` succeeds. The initial state is
empty; a stateful `keyroute key` call with no active profile returns an error
suggesting `--profile <name>` or `keyroute profile set <name>`.

Optional later state:

- last target
- last profile
- last tmux session
- recently focused window id
- target success/failure timestamps

## Error Handling

Keyroute treats routing failures as first-class events.

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success. |
| 1 | General error. |
| 2 | Config error (missing file, invalid YAML, unknown target). |
| 3 | Target not found or could not be resolved. |
| 4 | Adapter error (tmux not running, browser command failed, etc.). |
| 5 | Permission denied (Accessibility, etc.). |
| 6 | Active profile missing for stateful `keyroute key`. |

Behavior:

- Invalid config is reported at load time with the file path and line number if
  available.
- Unknown targets or profiles produce a clear message and a list of valid names.
- Adapter failures include the adapter name, target id, and underlying error.
- `keyroute doctor` checks for common problems: config syntax, required binaries,
  Accessibility permission, and tmux availability.

## Lifecycle and Concurrency

`keyroute go` and `keyroute profile` are meant to be invoked repeatedly by
hotkeys. Adapters should be idempotent: invoking the same target twice in a row
leaves the system in the same focused state.

There is no global lock. Two rapid invocations may race, but adapters must not
leave tmux, browser, or window state corrupted. The final focused target will
reflect the last completed call. If atomic sequences become necessary for
profiles, they can be added later behind a short-lived file lock.

## Security Notes

Because the `command` adapter can run arbitrary binaries, the config file is
effectively executable. Keyroute loads only `~/.config/keyroute/config.yaml` and
refuses to load configs from other paths or from world-writable directories.
Users should treat the config file with the same care as a shell script.

## Future Extensions

- Raycast extension for searching and running targets.
- Menu bar app for debugging, manual switching, and permission status.
- Interactive picker, potentially backed by `fzf`.
- `bind-window` command for binding the current focused window to a target.
- Verification hooks after focus.
- Browser-specific adapters beyond the initial chromium script wrapper.

## Non-Goals

- Replace BetterTouchTool.
- Replace Leader Key.
- Replace tmux.
- Become a full window manager.
- Infer user intent from window order as the primary mechanism.
- Depend primarily on cycling behavior.

## MVP

The first implementation should include:

1. Config loader with aliases.
2. Explicit CLI commands.
3. `command` adapter.
4. `chromium` adapter wrapping `switch-chromium`.
5. `tmux` adapter.
6. `macos-window` adapter using AX raise plus app activation.
7. `profile` command that activates a group and focuses the default.
