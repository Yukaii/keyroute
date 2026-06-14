import Foundation

public struct EmbeddedExample {
    public let name: String
    public let description: String
    public let content: String

    public init(name: String, description: String, content: String) {
        self.name = name
        self.description = description
        self.content = content
    }
}

public enum EmbeddedExamples {
    public static let all: [EmbeddedExample] = [
        tmuxShell,
        switchChromium
    ]

    public static func named(_ name: String) -> EmbeddedExample? {
        all.first { $0.name == name }
    }

    public static var names: [String] {
        all.map(\.name).sorted()
    }

    public static func defaultInstallDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        "\(PlatformPaths.configDirectory(environment: environment))/keyroute/adapters"
    }

    public struct InstallResult {
        public let directory: String
        public let installed: [String]
        public let skipped: [String]
        public let failed: [(name: String, error: String)]

        public init(directory: String, installed: [String], skipped: [String], failed: [(name: String, error: String)]) {
            self.directory = directory
            self.installed = installed
            self.skipped = skipped
            self.failed = failed
        }
    }

    public static func installAll(
        directory: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> InstallResult {
        let targetDirectory = directory ?? defaultInstallDirectory(environment: environment)
        let expanded = expandedPath(targetDirectory)

        if !fileManager.fileExists(atPath: expanded) {
            try fileManager.createDirectory(atPath: expanded, withIntermediateDirectories: true, attributes: nil)
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw KeyrouteError.config("adapters path exists but is not a directory: \(expanded)")
        }

        var installed: [String] = []
        var skipped: [String] = []
        var failed: [(name: String, error: String)] = []

        for example in all {
            let filePath = "\(expanded)/\(example.name)"
            if fileManager.fileExists(atPath: filePath) {
                skipped.append(example.name)
                continue
            }

            do {
                try example.content.write(toFile: filePath, atomically: true, encoding: .utf8)
                var attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let permissions = attributes[.posixPermissions] as? NSNumber {
                    attributes[.posixPermissions] = NSNumber(value: permissions.intValue | 0o111)
                    try fileManager.setAttributes(attributes, ofItemAtPath: filePath)
                }
                installed.append(example.name)
            } catch {
                failed.append((name: example.name, error: String(describing: error)))
            }
        }

        return InstallResult(directory: expanded, installed: installed, skipped: skipped, failed: failed)
    }

    private static let tmuxShell = EmbeddedExample(
        name: "tmux-shell",
        description: "External adapter script that focuses or creates tmux sessions.",
        content: #"""
#!/bin/sh
set -eu

payload=$(cat)
target_id=${KEYROUTE_TARGET:-tmux}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for this adapter" >&2
  exit 4
fi

session=$(printf '%s' "$payload" | jq -r '.target.session // empty')
cwd=$(printf '%s' "$payload" | jq -r '.target.cwd // empty')
create=$(printf '%s' "$payload" | jq -r '.target.create // false')

if [ -z "$session" ]; then
  echo "tmux adapter target '$target_id' requires session" >&2
  exit 4
fi

expand_path() {
  case "$1" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${1#~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

if [ "${KEYROUTE_DRY_RUN:-0}" = "1" ]; then
  if tmux has-session -t "$session" 2>/dev/null; then
    echo "dry-run: would switch tmux client to '$session'"
  elif [ "$create" = "true" ]; then
    echo "dry-run: would create tmux session '$session' and switch to it"
  else
    echo "tmux session '$session' not found" >&2
    exit 3
  fi
  exit 0
fi

if ! tmux has-session -t "$session" 2>/dev/null; then
  if [ "$create" = "true" ]; then
    if [ -n "$cwd" ]; then
      tmux new-session -d -s "$session" -c "$(expand_path "$cwd")"
    else
      tmux new-session -d -s "$session"
    fi
  else
    echo "tmux session '$session' not found" >&2
    exit 3
  fi
fi

if tmux switch-client -t "$session"; then
  echo "tmux session '$session' focused"
else
  echo "tmux session '$session' exists, but no attached client could be switched" >&2
  exit 4
fi
"""#
    )

    private static let switchChromium = EmbeddedExample(
        name: "switch-chromium",
        description: "Switch profile or workspace in any Chromium-based browser via macOS menus.",
        content: #"""
#!/usr/bin/env bash
# switch_chromium — switch profile or workspace in any Chromium-based browser via macOS menu
# Supports: Chrome, Chrome Dev/Canary, Edge, Edge Dev/Canary, Brave, Arc, Vivaldi, Opera, Thorium, Helium
#
# Usage:
#   switch-chromium --browser <app> (--profile <name> | --workspace <name>) [--en|--jp|--zh-tw|--zh-cn]
#
# Alternatively, invoke via convenience symlink:
#   switch-edge.sh  (defaults to --browser edge)
#   switch-chrome.sh (defaults to --browser chrome)
#   switch-brave.sh  (defaults to --browser brave)

set -e

usage() {
  local self
  self=$(basename "$0")
  cat <<USAGE
Usage: $0 --browser <app> (--profile <name> | --workspace <name>) [--en|--jp|--zh-tw|--zh-cn]

  --browser APP     Browser shortcut or full app name:
                      chrome, chrome-dev, chrome-canary,
                      edge, edge-dev, edge-canary,
                      brave, arc, vivaldi, opera, thorium, helium
  --profile NAME    switch to profile matching NAME (fuzzy)
  --workspace NAME  switch to workspace matching NAME (fuzzy)
  --en              use English menus (default)
  --jp              use Japanese menus
  --zh-tw           use Traditional Chinese menus
  --zh-cn           use Simplified Chinese menus

If invoked as switch-<browser>.sh, --browser defaults to that browser.
USAGE
  exit 1
}

# ── Resolve default browser from symlink name ──────────────────────────
resolve_default_browser() {
  local name
  name=$(basename "$0")
  name=${name%.sh}
  # strip "switch-" prefix
  local shortcut=${name#switch-}
  case $shortcut in
    edge)         echo "edge" ;;
    edge-dev)     echo "edge-dev" ;;
    edge-canary)  echo "edge-canary" ;;
    chrome)       echo "chrome" ;;
    chrome-dev)   echo "chrome-dev" ;;
    chrome-canary) echo "chrome-canary" ;;
    brave)        echo "brave" ;;
    arc)          echo "arc" ;;
    vivaldi)      echo "vivaldi" ;;
    opera)        echo "opera" ;;
    thorium)      echo "thorium" ;;
    helium)       echo "helium" ;;
    *)            echo "" ;;
  esac
}

