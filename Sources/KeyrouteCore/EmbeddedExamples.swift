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
        tmuxShell
    ]

    public static func named(_ name: String) -> EmbeddedExample? {
        all.first { $0.name == name }
    }

    public static var names: [String] {
        all.map(\.name).sorted()
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
}
