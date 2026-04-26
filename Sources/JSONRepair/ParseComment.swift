import Foundation

extension JSONParser {
    public func parseComment() throws -> JSONValue? {
        while true {
            guard let char = getCharAt() else { break }
            var terminationCharacters: Set<Character> = ["\n", "\r"]
            if context.context.contains(.array) {
                terminationCharacters.insert("]")
            }
            if context.context.contains(.objectValue) {
                terminationCharacters.insert("}")
            }
            if context.context.contains(.objectKey) {
                terminationCharacters.insert(":")
            }
            
            if char == "#" {
                var comment = ""
                var currentChar = getCharAt()
                while let c = currentChar, !terminationCharacters.contains(c) {
                    comment.append(c)
                    index = jsonStr.index(after: index)
                    currentChar = getCharAt()
                }
                log("Found line comment: \(comment), ignoring")
            } else if char == "/" {
                let nextChar = getCharAt(count: 1)
                if nextChar == "/" {
                    var comment = "//"
                    if let _ = jsonStr.index(index, offsetBy: 2, limitedBy: jsonStr.endIndex) {
                        index = jsonStr.index(index, offsetBy: 2)
                    } else {
                        index = jsonStr.endIndex
                    }
                    var currentChar = getCharAt()
                    while let c = currentChar, !terminationCharacters.contains(c) {
                        comment.append(c)
                        index = jsonStr.index(after: index)
                        currentChar = getCharAt()
                    }
                    log("Found line comment: \(comment), ignoring")
                } else if nextChar == "*" {
                    var comment = "/*"
                    if let _ = jsonStr.index(index, offsetBy: 2, limitedBy: jsonStr.endIndex) {
                        index = jsonStr.index(index, offsetBy: 2)
                    } else {
                        index = jsonStr.endIndex
                    }
                    while true {
                        guard let c = getCharAt() else {
                            log("Reached end-of-string while parsing block comment; unclosed block comment.")
                            break
                        }
                        comment.append(c)
                        index = jsonStr.index(after: index)
                        if comment.hasSuffix("*/") {
                            break
                        }
                    }
                    log("Found block comment: \(comment), ignoring")
                } else {
                    index = jsonStr.index(after: index)
                }
            }
            
            if context.isEmpty {
                skipWhitespaces()
                let next = getCharAt()
                if next == "#" || next == "/" {
                    continue
                }
                return try parseJson()
            }
            break
        }
        return .string("")
    }
}
