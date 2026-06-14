import XCTest
@testable import KeyrouteCore

final class PlatformPathsTests: XCTestCase {
    func testDefaultConfigPathUsesHomeConfigDirectory() {
        let path = ConfigLoader.defaultPath(environment: ["HOME": "/tmp/keyroute-home"])

        XCTAssertEqual(path, "/tmp/keyroute-home/.config/keyroute/config.yaml")
    }

    func testConfigPathUsesAbsoluteXDGConfigHome() {
        let path = ConfigLoader.defaultPath(environment: [
            "HOME": "/tmp/keyroute-home",
            "XDG_CONFIG_HOME": "/tmp/keyroute-config"
        ])

        XCTAssertEqual(path, "/tmp/keyroute-config/keyroute/config.yaml")
    }

    func testConfigPathIgnoresRelativeXDGConfigHome() {
        let path = ConfigLoader.defaultPath(environment: [
            "HOME": "/tmp/keyroute-home",
            "XDG_CONFIG_HOME": "relative-config"
        ])

        XCTAssertEqual(path, "/tmp/keyroute-home/.config/keyroute/config.yaml")
    }

    func testStatePathUsesAbsoluteXDGStateHome() {
        let path = StateStore.path(environment: [
            "HOME": "/tmp/keyroute-home",
            "XDG_STATE_HOME": "/tmp/keyroute-state"
        ])

        XCTAssertEqual(path, "/tmp/keyroute-state/keyroute/state.json")
    }
}
