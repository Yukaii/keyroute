import Foundation

public enum AdapterStatus: String, Codable {
    case success
    case notFound = "not-found"
    case permissionDenied = "permission-denied"
    case error
}

public struct AdapterResult {
    public let status: AdapterStatus
    public let message: String
    public let exitCode: ExitCode

    public init(status: AdapterStatus, message: String, exitCode: ExitCode) {
        self.status = status
        self.message = message
        self.exitCode = exitCode
    }

    public static func success(_ message: String) -> AdapterResult {
        AdapterResult(status: .success, message: message, exitCode: .success)
    }

    public static func notFound(_ message: String) -> AdapterResult {
        AdapterResult(status: .notFound, message: message, exitCode: .notFound)
    }

    public static func permissionDenied(_ message: String) -> AdapterResult {
        AdapterResult(status: .permissionDenied, message: message, exitCode: .permissionDenied)
    }

    public static func error(_ message: String, exitCode: ExitCode = .adapterError) -> AdapterResult {
        AdapterResult(status: .error, message: message, exitCode: exitCode)
    }
}

public struct RuntimeContext {
    public let dryRun: Bool
    public let verbose: Bool
    public let quiet: Bool
    public let environment: [String: String]

    public init(dryRun: Bool, verbose: Bool, quiet: Bool, environment: [String: String]) {
        self.dryRun = dryRun
        self.verbose = verbose
        self.quiet = quiet
        self.environment = environment
    }
}

public protocol Adapter {
    func activate(targetID: String, target: TargetConfig, context: RuntimeContext) -> AdapterResult
}
