import Foundation

extension JSONParser {
    public func parseObject() throws -> JSONValue {
        var objKeys: [String] = []
        var objValues: [String: JSONValue] = [:]
        let startIndex = index
        let parsingObjectValue = context.current == .objectValue
        
        while let char = getCharAt(), char != "}" {
            let loopStartIndex = index
            skipWhitespaces()
            
            if getCharAt() == ":" {
                log("While parsing an object we found a : before a key, ignoring")
                index = jsonStr.index(after: index)
            }
            
            var key = ""
            var rollbackIndex = index
            try withContext(.objectKey) {
                while let _ = getCharAt() {
                    rollbackIndex = index
                    
                    // Handle array continuation: if we see `[` and key is empty,
                    // this might be an array value continuation for the previous key
                    if getCharAt() == "[" && key.isEmpty && !objValues.isEmpty {
                        if mergeObjectArrayContinuation(obj: &objValues, keys: &objKeys) {
                            continue
                        }
                    }
                    
                    let preParseIndex = index
                    let rawKey = try parseString()
                    if case .string(let s) = rawKey {
                        key = s
                    } else if case .number(let n) = rawKey {
                        // Sometimes keys can be numbers, convert to string
                        if n == floor(n) {
                            key = String(Int(n))
                        } else {
                            key = String(n)
                        }
                    } else {
                        key = ""
                    }
                    
                    if key.isEmpty {
                        skipWhitespaces()
                    }
                    
                    if !key.isEmpty || (key.isEmpty && (getCharAt() == ":" || getCharAt() == "}")) {
                        if key.isEmpty && strict {
                            log("Empty key found in strict mode while parsing object, raising an error")
                            throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty key found in strict mode while parsing object."])
                        }
                        break
                    }
                    
                    // Safety: if parseString didn't advance the index and key is empty,
                    // skip the current character to avoid an infinite loop
                    if index == preParseIndex {
                        if index < jsonStr.endIndex {
                            index = jsonStr.index(after: index)
                        } else {
                            break
                        }
                    }
                }
            }
            
            if context.context.contains(.array) && objKeys.contains(key) {
                if strict {
                    log("Duplicate key found in strict mode while parsing object, raising an error")
                    throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Duplicate key found in strict mode while parsing object."])
                }
                if !parsingObjectValue {
                    if _shouldSplitDuplicateObject(rollbackIndex: rollbackIndex) {
                        log("While parsing an object we found a duplicate key, closing the object here and rolling back the index")
                        _splitObjectOnDuplicateKey(rollbackIndex: rollbackIndex)
                        break
                    }
                    log("While parsing an object we found a duplicate key with a normal comma separator, keeping duplicate-key overwrite behavior")
                }
            }
            
            skipWhitespaces()
            skipWhitespaces()
            let c = getCharAt()
            if c == "}" || c == nil {
                continue
            }
            
            skipWhitespaces()
            if getCharAt() != ":" {
                if strict {
                    log("Missing ':' after key in strict mode while parsing object, raising an error")
                    throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing ':' after key in strict mode while parsing object."])
                }
                log("While parsing an object we missed a : after a key")
            }
            if index < jsonStr.endIndex {
                index = jsonStr.index(after: index)
            }
            
            let value = try withContext(.objectValue) { () -> JSONValue in
                skipWhitespaces()
                let c = getCharAt()
                if c == "," || c == "}" {
                    log("While parsing an object value we found a stray \(c!), ignoring it")
                    return .string("")
                }
                return try parseJson() ?? .string("")
            }
            
            if strict && value.isStrictlyEmpty {
                if case .string(let s) = value, s.isEmpty {
                    if let prev = getCharAt(count: -1), !JSONParser.stringDelimiters.contains(prev) {
                        log("Parsed value is empty in strict mode while parsing object, raising an error")
                        throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Parsed value is empty in strict mode while parsing object."])
                    }
                }
            }
            
            if !objKeys.contains(key) {
                objKeys.append(key)
            }
            objValues[key] = value
            
            let nextChar = getCharAt()
            if nextChar == "," || nextChar == "'" || nextChar == "\"" {
                index = jsonStr.index(after: index)
            }
            
            if getCharAt() == "]" && context.context.contains(.array) {
                log("While parsing an object we found a closing array bracket, closing the object here and rolling back the index")
                if index > jsonStr.startIndex {
                    index = jsonStr.index(before: index)
                }
                break
            }
            skipWhitespaces()
            
            // Safety: if the loop iteration made no progress, skip the current char
            if index == loopStartIndex {
                if index < jsonStr.endIndex {
                    index = jsonStr.index(after: index)
                } else {
                    break
                }
            }
        }
        
        if index < jsonStr.endIndex {
            index = jsonStr.index(after: index)
        }
        
        if objValues.isEmpty && jsonStr.distance(from: startIndex, to: index) > 2 {
            if strict {
                log("Parsed object is empty but contains extra characters in strict mode, raising an error")
                throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Parsed object is empty but contains extra characters in strict mode."])
            }
            
            log("Parsed object is empty, we will try to parse this as an array instead")
            index = startIndex
            return try withContext(.objectKey) {
                let repairedArray = try parseArray()
                deferredContexts.append(.objectKey)
                return repairedArray
            }
        }
        
        if !context.isEmpty {
            if getCharAt() == "}" && context.current != .objectKey && context.current != .objectValue {
                log("Found an extra closing brace that shouldn't be there, skipping it")
                index = jsonStr.index(after: index)
            }
            return .object(objValues)
        }
        
        skipWhitespaces()
        if getCharAt() == "," {
            index = jsonStr.index(after: index)
            skipWhitespaces()
            if let c = getCharAt(), JSONParser.stringDelimiters.contains(c) && !strict {
                log("Found a comma and string delimiter after object closing brace, checking for additional key-value pairs")
                let additionalObj = try parseObject()
                if case .object(let addObj) = additionalObj {
                    for (k, v) in addObj {
                        objValues[k] = v
                    }
                }
            }
        }
        
        return .object(objValues)
    }
    
