import XCTest
@testable import KeyrouteCore

final class ExternalAdapterTests: XCTestCase {
    func testStructuredOutputCanSetStatusAndMessage() {
        let result = CommandRunResult(
            status: 0,
            stdout: Data(#"{"status":"not-found","message":"missing workspace"}"#.utf8),
            stderr: Data()
        )

        let adapterResult = ExternalAdapter().externalResult(
            targetID: "desktop.missing",
            command: "/tmp/adapter",
            result: result
        )

        XCTAssertEqual(adapterResult.status, .notFound)
        XCTAssertEqual(adapterResult.message, "missing workspace")
        XCTAssertEqual(adapterResult.exitCode, .notFound)
    }

    func testPlainOutputStillWorks() {
        let result = CommandRunResult(
            status: 0,
            stdout: Data("focused workspace".utf8),
            stderr: Data()
        )

        let adapterResult = ExternalAdapter().externalResult(
            targetID: "desktop.workspace",
            command: "/tmp/adapter",
            result: result
        )

        XCTAssertEqual(adapterResult.status, .success)
        XCTAssertEqual(adapterResult.message, "focused workspace")
        XCTAssertEqual(adapterResult.exitCode, .success)
    }
}
