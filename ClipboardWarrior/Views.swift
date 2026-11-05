import AppKit
import SwiftData
import SwiftUI

// MARK: - Colors & tag

extension ClipKind {
    var color: Color {
        switch self {
        case .text: .gray
        case .url: .blue
        case .json: .teal
        case .html: .orange
        case .python: .green
        case .swift: .pink
        case .shell: .purple
        case .image: .indigo
        case .files: .brown
        }
    }
}

/// Colored capsule: "HTML", "URL", "General Text", "Python", "Bash"...
struct KindBadge: View {
    let kind: ClipKind

    var body: some View {
        Text(kind.title)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(kind.color)
            .background(kind.color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

// MARK: - Leading icon (source app + type)

/// The icon at the start of a clip row: the app the clip was copied from, with a small
/// type-colored glyph in the corner. Images show a thumbnail with the source app as the corner badge.
/// Falls back to the type icon when the source app is unknown or no longer installed.
struct ClipLeadingIcon: View {
    let item: ClipItem
    var size: CGFloat = 34

    private var appIcon: NSImage? {
        AppIconProvider.shared.icon(forBundleID: item.sourceBundleID)
    }

    private var hasImageFile: Bool {
        item.kind == .image && !item.imageFileName.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            main
            badge.offset(x: size * 0.12, y: size * 0.12)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var main: some View {
        if item.isSensitive {
            tile(symbol: "lock.fill", tint: .orange)
        } else if hasImageFile {
            AsyncImage(url: ClipStore.imageURL(item.imageFileName)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(CWStyle.hairline, lineWidth: 0.8)
            }
        } else if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            tile(symbol: item.kind.symbol, tint: item.kind.color)
        }
    }

    @ViewBuilder private var badge: some View {
        if item.isSensitive {
            EmptyView()
        } else if hasImageFile {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size * 0.5, height: size * 0.5)
            }
        } else if appIcon != nil {
            Image(systemName: item.kind.symbol)
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size * 0.46, height: size * 0.46)
                .background(item.kind.color, in: Circle())
                .overlay { Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5) }
        }
    }

    private func tile(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Filtered list (shared by menu bar popover and archive window)

struct ClipListView: View {
    enum Style { case popover, archive }

    @Query private var clips: [ClipItem]
    // Fetched once here and passed to every ClipRow, eliminating N live @Query instances
    // (one per visible row) all fetching the same ClipCategory list.
    @Query(sort: \ClipCategory.createdAt) private var categories: [ClipCategory]

    private let style: Style
    private let pinnedOnly: Bool
    private let customCategoryName: String?
    private let hasSearch: Bool
    private let hasKindFilter: Bool
    private let selection: Binding<PersistentIdentifier?>
    private let onActivate: (ClipItem) -> Void
    private let onDelete: ((ClipItem) -> Void)?

    init(search: String,
         kind: ClipKind?,
         categoryName: String? = nil,
         pinnedOnly: Bool,
         limit: Int,
         style: Style,
         selection: Binding<PersistentIdentifier?>,
         onActivate: @escaping (ClipItem) -> Void,
         onDelete: ((ClipItem) -> Void)? = nil) {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let kindRaw = kind?.rawValue ?? ""

        let onlyPinned = pinnedOnly
        let selectedCategory = categoryName ?? ""
        let predicate = #Predicate<ClipItem> { item in
            (!onlyPinned || item.isPinned)
            && (selectedCategory.isEmpty || item.customCategory?.name == selectedCategory)
            && (kindRaw.isEmpty || item.kindRaw == kindRaw)
            && (q.isEmpty
                || item.text.localizedStandardContains(q)
                || item.preview.localizedStandardContains(q)
                || item.tags.localizedStandardContains(q)
                || item.sourceApp.localizedStandardContains(q))
        }

        let sort = [SortDescriptor(\ClipItem.lastCopiedAt, order: .reverse)]
        var descriptor = FetchDescriptor<ClipItem>(predicate: predicate, sortBy: sort)
        descriptor.fetchLimit = limit
        _clips = Query(descriptor)
        self.style = style
        self.pinnedOnly = pinnedOnly
        self.customCategoryName = categoryName
        self.hasSearch = !q.isEmpty
        self.hasKindFilter = kind != nil
        self.selection = selection
        self.onActivate = onActivate
        self.onDelete = onDelete
    }

    var body: some View {
        if clips.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptySymbol,
                description: Text(emptyDescription)
            )
        } else {
            List(selection: selection) {
                ForEach(clips) { item in
                    row(item)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onKeyPress(.return) {
                guard let id = selection.wrappedValue,
                      let item = clips.first(where: { $0.persistentModelID == id }) else { return .ignored }
                onActivate(item)
                return .handled
            }
            .onDeleteCommand {
                guard let onDelete,
                      let id = selection.wrappedValue,
                      let item = clips.first(where: { $0.persistentModelID == id }) else { return }
                onDelete(item)
            }
        }
    }

    private var isFiltered: Bool { hasSearch || hasKindFilter || pinnedOnly || customCategoryName != nil }

    private var emptySymbol: String {
        if hasSearch { return "magnifyingglass" }
        if pinnedOnly { return "pin" }
        return customCategoryName == nil ? "doc.on.clipboard" : "folder"
    }

    private var emptyTitle: String {
        if hasSearch { return "No matching clips" }
        if pinnedOnly { return "Nothing pinned" }
        if customCategoryName != nil { return "This board is empty" }
        if hasKindFilter { return "No clips of this type" }
        return "No clips yet"
    }

    private var emptyDescription: String {
        if hasSearch { return "Try a different search, or clear the filters." }
        if pinnedOnly { return "Pin a clip to keep it here." }
        if customCategoryName != nil { return "Add clips you want to keep together from a clip’s menu." }
        if hasKindFilter { return "Clips of this type will appear here as you copy them." }
        return "Copy something and it will show up here."
    }

    /// Popover: one click copies. Archive: one click selects; copying is available in the detail view.
    @ViewBuilder
    private func row(_ item: ClipItem) -> some View {
        if style == .popover {
            ClipRow(item: item, showsCopyButton: false, categories: categories)
                .tag(item.persistentModelID)
                .onTapGesture { onActivate(item) }
        } else {
            // Keep archive rows on the native single-click selection path. A second
            // competing tap gesture on List rows can swallow selection on macOS.
            ClipRow(item: item, showsCopyButton: true, categories: categories)
                .tag(item.persistentModelID)
        }
    }
}

