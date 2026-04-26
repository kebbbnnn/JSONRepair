import XCTest
@testable import JSONRepair

final class ParseObjectIsolationTests: XCTestCase {
    
    private func repairWithTimeout(_ input: String, timeout: TimeInterval = 2.0, file: StaticString = #file, line: UInt = #line) -> JSONValue? {
        var result: JSONValue?
        var error: Error?
        let expectation = self.expectation(description: "repair \(input.prefix(30))")
        
        DispatchQueue.global().async {
            do {
                result = try JSONRepair.repair(json: input)
            } catch let e {
                error = e
            }
            expectation.fulfill()
        }
        
        let waiterResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if waiterResult == .timedOut {
            XCTFail("TIMEOUT on input: \(input)", file: file, line: line)
            return nil
        }
        if let error = error {
            XCTFail("ERROR on input: \(input) -> \(error)", file: file, line: line)
            return nil
        }
        return result
    }
    
    func testAllEdgeCases() {
        let cases: [(String, Int)] = [
            ("{foo: [}", 1),
            ("{\"\": \"value\"", 2),
            ("{\"key\": \"v\"alue\"}", 3),
            ("{\"value_1\": true, COMMENT \"value_2\": \"data\"}", 4),
            ("{\"value_1\": true, SHOULD_NOT_EXIST \"value_2\": \"data\" AAAA }", 5),
            ("{\"\" : true, \"key2\": \"value2\"}", 6),
            ("{ \"words\": abcdef\", \"numbers\": 12345\", \"words2\": ghijkl\" }", 7),
            ("{\"number\": 1,\"reason\": \"According...\"\"ans\": \"YES\"}", 8),
            ("{ \"a\" : \"{ b\": {} }\" }", 9),
            ("{\"b\": \"xxxxx\" true}", 10),
            ("{\"key\": \"Lorem \"ipsum\" s,\"}", 11),
            ("{\"lorem\": ipsum, sic, datum.\",}", 12),
            ("{\"lorem\": sic tamet. \"ipsum\": sic tamet, quick brown fox. \"sic\": ipsum}", 13),
            ("{\"lorem_ipsum\": \"sic tamet, quick brown fox. }", 14),
            ("{\"key\":value, \" key2\":\"value2\" }", 15),
            ("{\"key\":value \"key2\":\"value2\" }", 16),
            ("{'text': 'words{words in brackets}more words'}", 17),
            ("{text:words{words in brackets}}", 18),
            ("{text:words{words in brackets}m}", 19),
            ("{\"key\": \"value, value2\"```", 20),
            ("{\"key\": \"value}```", 21),
            ("{key:value,key2:value2}", 22),
            ("{\"key:\"value\"}", 23),
            ("{\"key:value}", 24),
            ("[{\"lorem\": {\"ipsum\": \"sic\"}, \"\"\"\" \"lorem\": {\"ipsum\": \"sic\"}]", 25),
            ("{ \"key\": [\"arrayvalue\"], [\"arrayvalue1\"], [\"arrayvalue2\"], \"key3\": \"value3\" }", 26),
            ("{ \"key\": [[1, 2, 3], \"a\", \"b\"], [[4, 5, 6], [7, 8, 9]] }", 27),
            ("{ \"key\": [\"arrayvalue\"], \"key3\": \"value3\", [\"arrayvalue1\"] }", 28),
            ("{\"key\": , \"key2\": \"value2\"}", 29),
            ("{\"array\":[{\"key\": \"value\"], \"key2\": \"value2\"}", 30),
            ("[{\"key\":\"value\"}},{\"key\":\"value\"}]", 31),
            ("{'key': ['a':{'duplicated_key': 'duplicated_value', 'duplicated_key': 'duplicated_value'}]}", 32),
            ("[{\"b\":\"v2\",\"b\":\"v2\"}]", 33),
            ("{'item1', 'item2', 'item3'}", 34),
        ]
        
        for (input, idx) in cases {
            let result = repairWithTimeout(input)
            if let result = result {
                print("[\(idx)] OK: \(input.prefix(40)) -> \(result)")
            }
        }
    }
}
