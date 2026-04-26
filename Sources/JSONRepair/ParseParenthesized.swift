import Foundation

extension JSONParser {
    public func parenthesizedIsExplicitTuple() -> Bool {
        var i = jsonStr.index(after: index)
        var nestedParentheses = 0
        var squareBrackets = 0
        var braces = 0
        var inQuote: Character? = nil
        var backslashes = 0
        var sawTopLevelContent = false
        
        while i < jsonStr.endIndex {
            let ch = jsonStr[i]
            
            if ch == "\\" {
                backslashes += 1
                i = jsonStr.index(after: i)
                continue
            }
            
            if let q = inQuote {
                if ch == q && backslashes % 2 == 0 {
                    inQuote = nil
                }
                backslashes = 0
                i = jsonStr.index(after: i)
                continue
            }
            
            if JSONParser.stringDelimiters.contains(ch) && backslashes % 2 == 0 {
                inQuote = ch
                sawTopLevelContent = sawTopLevelContent || (nestedParentheses == 0 && squareBrackets == 0 && braces == 0)
                backslashes = 0
                i = jsonStr.index(after: i)
                continue
            }
            
            backslashes = 0
            
            if !ch.isWhitespace && ch != "," && ch != ")" && nestedParentheses == 0 && squareBrackets == 0 && braces == 0 {
                sawTopLevelContent = true
            }
            
            if ch == "(" {
                nestedParentheses += 1
            } else if ch == ")" {
                if nestedParentheses == 0 && squareBrackets == 0 && braces == 0 {
                    return !sawTopLevelContent
                }
                if nestedParentheses > 0 {
                    nestedParentheses -= 1
                }
            } else if ch == "[" {
                squareBrackets += 1
            } else if ch == "]" && squareBrackets > 0 {
                squareBrackets -= 1
            } else if ch == "{" {
                braces += 1
            } else if ch == "}" && braces > 0 {
                braces -= 1
            } else if ch == "," && nestedParentheses == 0 && squareBrackets == 0 && braces == 0 {
                return true
            }
            
            i = jsonStr.index(after: i)
        }
        return !sawTopLevelContent
    }
    
    public func topLevelParenthesizedCanStartValue() -> Bool {
        var i = index
        while i > jsonStr.startIndex {
            i = jsonStr.index(before: i)
            let ch = jsonStr[i]
            if ch == "\n" || ch == "\r" { break }
            if !ch.isWhitespace { return false }
        }
        
        let idx = scrollWhitespaces(idx: 1)
        guard let firstInnerChar = getCharAt(count: idx) else { return false }
        
        if firstInnerChar != ")" && firstInnerChar != "{" && firstInnerChar != "[" && firstInnerChar != "(" && !JSONParser.stringDelimiters.contains(firstInnerChar) && !firstInnerChar.isNumber && firstInnerChar != "-" && firstInnerChar != "." {
            let next4 = String(jsonStr[jsonStr.index(index, offsetBy: idx)..<jsonStr.endIndex].prefix(4))
            let next5 = String(jsonStr[jsonStr.index(index, offsetBy: idx)..<jsonStr.endIndex].prefix(5))
            if next4 != "true" && next4 != "null" && next5 != "false" {
                return false
            }
        }
        
        var j = jsonStr.index(after: index)
        var nestedParentheses = 0
        var squareBrackets = 0
        var braces = 0
        var inQuote: Character? = nil
        var backslashes = 0
        
        while j < jsonStr.endIndex {
            let ch = jsonStr[j]
            
            if ch == "\\" {
                backslashes += 1
                j = jsonStr.index(after: j)
                continue
            }
            
            if let q = inQuote {
                if ch == q && backslashes % 2 == 0 {
                    inQuote = nil
                }
                backslashes = 0
                j = jsonStr.index(after: j)
                continue
            }
            
            if JSONParser.stringDelimiters.contains(ch) && backslashes % 2 == 0 {
                inQuote = ch
                backslashes = 0
                j = jsonStr.index(after: j)
                continue
            }
            
            backslashes = 0
            
            if ch == "(" {
                nestedParentheses += 1
            } else if ch == ")" {
                if nestedParentheses == 0 && squareBrackets == 0 && braces == 0 {
                    j = jsonStr.index(after: j)
                    while j < jsonStr.endIndex {
                        let trailer = jsonStr[j]
                        if trailer == "\n" || trailer == "\r" { return true }
                        if !trailer.isWhitespace { return false }
                        j = jsonStr.index(after: j)
                    }
                    return true
                }
                nestedParentheses -= 1
            } else if ch == "[" {
                squareBrackets += 1
            } else if ch == "]" && squareBrackets > 0 {
                squareBrackets -= 1
            } else if ch == "{" {
                braces += 1
            } else if ch == "}" && braces > 0 {
                braces -= 1
            }
            
            j = jsonStr.index(after: j)
        }
        return true
    }
    
    public func parseParenthesized() throws -> JSONValue {
        let explicitTuple = parenthesizedIsExplicitTuple()
        index = jsonStr.index(after: index)
        let value = try parseArray(closingDelimiter: ")")
        
        if explicitTuple {
            return value
        }
        if case .array(let arr) = value, arr.count != 1 {
            return value
        }
        if case .array(let arr) = value {
            return arr[0]
        }
        return value
    }
}