// MARK: - Row

struct ClipRow: View {
    let item: ClipItem
    var showsCopyButton = false
    /// Injected by ClipListView — avoids one live @Query per visible row all fetching the same data.
    var categories: [ClipCategory] = []

    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.modelContext) private var context
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            ClipLeadingIcon(item: item, size: 34)
                .padding(.trailing, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .font(item.kind.isCode && !item.isSensitive
                          ? .system(size: 12.5, design: .monospaced) : .system(size: 13))
                    .foregroundStyle(item.isSensitive ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    KindBadge(kind: item.kind)
                    if !item.sourceApp.isEmpty {
                        Text(item.sourceApp).lineLimit(1).truncationMode(.tail)
                    }
                    Text(item.lastCopiedAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                        .layoutPriority(1)
                    if item.isSensitive, item.expiresAt != nil {
                        Label("auto-deletes", systemImage: "timer").labelStyle(.iconOnly)
                    }
                    if item.isPinned {
                        Image(systemName: "pin.fill").foregroundStyle(CWStyle.accent)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? CWStyle.hover : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .trailing) {
            if hovering { hoverActions.padding(.trailing, 6) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy") { monitor.copyBack(item) }
            Button(item.isPinned ? "Unpin" : "Pin") { monitor.togglePin(item) }
            if !categories.isEmpty {
                Menu("Move to Board") {
                    Button { setCategory(nil) } label: {
                        if item.customCategory == nil { Label("No Board", systemImage: "checkmark") }
                        else { Text("No Board") }
                    }
                    Divider()
                    ForEach(categories) { category in
                        Button { setCategory(category) } label: {
                            if item.customCategory?.persistentModelID == category.persistentModelID {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Label(category.name, systemImage: CWSymbol.resolved(category.symbol))
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { monitor.delete(item) }
        }
    }

    private var hoverActions: some View {
        HStack(spacing: 2) {
            if showsCopyButton {
                rowButton("doc.on.doc", help: "Copy") { monitor.copyBack(item) }
            }
            rowButton(item.isPinned ? "pin.slash" : "pin", help: item.isPinned ? "Unpin" : "Pin") {
                monitor.togglePin(item)
            }
            rowButton("trash", help: "Delete") { monitor.delete(item) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(CWStyle.hairline, lineWidth: 0.8) }
    }

    private func rowButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .accessibilityLabel(help)
    }

    private func setCategory(_ category: ClipCategory?) {
        item.customCategory = category
        try? context.save()
    }
}
