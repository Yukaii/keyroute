import Foundation

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
            MacOSWindowAdapter()
        case "external":
            ExternalAdapter()
        default:
            nil
        }
    }
}
