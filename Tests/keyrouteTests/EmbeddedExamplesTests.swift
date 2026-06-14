import XCTest
@testable import KeyrouteCore

final class EmbeddedExamplesTests: XCTestCase {
    func testTmuxShellExampleIsAvailable() throws {
        let example = try XCTUnwrap(EmbeddedExamples.named("tmux-shell"))

        XCTAssertEqual(example.name, "tmux-shell")
        XCTAssertTrue(example.content.hasPrefix("#!/bin/sh"))
        XCTAssertTrue(example.content.contains("tmux switch-client -t"))
        XCTAssertTrue(example.content.contains("KEYROUTE_DRY_RUN"))
    }
}
