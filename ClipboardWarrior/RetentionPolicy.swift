import Foundation

/// Centralized retention rule shared by ClipboardMonitor and the QA harness.
/// A zero-day setting means Never; pinned clips are always retained.
nonisolated enum RetentionPolicy {
    static func shouldDelete(
        lastCopiedAt: Date,
        isPinned: Bool,
        retentionDays: Int,
        now: Date
    ) -> Bool {
        guard !isPinned, retentionDays > 0 else { return false }
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        return lastCopiedAt < cutoff
    }
}
