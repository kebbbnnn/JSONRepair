import XCTest
@testable import JSONRepair

final class JSONRepairTests: XCTestCase {
    
    func testValidJSON() throws {
        XCTAssertEqual(try JSONRepair.repairJson("{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}"), JSONRepair.convertToJSONValue(["name": "John", "age": 30, "city": "New York"]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"employees\":[\"John\", \"Anna\", \"Peter\"]} "), JSONRepair.convertToJSONValue(["employees": ["John", "Anna", "Peter"]]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key\": \"value:value\"}"), JSONRepair.convertToJSONValue(["key": "value:value"]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"text\": \"The quick brown fox,\"}"), JSONRepair.convertToJSONValue(["text": "The quick brown fox,"]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"text\": \"The quick brown fox won't jump\"}"), JSONRepair.convertToJSONValue(["text": "The quick brown fox won't jump"]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key\": \"\""), JSONRepair.convertToJSONValue(["key": ""]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key1\": {\"key2\": [1, 2, 3]}}"), JSONRepair.convertToJSONValue(["key1": ["key2": [1, 2, 3]]]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key\": \"value☺\"}"), JSONRepair.convertToJSONValue(["key": "value☺"]))
    }
    
    func testMultipleJsons() throws {
        XCTAssertEqual(try JSONRepair.repairJson("[]{}"), JSONRepair.convertToJSONValue([]))
        XCTAssertEqual(try JSONRepair.repairJson("[]{\"key\":\"value\"}"), JSONRepair.convertToJSONValue(["key": "value"]))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key\":\"value\"}[1,2,3,True]"), JSONRepair.convertToJSONValue([["key": "value"], [1, 2, 3, true]]))
        XCTAssertEqual(try JSONRepair.repairJson("lorem ```json {\"key\":\"value\"} ``` ipsum ```json [1,2,3,True] ``` 42"), JSONRepair.convertToJSONValue([["key": "value"], [1, 2, 3, true]]))
        XCTAssertEqual(try JSONRepair.repairJson("[{\"key\":\"value\"}][{\"key\":\"value_after\"}]"), JSONRepair.convertToJSONValue([["key": "value_after"]]))
    }
    
    func testParenthesizedProseDoesNotHijackFencedJson() throws {
        let text = """
         **Decision**: bla, bla (some clarification):

        ```json
        {
          "key": "value"
        }
        ```
        """
        XCTAssertEqual(try JSONRepair.repairJson(text), JSONRepair.convertToJSONValue(["key": "value"]))
    }
    
    func testRepairJsonWithObjects() throws {
        XCTAssertEqual(try JSONRepair.repairJson("[]"), JSONRepair.convertToJSONValue([]))
        XCTAssertEqual(try JSONRepair.repairJson("{}"), JSONRepair.convertToJSONValue([String: Any]()))
        XCTAssertEqual(try JSONRepair.repairJson("{\"key\": true, \"key2\": false, \"key3\": null}"), JSONRepair.convertToJSONValue(["key": true, "key2": false, "key3": NSNull()]))
        XCTAssertEqual(try JSONRepair.repairJson("[1, 2, 3, 4]"), JSONRepair.convertToJSONValue([1, 2, 3, 4]))
        
        let bundleText = """
{
  "resourceType": "Bundle",
  "id": "1",
  "type": "collection",
  "entry": [
    {
      "resource": {
        "resourceType": "Patient",
        "id": "1",
        "name": [
          {"use": "official", "family": "Corwin", "given": ["Keisha", "Sunny"], "prefix": ["Mrs."},
          {"use": "maiden", "family": "Goodwin", "given": ["Keisha", "Sunny"], "prefix": ["Mrs."]}
        ]
      }
    }
  ]
}
"""
        let bundleParsed = try JSONRepair.repairJson(bundleText)
        if case .object(let obj) = bundleParsed, case .array(let entry) = obj["entry"] {
            XCTAssertEqual(entry.count, 1)
        } else {
            XCTFail("Failed to parse bundle")
        }
    }
    
    func testMissingQuotes() throws {
        let jsonStr = "{ name: John, age: 30 }"
        let result = try JSONRepair.repairJson(jsonStr)
        
        guard case .object(let dict) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(dict["name"], .string("John"))
        XCTAssertEqual(dict["age"], .number(30))
    }
    
    func testTrailingCommas() throws {
        let jsonStr = "[1, 2, 3,]"
        let result = try JSONRepair.repairJson(jsonStr)
        
        guard case .array(let arr) = result else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0], .number(1))
        XCTAssertEqual(arr[2], .number(3))
    }
    
    func testComments() throws {
        let jsonStr = """
        {
            // this is a comment
            "key": "value" /* block comment */
        }
        """
        let result = try JSONRepair.repairJson(jsonStr)
        
        guard case .object(let dict) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(dict["key"], .string("value"))
    }
}    

