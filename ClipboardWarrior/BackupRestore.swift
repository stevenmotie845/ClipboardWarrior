import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Versioned, local-only backup and restore for the complete ClipboardWarrior library.
/// Backups intentionally include sensitive clips so a restore is complete; the UI warns users
/// before creating or importing a file because a backup can contain private clipboard contents.
@MainActor
enum BackupRestoreManager {
    private static let formatIdentifier = "com.motielabs.clipboardwarrior.backup"
    private static let schemaVersion = 1
    private static let maximumBackupBytes = 500 * 1_024 * 1_024
    private static let maximumClipCount = 250_000

    private struct Archive: Codable {
        let format: String
        let version: Int
        let createdAt: Date
        let categories: [CategoryRecord]
        let clips: [ClipRecord]
    }

    private struct CategoryRecord: Codable {
        let name: String
        let symbol: String
        let colorHex: String
        let createdAt: Date
    }

    private struct ClipRecord: Codable {
        let contentHash: String
        let kindRaw: String
        let text: String
        let preview: String
        let tags: String
        let sourceApp: String
        let sourceBundleID: String
        let createdAt: Date
        let lastCopiedAt: Date
        let useCount: Int
        let isPinned: Bool
        let isSensitive: Bool
        let sensitiveReason: String
        let expiresAt: Date?
        let byteSize: Int
        let categoryName: String?
        let imageData: Data?

        init(item: ClipItem) throws {
            contentHash = item.contentHash
            kindRaw = item.kind.rawValue
            text = item.text
            preview = item.preview
            tags = item.tags
            sourceApp = item.sourceApp
            sourceBundleID = item.sourceBundleID
            createdAt = item.createdAt
            lastCopiedAt = item.lastCopiedAt
            useCount = item.useCount
            isPinned = item.isPinned
            isSensitive = item.isSensitive
            sensitiveReason = item.sensitiveReason
            expiresAt = item.expiresAt
            byteSize = item.byteSize
            categoryName = item.customCategory?.name

            if item.kind == .image, !item.imageFileName.isEmpty {
                let imageURL = ClipStore.imageURL(item.imageFileName)
                imageData = try FileManager.default.fileExists(atPath: imageURL.path)
                    ? Data(contentsOf: imageURL)
                    : nil
            } else {
                imageData = nil
            }
        }
    }

    /// Creates one JSON backup containing clips, boards, metadata, and captured image payloads.
    static func exportBackup(context: ModelContext) {
        let warning = NSAlert()
        warning.alertStyle = .warning
        warning.messageText = "Create a ClipboardWarrior backup?"
        warning.informativeText = "The backup includes your full clipboard history, including clips marked sensitive, board information, and saved images. The file is not encrypted. Store it somewhere private."
        warning.addButton(withTitle: "Continue")
        warning.addButton(withTitle: "Cancel")
        guard warning.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSSavePanel()
        panel.title = "Back Up ClipboardWarrior"
        panel.nameFieldStringValue = "ClipboardWarrior-Backup-\(Date().fileStamp).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let clips = try context.fetch(FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt)]))
            let categories = try context.fetch(FetchDescriptor<ClipCategory>(sortBy: [SortDescriptor(\.createdAt)]))
            guard clips.count <= maximumClipCount else {
                throw BackupError.tooManyClips(clips.count)
            }

            let archive = Archive(
                format: formatIdentifier,
                version: schemaVersion,
                createdAt: Date(),
                categories: categories.map {
                    CategoryRecord(name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, createdAt: $0.createdAt)
                },
                clips: try clips.map(ClipRecord.init(item:))
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(archive)
            guard data.count <= maximumBackupBytes else {
                throw BackupError.backupTooLarge(data.count)
            }
            try data.write(to: destination, options: .atomic)

            let alert = NSAlert()
            alert.messageText = "Backup created"
            alert.informativeText = "Saved \(clips.count) clip(s) and \(categories.count) board(s) to:\n\(destination.path)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            showError(error, title: "Couldn't create backup")
        }
    }

