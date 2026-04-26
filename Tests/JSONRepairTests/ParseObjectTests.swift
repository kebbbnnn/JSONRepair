import XCTest
@testable import JSONRepair

final class ParseObjectTests: XCTestCase {

    func testParseObject() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{}"), JSONRepair.convertToJSONValue([String: Any]()))
        XCTAssertEqual(try JSONRepair.repair(json: "{ \"key\": \"value\", \"key2\": 1, \"key3\": true }"), JSONRepair.convertToJSONValue([
            "key": "value",
            "key2": 1,
            "key3": true
        ]))
        XCTAssertEqual(try JSONRepair.repair(json: "{"), JSONRepair.convertToJSONValue([String: Any]()))
        XCTAssertEqual(try JSONRepair.repair(json: "{ \"key\": value, \"key2\": 1 \"key3\": null }"), JSONRepair.convertToJSONValue([
            "key": "value",
            "key2": 1,
            "key3": NSNull()
        ]))
        XCTAssertEqual(try JSONRepair.repair(json: "   {  }   "), JSONRepair.convertToJSONValue([String: Any]()))
        XCTAssertEqual(try JSONRepair.repair(json: "}"), JSONRepair.convertToJSONValue(""))
        XCTAssertEqual(try JSONRepair.repair(json: "{\""), JSONRepair.convertToJSONValue([String: Any]()))
    }
    
    // Each edge case is its own test so we can identify hangs individually
    func testEdge_fooArray() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{foo: [}"), JSONRepair.convertToJSONValue(["foo": [Any]()]))
    }
    
    func testEdge_emptyKeyValue() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{\"\": \"value\""), JSONRepair.convertToJSONValue(["": "value"]))
    }
    
    func testEdge_misplacedQuoteInValue() throws {
        // Input: {"key": "v"alue"}  -> Python: {"key": "v\"alue\""}
        let result = try JSONRepair.repair(json: "{\"key\": \"v\"alue\"}")
        print("testEdge_misplacedQuoteInValue result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["key": "v\"alue\""]))
    }
    
    func testEdge_commentBetweenPairs() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{\"value_1\": true, COMMENT \"value_2\": \"data\"}"), JSONRepair.convertToJSONValue(["value_1": true, "value_2": "data"]))
    }
    
    func testEdge_junkBetweenPairs() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{\"value_1\": true, SHOULD_NOT_EXIST \"value_2\": \"data\" AAAA }"), JSONRepair.convertToJSONValue(["value_1": true, "value_2": "data"]))
    }
    
    func testEdge_emptyKeyWithSpaceColon() throws {
        // Python: {"" : true, "key2": "value2"} -> {"": true, "key2": "value2"}
        XCTAssertEqual(try JSONRepair.repair(json: "{\"\" : true, \"key2\": \"value2\"}"), JSONRepair.convertToJSONValue(["": true, "key2": "value2"]))
    }
    
    func testEdge_unquotedValueWithTrailingQuote() throws {
        // { "words": abcdef", "numbers": 12345", "words2": ghijkl" }
        let result = try JSONRepair.repair(json: "{ \"words\": abcdef\", \"numbers\": 12345\", \"words2\": ghijkl\" }")
        print("testEdge_unquotedValueWithTrailingQuote result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["words": "abcdef", "numbers": 12345, "words2": "ghijkl"]))
    }
    
    func testEdge_missingCommaDoubledQuote() throws {
        // {"number": 1,"reason": "According...""ans": "YES"}
        let result = try JSONRepair.repair(json: "{\"number\": 1,\"reason\": \"According...\"\"ans\": \"YES\"}")
        print("testEdge_missingCommaDoubledQuote result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["number": 1, "reason": "According...", "ans": "YES"]))
    }
    
    func testEdge_nestedObjectInStringValue() throws {
        // { "a" : "{ b": {} }" }
        let result = try JSONRepair.repair(json: "{ \"a\" : \"{ b\": {} }\" }")
        print("testEdge_nestedObjectInStringValue result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["a": "{ b"]))
    }
    
    func testEdge_trailingBoolAfterString() throws {
        // {"b": "xxxxx" true}
        let result = try JSONRepair.repair(json: "{\"b\": \"xxxxx\" true}")
        print("testEdge_trailingBoolAfterString result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["b": "xxxxx"]))
    }
    
    func testEdge_loremWithQuotesInValue() throws {
        // {"key": "Lorem "ipsum" s,"}
        let result = try JSONRepair.repair(json: "{\"key\": \"Lorem \"ipsum\" s,\"}")
        print("testEdge_loremWithQuotesInValue result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["key": "Lorem \"ipsum\" s,"]))
    }
    
    func testEdge_unquotedValueWithComma() throws {
        // {"lorem": ipsum, sic, datum.",}
        let result = try JSONRepair.repair(json: "{\"lorem\": ipsum, sic, datum.\",}")
        print("testEdge_unquotedValueWithComma result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["lorem": "ipsum, sic, datum."]))
    }
    
    func testEdge_unquotedValuesMultipleKeys() throws {
        // {"lorem": sic tamet. "ipsum": sic tamet, quick brown fox. "sic": ipsum}
        let result = try JSONRepair.repair(json: "{\"lorem\": sic tamet. \"ipsum\": sic tamet, quick brown fox. \"sic\": ipsum}")
        print("testEdge_unquotedValuesMultipleKeys result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["lorem": "sic tamet.", "ipsum": "sic tamet", "sic": "ipsum"]))
    }
    
    func testEdge_missingClosingQuote() throws {
        // {"lorem_ipsum": "sic tamet, quick brown fox. }
        let result = try JSONRepair.repair(json: "{\"lorem_ipsum\": \"sic tamet, quick brown fox. }")
        print("testEdge_missingClosingQuote result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["lorem_ipsum": "sic tamet, quick brown fox."]))
    }
    
    func testEdge_unquotedValueCommaSpacedKey() throws {
        // {"key":value, " key2":"value2" }
        XCTAssertEqual(try JSONRepair.repair(json: "{\"key\":value, \" key2\":\"value2\" }"), JSONRepair.convertToJSONValue(["key": "value", " key2": "value2"]))
    }
    
    func testEdge_unquotedValueMissingSep() throws {
        // {"key":value "key2":"value2" }
        XCTAssertEqual(try JSONRepair.repair(json: "{\"key\":value \"key2\":\"value2\" }"), JSONRepair.convertToJSONValue(["key": "value", "key2": "value2"]))
    }
    
    func testEdge_singleQuoteBracesInValue() throws {
        // {'text': 'words{words in brackets}more words'}
        XCTAssertEqual(try JSONRepair.repair(json: "{'text': 'words{words in brackets}more words'}"), JSONRepair.convertToJSONValue(["text": "words{words in brackets}more words"]))
    }
    
    func testEdge_unquotedBracesInValue() throws {
        // {text:words{words in brackets}}
        let result = try JSONRepair.repair(json: "{text:words{words in brackets}}")
        print("testEdge_unquotedBracesInValue result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["text": "words{words in brackets}"]))
    }
    
    func testEdge_unquotedBracesInValueSuffix() throws {
        // {text:words{words in brackets}m}
        let result = try JSONRepair.repair(json: "{text:words{words in brackets}m}")
        print("testEdge_unquotedBracesInValueSuffix result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["text": "words{words in brackets}m"]))
    }
    
    func testEdge_trailingCodeFence() throws {
        // {"key": "value, value2"```
        XCTAssertEqual(try JSONRepair.repair(json: "{\"key\": \"value, value2\"```"), JSONRepair.convertToJSONValue(["key": "value, value2"]))
    }
    
    func testEdge_trailingCodeFence2() throws {
        // {"key": "value}```
        XCTAssertEqual(try JSONRepair.repair(json: "{\"key\": \"value}```"), JSONRepair.convertToJSONValue(["key": "value"]))
    }
    
    func testEdge_unquotedKeyValue() throws {
        // {key:value,key2:value2}
        XCTAssertEqual(try JSONRepair.repair(json: "{key:value,key2:value2}"), JSONRepair.convertToJSONValue(["key": "value", "key2": "value2"]))
    }
    
    func testEdge_missingQuoteAfterColon() throws {
        // {"key:"value"}
        let result = try JSONRepair.repair(json: "{\"key:\"value\"}")
        print("testEdge_missingQuoteAfterColon result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["key": "value"]))
    }
    
    func testEdge_unquotedValueMissingClosingQuote() throws {
        // {"key:value}
        let result = try JSONRepair.repair(json: "{\"key:value}")
        print("testEdge_unquotedValueMissingClosingQuote result: \(result)")
        XCTAssertEqual(result, JSONRepair.convertToJSONValue(["key": "value"]))
    }
    
    func testEdge_emptyKey() throws {
        XCTAssertEqual(try JSONRepair.repair(json: "{\"key\": , \"key2\": \"value2\"}"), JSONRepair.convertToJSONValue(["key": "", "key2": "value2"]))
    }
    
    func testEdge_setLikeBraces() throws {
        // {'item1', 'item2', 'item3'}
        XCTAssertEqual(try JSONRepair.repair(json: "{'item1', 'item2', 'item3'}"), JSONRepair.convertToJSONValue(["item1", "item2", "item3"]))
    }
}
