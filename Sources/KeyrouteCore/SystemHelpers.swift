import Foundation

public func expandedPath(_ path: String) -> String {
    NSString(string: path).expandingTildeInPath
}

public func currentPlatformName() -> String {
    #if os(macOS)
    return "macos"
    #elseif os(Linux)
    return "linux"
    #elseif os(Windows)
    return "windows"
    #else
    return "unknown"
    #endif
}