# ── Map shortcut → macOS app name ─────────────────────────────────────
resolve_app_name() {
  local shortcut=$1
  case $shortcut in
    chrome)         echo "Google Chrome" ;;
    chrome-dev)     echo "Google Chrome Dev" ;;
    chrome-canary)  echo "Google Chrome Canary" ;;
    edge)           echo "Microsoft Edge" ;;
    edge-dev)       echo "Microsoft Edge Dev" ;;
    edge-canary)    echo "Microsoft Edge Canary" ;;
    brave)          echo "Brave Browser" ;;
    arc)            echo "Arc" ;;
    vivaldi)        echo "Vivaldi" ;;
    opera)          echo "Opera" ;;
    thorium)        echo "Thorium" ;;
    helium)         echo "Helium" ;;
    *)              echo "$shortcut" ;;
  esac
}

# ── Defaults ───────────────────────────────────────────────────────────
browser=$(resolve_default_browser)
lang="en"; profile=""; workspace=""

# ── Parse arguments ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --browser)    browser="$2"; shift 2;;
    --profile)    [[ -n $workspace ]] && usage; profile="$2"; shift 2;;
    --workspace)  [[ -n $profile ]] && usage; workspace="$2"; shift 2;;
    --en|--jp|--zh-tw|--zh-cn) lang="${1#--}"; shift;;
    -h|--help)    usage;;
    *)            usage;;
  esac
done

[[ -z $browser ]] && { echo "Error: --browser is required (or invoke via switch-<browser>.sh symlink)" >&2; exit 1; }
[[ -z $profile && -z $workspace ]] && usage

app=$(resolve_app_name "$browser")

# ── Localize menu titles ──────────────────────────────────────────────
case $lang in
  jp)    M_PROFILE="プロファイル"; M_WINDOW="ウィンドウ" ;;
  zh-tw) M_PROFILE="個人檔案";     M_WINDOW="視窗" ;;
  zh-cn) M_PROFILE="个人资料";     M_WINDOW="窗口" ;;
  *)     M_PROFILE="Profile";      M_WINDOW="Window" ;;
esac

# ── Pick which menu item to target ─────────────────────────────────────
if [[ -n $profile ]]; then
  MENU_BAR_ITEM="$M_PROFILE"
  TARGET="$profile"
  MENU_BAR_ITEM_CANDIDATES=("Profile" "プロファイル" "個人檔案" "个人资料")
else
  MENU_BAR_ITEM="$M_WINDOW"
  TARGET="$workspace"
  MENU_BAR_ITEM_CANDIDATES=("Window" "ウィンドウ" "視窗" "窗口")
fi

# ── AppleScript: click first menu item whose name fuzzy-matches TARGET ─
MENU_BAR_ITEM_CANDIDATES_APPLE=""
for item in "${MENU_BAR_ITEM_CANDIDATES[@]}"; do
  MENU_BAR_ITEM_CANDIDATES_APPLE+="\"${item}\", "
done
MENU_BAR_ITEM_CANDIDATES_APPLE=${MENU_BAR_ITEM_CANDIDATES_APPLE%, }

osascript <<EOF
tell application "System Events"
  tell process "$app"
    set menuBarItemNames to {$MENU_BAR_ITEM_CANDIDATES_APPLE}
    repeat with menuBarItemName in menuBarItemNames
      try
        set theMenu to menu 1 of menu bar item menuBarItemName of menu bar 1
        click (first menu item of theMenu whose name contains "$TARGET")
        return
      end try
    end repeat
    error "Could not find matching menu bar item"
  end tell
end tell
EOF
"""#
    )
}
