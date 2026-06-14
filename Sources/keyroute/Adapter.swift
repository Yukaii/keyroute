import Foundation

enum AdapterStatus: String {
    case success
    case notFound = "not-found"
    case permissionDenied = "permission-denied"
    case error
}

struct AdapterResult {
    let status: AdapterStatus
    let message: String
    let exitCode: ExitCode

    static func success(_ message: String) -> AdapterResult {
        AdapterResult(status: .success, message: message, exitCode: .success)
    }

    static func notFound(_ message: String) -> AdapterResult {
        AdapterResult(status: .notFound, message: message, exitCode: .notFound)
    }

    static func permissionDenied(_ message: String) -> AdapterResult {
        AdapterResult(status: .permissionDenied, message: message, exitCode: .permissionDenied)
    }

    static func error(_ message: String, exitCode: ExitCode = .adapterError) -> AdapterResult {
        AdapterResult(status: .error, message: message, exitCode: exitCode)
    }
}

struct RuntimeContext {
    let dryRun: Bool
    let verbose: Bool
    let quiet: Bool
    let environment: [String: String]
}

protocol Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult
}
