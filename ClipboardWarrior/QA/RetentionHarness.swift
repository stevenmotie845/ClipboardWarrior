// QA/RetentionHarness.swift
// Compile and run via QA/run_portable_tests.sh — do NOT add to the Xcode app target.
import Foundation

func runRetentionTests() {
    let now    = Date(timeIntervalSince1970: 2_000_000_000)
    let old    = now.addingTimeInterval(-91 * 86_400)
    let dayOld = now.addingTimeInterval(-2 * 86_400)

    let cases: [(String, Bool)] = [
        ("Never retains old clip",
         !RetentionPolicy.shouldDelete(lastCopiedAt: old, isPinned: false, retentionDays: 0, now: now)),
        ("1 day deletes 2-day-old clip",
         RetentionPolicy.shouldDelete(lastCopiedAt: dayOld, isPinned: false, retentionDays: 1, now: now)),
        ("7 days retains 2-day-old clip",
         !RetentionPolicy.shouldDelete(lastCopiedAt: dayOld, isPinned: false, retentionDays: 7, now: now)),
        ("30 days retains 2-day-old clip",
         !RetentionPolicy.shouldDelete(lastCopiedAt: dayOld, isPinned: false, retentionDays: 30, now: now)),
        ("90 days deletes 91-day-old clip",
         RetentionPolicy.shouldDelete(lastCopiedAt: old, isPinned: false, retentionDays: 90, now: now)),
        ("Pinned old clip never deletes",
         !RetentionPolicy.shouldDelete(lastCopiedAt: old, isPinned: true, retentionDays: 1, now: now)),
        ("Exactly-at-cutoff clip is retained",
         !RetentionPolicy.shouldDelete(lastCopiedAt: now.addingTimeInterval(-7 * 86_400),
                                       isPinned: false, retentionDays: 7, now: now)),
    ]

    var failures = 0
    for (name, passed) in cases {
        print("\(passed ? "PASS" : "FAIL"): \(name)")
        if !passed { failures += 1 }
    }
    print("\nRetention result: \(cases.count - failures)/\(cases.count) passed")
    if failures > 0 { exit(1) }
}
