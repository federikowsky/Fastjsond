/**
 * fastjsond Benchmark Suite - Extended Edition
 * 
 * Compares performance of:
 * - std.json (D standard library)
 * - fastjsond.std (compatibility layer)
 * - fastjsond native (zero-copy)
 *
 * Categories:
 * - Simple/Medium/Complex JSON
 * - Edge cases (unicode, escapes, whitespace)
 * - Stress tests (MB/GB payloads)
 * - Pathological cases
 */
module benchmarks.benchmark;

import std.stdio;
import std.datetime.stopwatch;
import std.format;
import std.array;
import std.range;
import std.conv;
import std.algorithm : map, sum, min;
import std.random;
import std.utf;
import core.memory : GC;

// Standard library JSON
import std.json;

// fastjsond
import fastjsond;
import fastjsond.std;

void main(string[] args) {
    bool runHeavy = false;
    bool runExtreme = false;
    
    foreach (arg; args[1 .. $]) {
        if (arg == "--heavy" || arg == "-h") runHeavy = true;
        if (arg == "--extreme" || arg == "-e") runExtreme = true;
        if (arg == "--all" || arg == "-a") { runHeavy = true; runExtreme = true; }
    }
    
    writeln("╔══════════════════════════════════════════════════════════════════════════╗");
    writeln("║              fastjsond Benchmark Suite - Extended Edition                ║");
    writeln("║      Comparing: std.json vs fastjsond.std vs fastjsond native            ║");
    writeln("╠══════════════════════════════════════════════════════════════════════════╣");
    writefln("║  Heavy tests: %-5s  |  Extreme tests: %-5s                              ║", 
             runHeavy ? "ON" : "OFF", runExtreme ? "ON" : "OFF");
    writeln("║  Use --heavy, --extreme, or --all to enable more tests                   ║");
    writeln("╚══════════════════════════════════════════════════════════════════════════╝");
    writeln();
    
    // Warm up
    warmUp();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 1: Basic Tests
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("BASIC TESTS");
    
    benchmarkTiny();
    benchmarkSimple();
    benchmarkMedium();
    benchmarkComplex();
    benchmarkVeryComplex();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 2: Edge Cases
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("EDGE CASES");
    
    benchmarkEmptyStructures();
    benchmarkUnicodeHeavy();
    benchmarkEscapeHeavy();
    benchmarkWhitespaceHeavy();
    benchmarkNumberEdgeCases();
    benchmarkLongStrings();
    benchmarkDeepNesting();
    benchmarkWideObject();
    benchmarkSparseArray();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 3: Iteration & Access Patterns
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("ITERATION & ACCESS PATTERNS");
    
    benchmarkArrayIteration();
    benchmarkObjectIteration();
    benchmarkRandomAccess();
    benchmarkSequentialAccess();
    benchmarkMixedAccess();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 4: Realistic Payloads
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("REALISTIC PAYLOADS");
    
    benchmarkTwitter();
    benchmarkGitHub();
    benchmarkEcommerce();
    benchmarkGeoJSON();
    benchmarkLogEntry();
    benchmarkConfig();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 5: Stress Tests (Medium)
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("STRESS TESTS");
    
    benchmarkRecords1K();
    benchmarkRecords10K();
    benchmarkLargeArray10K();
    benchmarkLargeArray50K();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 6: Heavy Tests (MB payloads)
    // ═══════════════════════════════════════════════════════════════════════════
    if (runHeavy) {
        printSection("HEAVY TESTS (MB Payloads)");
        writeln("  ⚠ Each payload is parsed ONCE - measuring single-parse latency");
        writeln();
        
        benchmark1MB();
        benchmark5MB();
        benchmark10MB();
        benchmark50MB();
        benchmark100MB();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 7: Extreme Tests (GB payloads)
    // ═══════════════════════════════════════════════════════════════════════════
    if (runExtreme) {
        printSection("EXTREME TESTS (GB Payloads)");
        writeln("  ⚠ Warning: These tests require significant memory (16GB+ recommended)!");
        writeln("  ⚠ Each payload is parsed ONCE - measuring single-parse latency");
        writeln();
        
        benchmark500MB();
        benchmark1GB();
        // benchmark2GB();
        // benchmark5GB();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 8: Pathological Cases
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("PATHOLOGICAL CASES");
    
    benchmarkDeeplyNested50();
    benchmarkVeryLongString();
    benchmarkManySmallStrings();
    benchmarkAlternatingTypes();
    benchmarkRepeatedKeys();
    benchmarkNumericStrings();
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SECTION 9: Error Handling
    // ═══════════════════════════════════════════════════════════════════════════
    printSection("ERROR HANDLING");
    
    benchmarkInvalidJSON();
    benchmarkTruncatedJSON();
    benchmarkUnterminatedStrings();
    benchmarkInvalidNumbers();
    benchmarkTrailingContent();
    benchmarkControlCharacters();
    benchmarkInvalidEscapes();
    benchmarkInvalidUnicode();
    benchmarkMixedErrors();
    
    writeln();
    writeln("═══════════════════════════════════════════════════════════════════════════");
    writeln("  Benchmark complete!");
    writeln("═══════════════════════════════════════════════════════════════════════════");
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

void printSection(string name) {
    writeln();
    writeln("═══════════════════════════════════════════════════════════════════════════");
    writefln("  %s", name);
    writeln("═══════════════════════════════════════════════════════════════════════════");
    writeln();
}

void warmUp() {
    write("Warming up... ");
    stdout.flush();
    
    auto simpleJson = `{"test": 123}`;
    
    foreach (_; 0 .. 1000) {
        auto j = std.json.parseJSON(simpleJson);
    }
    
    foreach (_; 0 .. 1000) {
        auto j = fastjsond.std.parseJSON(simpleJson);
    }
    
    auto parser = Parser.create();
    foreach (_; 0 .. 1000) {
        auto doc = parser.parse(simpleJson);
    }
    
    writeln(" done.\n");
}

struct BenchResult {
    string name;
    Duration stdJson;
    Duration fastjsondStd;
    Duration fastjsondNative;
    size_t iterations;
    size_t dataSize;
}

string formatSize(size_t bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
        return format("%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0));
    } else if (bytes >= 1024 * 1024) {
        return format("%.2f MB", bytes / (1024.0 * 1024.0));
    } else if (bytes >= 1024) {
        return format("%.2f KB", bytes / 1024.0);
    } else {
        return format("%d B", bytes);
    }
}

void printResult(BenchResult r) {
    auto stdMs = r.stdJson.total!"usecs" / 1000.0;
    auto fastStdMs = r.fastjsondStd.total!"usecs" / 1000.0;
    auto fastNativeMs = r.fastjsondNative.total!"usecs" / 1000.0;
    
    auto speedupStd = stdMs / fastStdMs;
    auto speedupNative = stdMs / fastNativeMs;
    
    double throughputStd = 0, throughputFastStd = 0, throughputNative = 0;
    
    if (r.stdJson.total!"usecs" > 0) {
        throughputStd = (r.dataSize * r.iterations) / (r.stdJson.total!"usecs" / 1_000_000.0) / 1024 / 1024;
    }
    if (r.fastjsondStd.total!"usecs" > 0) {
        throughputFastStd = (r.dataSize * r.iterations) / (r.fastjsondStd.total!"usecs" / 1_000_000.0) / 1024 / 1024;
    }
    if (r.fastjsondNative.total!"usecs" > 0) {
        throughputNative = (r.dataSize * r.iterations) / (r.fastjsondNative.total!"usecs" / 1_000_000.0) / 1024 / 1024;
    }
    
    writeln("───────────────────────────────────────────────────────────────────────────");
    writefln("  %s", r.name);
    writefln("  Payload: %s  |  Iterations: %s  |  Total: %s", 
             formatSize(r.dataSize), r.iterations, formatSize(r.dataSize * r.iterations));
    writeln("───────────────────────────────────────────────────────────────────────────");
    
    writefln("  %-20s %12.2f ms  %10.1f MB/s", "std.json:", stdMs, throughputStd);
    writefln("  %-20s %12.2f ms  %10.1f MB/s  (%.1fx faster)", 
             "fastjsond.std:", fastStdMs, throughputFastStd, speedupStd);
    writefln("  %-20s %12.2f ms  %10.1f MB/s  (%.1fx faster)", 
             "fastjsond native:", fastNativeMs, throughputNative, speedupNative);
    writeln();
}

// Helper to run benchmark (always runs all parsers)
BenchResult runBench(string name, string json, size_t iterations, 
                     void delegate(std.json.JSONValue) stdWork = null,
                     void delegate(fastjsond.std.JSONValue) fastStdWork = null,
                     void delegate(Value) nativeWork = null) {
    
    Duration sw1, sw2, sw3;
    
    // Collect garbage before each test
    GC.collect();
    
    // std.json
    {
        auto t1 = StopWatch(AutoStart.yes);
        foreach (_; 0 .. iterations) {
            auto j = std.json.parseJSON(json);
            if (stdWork !is null) stdWork(j);
        }
        t1.stop();
        sw1 = t1.peek;
    }
    
    GC.collect();
    
    // fastjsond.std
    {
        auto t2 = StopWatch(AutoStart.yes);
        foreach (_; 0 .. iterations) {
            auto j = fastjsond.std.parseJSON(json);
            if (fastStdWork !is null) fastStdWork(j);
        }
        t2.stop();
        sw2 = t2.peek;
    }
    
    GC.collect();
    
    // fastjsond native
    auto parser = Parser.create();
    {
        auto t3 = StopWatch(AutoStart.yes);
        foreach (_; 0 .. iterations) {
            auto doc = parser.parse(json);
            if (nativeWork !is null) nativeWork(doc.root);
        }
        t3.stop();
        sw3 = t3.peek;
    }
    
    auto result = BenchResult(name, sw1, sw2, sw3, iterations, json.length);
    printResult(result);
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 1: Basic Tests
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkTiny() {
    runBench("Tiny JSON (minimal)", `{}`, 200_000);
}

void benchmarkSimple() {
    enum json = `{"name": "test", "value": 42, "active": true}`;
    runBench("Simple JSON (small object)", json, 100_000,
        (j) { auto x = j["name"].str; },
        (j) { auto x = j["name"].str; },
        (v) { auto x = v["name"].getString; }
    );
}

void benchmarkMedium() {
    enum json = `{
        "user": {"id": 12345, "name": "John Doe", "email": "john@example.com"},
        "settings": {"theme": "dark", "notifications": true},
        "tags": ["developer", "premium", "active"]
    }`;
    runBench("Medium JSON (nested object)", json, 50_000);
}

void benchmarkComplex() {
    enum json = `{
        "api_version": "2.0",
        "data": {
            "users": [
                {"id": 1, "name": "Alice", "role": "admin"},
                {"id": 2, "name": "Bob", "role": "user"},
                {"id": 3, "name": "Charlie", "role": "user"}
            ],
            "metadata": {"total": 3, "page": 1}
        }
    }`;
    runBench("Complex JSON (API response)", json, 30_000);
}

void benchmarkVeryComplex() {
    auto json = generateEcommerceOrder();
    runBench("Very Complex JSON (e-commerce)", json, 10_000);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 2: Edge Cases
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkEmptyStructures() {
    enum json = `{"a": [], "b": {}, "c": [[]], "d": {"e": {}}, "f": [{}]}`;
    runBench("Empty Structures", json, 100_000);
}

void benchmarkUnicodeHeavy() {
    // Mix of ASCII, Latin, Cyrillic, CJK, Emoji
    enum json = `{
        "english": "Hello World",
        "spanish": "¡Hola Mundo!",
        "russian": "Привет мир",
        "chinese": "你好世界",
        "japanese": "こんにちは世界",
        "korean": "안녕하세요 세계",
        "arabic": "مرحبا بالعالم",
        "emoji": "🎉🚀💻🔥✨🌍🎯💡",
        "mixed": "Hello 世界 Мир 🌍"
    }`;
    runBench("Unicode Heavy", json, 50_000);
}

void benchmarkEscapeHeavy() {
    enum json = `{
        "quotes": "He said \"Hello\" and she said \"Hi\"",
        "backslash": "C:\\Users\\test\\file.txt",
        "newlines": "Line1\nLine2\nLine3\nLine4\nLine5",
        "tabs": "Col1\tCol2\tCol3\tCol4",
        "unicode_esc": "\u0048\u0065\u006C\u006C\u006F",
        "mixed": "Path: \"C:\\test\\\"\nNew line\there"
    }`;
    runBench("Escape Heavy", json, 50_000);
}

void benchmarkWhitespaceHeavy() {
    // Lots of whitespace
    auto json = "{\n" ~
        "    \"key1\"   :   \"value1\"   ,\n" ~
        "    \"key2\"   :   \"value2\"   ,\n" ~
        "    \"key3\"   :   \"value3\"   ,\n" ~
        "    \"array\"  :   [\n" ~
        "        1   ,\n" ~
        "        2   ,\n" ~
        "        3   \n" ~
        "    ]   ,\n" ~
        "    \"nested\" :   {\n" ~
        "        \"a\"  :  1  ,\n" ~
        "        \"b\"  :  2  \n" ~
        "    }\n" ~
        "}";
    runBench("Whitespace Heavy", json, 50_000);
}

void benchmarkNumberEdgeCases() {
    enum json = `{
        "zero": 0,
        "neg_zero": -0,
        "one": 1,
        "neg_one": -1,
        "max_safe_int": 9007199254740991,
        "min_safe_int": -9007199254740991,
        "pi": 3.141592653589793,
        "e": 2.718281828459045,
        "tiny": 0.000000001,
        "huge": 9999999999999999999,
        "scientific": 1.23e10,
        "neg_scientific": -4.56e-7,
        "long_decimal": 1.23456789012345678901234567890
    }`;
    runBench("Number Edge Cases", json, 50_000);
}

void benchmarkLongStrings() {
    // 1KB string
    auto longStr = myReplicate("x", 1024);
    auto json = format(`{"long_string": "%s"}`, longStr);
    runBench("Long String (1KB)", json, 20_000);
}

void benchmarkDeepNesting() {
    auto json = generateDeepNested(30);
    runBench("Deep Nesting (30 levels)", json, 20_000);
}

void benchmarkWideObject() {
    auto json = generateManyFields(200);
    runBench("Wide Object (200 fields)", json, 10_000);
}

void benchmarkSparseArray() {
    // Array with lots of nulls
    auto app = appender!string();
    app.put("[");
    foreach (i; 0 .. 1000) {
        if (i > 0) app.put(",");
        if (i % 10 == 0) {
            app.put(format(`{"id": %d}`, i));
        } else {
            app.put("null");
        }
    }
    app.put("]");
    runBench("Sparse Array (90% null)", app.data, 5_000);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 3: Iteration & Access Patterns
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkArrayIteration() {
    auto json = generateLargeArray(500);
    runBench("Array Iteration (500 items)", json, 500,
        (j) { long sum = 0; foreach (item; j.array) sum += item["value"].integer; },
        (j) { long sum = 0; foreach (ref item; j.array) sum += item["value"].integer; },
        (v) { long sum = 0; foreach (item; v) sum += item["value"].getInt; }
    );
}

void benchmarkObjectIteration() {
    auto json = generateManyFields(100);
    runBench("Object Iteration (100 fields)", json, 5_000,
        (j) { long sum = 0; foreach (k, v; j.object) sum += v.integer; },
        (j) { long sum = 0; foreach (string k, ref v; j.object) sum += v.integer; },
        (v) { long sum = 0; foreach (const(char)[] k, val; v) sum += val.getInt; }
    );
}

void benchmarkRandomAccess() {
    auto json = generateManyFields(100);
    runBench("Random Access Pattern", json, 10_000,
        (j) { 
            auto a = j["field_7"].integer;
            auto b = j["field_93"].integer;
            auto c = j["field_42"].integer;
        },
        (j) { 
            auto a = j["field_7"].integer;
            auto b = j["field_93"].integer;
            auto c = j["field_42"].integer;
        },
        (v) { 
            auto a = v["field_7"].getInt;
            auto b = v["field_93"].getInt;
            auto c = v["field_42"].getInt;
        }
    );
}

void benchmarkSequentialAccess() {
    auto json = generateManyFields(100);
    runBench("Sequential Access Pattern", json, 10_000,
        (j) { 
            auto a = j["field_0"].integer;
            auto b = j["field_1"].integer;
            auto c = j["field_2"].integer;
        },
        (j) { 
            auto a = j["field_0"].integer;
            auto b = j["field_1"].integer;
            auto c = j["field_2"].integer;
        },
        (v) { 
            auto a = v["field_0"].getInt;
            auto b = v["field_1"].getInt;
            auto c = v["field_2"].getInt;
        }
    );
}

void benchmarkMixedAccess() {
    enum json = `{
        "users": [{"id": 1, "name": "A"}, {"id": 2, "name": "B"}],
        "config": {"debug": true, "level": 5},
        "tags": ["a", "b", "c"]
    }`;
    runBench("Mixed Access Pattern", json, 20_000,
        (j) { 
            auto id = j["users"][0]["id"].integer;
            auto debug_ = j["config"]["debug"].type == std.json.JSONType.true_;
            auto tag = j["tags"][1].str;
        },
        (j) { 
            auto id = j["users"][0]["id"].integer;
            auto debug_ = j["config"]["debug"].boolean;
            auto tag = j["tags"][1].str;
        },
        (v) { 
            auto id = v["users"][0]["id"].getInt;
            auto debug_ = v["config"]["debug"].getBool;
            auto tag = v["tags"][1].getString;
        }
    );
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 4: Realistic Payloads
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkTwitter() {
    auto json = generateTwitterPayload();
    runBench("Twitter-like Payload", json, 10_000);
}

void benchmarkGitHub() {
    auto json = generateGitHubPayload();
    runBench("GitHub-like Payload", json, 10_000);
}

void benchmarkEcommerce() {
    auto json = generateEcommerceOrder();
    runBench("E-commerce Order", json, 10_000);
}

void benchmarkGeoJSON() {
    auto json = generateGeoJSON(50);
    runBench("GeoJSON (50 points)", json, 5_000);
}

void benchmarkLogEntry() {
    auto json = generateLogEntries(100);
    runBench("Log Entries (100)", json, 2_000);
}

void benchmarkConfig() {
    enum json = `{
        "app": {
            "name": "MyApp",
            "version": "1.2.3",
            "environment": "production"
        },
        "database": {
            "host": "localhost",
            "port": 5432,
            "name": "mydb",
            "pool": {"min": 5, "max": 20}
        },
        "cache": {
            "enabled": true,
            "ttl": 3600,
            "provider": "redis"
        },
        "features": {
            "feature_a": true,
            "feature_b": false,
            "feature_c": true
        }
    }`;
    runBench("Config File", json, 20_000);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 5: Stress Tests
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkRecords1K() {
    auto json = generateLargeDataset(1_000);
    runBench("1K Records", json, 100);
}

void benchmarkRecords10K() {
    auto json = generateLargeDataset(10_000);
    runBench("10K Records", json, 10);
}

void benchmarkLargeArray10K() {
    auto json = generateNumberArray(10_000);
    runBench("Large Array (10K numbers)", json, 200);
}

void benchmarkLargeArray50K() {
    auto json = generateNumberArray(50_000);
    runBench("Large Array (50K numbers)", json, 50);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 6: Heavy Tests (MB payloads)
// ═══════════════════════════════════════════════════════════════════════════

void benchmark1MB() {
    writeln("  Generating 1 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(1);  // 1 MB
    runBench("1 MB Payload", json, 1);
}

void benchmark5MB() {
    writeln("  Generating 5 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(5);  // 5 MB
    runBench("5 MB Payload", json, 1);
}

void benchmark10MB() {
    writeln("  Generating 10 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(10);  // 10 MB
    runBench("10 MB Payload", json, 1);
}

void benchmark50MB() {
    writeln("  Generating 50 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(50);  // 50 MB
    runBench("50 MB Payload", json, 1);
}

void benchmark100MB() {
    writeln("  Generating 100 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(100);  // 100 MB
    runBench("100 MB Payload", json, 1);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 7: Extreme Tests (GB payloads)
// ═══════════════════════════════════════════════════════════════════════════

void benchmark500MB() {
    writeln("  Generating 500 MB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(500);  // 500 MB
    runBench("500 MB Payload", json, 1);
}

void benchmark1GB() {
    writeln("  Generating 1 GB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(1024);  // 1 GB
    runBench("1 GB Payload", json, 1);
}

void benchmark2GB() {
    writeln("  Generating 2 GB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(2048);  // 2 GB
    runBench("2 GB Payload", json, 1);
}

void benchmark5GB() {
    writeln("  Generating 5 GB payload...");
    stdout.flush();
    auto json = generateExactSizePayload(5120);  // 5 GB
    runBench("5 GB Payload", json, 1);
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 8: Pathological Cases
// ═══════════════════════════════════════════════════════════════════════════

void benchmarkDeeplyNested50() {
    auto json = generateDeepNested(50);
    runBench("Deeply Nested (50 levels)", json, 10_000);
}

void benchmarkVeryLongString() {
    auto longStr = myReplicate("x", 100_000);  // 100KB string
    auto json = format(`{"long": "%s"}`, longStr);
    runBench("Very Long String (100KB)", json, 100);
}

void benchmarkManySmallStrings() {
    // 1000 small strings
    auto app = appender!string();
    app.put("{");
    foreach (i; 0 .. 1000) {
        if (i > 0) app.put(",");
        app.put(format(`"k%d": "v%d"`, i, i));
    }
    app.put("}");
    runBench("Many Small Strings (1000)", app.data, 1_000);
}

void benchmarkAlternatingTypes() {
    // Mix of all types
    auto app = appender!string();
    app.put("[");
    foreach (i; 0 .. 500) {
        if (i > 0) app.put(",");
        switch (i % 7) {
            case 0: app.put("null"); break;
            case 1: app.put("true"); break;
            case 2: app.put("false"); break;
            case 3: app.put(format("%d", i)); break;
            case 4: app.put(format("%f", i * 0.1)); break;
            case 5: app.put(format(`"str%d"`, i)); break;
            case 6: app.put(format(`{"n": %d}`, i)); break;
            default: break;
        }
    }
    app.put("]");
    runBench("Alternating Types (500)", app.data, 2_000);
}

void benchmarkRepeatedKeys() {
    // Array of objects with same keys
    auto app = appender!string();
    app.put("[");
    foreach (i; 0 .. 500) {
        if (i > 0) app.put(",");
        app.put(format(`{"id": %d, "name": "item", "value": %d, "active": true}`, i, i * 10));
    }
    app.put("]");
    runBench("Repeated Keys Pattern", app.data, 1_000);
}

void benchmarkNumericStrings() {
    // Numbers as strings (common in some APIs)
    auto app = appender!string();
    app.put("{");
    foreach (i; 0 .. 200) {
        if (i > 0) app.put(",");
        app.put(format(`"field_%d": "%d"`, i, i * 12345));
    }
    app.put("}");
    runBench("Numeric Strings (200)", app.data, 5_000);
}

// ═══════════════════════════════════════════════════════════════════════════
// JSON Generators
// ═══════════════════════════════════════════════════════════════════════════

string generateEcommerceOrder() {
    auto app = appender!string();
    app.put(`{
        "order": {
            "id": "ORD-2024-12345",
            "customer": {
                "id": 98765,
                "name": "Jane Smith",
                "email": "jane.smith@example.com",
                "phone": "+1-555-123-4567",
                "address": {
                    "street": "123 Main Street",
                    "city": "San Francisco",
                    "state": "CA",
                    "zip": "94102",
                    "country": "USA"
                }
            },
            "items": [`);
    
    foreach (i; 0 .. 10) {
        if (i > 0) app.put(",");
        app.put(format(`
                {
                    "sku": "SKU-%04d",
                    "name": "Product %d",
                    "description": "A wonderful product",
                    "price": %.2f,
                    "quantity": %d,
                    "category": "Electronics"
                }`, i, i, 19.99 + i * 10, i % 5 + 1));
    }
    
    app.put(`
            ],
            "shipping": {"method": "express", "cost": 15.99},
            "payment": {"method": "credit_card", "status": "completed"},
            "totals": {"subtotal": 549.50, "tax": 45.23, "total": 590.72}
        }
    }`);
    
    return app.data;
}

string generateTwitterPayload() {
    return `{
        "data": [
            {
                "id": "1234567890",
                "text": "This is a sample tweet with #hashtags and @mentions! 🎉",
                "author_id": "9876543210",
                "created_at": "2024-01-15T10:30:00Z",
                "public_metrics": {
                    "retweet_count": 42,
                    "reply_count": 10,
                    "like_count": 256,
                    "quote_count": 5
                },
                "entities": {
                    "hashtags": [{"tag": "hashtags", "start": 28, "end": 37}],
                    "mentions": [{"username": "mentions", "start": 42, "end": 51}]
                }
            }
        ],
        "includes": {
            "users": [
                {"id": "9876543210", "name": "Test User", "username": "testuser"}
            ]
        },
        "meta": {"result_count": 1, "next_token": "abc123"}
    }`;
}

string generateGitHubPayload() {
    return `{
        "id": 123456789,
        "name": "awesome-project",
        "full_name": "user/awesome-project",
        "private": false,
        "owner": {
            "login": "user",
            "id": 12345,
            "avatar_url": "https://avatars.githubusercontent.com/u/12345",
            "type": "User"
        },
        "description": "An awesome project for doing awesome things",
        "fork": false,
        "created_at": "2020-01-01T00:00:00Z",
        "updated_at": "2024-01-15T12:00:00Z",
        "pushed_at": "2024-01-15T11:30:00Z",
        "homepage": "https://example.com",
        "size": 1024,
        "stargazers_count": 1234,
        "watchers_count": 56,
        "forks_count": 78,
        "language": "D",
        "topics": ["json", "parser", "fast", "simd"],
        "default_branch": "main"
    }`;
}

string generateGeoJSON(size_t points) {
    auto app = appender!string();
    app.put(`{"type": "FeatureCollection", "features": [`);
    
    foreach (i; 0 .. points) {
        if (i > 0) app.put(",");
        double lat = -90 + (cast(double)i / points) * 180;
        double lon = -180 + (cast(double)i / points) * 360;
        app.put(format(`{
            "type": "Feature",
            "geometry": {"type": "Point", "coordinates": [%.6f, %.6f]},
            "properties": {"id": %d, "name": "Point %d"}
        }`, lon, lat, i, i));
    }
    
    app.put("]}");
    return app.data;
}

string generateLogEntries(size_t count) {
    auto app = appender!string();
    app.put(`{"logs": [`);
    
    string[] levels = ["DEBUG", "INFO", "WARN", "ERROR"];
    
    foreach (i; 0 .. count) {
        if (i > 0) app.put(",");
        app.put(format(`{
            "timestamp": "2024-01-15T10:%02d:%02dZ",
            "level": "%s",
            "message": "Log message number %d with some context",
            "context": {"request_id": "req-%06d", "user_id": %d}
        }`, i / 60, i % 60, levels[i % 4], i, i, i * 100));
    }
    
    app.put("]}");
    return app.data;
}

string generateLargeDataset(size_t count) {
    auto app = appender!string();
    app.reserve(count * 300);  // Pre-allocate
    app.put(`{"records": [`);
    
    foreach (i; 0 .. count) {
        if (i > 0) app.put(",");
        app.put(format(`{
            "id": %d,
            "uuid": "550e8400-e29b-%04d-a716-446655440000",
            "name": "Record %d",
            "email": "user%d@example.com",
            "score": %.2f,
            "active": %s,
            "created": "2024-01-01T00:00:00Z"
        }`, i, i % 10000, i, i, i * 1.5, i % 2 == 0 ? "true" : "false"));
    }
    
    app.put(`]}`);
    return app.data;
}

string generateLargeArray(size_t count) {
    auto app = appender!string();
    app.put("[");
    
    foreach (i; 0 .. count) {
        if (i > 0) app.put(",");
        app.put(format(`{"id": %d, "value": %d, "name": "item_%d"}`, i, i * 10, i));
    }
    
    app.put("]");
    return app.data;
}

string generateDeepNested(int depth) {
    auto app = appender!string();
    
    foreach (_; 0 .. depth) {
        app.put(`{"nested": `);
    }
    app.put(`{"value": 42}`);
    foreach (_; 0 .. depth) {
        app.put("}");
    }
    
    return app.data;
}

string generateNumberArray(size_t count) {
    auto app = appender!string();
    app.reserve(count * 8);
    app.put("[");
    
    foreach (i; 0 .. count) {
        if (i > 0) app.put(",");
        app.put(to!string(i));
    }
    
    app.put("]");
    return app.data;
}

string generateManyFields(size_t count) {
    auto app = appender!string();
    app.put("{");
    
    foreach (i; 0 .. count) {
        if (i > 0) app.put(",");
        app.put(format(`"field_%d": %d`, i, i * 100));
    }
    
    app.put("}");
    return app.data;
}

string myReplicate(string s, size_t n) {
    auto app = appender!string();
    app.reserve(s.length * n);
    foreach (_; 0 .. n) {
        app.put(s);
    }
    return app.data;
}

/**
 * Generate a JSON payload of approximately the target size in MB.
 * Uses an array of objects with varying content to create realistic JSON.
 */
string generateExactSizePayload(size_t targetMB) {
    import core.memory : GC;
    
    size_t targetBytes = targetMB * 1024 * 1024;
    
    // Pre-allocate with some extra space
    auto app = appender!string();
    app.reserve(targetBytes + 1024);
    
    app.put(`{"data": [`);
    
    size_t currentSize = 10;  // Opening
    size_t recordNum = 0;
    
    // Each record is approximately 200-300 bytes
    while (currentSize < targetBytes - 500) {
        if (recordNum > 0) {
            app.put(",");
            currentSize++;
        }
        
        // Create a record with varying content
        auto record = format(`{"id":%d,"uuid":"550e8400-e29b-%04d-a716-44665544%04d","name":"Record number %d with description","email":"user%d@example.com","score":%.2f,"active":%s,"tags":["tag1","tag2","tag3"],"metadata":{"created":"2024-01-01T00:00:00Z","updated":"2024-06-15T12:30:00Z","version":%d}}`,
            recordNum,
            recordNum % 10000,
            recordNum % 10000,
            recordNum,
            recordNum,
            recordNum * 1.5,
            recordNum % 2 == 0 ? "true" : "false",
            recordNum % 100
        );
        
        app.put(record);
        currentSize += record.length;
        recordNum++;
        
        // Progress indicator for large payloads
        if (targetMB >= 100 && recordNum % 100000 == 0) {
            writef("\r  Generating %d MB payload... %d%%", targetMB, (currentSize * 100) / targetBytes);
            stdout.flush();
        }
    }
    
    app.put("]}");
    
    if (targetMB >= 100) {
        writef("\r  Generated %d MB payload (%s, %d records)      \n", 
               targetMB, formatSize(app.data.length), recordNum);
        stdout.flush();
    }
    
    // Force GC to release temporary allocations
    GC.collect();
    
    return app.data;
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION 9: Error Handling Benchmarks
// ═══════════════════════════════════════════════════════════════════════════

// Helper to run error benchmarks
void runErrorBench(string name, string[] invalidInputs, size_t iterations) {
    import core.memory : GC;
    
    writeln("───────────────────────────────────────────────────────────────────────────");
    writefln("  %s", name);
    writefln("  Testing %d invalid inputs × %d iterations", invalidInputs.length, iterations);
    writeln("───────────────────────────────────────────────────────────────────────────");
    
    size_t totalBytes = 0;
    foreach (json; invalidInputs) {
        totalBytes += json.length;
    }
    
    // std.json
    GC.collect();
    size_t stdErrors = 0;
    auto t1 = StopWatch(AutoStart.yes);
    foreach (_; 0 .. iterations) {
        foreach (json; invalidInputs) {
            try {
                auto j = std.json.parseJSON(json);
            } catch (Exception) {
                // Catches JSONException and UTFException
                stdErrors++;
            }
        }
    }
    t1.stop();
    auto stdMs = t1.peek.total!"usecs" / 1000.0;
    
    // fastjsond.std
    GC.collect();
    size_t fastStdErrors = 0;
    auto t2 = StopWatch(AutoStart.yes);
    foreach (_; 0 .. iterations) {
        foreach (json; invalidInputs) {
            try {
                auto j = fastjsond.std.parseJSON(json);
            } catch (fastjsond.std.JSONException) {
                fastStdErrors++;
            }
        }
    }
    t2.stop();
    auto fastStdMs = t2.peek.total!"usecs" / 1000.0;
    
    // fastjsond native
    GC.collect();
    size_t nativeErrors = 0;
    auto parser = Parser.create();
    auto t3 = StopWatch(AutoStart.yes);
    foreach (_; 0 .. iterations) {
        foreach (json; invalidInputs) {
            auto doc = parser.parse(json);
            if (!doc.valid) {
                nativeErrors++;
            }
        }
    }
    t3.stop();
    auto nativeMs = t3.peek.total!"usecs" / 1000.0;
    
    auto speedupStd = stdMs / fastStdMs;
    auto speedupNative = stdMs / nativeMs;
    
    writefln("  %-20s %10.2f ms  (%d errors caught)", "std.json:", stdMs, stdErrors);
    writefln("  %-20s %10.2f ms  (%d errors caught)  (%.1fx faster)", 
             "fastjsond.std:", fastStdMs, fastStdErrors, speedupStd);
    writefln("  %-20s %10.2f ms  (%d errors caught)  (%.1fx faster)", 
             "fastjsond native:", nativeMs, nativeErrors, speedupNative);
    writeln();
}

void benchmarkInvalidJSON() {
    string[] inputs = [
        `{invalid}`,
        `{"key": }`,
        `{: "value"}`,
        `{"key" "value"}`,
        `["item",]`,
        `[,]`,
        `{,}`,
        `{"key": undefined}`,
        `{'key': 'value'}`,
        `{key: "value"}`,
    ];
    runErrorBench("Invalid JSON Syntax", inputs, 10_000);
}

void benchmarkTruncatedJSON() {
    string[] inputs = [
        `{"key": "val`,
        `{"key": `,
        `{"key"`,
        `{"ke`,
        `{`,
        `[1, 2, 3`,
        `[1, 2,`,
        `[`,
        `"hello`,
        `tru`,
        `fals`,
        `nul`,
        `123.`,
        `{"nested": {"deep": {"value"`,
    ];
    runErrorBench("Truncated JSON", inputs, 10_000);
}

void benchmarkUnterminatedStrings() {
    string[] inputs = [
        `{"key": "unterminated`,
        `{"key": "line1\nline2`,
        `{"key": "with\\escape`,
        `"just a string`,
        `["item1", "item2`,
        `{"a": "b", "c": "d`,
    ];
    runErrorBench("Unterminated Strings", inputs, 10_000);
}

void benchmarkInvalidNumbers() {
    string[] inputs = [
        `{"n": 01234}`,
        `{"n": +123}`,
        `{"n": .123}`,
        `{"n": 123.}`,
        `{"n": 1e}`,
        `{"n": 1e+}`,
        `{"n": 1.2.3}`,
        `{"n": --123}`,
        `{"n": 1e1e1}`,
        `{"n": NaN}`,
        `{"n": Infinity}`,
        `{"n": -Infinity}`,
    ];
    runErrorBench("Invalid Numbers", inputs, 10_000);
}

void benchmarkTrailingContent() {
    string[] inputs = [
        `{"key": "value"} extra`,
        `{"key": "value"}{}`,
        `{"key": "value"}[]`,
        `123 456`,
        `true false`,
        `null null`,
        `"hello" "world"`,
        `[1,2,3][4,5,6]`,
        `{"a": 1}{"b": 2}`,
    ];
    runErrorBench("Trailing Content", inputs, 10_000);
}

void benchmarkControlCharacters() {
    // Create strings with literal control characters (0x00-0x1F)
    string[] inputs;
    
    // Null character
    inputs ~= `{"key": "hello` ~ cast(char)0x00 ~ `world"}`;
    // Tab in wrong place
    inputs ~= `{"key":` ~ cast(char)0x09 ~ `"value"}`;
    // Vertical tab
    inputs ~= `{"key": "hello` ~ cast(char)0x0B ~ `world"}`;
    // Form feed
    inputs ~= `{"key": "hello` ~ cast(char)0x0C ~ `world"}`;
    // Backspace
    inputs ~= `{"key": "hello` ~ cast(char)0x08 ~ `world"}`;
    // Bell
    inputs ~= `{"key": "hello` ~ cast(char)0x07 ~ `world"}`;
    
    runErrorBench("Control Characters", inputs, 10_000);
}

void benchmarkInvalidEscapes() {
    string[] inputs = [
        `{"key": "\x00"}`,
        `{"key": "\a"}`,
        `{"key": "\v"}`,
        `{"key": "\0"}`,
        `{"key": "\1"}`,
        `{"key": "\ "}`,
        `{"key": "\"}`,
        `{"key": "\u"}`,
        `{"key": "\u12"}`,
        `{"key": "\u123"}`,
        `{"key": "\uGHIJ"}`,
        `{"key": "\u12G4"}`,
    ];
    runErrorBench("Invalid Escapes", inputs, 10_000);
}

void benchmarkInvalidUnicode() {
    string[] inputs = [
        `{"key": "\uD800"}`,         // Lone high surrogate
        `{"key": "\uDC00"}`,         // Lone low surrogate
        `{"key": "\uD800\u0041"}`,   // High surrogate + non-surrogate
        `{"key": "\uD800\uD800"}`,   // Two high surrogates
        `{"key": "\uDC00\uDC00"}`,   // Two low surrogates
    ];
    runErrorBench("Invalid Unicode", inputs, 5_000);
}

void benchmarkMixedErrors() {
    // A variety of different errors
    string[] inputs = [
        `{invalid}`,
        `{"key": `,
        `{"n": 01}`,
        `{"key": "unterminated`,
        `{"a": 1} extra`,
        `{"key": "\z"}`,
        `{"key": "\uD800"}`,
        `[1, 2, ]`,
        `{"key" "value"}`,
        `null null`,
        // Larger invalid payloads
        `{"users": [{"id": 1, "name": "Alice"}, {"id": 2, invalid}]}`,
        `{"data": {"nested": {"deep": {"value": }}}}`,
        `{"array": [1, 2, 3, 4, 5, ]}`,
        `{"config": {"host": "localhost", "port": }}`,
        `{"items": [{"name": "item1"}, {"name": "}]}`,
    ];
    runErrorBench("Mixed Errors", inputs, 10_000);
}