    private func _shouldSplitDuplicateObject(rollbackIndex: String.Index) -> Bool {
        var lookbackIdx = -1
        var prevNonWhitespace = getCharAt(count: jsonStr.distance(from: index, to: rollbackIndex) - 1)
        while let c = prevNonWhitespace, c.isWhitespace {
            lookbackIdx -= 1
            prevNonWhitespace = getCharAt(count: jsonStr.distance(from: index, to: rollbackIndex) + lookbackIdx)
        }
        
        let keyStartChar = getCharAt(count: jsonStr.distance(from: index, to: rollbackIndex))
        let nextNonWhitespace = getCharAt(count: scrollWhitespaces())
        
        if let keyStart = keyStartChar, JSONParser.stringDelimiters.contains(keyStart),
           prevNonWhitespace == ",", nextNonWhitespace == ":" {
            return false
        }
        return true
    }
    
    private func _splitObjectOnDuplicateKey(rollbackIndex: String.Index) {
        if rollbackIndex > jsonStr.startIndex {
            index = jsonStr.index(before: rollbackIndex)
            jsonStr.insert("{", at: jsonStr.index(after: index))
        }
    }

    /// Port of `_merge_object_array_continuation`.
    /// Called when a bare `[` is seen where a key is expected and the previous value was an array.
    /// Parses the new array and merges it into the previous key's array value.
    /// Returns true if the continuation was handled (caller should `continue` the key loop).
    @discardableResult
    func mergeObjectArrayContinuation(obj: inout [String: JSONValue], keys: inout [String]) -> Bool {
        guard let prevKey = keys.last,
              case .array(let prevArray) = obj[prevKey],
              !strict else {
            return false
        }

        // Consume the `[`
        index = jsonStr.index(after: index)
        guard let newValue = try? parseArray(), case .array(let newArray) = newValue else {
            return false
        }

        var merged = prevArray

        // Determine if prev array has uniform sub-array lengths
        let subLengths = prevArray.compactMap { item -> Int? in
            if case .array(let sub) = item { return sub.count }
            return nil
        }
        let expectedLen: Int?
        if !subLengths.isEmpty && subLengths.allSatisfy({ $0 == subLengths[0] }) {
            expectedLen = subLengths[0]
        } else {
            expectedLen = nil
        }

        if let expectedLen = expectedLen {
            // Pop trailing non-array items and group them into rows
            var tail: [JSONValue] = []
            while let last = merged.last {
                if case .array = last {
                    break
                }
                tail.insert(last, at: 0)
                merged.removeLast()
            }
            if !tail.isEmpty {
                if tail.count % expectedLen == 0 {
                    log("While parsing an object we found row values without an inner array, grouping them into rows")
                    for i in stride(from: 0, to: tail.count, by: expectedLen) {
                        merged.append(.array(Array(tail[i..<min(i+expectedLen, tail.count)])))
                    }
                } else {
                    merged.append(contentsOf: tail)
                }
            }
            if !newArray.isEmpty {
                let allSubArrays = newArray.allSatisfy { item in
                    if case .array = item { return true }
                    return false
                }
                if allSubArrays {
                    log("While parsing an object we found additional rows, appending them without flattening")
                    merged.append(contentsOf: newArray)
                } else {
                    merged.append(.array(newArray))
                }
            }
        } else {
            // Flat merge
            if newArray.count == 1, case .array(let inner) = newArray[0] {
                merged.append(contentsOf: inner)
            } else {
                merged.append(contentsOf: newArray)
            }
        }

        obj[prevKey] = .array(merged)

        skipWhitespaces()
        if getCharAt() == "," {
            index = jsonStr.index(after: index)
        }
        skipWhitespaces()
        return true
    }
}

