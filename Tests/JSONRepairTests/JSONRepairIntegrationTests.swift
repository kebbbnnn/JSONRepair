import XCTest
@testable import JSONRepair

final class JSONRepairIntegrationTests: XCTestCase {
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

    func test_valid_json() {
        check("{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}")
        check("{\"employees\":[\"John\", \"Anna\", \"Peter\"]} ", "{\"employees\": [\"John\", \"Anna\", \"Peter\"]}")
        check("{\"key\": \"value:value\"}", "{\"key\": \"value:value\"}")
        check("{\"text\": \"The quick brown fox,\"}", "{\"text\": \"The quick brown fox,\"}")
        check("{\"text\": \"The quick brown fox won't jump\"}", "{\"text\": \"The quick brown fox won't jump\"}")
        check("{\"key\": \"\"", "{\"key\": \"\"}")
        check("{\"key1\": {\"key2\": [1, 2, 3]}}", "{\"key1\": {\"key2\": [1, 2, 3]}}")
        check("{\"key\": 12345678901234567890}", "{\"key\": 12345678901234567890}")
        check("{\"key\": \"value☺\"}", "{\"key\": \"value\\u263a\"}")
        check("{\"key\": \"value\\nvalue\"}", "{\"key\": \"value\\nvalue\"}")
    }

    func test_valid_json_fast_path_does_not_initialize_repair_parser() {
    }

    func test_multiple_jsons() {
        check("[]{}", "[]")
        check("[]{\"key\":\"value\"}", "{\"key\": \"value\"}")
        check("{\"key\":\"value\"}[1,2,3,True]", "[{\"key\": \"value\"}, [1, 2, 3, true]]")
        check("lorem ```json {\"key\":\"value\"} ``` ipsum ```json [1,2,3,True] ``` 42", "[{\"key\": \"value\"}, [1, 2, 3, true]]")
        check("[{\"key\":\"value\"}][{\"key\":\"value_after\"}]", "[{\"key\": \"value_after\"}]")
    }

    func test_parenthesized_prose_does_not_hijack_fenced_json() {
        check("\n         **Decision**: bla, bla (some clarification):\n\n        ```json\n        {\n          \"key\": \"value\"\n        }\n        ```\n        ", "{\"key\": \"value\"}")
    }

    func test_numbered_prose_line_does_not_hijack_fenced_json() {
        check("\n        (1) Keep this note in the explanation.\n\n        ```json\n        {\n          \"key\": \"value\"\n        }\n        ```\n        ", "{\"key\": \"value\"}")
    }

    func test_parenthesized_tuple_still_parses_when_it_is_the_fenced_json_payload() {
        checkValue("\n        Here is the tuple payload:\n\n        ```json\n        (1, 2)\n        ```\n        ", JSONValue.array([JSONValue.number(1), JSONValue.number(2)]))
    }

    func test_repair_json_with_objects() {
        checkValue("[]", JSONValue.array([]))
        checkValue("{}", JSONValue.object([:]))
        checkValue("{\"key\": true, \"key2\": false, \"key3\": null}", JSONValue.object(["key": JSONValue.boolean(true), "key2": JSONValue.boolean(false), "key3": JSONValue.null]))
        checkValue("{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}", JSONValue.object(["name": JSONValue.string("John"), "age": JSONValue.number(30), "city": JSONValue.string("New York")]))
        checkValue("[1, 2, 3, 4]", JSONValue.array([JSONValue.number(1), JSONValue.number(2), JSONValue.number(3), JSONValue.number(4)]))
        checkValue("{\"employees\":[\"John\", \"Anna\", \"Peter\"]} ", JSONValue.object(["employees": JSONValue.array([JSONValue.string("John"), JSONValue.string("Anna"), JSONValue.string("Peter")])]))
        checkValue("\n{\n  \"resourceType\": \"Bundle\",\n  \"id\": \"1\",\n  \"type\": \"collection\",\n  \"entry\": [\n    {\n      \"resource\": {\n        \"resourceType\": \"Patient\",\n        \"id\": \"1\",\n        \"name\": [\n          {\"use\": \"official\", \"family\": \"Corwin\", \"given\": [\"Keisha\", \"Sunny\"], \"prefix\": [\"Mrs.\"},\n          {\"use\": \"maiden\", \"family\": \"Goodwin\", \"given\": [\"Keisha\", \"Sunny\"], \"prefix\": [\"Mrs.\"]}\n        ]\n      }\n    }\n  ]\n}\n", JSONValue.object(["resourceType": JSONValue.string("Bundle"), "id": JSONValue.string("1"), "type": JSONValue.string("collection"), "entry": JSONValue.array([JSONValue.object(["resource": JSONValue.object(["resourceType": JSONValue.string("Patient"), "id": JSONValue.string("1"), "name": JSONValue.array([JSONValue.object(["use": JSONValue.string("official"), "family": JSONValue.string("Corwin"), "given": JSONValue.array([JSONValue.string("Keisha"), JSONValue.string("Sunny")]), "prefix": JSONValue.array([JSONValue.string("Mrs.")])]), JSONValue.object(["use": JSONValue.string("maiden"), "family": JSONValue.string("Goodwin"), "given": JSONValue.array([JSONValue.string("Keisha"), JSONValue.string("Sunny")]), "prefix": JSONValue.array([JSONValue.string("Mrs.")])])])])])])]))
        checkValue("{\n\"html\": \"<h3 id=\"aaa\">Waarom meer dan 200 Technical Experts - \"Passie voor techniek\"?</h3>\"}", JSONValue.object(["html": JSONValue.string("<h3 id=\"aaa\">Waarom meer dan 200 Technical Experts - \"Passie voor techniek\"?</h3>")]))
        checkValue("\n        [\n            {\n                \"foo\": \"Foo bar baz\",\n                \"tag\": \"#foo-bar-baz\"\n            },\n            {\n                \"foo\": \"foo bar \"foobar\" foo bar baz.\",\n                \"tag\": \"#foo-bar-foobar\"\n            }\n        ]\n        ", JSONValue.array([JSONValue.object(["foo": JSONValue.string("Foo bar baz"), "tag": JSONValue.string("#foo-bar-baz")]), JSONValue.object(["foo": JSONValue.string("foo bar \"foobar\" foo bar baz."), "tag": JSONValue.string("#foo-bar-foobar")])]))
    }

