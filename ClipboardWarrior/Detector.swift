import Foundation

// MARK: - Signal helper

private struct Signal {
    let regex: NSRegularExpression
    let weight: Int

    init(_ pattern: String, _ weight: Int = 1) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        self.weight = weight
    }

    func hits(in s: String, range: NSRange) -> Bool {
        regex.firstMatch(in: s, options: [], range: range) != nil
    }
}

// MARK: - Content detection

/// Weighted multi-signal detection for Python, Swift and Bash. Each needs a score of 3+, so a
/// single stray `print(` or a prose line starting with "From now on" can't misclassify a clip.
/// Anything that doesn't score high enough stays General Text.
enum ContentDetector {

    private static let python: [Signal] = [
        Signal(#"^\s*def\s+\w+\s*\(.*\)\s*(->\s*[^:]+)?:\s*$"#, 2),
        Signal(#"^\s*class\s+\w+(\(.*\))?:\s*$"#, 2),
        Signal(#"^\s*(import\s+[\w.]+(\s+as\s+\w+)?|from\s+[\w.]+\s+import\s+.+)\s*$"#, 2),
        Signal(#"if\s+__name__\s*==\s*['"]__main__['"]"#, 3),
        Signal(#"\bself\.\w+"#, 1),
        Signal(#"^\s*(elif\s+.+|else|try|finally):\s*$"#, 1),
        Signal(#"^\s*except(\s+[\w.]+(\s+as\s+\w+)?)?:\s*$"#, 2),
        Signal(#"^\s*(for\s+\w+(\s*,\s*\w+)*\s+in\s+.+|while\s+.+|with\s+.+):\s*$"#, 1),
        Signal(#"\bprint\("#, 1),
        Signal(#"\bf(["'])[^"'\n]*\{[^}\n]+\}"#, 1),
        Signal(#"^\s*@\w+(\.\w+)*(\(.*\))?\s*$"#, 1),
        Signal(#"^\s*>>>\s"#, 3),
        Signal(#"\blambda\b[^:\n]*:"#, 1),
        Signal(#"\braise\s+[A-Z]\w*(Error|Exception|Warning)"#, 2),
    ]

    private static let swift: [Signal] = [
        Signal(#"^\s*import\s+(SwiftUI|Foundation|AppKit|UIKit|Combine|SwiftData|Cocoa|CryptoKit)\b"#, 3),
        Signal(#"\bfunc\s+\w+\s*(<[^>]*>)?\s*\("#, 2),
        Signal(#"^\s*((public|private|fileprivate|internal|final|open)\s+)*(struct|class|enum|protocol|extension|actor)\s+\w+[^\n]*\{\s*$"#, 2),
        Signal(#"\b(guard|if)\s+let\b"#, 2),
        Signal(#"@(State|Binding|Published|Observable|MainActor|Model|Environment|ObservedObject|StateObject|AppStorage|Query)\b"#, 3),
        Signal(#"\bvar\s+body\s*:\s*some\s+View"#, 4),
        Signal(#"\b(let|var)\s+\w+\s*:\s*[A-Z][\w<>\[\]?]*"#, 1),
        Signal(#"\)\s*->\s*[\w<>\[\]?]+\s*\{"#, 1),
        Signal(#"\bnil\b"#, 1),
        Signal(#"\s\?\?\s"#, 1),
    ]

    private static let shell: [Signal] = [
        // A single well-known command line is enough (copied terminal commands are common).
        Signal(#"^\s*(\$\s+)?(sudo\s+\w|brew\s+(install|update|upgrade|uninstall|tap|list|services)|git\s+(clone|pull|push|commit|checkout|status|add|log|diff|init|rebase|merge|stash|branch|fetch)|npm\s+(install|run|i|init|start)|npx\s+\w|pip3?\s+install|docker\s+\w|curl\s+(-|http)|chmod\s+|chown\s+|mkdir\s+(-p\s+)?\S|defaults\s+(read|write|delete)|launchctl\s+\w|killall\s+\w|xcrun\s+\w|xcodebuild\b|ssh\s+\S+@|rsync\s+-|cd\s+[~/.])"#, 3),
        Signal(#"\$\(\s*\w"#, 1),
        Signal(#"\$\{\w+\}"#, 1),
        Signal(#"^\s*fi\s*$"#, 1),
        Signal(#"^\s*done\s*$"#, 1),
        Signal(#"^\s*esac\s*$"#, 1),
        Signal(#"^\s*then\s*$"#, 1),
        Signal(#"^\s*if\s+\[\[?\s"#, 2),
        Signal(#"^\s*for\s+\w+\s+in\s+.+;\s*do\b"#, 2),
        Signal(#"\|\s*(grep|awk|sed|xargs|sort|uniq|wc|head|tail)\b"#, 1),
        Signal(#"^\s*export\s+[A-Z_]+="#, 1),
        Signal(#"^\s*echo\s+["'$]"#, 1),
        Signal(#"^\s*(source|\.)\s+\S+\.sh\b"#, 1),
    ]

    private static let htmlTags = try! NSRegularExpression(
        pattern: #"<(/?)(div|span|head|body|script|style|form|input|button|nav|header|footer|section|article|main|aside|ul|ol|li|table|thead|tbody|tr|td|th|h[1-6]|meta|link|img|video|audio|canvas|iframe|svg|p|a|em|strong|pre|code|br|hr|label|select|option|textarea|title|html)[\s>/]"#,
        options: [.caseInsensitive]
    )

    // MARK: detect

    static func detect(_ raw: String) -> ClipKind {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .text }

        if isURL(t) { return .url }
        if isJSON(t) { return .json }

        // Cap analysis so a huge paste can't stall the main thread.
        let sample = String(t.prefix(20_000))
        let range = NSRange(sample.startIndex..., in: sample)

        // Shebang is decisive.
        if sample.hasPrefix("#!") {
            let first = (sample.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? "").lowercased()
            if first.contains("python") { return .python }
            if first.contains("sh") { return .shell }   // sh, bash, zsh
        }

        // HTML
        let lower = sample.lowercased()
        if lower.hasPrefix("<!doctype html") || lower.hasPrefix("<html") { return .html }
        var names = Set<String>()
        var closing = false
        for m in htmlTags.matches(in: sample, range: range) {
            names.insert((sample as NSString).substring(with: m.range(at: 2)).lowercased())
            if m.range(at: 1).length > 0 { closing = true }
        }
        if names.count >= 3 || (names.count >= 2 && closing) { return .html }
        // A small fragment that is wrapped in tags, e.g. <div class="card">Hi</div>
        if closing, !names.isEmpty, t.hasPrefix("<"), t.hasSuffix(">") { return .html }

        // Scored languages (tie -> earlier entry wins)
        let scores: [(ClipKind, Int)] = [
            (.python, score(python, sample, range)),
            (.swift, score(swift, sample, range)),
            (.shell, score(shell, sample, range)),
        ]
        if let best = scores.max(by: { $0.1 < $1.1 }), best.1 >= 3 { return best.0 }

        return .text
    }

    private static func score(_ signals: [Signal], _ s: String, _ range: NSRange) -> Int {
        signals.reduce(0) { $0 + ($1.hits(in: s, range: range) ? $1.weight : 0) }
    }

    private static func isURL(_ t: String) -> Bool {
        guard !t.contains(where: \.isWhitespace),
              let url = URL(string: t),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "ftp", "ssh", "file"].contains(scheme) else { return false }
        return url.host != nil || scheme == "file"
    }

    private static func isJSON(_ t: String) -> Bool {
        guard (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")),
              t.count >= 7,
              let obj = try? JSONSerialization.jsonObject(with: Data(t.utf8)) else { return false }
        if let d = obj as? [String: Any] { return !d.isEmpty }
        if let a = obj as? [Any] { return !a.isEmpty }
        return false
    }
}

// MARK: - Secret scanner

/// Flags clips that look like credentials so they can be masked / expired / skipped,
/// and so autosave never writes them to disk.
nonisolated enum SecretScanner {
    private static let patterns: [(String, NSRegularExpression)] = {
        func re(_ p: String, _ o: NSRegularExpression.Options = []) -> NSRegularExpression {
            try! NSRegularExpression(pattern: p, options: o)
        }
        return [
            ("Private key", re(#"-----BEGIN [A-Z ]*PRIVATE KEY-----"#)),
            ("AWS access key", re(#"\bAKIA[0-9A-Z]{16}\b"#)),
            ("GitHub token", re(#"\bgh[pousr]_[A-Za-z0-9]{36,}\b"#)),
            ("API key", re(#"\bsk-[A-Za-z0-9_\-]{20,}\b"#)),
            ("Slack token", re(#"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#)),
            ("Google API key", re(#"\bAIza[0-9A-Za-z_\-]{35}\b"#)),
            ("JWT", re(#"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#)),
            ("Bearer token", re(#"\bbearer\s+[A-Za-z0-9._\-]{20,}"#, [.caseInsensitive])),
            ("Credential assignment",
             re(#"\b(password|passwd|pwd|secret|api[_-]?key|token|authorization)\b\s*[:=]\s*\S{6,}"#, [.caseInsensitive])),
        ]
    }()

    private static let cardRegex = try! NSRegularExpression(pattern: #"\b\d(?:[ -]?\d){12,18}\b"#)

    /// Returns a short human-readable reason, or nil if the text looks harmless.
    static func scan(_ text: String) -> String? {
        let sample = String(text.prefix(100_000))
        let ns = sample as NSString
        let full = NSRange(location: 0, length: ns.length)

        for (name, regex) in patterns where regex.firstMatch(in: sample, range: full) != nil {
            return name
        }
        for m in cardRegex.matches(in: sample, range: full) {
            let digits = ns.substring(with: m.range).compactMap { $0.wholeNumberValue }
            if (13...19).contains(digits.count), luhn(digits) { return "Card number" }
        }
        if looksLikePassword(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return "Looks like a password"
        }
        return nil
    }

    private static func luhn(_ digits: [Int]) -> Bool {
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 {
                let x = d * 2
                sum += x > 9 ? x - 9 : x
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }

    private static func looksLikePassword(_ t: String) -> Bool {
        guard (8...40).contains(t.count),
              !t.contains(where: \.isWhitespace),
              !t.contains("/") else { return false }
        let lower = t.contains { $0.isLowercase }
        let upper = t.contains { $0.isUppercase }
        let digit = t.contains { $0.isNumber }
        let symbol = t.contains { !$0.isLetter && !$0.isNumber }
        return lower && upper && digit && symbol
    }
}