    /// Restores by merging missing clip hashes into the current library. Existing clips are never
    /// overwritten or deleted. Any image files written during a failed import are rolled back.
    static func importBackup(context: ModelContext) {
        let panel = NSOpenPanel()
        panel.title = "Restore a ClipboardWarrior Backup"
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let source = panel.url else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard fileSize > 0, fileSize <= maximumBackupBytes else {
                throw BackupError.invalidFileSize(fileSize)
            }
            let data = try Data(contentsOf: source)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let archive = try decoder.decode(Archive.self, from: data)
            guard archive.format == formatIdentifier, archive.version == schemaVersion else {
                throw BackupError.unsupportedFormat
            }
            guard archive.clips.count <= maximumClipCount else {
                throw BackupError.tooManyClips(archive.clips.count)
            }

            let confirmation = NSAlert()
            confirmation.alertStyle = .warning
            confirmation.messageText = "Merge this backup into your library?"
            confirmation.informativeText = "The backup contains \(archive.clips.count) clip(s) and \(archive.categories.count) board(s). New clips will be added; existing clips will be kept. The backup may contain sensitive clipboard data."
            confirmation.addButton(withTitle: "Merge Backup")
            confirmation.addButton(withTitle: "Cancel")
            guard confirmation.runModal() == .alertFirstButtonReturn else { return }

            let existingClips = try context.fetch(FetchDescriptor<ClipItem>())
            var knownHashes = Set(existingClips.map(\.contentHash))
            let existingCategories = try context.fetch(FetchDescriptor<ClipCategory>())
            var categoriesByName = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.name, $0) })
            var writtenImages: [URL] = []
            var imported = 0
            var duplicates = 0
            var missingImages = 0
            var addedCategories = 0

            do {
                for record in archive.categories where categoriesByName[record.name] == nil {
                    guard !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, record.name.count <= 120 else { continue }
                    let category = ClipCategory(
                        name: record.name,
                        symbol: CWSymbol.resolved(record.symbol),
                        colorHex: record.colorHex
                    )
                    category.createdAt = record.createdAt
                    context.insert(category)
                    categoriesByName[record.name] = category
                    addedCategories += 1
                }

                for record in archive.clips {
                    guard Self.isValidHash(record.contentHash),
                          let kind = ClipKind(rawValue: record.kindRaw) else {
                        duplicates += 1
                        continue
                    }
                    guard !knownHashes.contains(record.contentHash) else {
                        duplicates += 1
                        continue
                    }

                    var imageFileName = ""
                    if kind == .image {
                        if let imageData = record.imageData,
                           imageData.count <= 25 * 1_024 * 1_024,
                           Helpers.sha256Hex(imageData).caseInsensitiveCompare(record.contentHash) == .orderedSame {
                            imageFileName = record.contentHash.lowercased() + ".png"
                            let imageURL = ClipStore.imageURL(imageFileName)
                            if !FileManager.default.fileExists(atPath: imageURL.path) {
                                try imageData.write(to: imageURL, options: .atomic)
                                writtenImages.append(imageURL)
                            }
                        } else {
                            missingImages += 1
                        }
                    }

                    let clip = ClipItem(
                        contentHash: record.contentHash,
                        kind: kind,
                        text: record.text,
                        preview: record.preview,
                        tags: record.tags,
                        sourceApp: record.sourceApp,
                        sourceBundleID: record.sourceBundleID,
                        isSensitive: record.isSensitive,
                        sensitiveReason: record.sensitiveReason,
                        expiresAt: record.expiresAt,
                        imageFileName: imageFileName,
                        byteSize: max(record.byteSize, 0),
                        customCategory: record.categoryName.flatMap { categoriesByName[$0] }
                    )
                    clip.createdAt = record.createdAt
                    clip.lastCopiedAt = record.lastCopiedAt
                    clip.useCount = max(record.useCount, 1)
                    clip.isPinned = record.isPinned
                    context.insert(clip)
                    knownHashes.insert(record.contentHash)
                    imported += 1
                }

                try context.save()
            } catch {
                context.rollback()
                for imageURL in writtenImages {
                    try? FileManager.default.removeItem(at: imageURL)
                }
                throw error
            }

            let result = NSAlert()
            result.messageText = "Restore complete"
            var details = "Imported \(imported) clip(s) and added \(addedCategories) board(s). Skipped \(duplicates) existing or invalid clip(s)."
            if missingImages > 0 { details += "\n\(missingImages) image clip(s) had no usable image payload in the backup." }
            result.informativeText = details
            result.addButton(withTitle: "OK")
            result.runModal()
        } catch {
            showError(error, title: "Couldn't restore backup")
        }
    }

    private static func isValidHash(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
        }
    }

    private static func showError(_ error: Error, title: String) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.runModal()
    }

    private enum BackupError: LocalizedError {
        case tooManyClips(Int)
        case backupTooLarge(Int)
        case invalidFileSize(Int)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .tooManyClips(let count):
                "This backup contains \(count) clips, which exceeds the supported limit."
            case .backupTooLarge(let size):
                "The generated backup is too large (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))."
            case .invalidFileSize(let size):
                "The selected backup file is empty or too large (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))."
            case .unsupportedFormat:
                "This is not a supported ClipboardWarrior backup or its version is not supported."
            }
        }
    }
}
