import Foundation

public struct JSONRepair {
    
    /// Repairs a malformed JSON string and returns it as a type-safe `JSONValue`.
    /// - Parameters:
    ///   - jsonStr: The broken JSON string
    ///   - strict: If true, stops and throws errors on structural issues instead of repairing.
    ///   - logging: If true, captures a log of repair actions in the parser (accessible if using `JSONParser` directly).
    /// - Returns: The repaired `JSONValue`
    public static func repair(json jsonStr: String, strict: Bool = false, logging: Bool = false, streamStable: Bool = false) throws -> JSONValue {
        // Fast path for valid JSON
        if !strict {
            if let data = jsonStr.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) {
                return convertToJSONValue(jsonObject)
            }
        }
        
        // Repair path
        let parser = JSONParser(jsonStr: jsonStr, logging: logging, streamStable: streamStable, strict: strict)
        return try parser.parse()
    }
    
    /// Helper to convert Foundation `Any` JSON types to `JSONValue` enum.
    public static func convertToJSONValue(_ object: Any) -> JSONValue {
        if let dict = object as? [String: Any] {
            var newDict: [String: JSONValue] = [:]
            for (key, value) in dict {
                newDict[key] = convertToJSONValue(value)
            }
            return .object(newDict)
        } else if let arr = object as? [Any] {
            return .array(arr.map { convertToJSONValue($0) })
        } else if let str = object as? String {
            return .string(str)
        } else if let num = object as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .boolean(num.boolValue)
            }
            return .number(num.doubleValue)
        } else if object is NSNull {
            return .null
        }
        return .string(String(describing: object))
    }
}
