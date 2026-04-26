import Foundation

public enum JSONValue: Equatable, Hashable, CustomStringConvertible {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    public var description: String {
        switch self {
        case .object(let dict):
            let content = dict.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
            return "{\(content)}"
        case .array(let arr):
            let content = arr.map { $0.description }.joined(separator: ", ")
            return "[\(content)]"
        case .string(let str):
            let escaped = str
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        case .number(let num):
            // Avoid printing `.0` if it's an integer
            if num == floor(num) {
                return String(Int(num))
            }
            return String(num)
        case .boolean(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        }
    }
    
    /// Helper to unwrap back to Swift Foundation Any types if needed
    public var rawValue: Any {
        switch self {
        case .object(let dict):
            var rawDict = [String: Any]()
            for (key, value) in dict {
                if case .null = value {
                    rawDict[key] = NSNull()
                } else {
                    rawDict[key] = value.rawValue
                }
            }
            return rawDict
        case .array(let arr):
            return arr.map { $0.rawValue }
        case .string(let str):
            return str
        case .number(let num):
            return num
        case .boolean(let bool):
            return bool
        case .null:
            return NSNull()
        }
    }
    
    public var isStrictlyEmpty: Bool {
        switch self {
        case .string(let s): return s.isEmpty
        case .array(let a): return a.isEmpty
        case .object(let o): return o.isEmpty
        case .null: return false
        case .boolean: return false
        case .number: return false
        }
    }
    
    public var isTruthy: Bool {
        switch self {
        case .object(let o): return !o.isEmpty
        case .array(let a): return !a.isEmpty
        case .string(let s): return !s.isEmpty
        case .number(let n): return n != 0
        case .boolean(let b): return b
        case .null: return false
        }
    }

    public func isSameShape(as other: JSONValue?) -> Bool {
        guard let other = other else { return false }
        switch (self, other) {
        case (.object(let o1), .object(let o2)):
            if o1.count != o2.count { return false }
            for (k, v1) in o1 {
                if let v2 = o2[k], v1.isSameShape(as: v2) { continue }
                return false
            }
            return true
        case (.array(let a1), .array(let a2)):
            if a1.count != a2.count { return false }
            for i in 0..<a1.count {
                if !a1[i].isSameShape(as: a2[i]) { return false }
            }
            return true
        case (.string, .string), (.number, .number), (.boolean, .boolean), (.null, .null):
            return true
        default:
            return false
        }
    }
}
