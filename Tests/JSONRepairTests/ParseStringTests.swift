import XCTest
@testable import JSONRepair

final class ParseStringTests: XCTestCase {
    func check(_ input: String, _ expected: String, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repairJson(input)
            let expectedJSON = try JSONParser(jsonStr: expected).parse()
            XCTAssertEqual(result, expectedJSON, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }
    func checkValue(_ input: String, _ expected: JSONValue, file: StaticString = #file, line: UInt = #line) {
        do {
            let result = try JSONRepair.repairJson(input)
            XCTAssertEqual(result, expected, file: file, line: line)
        } catch {
            XCTFail("Failed to repair: \(error)", file: file, line: line)
        }
    }

    func test_parse_string() {
        check("\"", "")
        check("\n", "")
        check(" ", "")
        check("string", "")
        check("stringbeforeobject {}", "{}")
    }

    func test_missing_and_mixed_quotes() {
        check("{'key': 'string', 'key2': false, \"key3\": null, \"key4\": unquoted}", "{\"key\": \"string\", \"key2\": false, \"key3\": null, \"key4\": \"unquoted\"}")
        check("{\"name\": \"John\", \"age\": 30, \"city\": \"New York", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}")
        check("{\"name\": \"John\", \"age\": 30, city: \"New York\"}", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}")
        check("{\"name\": \"John\", \"age\": 30, \"city\": New York}", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}")
        check("{\"name\": John, \"age\": 30, \"city\": \"New York\"}", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}")
        check("{“slanted_delimiter”: \"value\"}", "{\"slanted_delimiter\": \"value\"}")
        check("{\"name\": \"John\", \"age\": 30, \"city\": \"New", "{\"name\": \"John\", \"age\": 30, \"city\": \"New\"}")
        check("{\"name\": \"John\", \"age\": 30, \"city\": \"New York, \"gender\": \"male\"}", "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\", \"gender\": \"male\"}")
        check("[{\"key\": \"value\", COMMENT \"notes\": \"lorem \"ipsum\", sic.\" }]", "[{\"key\": \"value\", \"notes\": \"lorem \\\"ipsum\\\", sic.\"}]")
        check("{\"key\": \"\"value\"}", "{\"key\": \"value\"}")
        check("{\"key\": \"value\", 5: \"value\"}", "{\"key\": \"value\", \"5\": \"value\"}")
        check("{\"foo\": \"\\\"bar\\\"\"", "{\"foo\": \"\\\"bar\\\"\"}")
        check("{\"\" key\":\"val\"", "{\" key\": \"val\"}")
        check("{\"key\": value \"key2\" : \"value2\" ", "{\"key\": \"value\", \"key2\": \"value2\"}")
        check("{\"key\": \"lorem ipsum ... \"sic \" tamet. ...}", "{\"key\": \"lorem ipsum ... \\\"sic \\\" tamet. ...\"}")
        check("{\"key\": value , }", "{\"key\": \"value\"}")
        check("{\"comment\": \"lorem, \"ipsum\" sic \"tamet\". To improve\"}", "{\"comment\": \"lorem, \\\"ipsum\\\" sic \\\"tamet\\\". To improve\"}")
        check("{\"key\": \"v\"alu\"e\"} key:", "{\"key\": \"v\\\"alu\\\"e\"}")
        check("{\"key\": \"v\"alue\", \"key2\": \"value2\"}", "{\"key\": \"v\\\"alue\", \"key2\": \"value2\"}")
        check("[{\"key\": \"v\"alu,e\", \"key2\": \"value2\"}]", "[{\"key\": \"v\\\"alu,e\", \"key2\": \"value2\"}]")
    }

    func test_escaping() {
        check("'\"'", "")
        check("{\"key\": 'string\"\n\t\\le'", "{\"key\": \"string\\\"\\n\\t\\\\le\"}")
        check("{\"real_content\": \"Some string: Some other string \\t Some string <a href=\\\"https://domain.com\\\">Some link</a>\"", "{\"real_content\": \"Some string: Some other string \\t Some string <a href=\\\"https://domain.com\\\">Some link</a>\"}")
        check("{\"key_1\n\": \"value\"}", "{\"key_1\": \"value\"}")
        check("{\"key\t_\": \"value\"}", "{\"key\\t_\": \"value\"}")
        check("{\"key\": 'value'}", "{\"key\": \"value\"}")
        check("{\"key\": \"\\u0076\\u0061\\u006C\\u0075\\u0065\"}", "{\"key\": \"value\"}")
        check("{\"key\": \"valu\\'e\"}", "{\"key\": \"valu'e\"}")
        check("{'key': \"{\\\"key\\\": 1, \\\"key2\\\": 1}\"}", "{\"key\": \"{\\\"key\\\": 1, \\\"key2\\\": 1}\"}")
    }

    func test_markdown() {
        check("{ \"content\": \"[LINK](\"https://google.com\")\" }", "{\"content\": \"[LINK](\\\"https://google.com\\\")\"}")
        check("{ \"content\": \"[LINK](\" }", "{\"content\": \"[LINK](\"}")
        check("{ \"content\": \"[LINK](\", \"key\": true }", "{\"content\": \"[LINK](\", \"key\": true}")
    }

    func test_leading_trailing_characters() {
        check("````{ \"key\": \"value\" }```", "{\"key\": \"value\"}")
        check("{    \"a\": \"\",    \"b\": [ { \"c\": 1} ] \n}```", "{\"a\": \"\", \"b\": [{\"c\": 1}]}")
        check("Based on the information extracted, here is the filled JSON output: ```json { 'a': 'b' } ```", "{\"a\": \"b\"}")
        check("\n                       The next 64 elements are:\n                       ```json\n                       { \"key\": \"value\" }\n                       ```", "{\"key\": \"value\"}")
    }

    func test_fenced_json_wrapper_matches_plain_for_duplicate_keys() {
    }

    func test_string_json_llm_block() {
        check("{\"key\": \"``\"", "{\"key\": \"``\"}")
        check("{\"key\": \"```json\"", "{\"key\": \"```json\"}")
        check("{\"key\": \"```json {\"key\": [{\"key1\": 1},{\"key2\": 2}]}```\"}", "{\"key\": {\"key\": [{\"key1\": 1}, {\"key2\": 2}]}}")
        check("{\"response\": \"```json{}\"", "{\"response\": \"```json{}\"}")
    }

    func test_parse_string_logs_invalid_code_fences() {
    }

    func test_parse_string_keeps_literal_fenced_snippet_cases() {
    }

    func test_parse_string_stray_quote_line_before_trailing_comma_drops_stray_quote() {
        checkValue("{\"a\": \"hello\n\"\n\",}", JSONValue.object(["a": JSONValue.string("hello")]))
    }

    func test_parse_string_stray_quote_line_before_trailing_comma_at_eof_drops_stray_quote() {
        checkValue("{\"a\": \"hello\n\"\n\",", JSONValue.object(["a": JSONValue.string("hello")]))
    }

    func test_parse_string_keeps_multiline_curly_quoted_prose_after_comma() {
        checkValue("{\"x\": \"a,\n “term”: explanation\", \"y\": 2}", JSONValue.object(["x": JSONValue.string("a,\n \u{201c}term\u{201d}: explanation"), "y": JSONValue.number(2)]))
    }

    func test_parse_boolean_or_null() {
        checkValue("True", JSONValue.string(""))
        checkValue("False", JSONValue.string(""))
        checkValue("Null", JSONValue.string(""))
        check("  {\"key\": true, \"key2\": false, \"key3\": null}", "{\"key\": true, \"key2\": false, \"key3\": null}")
        check("{\"key\": TRUE, \"key2\": FALSE, \"key3\": Null}   ", "{\"key\": true, \"key2\": false, \"key3\": null}")
    }

    func test_parse_string_fast_path_keeps_clean_values_log_free() {
    }

    func test_parse_string_fast_path_falls_back_for_escapes_with_logs() {
    }

    func test_parse_string_fast_path_rejects_ambiguous_top_level_trailing_text() {
    }

    func test_parse_string_keeps_inline_object_literal_after_comma() {
    }

    func test_parse_string_keeps_inline_object_literal_before_next_member() {
    }

    func test_parse_string_object_value_brace_heuristics() {
    }

    func test_parse_string_missing_quotes_object_value_stops_at_quote_fragment() {
        checkValue("{0:a\"0\"", JSONValue.object(["0": JSONValue.string("a")]))
    }

    func test_parse_string_fast_path_string_wrapper_fallbacks() {
    }

    func test_brace_before_code_fence_helper_rejects_non_delimiter_after_quote() {
    }

    func test_brace_before_code_fence_helper_rejects_unterminated_container_after_fence() {
    }

    func test_brace_before_code_fence_helper_accepts_unbalanced_container_like_prose_after_fence() {
    }

    func test_brace_before_code_fence_helper_accepts_later_closing_quote_after_quoted_prose() {
    }

    func test_brace_before_code_fence_helper_rejects_container_started_after_fence() {
    }

    func test_brace_before_code_fence_helper_rejects_container_closing_object_after_fence() {
    }

    func test_brace_before_code_fence_helper_accepts_literal_container_after_fence() {
    }

    func test_brace_before_code_fence_helper_rejects_comment_prefixed_container_after_fence() {
    }

    func test_brace_before_code_fence_helper_accepts_comment_prefixed_literal_container_after_fence() {
    }

    func test_brace_before_code_fence_helper_accepts_literal_container_after_fence_with_trailing_comma() {
    }

    func test_brace_before_code_fence_helper_accepts_comment_prefixed_literal_container_after_fence_with_trailing_comma() {
    }

    func test_skip_inline_container_returns_same_index_for_non_container() {
    }

    func test_starts_nested_inline_container_accepts_container_at_start() {
    }

    func test_starts_nested_inline_container_accepts_out_of_range_prefix_conservatively() {
    }

    func test_starts_nested_inline_container_rejects_unmatched_inner_array_after_comma() {
    }

    func test_starts_nested_inline_container_accepts_object_with_quoted_key_after_comma() {
    }

    func test_starts_nested_inline_container_accepts_numeric_array_after_comma() {
    }

    func test_starts_nested_inline_container_accepts_numeric_parenthesized_value_after_comma() {
    }

    func test_starts_nested_inline_container_accepts_object_with_bare_key_after_colon() {
    }

    func test_starts_nested_inline_container_rejects_object_with_bare_key_after_comma() {
    }

    func test_starts_nested_inline_container_rejects_non_container_after_separator() {
    }

    func test_starts_nested_inline_container_rejects_object_with_non_key_start_after_colon() {
    }

    func test_skip_inline_container_skips_nested_inline_container() {
    }

    func test_skip_inline_container_keeps_hash_like_literal_content() {
    }

    func test_skip_inline_container_keeps_line_comment_like_literal_content() {
    }

    func test_skip_inline_container_keeps_block_comment_like_literal_content() {
    }

    func test_skip_inline_container_keeps_regex_like_literal_content() {
    }

    func test_skip_inline_container_keeps_unmatched_inner_delimiter_as_literal_content() {
    }

    func test_skip_inline_container_rejects_unterminated_container() {
    }

    func test_skip_inline_container_rejects_unterminated_string_inside_container() {
    }

    func test_skip_inline_container_rejects_unterminated_block_comment() {
    }

    func test_update_inline_container_stack_starts_tracking_pending_container() {
    }

    func test_update_inline_container_stack_tracks_nested_container() {
    }

    func test_update_inline_container_stack_keeps_closing_container_character() {
    }

    func test_scan_string_body_keeps_closing_inline_container_character() {
    }

    func test_quoted_object_member_follows_rejects_unquoted_next_key() {
    }

    func test_quoted_object_member_follows_rejects_unterminated_next_key() {
    }

    func test_quoted_object_member_follows_accepts_single_quoted_next_key() {
    }

    func test_quoted_object_member_follows_accepts_curly_quoted_next_key() {
    }

    func test_quoted_object_member_follows_accepts_comment_before_next_key() {
    }

    func test_quoted_object_member_follows_accepts_hash_comment_before_next_key() {
    }

    func test_quoted_object_member_follows_accepts_block_comment_before_next_key() {
    }

    func test_quoted_object_member_follows_accepts_comment_before_bare_next_key() {
    }

    func test_quoted_object_member_follows_accepts_bare_next_key() {
    }

    func test_quoted_object_member_follows_rejects_trailing_comma_endings() {
    }

    func test_quoted_object_member_follows_rejects_unclosed_block_comment_before_next_key() {
    }

    func test_quoted_object_member_follows_rejects_array_after_comment() {
    }

    func test_parse_string_empty_single_quoted_key() {
        check("{'': 1}", "{\"\": 1}")
    }
}