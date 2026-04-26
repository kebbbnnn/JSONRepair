import Foundation

// MARK: - Inline container helpers
// Mirrors Python's INLINE_CONTAINER_CLOSING_DELIMITERS / update_inline_container_stack
private let inlineContainerClosingDelimiters: [Character: Character] = ["{": "}", "[": "]", "(": ")"]
private let inlineContainerOpeners: Set<Character> = ["{", "[", "("]

extension JSONParser {

    // MARK: - Main Entry Point

    public func parseString() throws -> JSONValue {
        // ── 1. Comments ──────────────────────────────────────────────────
        if let d = getCharAt(), d == "#" || d == "/" {
            if let commentVal = try parseComment() {
                return commentVal
            }
            return .string("")
        }

        // ── 2. Set-up delimiters / quoting state ──────────────────────
        var lStringDelimiter: Character = "\""
        var rStringDelimiter: Character = "\""
        var missingQuotes = false
        var doubledQuotes = false
        var unmatchedDelimiter = false
        var stringAcc = ""
        var inlineContainerStack: [Character] = []   // tracks { [ ( for brace-balance

        skipWhitespaces()
        
        let openingChar = getCharAt()

        // Advance past non-alphanumeric, non-delimiter junk
        var skipChar = openingChar
        while let sc = skipChar, !JSONParser.stringDelimiters.contains(sc) && !sc.isLetter && !sc.isNumber {
            // Don't skip if we're in a context where we would parse a value
            if context.current == .objectKey || context.current == .objectValue || context.current == .array {
                break
            }
            index = jsonStr.index(after: index)
            skipChar = getCharAt()
        }

        guard let firstChar = getCharAt() else {
            return .string("")
        }

        // Fast-path for clean simple quoted strings
        if let fastValue = tryParseSimpleQuotedString() {
            return .string(fastValue)
        }

        if JSONParser.stringDelimiters.contains(firstChar) {
            index = jsonStr.index(after: index)   // consume opening delimiter
            lStringDelimiter = firstChar
            rStringDelimiter = matchingStringDelimiter(firstChar)
            
            // Try to parse a string that is actually a json llm block
            if String(jsonStr[index...].prefix(7)) == "```json" {
                let i = skipToCharacter(["`"], idx: 7)
                let suffixStart = jsonStr.index(index, offsetBy: i, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
                if String(jsonStr[suffixStart...]).hasPrefix("```") {
                    let oldIndex = index
                    index = jsonStr.index(index, offsetBy: 7, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
                    if let parsed = try parseJson() {
                        return parsed
                    }
                    index = oldIndex
                }
            }
        } else if firstChar.isLetter || firstChar.isNumber {
            // Boolean / null first
            if firstChar.lowercased().first! != "t" && firstChar.lowercased().first! != "f"
                && firstChar.lowercased().first! != "n"
                || context.current == .objectKey {
                // Fall through to missing-quotes string
            } else {
                if let boolNull = parseBooleanOrNull() {
                    return boolNull
                }
            }
            log("While parsing a string, we found a literal instead of a quote")
            missingQuotes = true
        } else {
            return .string("")
        }

        // ── 3. Handle doubled-quote openers ───────────────────────────
        if !missingQuotes && getCharAt() == lStringDelimiter {
            let cur = context.current
            if (cur == .objectKey   && getCharAt(count: 1) == ":") ||
               (cur == .objectValue && (getCharAt(count: 1) == "," || getCharAt(count: 1) == "}")) ||
               (cur == .array       && (getCharAt(count: 1) == "," || getCharAt(count: 1) == "]")) {
                index = jsonStr.index(after: index)
                return .string("")
            }
            if getCharAt(count: 1) == lStringDelimiter {
                log("While parsing a string, we found a doubled quote and then a quote again, ignoring it")
                if strict {
                    throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Found doubled quotes followed by another quote."])
                }
                return .string("")
            }
            let skipIdx = skipToCharacter([rStringDelimiter], idx: 1)
            if getCharAt(count: skipIdx + 1) == rStringDelimiter {
                log("While parsing a string, we found a valid starting doubled quote")
                doubledQuotes = true
                index = jsonStr.index(after: index)
            } else {
                let scrollIdx = scrollWhitespaces(idx: 1)
                let nextC = getCharAt(count: scrollIdx)
                if let nc = nextC, JSONParser.stringDelimiters.contains(nc) || nc == "{" || nc == "[" {
                    log("While parsing a string, we found a doubled quote but also another quote afterwards, ignoring it")
                    if strict {
                        throw NSError(domain: "JSONRepair", code: 1, userInfo: [NSLocalizedDescriptionKey: "Found doubled quotes followed by another quote while parsing a string."])
                    }
                    index = jsonStr.index(after: index)
                    return .string("")
                }
                if nextC != "," && nextC != "]" && nextC != "}" {
                    log("While parsing a string, we found a doubled quote but it was a mistake, removing one quote")
                    index = jsonStr.index(after: index)
                }
            }
        }

        // ── 4. Main body scan ─────────────────────────────────────────
        var char = getCharAt()
        while let c = char, c != rStringDelimiter {
            // ── missing-quotes breaks ──
            if missingQuotes {
                if context.current == .objectKey && (c == ":" || c.isWhitespace) {
                    log("While parsing a string missing the left delimiter in object key context, we found a : or space, stopping here")
                    break
                }
                if context.current == .array && (c == "]" || c == ",") {
                    log("While parsing a string missing the left delimiter in array context, we found a ] or ,, stopping here")
                    break
                }
            }

            // ── comma classification for unquoted object values ────────
            if !streamStable && context.current == .objectValue && c == "," && inlineContainerStack.isEmpty {
                let classification = classifyObjectValueComma(missingQuotes: missingQuotes)
                if classification == .member {
                    log("While parsing a string missing the right delimiter in object value context, we found a comma that starts the next object member. Stopping here")
                    break
                }
                // Comma belongs to the value
                log("While parsing a string in object value context, we found a comma that belongs to the string, keeping it")
                stringAcc.append(c)
                index = jsonStr.index(after: index)
                char = getCharAt()
                continue
            }

            // ── inline container stack update ──────────────────────────
            let (newPending, keepChar) = updateInlineContainerStack(c, stack: &inlineContainerStack)
            _ = newPending
            if keepChar {
                stringAcc.append(c)
                index = jsonStr.index(after: index)
                char = getCharAt()
                continue
            }

            // ── } in object value context ──────────────────────────────
            if !streamStable && context.current == .objectValue && c == "}" {
                var rStringDelimiterMissing = true
                skipWhitespaces()
                // peek one char ahead
                if getCharAt(count: 1) == "\\" {
                    rStringDelimiterMissing = false
                }
                let i = skipToCharacter([rStringDelimiter], idx: 1)
                let nextC = getCharAt(count: i)
                if let _ = nextC {
                    var j = i + 1
                    j = scrollWhitespaces(idx: j)
                    let jc = getCharAt(count: j)
                    if jc == nil || jc == "," || jc == "}" {
                        rStringDelimiterMissing = false
                    } else {
                        var k = skipToCharacter([lStringDelimiter], idx: j)
                        let kc = getCharAt(count: k)
                        if kc == nil {
                            rStringDelimiterMissing = false
                        } else {
                            k = scrollWhitespaces(idx: k + 1)
                            let lc = getCharAt(count: k)
                            if let l = lc, l != ":" {
                                rStringDelimiterMissing = false
                            }
                        }
                    }
                } else {
                    let colonIdx = skipToCharacter([":"], idx: 1)
                    if getCharAt(count: colonIdx) != nil {
                        break
                    }
                    let wIdx = scrollWhitespaces(idx: 1)
                    let closeIdx = skipToCharacter(["}"], idx: wIdx)
                    if closeIdx - wIdx > 1 {
                        rStringDelimiterMissing = false
                    } else if getCharAt(count: closeIdx) != nil {
                        // check if string_acc has a matching {
                        for sc in stringAcc.reversed() {
                            if sc == "{" { rStringDelimiterMissing = false; break }
                        }
                    }
                }
                if rStringDelimiterMissing {
                    log("While parsing a string missing the left delimiter in object value context, we found a } and we couldn't determine that a right delimiter was present. Stopping here")
                    break
                }
            }

            // ── ] in array context ─────────────────────────────────────
            if !streamStable && c == "]" && context.context.contains(.array) {
                let i = skipToCharacter([rStringDelimiter], idx: 0)
                if getCharAt(count: i) == nil { break }
            }

            // ── } immediately before ``` code fence ───────────────────
            if context.current == .objectValue && c == "}" {
                let wi = scrollWhitespaces(idx: 1)
                if getCharAt(count: wi) == "`" && getCharAt(count: wi+1) == "`" && getCharAt(count: wi+2) == "`" {
                    // simplified: just stop
                    log("While parsing a string in object value context, we found a } that closes the object before code fences, stopping here")
                    break
                }
                if getCharAt(count: 1) == nil {
                    log("While parsing a string in object value context, we found a } that closes the object, stopping here")
                    break
                }
            }

            // ── default append ─────────────────────────────────────────
            stringAcc.append(c)
            index = jsonStr.index(after: index)
            char = getCharAt()

            guard let nextChar = char else {
                if streamStable && !stringAcc.isEmpty && stringAcc.last == "\\" {
                    stringAcc.removeLast()
                }
                break
            }

            // ── stray escape normalization ─────────────────────────────
            if !stringAcc.isEmpty && stringAcc.last == "\\" {
                let (handled, newChar) = normalizeEscapeSequence(
                    &stringAcc, nextChar: nextChar,
                    rStringDelimiter: rStringDelimiter, lStringDelimiter: lStringDelimiter
                )
                if handled {
                    char = newChar
                    continue
                }
            }

            // ── colon-in-key detection ─────────────────────────────────
            if nextChar == ":" && !missingQuotes && context.current == .objectKey {
                let i = skipToCharacter([lStringDelimiter], idx: 1)
                if let _ = getCharAt(count: i) {
                    let j = skipToCharacter([rStringDelimiter], idx: i + 1)
                    if let _ = getCharAt(count: j) {
                        let k = scrollWhitespaces(idx: j + 1)
                        let kc = getCharAt(count: k)
                        if kc == "," || kc == "}" {
                            log("While parsing a string missing the right delimiter in object key context, we found a \(kc!) stopping here")
                            break
                        }
                    }
                } else {
                    log("While parsing a string missing the right delimiter in object key context, we found a :, stopping here")
                    break
                }
            }

            // ── right-delimiter candidate (quoted + unquoted strings) ─────
            if nextChar == rStringDelimiter && (stringAcc.isEmpty || stringAcc.last != "\\") {
                let (handled, newChar, shouldBreak) = handleRightDelimiterCandidate(
                    &stringAcc, char: nextChar,
                    rStringDelimiter: rStringDelimiter,
                    lStringDelimiter: lStringDelimiter,
                    doubledQuotes: &doubledQuotes,
                    unmatchedDelimiter: &unmatchedDelimiter,
                    missingQuotes: missingQuotes
                )
                if shouldBreak { char = getCharAt(); break }
                if handled { char = newChar; continue }
            }
        }

        // ── 5. Finalize ───────────────────────────────────────────────
        return .string(finalizeStringResult(
            stringAcc: stringAcc, char: char,
            rStringDelimiter: rStringDelimiter,
            missingQuotes: missingQuotes
        ))
    }

    // MARK: - Helpers

    /// Fast path for clean, simple quoted strings (no escapes, no embedded newlines)
    func tryParseSimpleQuotedString() -> String? {
        guard getCharAt() == "\"" else { return nil }
        var i = 1
        var value = ""
        while let c = getCharAt(count: i) {
            if c == "\"" {
                // Check structural character after closing quote
                let afterIdx = scrollWhitespaces(idx: i + 1)
                let afterChar = getCharAt(count: afterIdx)
                let cur = context.current
                if cur == .objectKey {
                    if afterChar != ":" { return nil }
                } else if cur == .objectValue {
                    if afterChar != nil && afterChar != "," && afterChar != "}" { return nil }
                } else if cur == .array {
                    if afterChar != nil && afterChar != "," && afterChar != "]" { return nil }
                } else if afterChar != nil {
                    return nil
                }
                // Found valid end – consume up through the closing quote
                index = jsonStr.index(index, offsetBy: i + 1, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
                return value
            }
            if c == "\\" || c == "\n" || c == "\r" { return nil }
            value.append(c)
            i += 1
        }
        return nil
    }

    func parseBooleanOrNull() -> JSONValue? {
        guard getCharAt() != nil else { return nil }
        let remaining = String(jsonStr[index...]).lowercased()
        if remaining.hasPrefix("true") {
            let afterIdx = jsonStr.index(index, offsetBy: 4, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            let afterChar = afterIdx < jsonStr.endIndex ? jsonStr[afterIdx] : nil
            if afterChar == nil || !afterChar!.isLetter {
                index = afterIdx; return .boolean(true)
            }
        }
        if remaining.hasPrefix("false") {
            let afterIdx = jsonStr.index(index, offsetBy: 5, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            let afterChar = afterIdx < jsonStr.endIndex ? jsonStr[afterIdx] : nil
            if afterChar == nil || !afterChar!.isLetter {
                index = afterIdx; return .boolean(false)
            }
        }
        if remaining.hasPrefix("null") || remaining.hasPrefix("none") {
            let afterIdx = jsonStr.index(index, offsetBy: 4, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            let afterChar = afterIdx < jsonStr.endIndex ? jsonStr[afterIdx] : nil
            if afterChar == nil || !afterChar!.isLetter {
                index = afterIdx; return .null
            }
        }
        if remaining.hasPrefix("nan") {
            index = jsonStr.index(index, offsetBy: 3, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            return .number(Double.nan)
        }
        return nil
    }

    func matchingStringDelimiter(_ d: Character) -> Character {
        if d == "\u{201C}" { return "\u{201D}" }
        return d
    }

    /// Port of `_normalize_escape_sequence`
    func normalizeEscapeSequence(
        _ acc: inout String,
        nextChar: Character,
        rStringDelimiter: Character,
        lStringDelimiter: Character
    ) -> (handled: Bool, newChar: Character?) {
        log("Found a stray escape sequence, normalizing it")
        let escapeMap: [Character: Character] = ["t": "\t", "n": "\n", "r": "\r", "b": "\u{08}"]
        if nextChar == rStringDelimiter || nextChar == "\\" || escapeMap[nextChar] != nil {
            acc.removeLast()
            acc.append(escapeMap[nextChar] ?? nextChar)
            index = jsonStr.index(after: index)
            var nc = getCharAt()
            // chain: handle multiple consecutive escapes
            while let n = nc, !acc.isEmpty && acc.last == "\\", n == rStringDelimiter || n == "\\" {
                acc.removeLast()
                acc.append(n)
                index = jsonStr.index(after: index)
                nc = getCharAt()
            }
            return (true, nc)
        }
        if nextChar == "u" || nextChar == "x" {
            let numChars = nextChar == "u" ? 4 : 2
            let hexStart = jsonStr.index(after: index)
            let hexEnd = jsonStr.index(hexStart, offsetBy: numChars, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            let hexStr = String(jsonStr[hexStart..<hexEnd])
            if hexStr.count == numChars && hexStr.allSatisfy({ $0.isHexDigit }) {
                if let cp = UInt32(hexStr, radix: 16), let scalar = Unicode.Scalar(cp) {
                    acc.removeLast()
                    acc.append(Character(scalar))
                    index = hexEnd
                    return (true, getCharAt())
                }
            }
        }
        if JSONParser.stringDelimiters.contains(nextChar) && nextChar != rStringDelimiter {
            log("Found a delimiter that was escaped but shouldn't be escaped, removing the escape")
            acc.removeLast()
            acc.append(nextChar)
            index = jsonStr.index(after: index)
            return (true, getCharAt())
        }
        return (false, nextChar)
    }

    func handleRightDelimiterCandidate(
        _ stringAcc: inout String,
        char: Character,
        rStringDelimiter: Character,
        lStringDelimiter: Character,
        doubledQuotes: inout Bool,
        unmatchedDelimiter: inout Bool,
        missingQuotes: Bool = false
    ) -> (handled: Bool, newChar: Character?, shouldBreak: Bool) {

        // ── missing-quotes + objectValue: check if this " starts a new key ──
        if missingQuotes && context.current == .objectValue {
            var i = 1
            var nextC = getCharAt(count: i)
            while let nc = nextC, nc != rStringDelimiter && nc != lStringDelimiter {
                i += 1
                nextC = getCharAt(count: i)
            }
            if let _ = nextC {
                i += 1
                i = scrollWhitespaces(idx: i)
                if getCharAt(count: i) == ":" {
                    // This " starts a new key: back up one so finalize sees non-rstring-delimiter
                    if index > jsonStr.startIndex {
                        index = jsonStr.index(before: index)
                    }
                    let backChar = getCharAt()
                    log("In a string with missing quotes and object value context, I found a delimiter but it turns out it was the beginning of the next key. Stopping here.")
                    return (false, backChar, true)
                }
            }
            return (false, char, false)
        }

        // Doubled-quote close
        if doubledQuotes && getCharAt(count: 1) == rStringDelimiter {
            log("While parsing a string, we found a doubled quote, ignoring it")
            index = jsonStr.index(after: index)
            return (true, getCharAt(), false)
        }

        // unmatched delimiter flag: append as literal
        if unmatchedDelimiter {
            unmatchedDelimiter = false
            stringAcc.append(char)
            index = jsonStr.index(after: index)
            return (true, getCharAt(), false)
        }

        // Scan forward looking for the next delimiter or structural character
        var i = 1
        var nextC = getCharAt(count: i)
        var checkCommaInObjectValue = true
        while let nc = nextC, nc != rStringDelimiter && nc != lStringDelimiter {
            if checkCommaInObjectValue && nc.isLetter { checkCommaInObjectValue = false }
            if (context.context.contains(.objectKey) && (nc == ":" || nc == "}")) ||
               (context.context.contains(.objectValue) && nc == "}") ||
               (context.context.contains(.array) && (nc == "]" || nc == ",")) ||
               (checkCommaInObjectValue && context.current == .objectValue && nc == ",") {
                break
            }
            i += 1
            nextC = getCharAt(count: i)
        }

        // next structural char is a comma in object value context
        if nextC == "," && context.current == .objectValue {
            i += 1
            i = skipToCharacter([rStringDelimiter], idx: i)
            nextC = getCharAt(count: i)
            i += 1
            i = scrollWhitespaces(idx: i)
            nextC = getCharAt(count: i)
            if nextC == "}" || nextC == "," {
                log("While parsing a string, we found a misplaced quote that would have closed the string but has a different meaning here, ignoring it")
                stringAcc.append(char)
                index = jsonStr.index(after: index)
                return (true, getCharAt(), false)
            }
        } else if nextC == rStringDelimiter {
            // Only-whitespace check
            var onlyWhitespace = true
            for j in 1..<i {
                if let c = getCharAt(count: j), !c.isWhitespace { onlyWhitespace = false; break }
            }
            if onlyWhitespace {
                // check previous char isn't backslash
                let prevBackslash = getCharAt(count: i - 1) == "\\"
                if !prevBackslash {
                    // If we're in object value and a quoted member follows after this close, it's a misplaced quote
                    if context.current == .objectValue && quotedObjectMemberFollows(quoteIdx: i) {
                        // fall through – NOT a real close
                    } else {
                        return (false, char, true)  // shouldBreak – real closing delimiter
                    }
                }
            }

            if context.current == .objectValue {
                if quotedObjectMemberFollows(quoteIdx: i) {
                    log("While parsing a string, we found a misplaced quote that would have closed the string but has a different meaning here, ignoring it")
                    stringAcc.append(char)
                    index = jsonStr.index(after: index)
                    return (true, getCharAt(), false)
                }
                // look for further structure
                var k = skipToCharacter([rStringDelimiter], idx: i + 1)
                k += 1
                var kc = getCharAt(count: k)
                while let lkc = kc, lkc != ":" {
                    if lkc == "," || lkc == "]" || lkc == "}" || lkc == rStringDelimiter {
                        break
                    }
                    k += 1
                    kc = getCharAt(count: k)
                }
                if kc != ":" {
                    log("While parsing a string, we found a misplaced quote that would have closed the string but has a different meaning here, ignoring it")
                    unmatchedDelimiter = !unmatchedDelimiter
                    stringAcc.append(char)
                    index = jsonStr.index(after: index)
                    return (true, getCharAt(), false)
                }
            } else if context.current == .array {
                // count even delimiters
                var evenDelimiters = (nextC == rStringDelimiter)
                var k = i
                while getCharAt(count: k) == rStringDelimiter {
                    k = skipToCharacter([rStringDelimiter, "]"], idx: k + 1)
                    if getCharAt(count: k) != rStringDelimiter {
                        evenDelimiters = false; break
                    }
                    k = skipToCharacter([rStringDelimiter, "]"], idx: k + 1)
                }
                if evenDelimiters {
                    log("While parsing a string in Array context, we detected a quoted section that would have closed the string but has a different meaning here, ignoring it")
                    unmatchedDelimiter = !unmatchedDelimiter
                    stringAcc.append(char)
                    index = jsonStr.index(after: index)
                    return (true, getCharAt(), false)
                }
                return (false, char, true)
            } else if context.current == .objectKey {
                log("While parsing a string in Object Key context, we detected a quoted section that would have closed the string but has a different meaning here, ignoring it")
                stringAcc.append(char)
                index = jsonStr.index(after: index)
                return (true, getCharAt(), false)
            }
        }

        return (false, char, false)
    }

    /// Check if after `quoteIdx` there's `,` followed by a valid object member
    func quotedObjectMemberFollows(quoteIdx: Int) -> Bool {
        let commaIdx = scrollWhitespaces(idx: quoteIdx + 1)
        guard getCharAt(count: commaIdx) == "," else { return false }
        let memberIdx = scrollWhitespaces(idx: commaIdx + 1)
        return objectMemberStartsAt(memberIdx)
    }

    func objectMemberStartsAt(_ idx: Int) -> Bool {
        guard let c = getCharAt(count: idx) else { return false }
        if c == "}" { return false }
        if JSONParser.stringDelimiters.contains(c) {
            let keyEnd = skipToCharacter([c], idx: idx + 1)
            guard getCharAt(count: keyEnd) == c else { return false }
            let afterKey = scrollWhitespaces(idx: keyEnd + 1)
            return getCharAt(count: afterKey) == ":"
        }
        if c.isLetter || c == "_" {
            var k = idx
            while let kc = getCharAt(count: k), kc.isLetter || kc.isNumber || kc == "_" || kc == "-" { k += 1 }
            let after = scrollWhitespaces(idx: k)
            return getCharAt(count: after) == ":"
        }
        return false
    }

    /// Port of `_finalize_string_result`
    func finalizeStringResult(
        stringAcc: String,
        char: Character?,
        rStringDelimiter: Character,
        missingQuotes: Bool
    ) -> String {
        var result = stringAcc

        // LLM-comment corner case
        if let c = char, missingQuotes && context.current == .objectKey && c.isWhitespace {
            log("While parsing a string, handling an extreme corner case in which the LLM added a comment instead of valid string, invalidate the string and return an empty value")
            skipWhitespaces()
            let nextC = getCharAt()
            if nextC != ":" && nextC != "," {
                return ""
            }
        }

        if char != rStringDelimiter {
            if !streamStable {
                log("While parsing a string, we missed the closing quote, ignoring")
                result = String(result.drop(while: { _ in false }))  // no-op, just for clarity
                // rstrip
                while result.last?.isWhitespace == true { result.removeLast() }
            }
        } else {
            // consume closing delimiter
            if index < jsonStr.endIndex {
                index = jsonStr.index(after: index)
            }
            // skip trailing code fences
            skipTrailingCodeFences()
        }

        if !streamStable && (missingQuotes || result.last == "\n") {
            while result.last?.isWhitespace == true { result.removeLast() }
        }

        return result
    }

    /// Skip trailing ``` code fences and language tag
    func skipTrailingCodeFences() {
        if getCharAt() == "`" && getCharAt(count: 1) == "`" && getCharAt(count: 2) == "`" {
            log("Skipping trailing code fences after string")
            index = jsonStr.index(index, offsetBy: 3, limitedBy: jsonStr.endIndex) ?? jsonStr.endIndex
            while let c = getCharAt(), c.isLetter { index = jsonStr.index(after: index) }
            skipWhitespaces()
        }
    }

    // MARK: - Inline Container Stack

    /// Returns (pendingInlineContainer: Bool, keepChar: Bool)
    func updateInlineContainerStack(
        _ char: Character,
        stack: inout [Character]
    ) -> (pending: Bool, keepChar: Bool) {
        if let closingDelim = inlineContainerClosingDelimiters[char] {
            stack.append(closingDelim)
            return (false, false)
        }
        if !stack.isEmpty && char == stack.last {
            stack.removeLast()
            return (false, false)
        }
        return (false, false)
    }

    // MARK: - Comma Classification

    enum CommaClassification {
        case member
        case valueContent
    }

    func classifyObjectValueComma(missingQuotes: Bool) -> CommaClassification {
        var i = 1
        i = scrollWhitespaces(idx: i)
        let afterCommaChar = getCharAt(count: i)

        // } or end-of-input → closing separator
        if afterCommaChar == "}" || afterCommaChar == nil { return .member }

        // Quoted key: "key":
        if let ac = afterCommaChar, JSONParser.stringDelimiters.contains(ac) {
            let keyEnd = skipToCharacter([ac], idx: i + 1)
            if getCharAt(count: keyEnd) != nil {
                let afterKeyEnd = scrollWhitespaces(idx: keyEnd + 1)
                if getCharAt(count: afterKeyEnd) == ":" { return .member }
            }
            // Quoted string but no colon → "string" (valueContent)
            return .valueContent
        }

        // Backtick-prefixed bare key: `key:
        if afterCommaChar == "`" {
            var bareKeyIdx = i + 1
            while let kc = getCharAt(count: bareKeyIdx), kc.isLetter || kc.isNumber || kc == "_" || kc == "-" { bareKeyIdx += 1 }
            let afterKey = scrollWhitespaces(idx: bareKeyIdx)
            return getCharAt(count: afterKey) == ":" ? .member : .valueContent
        }

        // Unquoted key: bareword followed by colon
        if let ac = afterCommaChar, ac.isLetter || ac.isNumber || ac == "_" {
            var keyIdx = i
            while let kc = getCharAt(count: keyIdx), kc.isLetter || kc.isNumber || kc == "_" || kc == "-" { keyIdx += 1 }
            let afterKey = scrollWhitespaces(idx: keyIdx)
            if getCharAt(count: afterKey) == ":" { return .member }
        }

        // Fallback: scan ahead to the next string delimiter
        // If a "key": pattern exists ahead (even separated by prose), it's a member separator
        let nextQuoteIdx = skipToCharacter(JSONParser.stringDelimiters, idx: i)
        guard let nextQuote = getCharAt(count: nextQuoteIdx) else {
            return .valueContent   // "string" in Python
        }

        // If a container opener appears before the quote, treat as container (embedded inline value)
        let containerIdx = skipToCharacter(["{", "["], idx: i)
        if let cc = getCharAt(count: containerIdx), (cc == "{" || cc == "["), containerIdx < nextQuoteIdx {
            return .valueContent   // "container" in Python — keep comma
        }

        // Find closing quote of the potential key
        let keyEndIdx = skipToCharacter([nextQuote], idx: nextQuoteIdx + 1)
        guard getCharAt(count: keyEndIdx) != nil else {
            return .valueContent   // "string" — no closing quote found
        }
        let afterKeyClose = scrollWhitespaces(idx: keyEndIdx + 1)
        return getCharAt(count: afterKeyClose) == ":" ? .member : .valueContent
    }
}

