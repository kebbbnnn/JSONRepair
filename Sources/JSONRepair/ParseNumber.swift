import Foundation

extension JSONParser {
    public func parseNumber() throws -> JSONValue {
        var numberStr = ""
        var char = getCharAt()
        let isArray = context.current == .array
        
        let numberChars: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "-", ".", "e", "E", "/", ",", "_"]
        
        while let c = char, numberChars.contains(c), (!isArray || c != ",") {
            if c != "_" {
                numberStr.append(c)
            }
            index = jsonStr.index(after: index)
            char = getCharAt()
        }
        
        if let c = getCharAt(), c.isLetter {
            index = jsonStr.index(index, offsetBy: -numberStr.count)
            return try parseString()
        }
        
        if !numberStr.isEmpty {
            let lastChar = numberStr.last!
            if lastChar == "-" || lastChar == "e" || lastChar == "E" || lastChar == "/" || lastChar == "," {
                numberStr.removeLast()
                index = jsonStr.index(before: index)
            }
        }
        
        if numberStr.contains(",") {
            return .string(numberStr)
        }
        if numberStr.contains(".") || numberStr.contains("e") || numberStr.contains("E") {
            if let d = Double(numberStr) {
                return .number(d)
            }
        } else {
            if let d = Double(numberStr) {
                return .number(d)
            }
        }
        
        return .string(numberStr)
    }
}
