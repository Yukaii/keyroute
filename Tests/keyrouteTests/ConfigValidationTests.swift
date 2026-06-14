import XCTest
@testable import KeyrouteCore

final class ConfigValidationTests: XCTestCase {
    func makeConfig(targets: [String: TargetConfig]) -> LoadedConfig {
        LoadedConfig(path: "/tmp/config.yaml", config: KeyrouteConfig(targets: targets))
    }

    func testChromiumRequiresBrowser() {
        let config = makeConfig(targets: [
            "browser.work": TargetConfig(fields: ["adapter": .string("chromium"), "workspace": .string("work")])
        ])

        XCTAssertThrowsError(try config.validate()) { error in
            guard case let .config(message) = error as? KeyrouteError else {
                return XCTFail("expected config error")
            }
            XCTAssertTrue(message.contains("requires 'browser'"))
        }
    }

    func testChromiumRequiresWorkspaceOrProfile() {
        let config = makeConfig(targets: [
            "browser.work": TargetConfig(fields: ["adapter": .string("chromium"), "browser": .string("chrome")])
        ])

        XCTAssertThrowsError(try config.validate()) { error in
            guard case let .config(message) = error as? KeyrouteError else {
                return XCTFail("expected config error")
            }
            XCTAssertTrue(message.contains("requires either 'workspace' or 'profile'"))
        }
    }

    func testChromiumRejectsWorkspaceAndProfile() {
        let config = makeConfig(targets: [
            "browser.work": TargetConfig(fields: [
                "adapter": .string("chromium"),
                "browser": .string("chrome"),
                "workspace": .string("work"),
                "profile": .string("personal")
            ])
        ])

        XCTAssertThrowsError(try config.validate()) { error in
            guard case let .config(message) = error as? KeyrouteError else {
                return XCTFail("expected config error")
            }
            XCTAssertTrue(message.contains("cannot specify both 'workspace' and 'profile'"))
        }
    }

    func testChromiumAcceptsWorkspace() throws {
        let config = makeConfig(targets: [
            "browser.work": TargetConfig(fields: [
                "adapter": .string("chromium"),
                "browser": .string("chrome"),
                "workspace": .string("work")
            ])
        ])

        XCTAssertNoThrow(try config.validate())
    }

    func testChromiumAcceptsProfile() throws {
        let config = makeConfig(targets: [
            "browser.personal": TargetConfig(fields: [
                "adapter": .string("chromium"),
                "browser": .string("brave"),
                "profile": .string("personal")
            ])
        ])

        XCTAssertNoThrow(try config.validate())
    }

    func testChromiumRejectsUnsupportedLang() {
        let config = makeConfig(targets: [
            "browser.work": TargetConfig(fields: [
                "adapter": .string("chromium"),
                "browser": .string("chrome"),
                "workspace": .string("work"),
                "lang": .string("fr")
            ])
        ])

        XCTAssertThrowsError(try config.validate()) { error in
            guard case let .config(message) = error as? KeyrouteError else {
                return XCTFail("expected config error")
            }
            XCTAssertTrue(message.contains("unsupported 'lang'"))
        }
    }
}
