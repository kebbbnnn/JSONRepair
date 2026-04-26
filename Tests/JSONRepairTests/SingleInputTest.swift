import XCTest
@testable import JSONRepair

final class SingleInputTest: XCTestCase {
    func testInput7() throws {
        let expectation = self.expectation(description: "repair")
        var result: JSONValue?
        DispatchQueue.global().async {
            result = try? JSONRepair.repairJson("{ \"words\": abcdef\", \"numbers\": 12345\", \"words2\": ghijkl\" }")
            expectation.fulfill()
        }
        let waiterResult = XCTWaiter().wait(for: [expectation], timeout: 3.0)
        if waiterResult == .timedOut {
            XCTFail("TIMEOUT on input 7")
        } else {
            print("Result 7: \(result!)")
        }
    }
    
    func testInput27() throws {
        let expectation = self.expectation(description: "repair")
        var result: JSONValue?
        DispatchQueue.global().async {
            result = try? JSONRepair.repairJson("{ \"key\": [[1, 2, 3], \"a\", \"b\"], [[4, 5, 6], [7, 8, 9]] }")
            expectation.fulfill()
        }
        let waiterResult = XCTWaiter().wait(for: [expectation], timeout: 3.0)
        if waiterResult == .timedOut {
            XCTFail("TIMEOUT on input 27")
        } else {
            print("Result 27: \(result!)")
        }
    }
}
