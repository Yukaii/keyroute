import Foundation
import KeyrouteCore
import KeyrouteTmux

#if os(macOS)
import KeyrouteMacOS
#endif

struct AdapterRegistry {
    func adapter(named name: String) -> Adapter? {
        switch name {
        case "command":
            CommandAdapter()
        case "chromium":
            ChromiumAdapter()
        case "tmux":
            TmuxAdapter()
        case "macos-window":
            #if os(macOS)
            MacOSWindowAdapter()
            #else
            UnsupportedAdapter(message: "macos-window is only supported on macOS")
            #endif
        case "external":
            ExternalAdapter()
        default:
            nil
        }
    }
}

private struct UnsupportedAdapter: Adapter {
    let message: String

    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        .error("\(message): target '\(targetID)'", exitCode: .config)
    }
}
