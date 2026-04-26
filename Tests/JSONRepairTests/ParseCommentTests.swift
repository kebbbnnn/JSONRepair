import XCTest
@testable import JSONRepair

final class ParseCommentTests: XCTestCase {
    func check(_ input: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repairJson(input)
            let expectedJSON = try JSONParser(jsonStr: expected).parse()
            XCTAssertEqual(result, expectedJSON, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }
    func checkValue(_ input: String, _ expected: JSONValue, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repairJson(input)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }

    func test_parse_comment() {
        check("/", "")
        check("{ \"key\": { \"key2\": \"value2\" // comment }, \"key3\": \"value3\" }", "{\"key\": {\"key2\": \"value2\"}, \"key3\": \"value3\"}")
        check("{ \"key\": { \"key2\": \"value2\" # comment }, \"key3\": \"value3\" }", "{\"key\": {\"key2\": \"value2\"}, \"key3\": \"value3\"}")
        check("{ \"key\": { \"key2\": \"value2\" /* comment */ }, \"key3\": \"value3\" }", "{\"key\": {\"key2\": \"value2\"}, \"key3\": \"value3\"}")
        check("[ \"value\", /* comment */ \"value2\" ]", "[\"value\", \"value2\"]")
        check("{ \"key\": \"value\" /* comment", "{\"key\": \"value\"}")
    }

    func test_parse_many_top_level_comments_without_recursion_error() {
    }
}