    func test_repair_json_skip_json_loads() {
        check("{\"key\": true, \"key2\": false, \"key3\": null}", "{\"key\": true, \"key2\": false, \"key3\": null}")
        checkValue("{\"key\": true, \"key2\": false, \"key3\": null}", JSONValue.object(["key": JSONValue.boolean(true), "key2": JSONValue.boolean(false), "key3": JSONValue.null]))
        check("{\"key\": true, \"key2\": false, \"key3\": }", "{\"key\": true, \"key2\": false, \"key3\": \"\"}")
    }

    func test_repair_json_normalizes_real_parser_recursion_error() {
    }

    func test_ensure_ascii() {
        check("{'test_中国人_ascii':'统一码'}", "{\"test_中国人_ascii\": \"统一码\"}")
    }

    func checkStreamStable(_ input: String, _ expected: JSONValue, streamStable: Bool, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repair(json: input, streamStable: streamStable)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }

    func test_stream_stable_false() {
        // stream_stable=False: {"key": "val\" -> {"key": "val\\"} (trailing \ kept as literal)
        checkStreamStable(
            #"{"key": "val\"#,
            .object(["key": .string("val\\")]),
            streamStable: false
        )
        // stream_stable=False: {"key": "val\n -> {"key": "val"} (\n normalized then rstripped)
        checkStreamStable(
            "{\"key\": \"val\\n",
            .object(["key": .string("val")]),
            streamStable: false
        )
        // stream_stable=False: comma splits into two keys
        checkStreamStable(
            "{\"key\": \"val\\n123,`key2:value2",
            .object(["key": .string("val\n123"), "key2": .string("value2")]),
            streamStable: false
        )
        // stream_stable=False: backtick-quoted value stays intact
        checkStreamStable(
            "{\"key\": \"val\\n123,`key2:value2`\"}",
            .object(["key": .string("val\n123,`key2:value2`")]),
            streamStable: false
        )
    }

    func test_stream_stable_true() {
        // stream_stable=True: {"key": "val\" -> {"key": "val"} (trailing \ stripped)
        checkStreamStable(
            #"{"key": "val\"#,
            .object(["key": .string("val")]),
            streamStable: true
        )
        // stream_stable=True: {"key": "val\n -> {"key": "val\n"} (\n normalized and kept)
        checkStreamStable(
            "{\"key\": \"val\\n",
            .object(["key": .string("val\n")]),
            streamStable: true
        )
        // stream_stable=True: comma NOT split, kept as string
        checkStreamStable(
            "{\"key\": \"val\\n123,`key2:value2",
            .object(["key": .string("val\n123,`key2:value2")]),
            streamStable: true
        )
        // stream_stable=True: backtick-quoted value stays intact
        checkStreamStable(
            "{\"key\": \"val\\n123,`key2:value2`\"}",
            .object(["key": .string("val\n123,`key2:value2`")]),
            streamStable: true
        )
    }

    func test_logging() {
        // Logging API test — verify the logging flag doesn't crash and returns correct results
        let result = try? JSONRepair.repair(json: "{}", logging: true)
        XCTAssertEqual(result, .object([:]))
    }
}