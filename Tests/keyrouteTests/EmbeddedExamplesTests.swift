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

    func testSwitchChromiumExampleIsAvailable() throws {
        let example = try XCTUnwrap(EmbeddedExamples.named("switch-chromium"))

        XCTAssertEqual(example.name, "switch-chromium")
        XCTAssertTrue(example.content.hasPrefix("#!/usr/bin/env bash"))
        XCTAssertTrue(example.content.contains("--browser"))
        XCTAssertTrue(example.content.contains("--profile"))
        XCTAssertTrue(example.content.contains("--workspace"))
        XCTAssertTrue(example.content.contains("--zh-tw"))
        XCTAssertTrue(example.content.contains("osascript"))
    }

    func testInstallAllWritesExamplesAndSkipsExisting() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        defer { try? FileManager.default.removeItem(atPath: tempDirectory) }

        let first = try EmbeddedExamples.installAll(directory: tempDirectory)
        XCTAssertEqual(first.directory, tempDirectory)
        XCTAssertEqual(Set(first.installed), Set(["tmux-shell", "switch-chromium"]))
        XCTAssertTrue(first.skipped.isEmpty)
        XCTAssertTrue(first.failed.isEmpty)

        for name in EmbeddedExamples.names {
            let path = "\(tempDirectory)/\(name)"
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        }

        let second = try EmbeddedExamples.installAll(directory: tempDirectory)
        XCTAssertTrue(second.installed.isEmpty)
        XCTAssertEqual(Set(second.skipped), Set(["tmux-shell", "switch-chromium"]))
        XCTAssertTrue(second.failed.isEmpty)
    }
}
