import Foundation

public enum ContextValue {
    case objectKey
    case objectValue
    case array
}

public class JsonContext {
    public var context: [ContextValue] = []
    public var current: ContextValue? { context.last }
    public var isEmpty: Bool { context.isEmpty }

    public init() {}

    public func set(_ value: ContextValue) {
        context.append(value)
    }

    public func reset() {
        if !context.isEmpty {
            context.removeLast()
        }
    }

    public func clear() {
        context.removeAll()
    }
}

public class JSONParser {
    public var jsonStr: String
    public var index: String.Index
    public var context: JsonContext
    public var deferredContexts: [ContextValue]
    public var logging: Bool
    public var logger: [[String: String]]
    public var streamStable: Bool
    public var strict: Bool

    public static let stringDelimiters: Set<Character> = ["\"", "'", "“", "”"]

    public init(
        jsonStr: String,
        logging: Bool = false,
        streamStable: Bool = false,
        strict: Bool = false
    ) {
        self.jsonStr = jsonStr
        self.index = jsonStr.startIndex
        self.context = JsonContext()
        self.deferredContexts = []
        self.logging = logging
        self.logger = []
        self.streamStable = streamStable
        self.strict = strict
    }

    public func withContext<T>(_ value: ContextValue, _ block: () throws -> T) rethrows -> T {
        context.set(value)
        defer { context.reset() }
        return try block()
    }

    public func log(_ text: String) {
        guard logging else { return }
        let window = 10
        let startDistance = max(jsonStr.distance(from: jsonStr.startIndex, to: index) - window, 0)
        let endDistance = min(jsonStr.distance(from: jsonStr.startIndex, to: index) + window, jsonStr.count)
        
        let start = jsonStr.index(jsonStr.startIndex, offsetBy: startDistance)
        let end = jsonStr.index(jsonStr.startIndex, offsetBy: endDistance)
        let ctx = String(jsonStr[start..<end])
        
        logger.append([
            "text": text,
            "context": ctx
        ])
    }

    public func getCharAt(count: Int = 0) -> Character? {
        guard let targetIndex = jsonStr.index(index, offsetBy: count, limitedBy: jsonStr.endIndex),
              targetIndex < jsonStr.endIndex else {
            return nil
        }
        return jsonStr[targetIndex]
    }

    public func skipWhitespaces() {
        while let char = getCharAt(), char.isWhitespace {
            index = jsonStr.index(after: index)
        }
    }

    public func scrollWhitespaces(idx: Int = 0) -> Int {
        var currentIdx = idx
        while let targetIndex = jsonStr.index(index, offsetBy: currentIdx, limitedBy: jsonStr.endIndex),
              targetIndex < jsonStr.endIndex,
              jsonStr[targetIndex].isWhitespace {
            currentIdx += 1
        }
        return currentIdx
    }

    public func skipToCharacter(_ targets: Set<Character>, idx: Int = 0) -> Int {
        var i = jsonStr.index(index, offsetBy: idx, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
        var backslashes = 0
        
        while i < jsonStr.endIndex {
            let ch = jsonStr[i]
            
            if ch == "\\" {
                backslashes += 1
                i = jsonStr.index(after: i)
                continue
            }
            
            if targets.contains(ch) && (backslashes % 2 == 0) {
                return jsonStr.distance(from: index, to: i)
            }
            
            backslashes = 0
            i = jsonStr.index(after: i)
        }
        return jsonStr.distance(from: index, to: jsonStr.endIndex)
    }

    public func parse() throws -> JSONValue {
        guard let first = try parseJson() else {
            return .string("")
        }
        
        if index < jsonStr.endIndex {
            log("The parser returned early, checking if there's more json elements")
            var elements: [JSONValue] = [first]
            
            while index < jsonStr.endIndex {
                context.clear()
                deferredContexts.removeAll()
                if let j = try parseJson() {
                    if j.isTruthy {
                        if j.isSameShape(as: elements.last) {
                            elements.removeLast()
                        } else {
                            if let last = elements.last, !last.isTruthy {
                                elements.removeLast()
                            }
                        }
                        elements.append(j)
                    } else {
                        if index < jsonStr.endIndex {
                            index = jsonStr.index(after: index)
                        }
                    }
                } else {
                    if index < jsonStr.endIndex {
                        index = jsonStr.index(after: index)
                    }
                }
            }
            
            if elements.count == 1 {
                log("There were no more elements, returning the element without the array")
                return elements[0]
            } else if strict {
                log("Multiple top-level JSON elements found in strict mode, raising an error")
                throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Multiple top-level JSON elements found in strict mode."])
            }
            
            return .array(elements)
        }
        
        return first
    }

    public func parseJson() throws -> JSONValue? {
        if !deferredContexts.isEmpty {
            let deferred = deferredContexts
            deferredContexts.removeAll()
            
            let originalContextCount = context.context.count
            for ctx in deferred {
                context.set(ctx)
            }
            defer {
                while context.context.count > originalContextCount {
                    context.reset()
                }
            }
            return try parseJson()
        }

        while true {
            guard let char = getCharAt() else {
                return nil
            }
            
            if char == "{" {
                index = jsonStr.index(after: index)
                return try parseObject()
            }
            if char == "[" {
                index = jsonStr.index(after: index)
                return try parseArray()
            }
            
            if char == "(" {
                if !context.isEmpty || topLevelParenthesizedCanStartValue() {
                    return try parseParenthesized()
                }
                index = jsonStr.index(after: index)
                continue
            }
            
            if !context.isEmpty && (JSONParser.stringDelimiters.contains(char) || char.isLetter) {
                return try parseString()
            }
            
            if !context.isEmpty && (char.isNumber || char == "-" || char == ".") {
                return try parseNumber()
            }
            
            if char == "#" || char == "/" {
                return try parseComment()
            }
            
            index = jsonStr.index(after: index)
        }
    }
}
