import Foundation


extension JSONParser {
    public func parseArray(closingDelimiter: Character = "]") throws -> JSONValue {
        var arr: [JSONValue] = []
        try withContext(.array) {
            skipWhitespaces()
            var char = getCharAt()
            while let c = char, c != closingDelimiter && c != "}" {
                var value: JSONValue?
                
                if JSONParser.stringDelimiters.contains(c) {
                    var i = 1
                    i = skipToCharacter([c], idx: i)
                    i = scrollWhitespaces(idx: i + 1)
                    if getCharAt(count: i) == ":" {
                        value = try parseObject()
                    } else {
                        value = try parseString()
                    }
                } else {
                    value = try parseJson()
                }
                
                let strictlyEmpty = value?.isStrictlyEmpty ?? true
                
                if strictlyEmpty && getCharAt() != closingDelimiter && getCharAt() != "," {
                    if index < jsonStr.endIndex {
                        index = jsonStr.index(after: index)
                    }
                } else if value == .string("...") && getCharAt(count: -1) == "." {
                    log("While parsing an array, found a stray '...'; ignoring it")
                } else if let v = value {
                    // Only omit if it's strictly empty and not a genuine value (python handles missing items differently, here we just append)
                    arr.append(v)
                }
                
                char = getCharAt()
                while let c2 = char, c2 != closingDelimiter && (c2.isWhitespace || c2 == ",") {
                    index = jsonStr.index(after: index)
                    char = getCharAt()
                }
            }
            
            if char != closingDelimiter {
                log("While parsing an array we missed the closing \(closingDelimiter), ignoring it")
            }
            
            if index < jsonStr.endIndex {
                index = jsonStr.index(after: index)
            }
        }
        return .array(arr)
    }
}
