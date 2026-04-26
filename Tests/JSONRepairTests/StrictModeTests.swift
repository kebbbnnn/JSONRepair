import XCTest
@testable import JSONRepair

final class StrictModeTests: XCTestCase {

    func test_strict_rejects_multiple_top_level_values() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\"key\":\"value\"}[\"value\"]", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Multiple top-level JSON elements"))
        }
    }

    func test_strict_duplicate_keys_inside_array() {
        let payload = "[{\"key\": \"first\", \"key\": \"second\"}]"
        XCTAssertThrowsError(try JSONRepair.repair(json: payload, strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Duplicate key found"))
        }
    }

    func test_strict_rejects_empty_keys() {
        let payload = "{\"\" : \"value\"}"
        XCTAssertThrowsError(try JSONRepair.repair(json: payload, strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Empty key found"))
        }
    }

    func test_strict_requires_colon_between_key_and_value() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\"missing\" \"colon\"}", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Missing ':'"))
        }
    }

    func test_strict_rejects_empty_values() {
        let payload = "{\"key\": , \"key2\": \"value2\"}"
        XCTAssertThrowsError(try JSONRepair.repair(json: payload, strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Parsed value is empty"))
        }
    }

    func test_strict_rejects_empty_object_with_extra_characters() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\"dangling\"}", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Parsed object is empty"))
        }
    }

    func test_strict_rejects_empty_escaped_object_with_extra_characters() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\\\"key\\\": \\\"value\\\"}", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("Parsed object is empty"))
        }
    }

    func test_strict_detects_immediate_doubled_quotes() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\"key\": \"\"\"\"}", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("doubled quotes"))
        }
    }

    func test_strict_detects_doubled_quotes_followed_by_string() {
        XCTAssertThrowsError(try JSONRepair.repair(json: "{\"key\": \"\" \"value\"}", strict: true)) { error in
            XCTAssertTrue("\(error)".contains("doubled quotes"))
        }
    }
}
