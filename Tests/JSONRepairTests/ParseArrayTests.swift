import XCTest
@testable import JSONRepair

final class ParseArrayTests: XCTestCase {
    func check(_ input: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repair(json: input)
            let expectedJSON = try JSONParser(jsonStr: expected).parse()
            XCTAssertEqual(result, expectedJSON, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }
    func checkValue(_ input: String, _ expected: JSONValue, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repair(json: input)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }

    func test_parse_array() {
        checkValue("[]", JSONValue.array([]))
        checkValue("[1, 2, 3, 4]", JSONValue.array([JSONValue.number(1), JSONValue.number(2), JSONValue.number(3), JSONValue.number(4)]))
        checkValue("[", JSONValue.array([]))
        check("[[1\n\n]", "[[1]]")
    }

    func test_parse_array_edge_cases() {
        check("[{]", "[]")
        check("[", "[]")
        check("[\"", "[]")
        check("]", "")
        check("[1, 2, 3,", "[1, 2, 3]")
        check("[1, 2, 3, ...]", "[1, 2, 3]")
        check("[1, 2, ... , 3]", "[1, 2, 3]")
        check("[1, 2, '...', 3]", "[1, 2, \"...\", 3]")
        check("[true, false, null, ...]", "[true, false, null]")
        check("[\"a\" \"b\" \"c\" 1", "[\"a\", \"b\", \"c\", 1]")
        check("{\"employees\":[\"John\", \"Anna\",", "{\"employees\": [\"John\", \"Anna\"]}")
        check("{\"employees\":[\"John\", \"Anna\", \"Peter", "{\"employees\": [\"John\", \"Anna\", \"Peter\"]}")
        check("{\"key1\": {\"key2\": [1, 2, 3", "{\"key1\": {\"key2\": [1, 2, 3]}}")
        check("{\"key\": [\"value]}", "{\"key\": [\"value\"]}")
        check("[\"lorem \"ipsum\" sic\"]", "[\"lorem \\\"ipsum\\\" sic\"]")
        check("{\"key1\": [\"value1\", \"value2\"}, \"key2\": [\"value3\", \"value4\"]}", "{\"key1\": [\"value1\", \"value2\"], \"key2\": [\"value3\", \"value4\"]}")
        check("{\"headers\": [\"A\", \"B\", \"C\"], \"rows\": [[\"r1a\", \"r1b\", \"r1c\"], [\"r2a\", \"r2b\", \"r2c\"], \"r3a\", \"r3b\", \"r3c\"], [\"r4a\", \"r4b\", \"r4c\"], [\"r5a\", \"r5b\", \"r5c\"]]}", "{\"headers\": [\"A\", \"B\", \"C\"], \"rows\": [[\"r1a\", \"r1b\", \"r1c\"], [\"r2a\", \"r2b\", \"r2c\"], [\"r3a\", \"r3b\", \"r3c\"], [\"r4a\", \"r4b\", \"r4c\"], [\"r5a\", \"r5b\", \"r5c\"]]}")
        check("{\"key\": [\"value\" \"value1\" \"value2\"]}", "{\"key\": [\"value\", \"value1\", \"value2\"]}")
        check("{\"key\": [\"lorem \"ipsum\" dolor \"sit\" amet, \"consectetur\" \", \"lorem \"ipsum\" dolor\", \"lorem\"]}", "{\"key\": [\"lorem \\\"ipsum\\\" dolor \\\"sit\\\" amet, \\\"consectetur\\\" \", \"lorem \\\"ipsum\\\" dolor\", \"lorem\"]}")
        check("{\"k\"e\"y\": \"value\"}", "{\"k\\\"e\\\"y\": \"value\"}")
        check("[\"key\":\"value\"}]", "[{\"key\": \"value\"}]")
        check("[\"key\":\"value\"]", "[{\"key\": \"value\"}]")
        check("[ \"key\":\"value\"]", "[{\"key\": \"value\"}]")
        check("[{\"key\": \"value\", \"key", "[{\"key\": \"value\"}, [\"key\"]]")
        check("{'key1', 'key2'}", "[\"key1\", \"key2\"]")
    }

    func test_parse_array_python_tuple_literals() {
        checkValue("(\"a\", \"b\", \"c\")", JSONValue.array([JSONValue.string("a"), JSONValue.string("b"), JSONValue.string("c")]))
        checkValue("((1, 2), (3, 4))", JSONValue.array([JSONValue.array([JSONValue.number(1), JSONValue.number(2)]), JSONValue.array([JSONValue.number(3), JSONValue.number(4)])]))
        checkValue("{\"coords\": (1, 2), \"ok\": true}", JSONValue.object(["coords": JSONValue.array([JSONValue.number(1), JSONValue.number(2)]), "ok": JSONValue.boolean(true)]))
        checkValue("{\"empty\": ()}", JSONValue.object(["empty": JSONValue.array([])]))
    }

    func test_parse_array_parenthesized_scalar_keeps_scalar_shape() {
        checkValue("(1)", JSONValue.number(1))
        checkValue("(\"x\")", JSONValue.string("x"))
        checkValue("{\"scalar_group\": (1)}", JSONValue.object(["scalar_group": JSONValue.number(1)]))
        checkValue("{\"string_group\": (\"x\")}", JSONValue.object(["string_group": JSONValue.string("x")]))
    }

    func test_parse_array_mismatched_parenthesis_still_logs_missing_bracket() {
    }

    func test_parenthesized_tuple_classifier_handles_nested_delimiters_and_missing_close() {
    }

    func test_top_level_parenthesized_value_gate_rejects_prose_and_accepts_standalone_jsonish_values() {
    }

    func test_parse_array_missing_quotes() {
        check("[\"value1\" value2\", \"value3\"]", "[\"value1\", \"value2\", \"value3\"]")
        check("{\"bad_one\":[\"Lorem Ipsum\", \"consectetur\" comment\" ], \"good_one\":[ \"elit\", \"sed\", \"tempor\"]}", "{\"bad_one\": [\"Lorem Ipsum\", \"consectetur\", \"comment\"], \"good_one\": [\"elit\", \"sed\", \"tempor\"]}")
        check("{\"bad_one\": [\"Lorem Ipsum\",\"consectetur\" comment],\"good_one\": [\"elit\",\"sed\",\"tempor\"]}", "{\"bad_one\": [\"Lorem Ipsum\", \"consectetur\", \"comment\"], \"good_one\": [\"elit\", \"sed\", \"tempor\"]}")
    }
}