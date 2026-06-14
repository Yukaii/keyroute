#if os(macOS)
import ApplicationServices

public func macOSAccessibilityStatus() -> String {
    AXIsProcessTrusted() ? "granted" : "not granted"
}
#endif
