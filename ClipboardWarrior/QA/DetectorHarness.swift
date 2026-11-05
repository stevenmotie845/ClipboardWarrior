// QA/DetectorHarness.swift
// Compile and run via QA/run_portable_tests.sh — do NOT add to the Xcode app target.
import Foundation

func runDetectorTests() {
    let tests: [(String, ClipKind)] = [
        ("Plain notes for tomorrow", .text),
        ("https://example.com", .url),
        ("{\n  \"name\": \"Alice\"\n}", .json),
        ("<!doctype html><html><body><div>Hi</div></body></html>", .html),
        ("<div class=\"card\">Hello</div>", .html),
        ("import SwiftUI\nstruct Demo: View { var body: some View { Text(\"Hi\") } }", .swift),
        ("def greet(name):\n    print(name)", .python),
        ("#!/bin/bash\necho \"hello\"", .shell),
        ("Subject: Lunch plans\nI will meet you at noon.", .text),
        ("The result is x => y in this explanation.", .text),
    ]

    var failures = 0
    for (input, expected) in tests {
        let actual = ContentDetector.detect(input)
        let passed = actual == expected
        print("\(passed ? "PASS" : "FAIL"): got '\(actual.rawValue)', expected '\(expected.rawValue)'")
        if !passed { failures += 1 }
    }
    print("\nDetector result: \(tests.count - failures)/\(tests.count) passed")
    if failures > 0 { exit(1) }
}
