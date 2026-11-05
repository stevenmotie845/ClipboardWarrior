import AppKit
import SwiftData
import SwiftUI

// MARK: - Sidebar model

enum SidebarFilter: Hashable, Identifiable {
    case all, pinned, kind(ClipKind), custom(name: String, symbol: String, colorHex: String)

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All Clips"
        case .pinned: "Pinned"
        case .kind(let k): k.title
        case .custom(let name, _, _): name
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .pinned: "pin"
        case .kind(let k): k.symbol
        case .custom(_, let symbol, _): CWSymbol.resolved(symbol)
        }
    }

    /// Icon tint. Names in the sidebar always use the standard text color; only icons are tinted.
    var color: Color {
        switch self {
        case .all: .accentColor
        case .pinned: .yellow
        case .kind(let k): k.color
        case .custom(_, _, let colorHex): Color(hex: colorHex)
        }
    }

    var customCategoryName: String? {
        if case .custom(let name, _, _) = self { return name }
        return nil
    }
}

/// Sidebar row: tinted icon, standard-color name.
private struct SidebarRow: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label {
            Text(title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
    }
}

/// Live clip totals for the sidebar footer.
private struct ArchiveStats: View {
    @Environment(ClipboardMonitor.self) private var monitor
    @Query private var clips: [ClipItem]

