import Foundation

public enum ExitCode: Equatable {
    case success
    case general
    case config
    case notFound
    case adapterError
    case permissionDenied
    case activeProfileMissing
    case raw(Int)

    public var value: Int32 {
        switch self {
        case .success: 0
        case .general: 1
        case .config: 2
        case .notFound: 3
        case .adapterError: 4
        case .permissionDenied: 5
        case .activeProfileMissing: 6
        case let .raw(value): Int32(value)
        }
    }
}

public enum KeyrouteError: Error, CustomStringConvertible {
    case general(String)
    case config(String)
    case notFound(String)
    case adapter(String)
    case permissionDenied(String)
    case activeProfileMissing(String)

    public var description: String {
        switch self {
        case let .general(message),
             let .config(message),
             let .notFound(message),
             let .adapter(message),
             let .permissionDenied(message),
             let .activeProfileMissing(message):
            message
        }
    }

    public var exitCode: ExitCode {
        switch self {
        case .general: .general
        case .config: .config
        case .notFound: .notFound
        case .adapter: .adapterError
        case .permissionDenied: .permissionDenied
        case .activeProfileMissing: .activeProfileMissing
        }
    }
}

public func fail(_ message: String, code: ExitCode) -> Never {
    fputs("keyroute: \(message)\n", stderr)
    Foundation.exit(code.value)
}

public func fail(_ error: Error) -> Never {
    if let keyrouteError = error as? KeyrouteError {
        fail(keyrouteError.description, code: keyrouteError.exitCode)
    }
    fail(String(describing: error), code: .general)
}
