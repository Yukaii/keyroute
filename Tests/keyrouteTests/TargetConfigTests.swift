import XCTest
@testable import keyroute

final class TargetConfigTests: XCTestCase {
    func testDecodesKnownAndCustomFields() throws {
        let json = """
        {
          "adapter": "external",
          "run": "/tmp/focus",
          "args": ["--mode", "focus"],
          "env": { "MODE": "test" },
          "customField": "custom-value",
          "nested": {
            "enabled": true,
            "count": 2
          }
        }
        """

        let target = try JSONDecoder().decode(TargetConfig.self, from: Data(json.utf8))

        XCTAssertEqual(target.adapter, "external")
        XCTAssertEqual(target.run, "/tmp/focus")
        XCTAssertEqual(target.args, ["--mode", "focus"])
        XCTAssertEqual(target.env, ["MODE": "test"])
        XCTAssertEqual(target.fields["customField"]?.stringValue, "custom-value")

        guard case let .object(nested)? = target.fields["nested"] else {
            return XCTFail("expected nested object")
        }
        XCTAssertEqual(nested["enabled"]?.boolValue, true)
        XCTAssertEqual(nested["count"]?.intValue, 2)
    }
}