    var body: some View {
        let pinned = clips.filter(\.isPinned).count
        VStack(alignment: .leading, spacing: 3) {
            Text("\(clips.count.formatted()) clips")
                .font(.system(size: 11, weight: .semibold))
            Text("\(pinned.formatted()) pinned")
                .foregroundStyle(.secondary)
            Text("This session: \(monitor.sessionSaved) saved, \(monitor.sessionDuplicates) repeats")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Archive window

struct ArchiveView: View {
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.modelContext) private var context
    @Query(sort: \ClipCategory.createdAt) private var categories: [ClipCategory]

    @State private var search = ""
    @State private var filter: SidebarFilter? = .all
    @State private var selection: PersistentIdentifier?
    @State private var showingNewBoard = false

    private var filters: [SidebarFilter] {
        [.all, .pinned] + ClipKind.allCases.map(SidebarFilter.kind)
    }

    var body: some View {
        let active = filter ?? .all
        NavigationSplitView {
            sidebar
        } content: {
            ClipListView(
                search: search,
                kind: { if case .kind(let k) = active { return k } else { return nil } }(),
                categoryName: active.customCategoryName,
                pinnedOnly: active == .pinned,
                limit: 2000,
                style: .archive,
                selection: $selection,
                onActivate: { monitor.copyBack($0) },
                onDelete: { item in
                    selection = nil
                    monitor.delete(item)
                }
            )
            // Recreate the query when the sidebar filter changes. SwiftData's
            // @Query descriptor is captured when ClipListView is initialized;
            // NavigationSplitView can otherwise retain the old query for the
            // same content-column identity.
            .id(active)
            .navigationTitle(active.title)
            .navigationSplitViewColumnWidth(min: 290, ideal: 360, max: 520)
        } detail: {
            if let id = selection,
               let item = context.model(for: id) as? ClipItem,
               item.modelContext != nil, !item.isDeleted {
                ClipDetailView(item: item, onDelete: { selection = nil })
                    .id(item.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Select a clip",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose a clip from the list to see its details.")
                )
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Search text, tags, apps")
        .sheet(isPresented: $showingNewBoard) {
            NewBoardView { name, symbol, colorHex in
                let category = ClipCategory(name: name, symbol: symbol, colorHex: colorHex)
                context.insert(category)
                try? context.save()
                filter = .custom(name: name, symbol: symbol, colorHex: colorHex)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { showingNewBoard = true } label: {
                    Label("New Board", systemImage: "plus.rectangle.on.folder")
                }
                .help("Create a new board")

                Menu {
                    Button("Open Autosave Folder") { AutoSaver.openFolder() }
                    Button("Save All Clips to Folder") { monitor.syncAllToFolder() }
                    Divider()
                    Button("Export Individual Clips…") { Exporter.exportIndividualMarkdown(context: context) }
                    Button("Export Archive to Single Markdown…") { Exporter.exportMarkdown(context: context) }
                    Divider()
                    Button("Quick Paste…") {
                        DispatchQueue.main.async { QuickPasteController.shared.show() }
                    }
                    Divider()
                    Menu("Manage Clipboard History") {
                        Button("Clear Pinned Clips…", role: .destructive) {
                            monitor.confirmDeletePinnedClips { selection = nil }
                        }
                        Button("Delete All Clips…", role: .destructive) {
                            monitor.confirmDeleteAllClips { selection = nil }
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .help("More actions")
            }
        }
        .frame(minWidth: 780, minHeight: 500)
        .background(WindowFrontmostBridge())
        .onAppear {
            WindowActivation.activateAndRaiseKeyWindow()
        }
    }

    private var sidebar: some View {
        List(selection: $filter) {
            Section("Library") {
                ForEach(filters) { f in
                    SidebarRow(title: f.title, symbol: f.symbol, tint: f.color)
                        .tag(f)
                }
            }
            Section {
                ForEach(categories) { category in
                    let board = SidebarFilter.custom(name: category.name, symbol: category.symbol, colorHex: category.colorHex)
                    SidebarRow(title: category.name,
                               symbol: CWSymbol.resolved(category.symbol),
                               tint: Color(hex: category.colorHex))
                        .tag(board)
                        .contextMenu {
                            Button("Delete Board", role: .destructive) {
                                if filter == board { filter = .all }
                                context.delete(category)
                                try? context.save()
                            }
                        }
                }
                if categories.isEmpty {
                    Text("No boards yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } header: {
                HStack {
                    Text("Boards")
                    Spacer()
                    Button { showingNewBoard = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                        .help("New Board")
                        .accessibilityLabel("New Board")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 280)
        .safeAreaInset(edge: .bottom) {
            ArchiveStats()
        }
    }
}

// MARK: - New board

private struct NewBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var existingCategories: [ClipCategory]
    @State private var name = ""
    @State private var symbol = "folder"
    @State private var colorHex = "007AFF"
    @State private var isIconPickerPresented = false
    @FocusState private var nameFocused: Bool
    let onCreate: (String, String, String) -> Void

    private static let palette = [
        ("Blue", "007AFF"), ("Purple", "AF52DE"), ("Pink", "FF2D55"),
        ("Orange", "FF9500"), ("Green", "34C759"), ("Teal", "5AC8FA"),
        ("Yellow", "FFCC00")
    ]

    // Recognizable SF Symbols for user-created boards. Every name here is a real symbol.
    private static let availableSymbols: [(name: String, title: String)] = [
        ("folder", "Folder"), ("briefcase", "Work"), ("house", "Home"),
        ("person", "Personal"), ("star", "Favorites"), ("bookmark", "Bookmark"),
        ("cart", "Shopping"), ("creditcard", "Payment"), ("doc.text", "Documents"),
        ("book", "Books"), ("graduationcap", "Study"), ("lightbulb", "Ideas"),
        (CWSymbol.codeBoard, "Code"), ("terminal", "Terminal"), ("laptopcomputer", "Computer"),
        ("paperclip", "Attachments"), ("link", "Links"), ("photo", "Photos"),
        ("camera", "Camera"), ("music.note", "Music"), ("film", "Video"),
        ("calendar", "Calendar"), ("clock", "Later"), ("checkmark.circle", "Done"),
        ("heart", "Important"), ("flag", "Flagged"), ("tray", "Inbox"),
        ("archivebox", "Archive"), ("shippingbox", "Package"), ("wrench.and.screwdriver", "Tools"),
        ("paintpalette", "Design"), ("globe", "Web"), ("airplane", "Travel"),
        ("fork.knife", "Food"), ("gamecontroller", "Games"), ("ellipsis", "Other")
    ]

    private var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameIsTaken: Bool {
        existingCategories.contains { $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(hex: colorHex))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Board").font(.title3.weight(.semibold))
                    Text("Group clips you want to keep together.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.subheadline.weight(.medium))
                TextField("e.g. Work snippets", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                if nameIsTaken {
                    Text("A board with this name already exists.")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon").font(.subheadline.weight(.medium))
                Button {
                    isIconPickerPresented.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: colorHex))
                            .frame(width: 26, height: 26)
                            .background(Color(hex: colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        Text(Self.availableSymbols.first(where: { $0.name == symbol })?.title ?? "Custom Icon")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.secondary.opacity(0.25)))
                .popover(isPresented: $isIconPickerPresented, arrowEdge: .bottom) {
                    iconPicker
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.subheadline.weight(.medium))
                HStack(spacing: 11) {
                    ForEach(0..<Self.palette.count, id: \.self) { index in
                        let color = Self.palette[index]
                        Button { colorHex = color.1 } label: {
                            Circle()
                                .fill(Color(hex: color.1))
                                .frame(width: 20, height: 20)
                                .padding(3)
                                .overlay {
                                    Circle().stroke(colorHex == color.1 ? Color.primary : .clear, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .help(color.0)
                        .accessibilityLabel("\(color.0) board color")
                        .accessibilityAddTraits(colorHex == color.1 ? .isSelected : [])
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Board") {
                    onCreate(normalizedName, CWSymbol.resolved(symbol), colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(normalizedName.isEmpty || nameIsTaken)
            }
        }
        .padding(22)
        .frame(width: 400)
        .task { nameFocused = true }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a board icon").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 8), count: 6), spacing: 8) {
                ForEach(Self.availableSymbols, id: \.name) { option in
                    Button {
                        symbol = option.name
                        isIconPickerPresented = false
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: option.name)
                                .font(.system(size: 19))
                                .frame(width: 40, height: 34)
                                .foregroundStyle(symbol == option.name ? Color(hex: colorHex) : Color.primary)
                                .background(symbol == option.name ? Color(hex: colorHex).opacity(0.14) : Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(option.title)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .frame(width: 48)
                        }
                        .frame(width: 48, height: 55)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(option.title)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(symbol == option.name ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}

// MARK: - Detail

private struct BoardPicker: View {
    let item: ClipItem
    @Environment(\.modelContext) private var context
    @Query(sort: \ClipCategory.createdAt) private var categories: [ClipCategory]

    var body: some View {
        Menu {
            Button("No Board") { assign(nil) }
            if !categories.isEmpty { Divider() }
            ForEach(categories) { category in
                Button { assign(category) } label: {
                    Label(category.name, systemImage: CWSymbol.resolved(category.symbol))
                }
            }
        } label: {
            Label(item.customCategory?.name ?? "Add to Board",
                  systemImage: item.customCategory.map { CWSymbol.resolved($0.symbol) } ?? "folder.badge.plus")
        }
        .menuStyle(.button)
        .controlSize(.small)
        .fixedSize()
    }

    private func assign(_ category: ClipCategory?) {
        item.customCategory = category
        try? context.save()
    }
}

private struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(CWStyle.subtleFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct ClipDetailView: View {
    let item: ClipItem
    let onDelete: () -> Void

    @Environment(ClipboardMonitor.self) private var monitor
    @State private var revealed = false
    @State private var justCopied = false

    private static let displayLimit = 100_000

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            actionBar
            metadata
            contentCard
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            ClipLeadingIcon(item: item, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.sourceApp.isEmpty ? "Unknown source" : item.sourceApp)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    KindBadge(kind: item.kind)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            BoardPicker(item: item)
        }
    }

    // MARK: Actions

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            actions(compact: false)
            actions(compact: true)
        }
    }

    private func actions(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                monitor.copyBack(item)
                justCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { justCopied = false }
            } label: {
                actionLabel(justCopied ? "Copied" : "Copy",
                            symbol: justCopied ? "checkmark" : "doc.on.doc",
                            compact: compact)
            }
            .buttonStyle(.borderedProminent)
            .tint(CWStyle.accent)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy this clip back to the clipboard")

            Button { monitor.togglePin(item) } label: {
                actionLabel(item.isPinned ? "Unpin" : "Pin",
                            symbol: item.isPinned ? "pin.slash" : "pin",
                            compact: compact)
            }
            .help(item.isPinned ? "Unpin this clip" : "Pin this clip")

            Button(role: .destructive) {
                onDelete()
                monitor.delete(item)
            } label: {
                actionLabel("Delete", symbol: "trash", compact: compact)
            }
            .help("Delete this clip")

            Spacer(minLength: 0)
        }
        .controlSize(.regular)
    }

    @ViewBuilder
    private func actionLabel(_ title: String, symbol: String, compact: Bool) -> some View {
        if compact {
            Label(title, systemImage: symbol).labelStyle(.iconOnly)
        } else {
            Label(title, systemImage: symbol)
        }
    }

    // MARK: Metadata

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                InfoTile(title: "Last copied",
                         value: item.lastCopiedAt.formatted(date: .abbreviated, time: .shortened))
                InfoTile(title: "Times copied", value: "\(item.useCount)")
                InfoTile(title: "Size",
                         value: ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
                if !item.tags.isEmpty {
                    InfoTile(title: "Tags", value: item.tags.replacingOccurrences(of: ",", with: ", "))
                }
            }
            if item.isSensitive {
                Label(item.sensitiveReason + (item.expiresAt.map {
                    " · deletes \($0.formatted(date: .abbreviated, time: .shortened))"
                } ?? ""), systemImage: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Content

    private var contentCard: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.7),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(CWStyle.hairline, lineWidth: 0.8)
            }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .image:
            if let image = NSImage(contentsOf: ClipStore.imageURL(item.imageFileName)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Image file is missing from disk.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .files:
            List(item.text.split(separator: "\n").map(String.init), id: \.self) { path in
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(path).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .buttonStyle(.link)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        default:
            if item.isSensitive && !revealed {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Hidden because it looks sensitive").foregroundStyle(.secondary)
                    Button("Reveal") { revealed = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let shown = item.byteSize > Self.displayLimit
                    ? String(item.text.prefix(Self.displayLimit)) : item.text
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shown)
                            .font(item.kind.isCode ? .system(.body, design: .monospaced) : .body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if item.byteSize > Self.displayLimit {
                            Text("Showing the first \(Self.displayLimit.formatted()) characters. Copy to get everything.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}
