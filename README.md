# JSONRepair (Swift)

A Swift port of the Python [json_repair](https://github.com/mangiucugna/json_repair) library. Repairs malformed JSON strings using heuristics — missing quotes, trailing commas, unquoted keys, LLM code fences, and more.

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kebbbnnn/JSONRepair.git", from: "1.0.0")
]
```

Then add `"JSONRepair"` to your target's dependencies.

## Usage

````swift
import JSONRepair

// Basic repair — returns a type-safe JSONValue enum
let result = try JSONRepair.repair(json: #"{"key": "value",}"#)
// → .object(["key": .string("value")])

// Handles broken LLM output (input may contain ```json ... ``` code fences)
let llmOutput = """
    Here is the JSON:
    ```json
    {"name": "Alice", "age": 30,}
    ```
    """
let repaired = try JSONRepair.repair(json: llmOutput)
// → .object(["name": .string("Alice"), "age": .number(30)])

// Strict mode — throws instead of repairing
do {
    let _ = try JSONRepair.repair(json: #"{"key" "value"}"#, strict: true)
} catch {
    print(error) // Missing ':' after key
}

// Stream-stable mode — for incremental streaming JSON
let partial = try JSONRepair.repair(json: #"{"key": "val\n"#, streamStable: true)
// → .object(["key": .string("val\n")])
````

## API

### `JSONRepair.repair(json:strict:logging:streamStable:)`

```swift
public static func repair(
    json: String,
    strict: Bool = false,
    logging: Bool = false,
    streamStable: Bool = false
) throws -> JSONValue
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `json` | — | The malformed JSON string to repair |
| `strict` | `false` | Throw errors on structural issues instead of repairing |
| `logging` | `false` | Enable repair action logging (access via `JSONParser.logger`) |
| `streamStable` | `false` | Stable repairs for incrementally-streamed JSON |

### `JSONValue`

```swift
public enum JSONValue: Equatable, Hashable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
}
```

Use `.rawValue` to convert back to Foundation types (`[String: Any]`, `[Any]`, etc.).

## What it repairs

- Missing or mismatched quotes (`'single'`, `"curly"`, unquoted keys)
- Trailing commas, missing commas
- Missing colons between keys and values
- Unclosed objects/arrays/strings
- LLM markdown code fences (`` ```json `` / `` ``` ``)
- Python-style tuples `(1, 2, 3)`
- Comments (`//`, `/* */`, `#`)
- Boolean/null literals (`True` → `true`, `None` → `null`)
- Set-like braces (`{'a', 'b'}` → `["a", "b"]`)

## Tests

```bash
swift test
# 140 tests, 0 failures
```

## License

MIT — see [LICENSE](LICENSE). Original Python library by Stefano Baccianella.

## Credit

Ported from [json_repair](https://github.com/mangiucugna/json_repair) by Stefano Baccianella.

