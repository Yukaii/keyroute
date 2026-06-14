import AppKit
import ApplicationServices
import Foundation

struct MacOSWindowAdapter: Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult {
        guard let bundleID = target.app, !bundleID.isEmpty else {
            return .error("macos-window target '\(targetID)' requires 'app'")
        }
        guard target.hasWindowMatchRule else {
            return .error("macos-window target '\(targetID)' requires title, titleContains, titleRegex, or windowIndex")
        }

        if context.dryRun {
            return .success("dry-run: would raise matching window for app \(bundleID)")
        }

        guard AXIsProcessTrusted() else {
            return .permissionDenied("Accessibility permission is required. Grant Keyroute access in System Settings > Privacy & Security > Accessibility.")
        }

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return .notFound("app '\(bundleID)' is not running")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard copyResult == .success, let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
            return .notFound("no accessible windows found for app '\(bundleID)'")
        }

        guard let window = matchingWindow(in: windows, target: target) else {
            return .notFound("no window matched target '\(targetID)'")
        }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return .success("window target '\(targetID)' focused")
    }

    private func matchingWindow(in windows: [AXUIElement], target: TargetConfig) -> AXUIElement? {
        if let index = target.windowIndex {
            let arrayIndex = index - 1
            guard windows.indices.contains(arrayIndex) else { return nil }
            return windows[arrayIndex]
        }

        return windows.first { window in
            let title = windowTitle(window)
            if let exact = target.title, title == exact {
                return true
            }
            if let contains = target.titleContains, title.localizedCaseInsensitiveContains(contains) {
                return true
            }
            if let pattern = target.titleRegex {
                return title.range(of: pattern, options: .regularExpression) != nil
            }
            return false
        }
    }

    private func windowTitle(_ window: AXUIElement) -> String {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success else {
            return ""
        }
        return titleValue as? String ?? ""
    }
}
