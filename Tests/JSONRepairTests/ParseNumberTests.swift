import XCTest
@testable import JSONRepair

final class ParseNumberTests: XCTestCase {
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

    func test_parse_number() {
        checkValue("1", JSONValue.number(1))
        checkValue("1.2", JSONValue.number(1.2))
        checkValue("{\"value\": 82_461_110}", JSONValue.object(["value": JSONValue.number(82461110)]))
        checkValue("{\"value\": 1_234.5_6}", JSONValue.object(["value": JSONValue.number(1234.56)]))
    }

    func test_parse_number_edge_cases() {
        check(" - { \"test_key\": [\"test_value\", \"test_value2\"] }", "{\"test_key\": [\"test_value\", \"test_value2\"]}")
        check("{\"key\": 1/3}", "{\"key\": \"1/3\"}")
        check("{\"key\": .25}", "{\"key\": 0.25}")
        check("{\"here\": \"now\", \"key\": 1/3, \"foo\": \"bar\"}", "{\"here\": \"now\", \"key\": \"1/3\", \"foo\": \"bar\"}")
        check("{\"key\": 12345/67890}", "{\"key\": \"12345/67890\"}")
        check("[105,12", "[105, 12]")
        check("{\"key\", 105,12,", "{\"key\": \"105,12\"}")
        check("{\"key\": 1/3, \"foo\": \"bar\"}", "{\"key\": \"1/3\", \"foo\": \"bar\"}")
        check("{\"key\": 10-20}", "{\"key\": \"10-20\"}")
        check("{\"key\": 1.1.1}", "{\"key\": \"1.1.1\"}")
        check("[- ", "[]")
        check("{\"key\": 1. }", "{\"key\": 1.0}")
        check("{\"key\": 1e10 }", "{\"key\": 10000000000.0}")
        check("{\"key\": 1e }", "{\"key\": 1}")
        check("{\"key\": 1notanumber }", "{\"key\": \"1notanumber\"}")
        check("{\"rowId\": 57eeeeb1-450b-482c-81b9-4be77e95dee2}", "{\"rowId\": \"57eeeeb1-450b-482c-81b9-4be77e95dee2\"}")
        check("[1, 2notanumber]", "[1, \"2notanumber\"]")
    }
}