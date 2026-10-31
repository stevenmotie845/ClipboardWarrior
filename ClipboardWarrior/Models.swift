import Foundation
import SwiftData

/// Old clips saved as javascript / css / applescript still load: `ClipItem.kind`
/// falls back to `.text` for any raw value that no longer exists.
nonisolated enum ClipKind: String, CaseIterable, Identifiable {
    case text, url, json, html, python, swift, shell, image, files

    var id: String { rawValue }

    /// Label shown in the colored tag.
    var title: String {
        switch self {
        case .text: "General Text"
        case .url: "URL"
        case .json: "JSON"
        case .html: "HTML"
        case .python: "Python"
        case .swift: "Swift"
        case .shell: "Bash"
        case .image: "Image"
        case .files: "Files"
        }
    }

    /// Folder name used under Desktop/ClipboardWarrior.
    var folderName: String {
        switch self {
        case .image: "Images"
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .json: "curlybraces"
        case .html: "globe"
        case .python: "chevron.left.forwardslash.chevron.right"
        case .swift: "swift"
        case .shell: "terminal"
        case .image: "photo"
        case .files: "doc.on.doc"
        }
    }

    var fileExtension: String {
        switch self {
        case .text, .url, .files: "txt"
        case .json: "json"
        case .html: "html"
        case .python: "py"
        case .swift: "swift"
        case .shell: "sh"
        case .image: "png"
        }
    }

    var isCode: Bool {
        switch self {
        case .json, .html, .python, .swift, .shell: true
        default: false
        }
    }
}

@Model
final class ClipItem {
    @Attribute(.unique) var contentHash: String
    var kindRaw: String
    var text: String                // text, or newline-separated paths for .files, empty for images
    var preview: String
    var tags: String
    var sourceApp: String
    var sourceBundleID: String
    var createdAt: Date
    var lastCopiedAt: Date
    var useCount: Int
    var isPinned: Bool
    var isSensitive: Bool
    var sensitiveReason: String
    var expiresAt: Date?
    var imageFileName: String
    var byteSize: Int
    var customCategory: ClipCategory?

    init(
        contentHash: String,
        kind: ClipKind,
        text: String,
        preview: String,
        tags: String,
        sourceApp: String,
        sourceBundleID: String,
        isSensitive: Bool,
        sensitiveReason: String,
        expiresAt: Date?,
        imageFileName: String,
        byteSize: Int,
        customCategory: ClipCategory? = nil
    ) {
        let now = Date()
        self.contentHash = contentHash
        self.kindRaw = kind.rawValue
        self.text = text
        self.preview = preview
        self.tags = tags
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.createdAt = now
        self.lastCopiedAt = now
        self.useCount = 1
        self.isPinned = false
        self.isSensitive = isSensitive
        self.sensitiveReason = sensitiveReason
        self.expiresAt = expiresAt
        self.imageFileName = imageFileName
        self.byteSize = byteSize
        self.customCategory = customCategory
    }

    var kind: ClipKind { ClipKind(rawValue: kindRaw) ?? .text }
}


@Model
final class ClipCategory {
    @Attribute(.unique) var name: String
    var symbol: String
    var colorHex: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ClipItem.customCategory)
    var clips: [ClipItem]?

    init(name: String, symbol: String = "folder", colorHex: String = "007AFF") {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
