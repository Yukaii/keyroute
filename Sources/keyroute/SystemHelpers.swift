import AppKit
import Foundation

@discardableResult
func activateApp(bundleID: String) -> Bool {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
        return false
    }
    return app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
}

func expandedPath(_ path: String) -> String {
    NSString(string: path).expandingTildeInPath
}
