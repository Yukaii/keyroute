#if os(macOS)
import ApplicationServices
import AppKit
#endif
import Foundation

@discardableResult
func activateApp(bundleID: String) -> Bool {
    #if os(macOS)
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
        return false
    }
    return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    #else
    return false
    #endif
}

func expandedPath(_ path: String) -> String {
    NSString(string: path).expandingTildeInPath
}

func accessibilityStatus() -> String {
    #if os(macOS)
    return AXIsProcessTrusted() ? "granted" : "not granted"
    #else
    return "unsupported"
    #endif
}
