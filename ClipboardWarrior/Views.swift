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
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .foregroundStyle(kind.color)
            .background(kind.color.opacity(0.16), in: Capsule())
            .fixedSize()
    }
}

// MARK: - Filtered list (shared by menu bar popover and archive window)

struct ClipListView: View {
    @Query private var clips: [ClipItem]

    private let pinnedOnly: Bool
    private let customCategoryName: String?
    private let singleClick: Bool
    private let selection: Binding<PersistentIdentifier?>
    private let onActivate: (ClipItem) -> Void

    init(search: String,
         kind: ClipKind?,
         categoryName: String? = nil,
         pinnedOnly: Bool,
         limit: Int,
         singleClick: Bool,
         selection: Binding<PersistentIdentifier?>,
         onActivate: @escaping (ClipItem) -> Void) {
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
        self.pinnedOnly = pinnedOnly
        self.customCategoryName = categoryName
        self.singleClick = singleClick
        self.selection = selection
        self.onActivate = onActivate
    }

    var body: some View {
        if clips.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: customCategoryName == nil ? "doc.on.clipboard" : "folder",
                description: Text(emptyDescription)
            )
        } else {
            List(selection: selection) { ForEach(clips) { row($0) } }
            .listStyle(.plain)
            .onKeyPress(.return) {
                guard let id = selection.wrappedValue,
                      let item = clips.first(where: { $0.persistentModelID == id }) else { return .ignored }
                onActivate(item)
                return .handled
            }
        }
    }

    private var emptyTitle: String {
        if pinnedOnly { return "Nothing pinned" }
        if customCategoryName != nil { return "This board is empty" }
        return "No clips"
    }

    private var emptyDescription: String {
        if pinnedOnly { return "Pin a clip to keep it here." }
        if customCategoryName != nil { return "Add clips you want to keep together from a clip’s menu." }
        return "Copy something and it will show up here."
    }

    /// Popover: one click copies. Archive: one click selects; copying is available in the detail view.
    @ViewBuilder
    private func row(_ item: ClipItem) -> some View {
        if singleClick {
            ClipRow(item: item)
                .tag(item.persistentModelID)
                .onTapGesture { onActivate(item) }
        } else {
            // Keep archive rows on the native single-click selection path. A second
            // competing tap gesture on List rows can swallow selection on macOS.
            ClipRow(item: item)
                .tag(item.persistentModelID)
        }
    }
}

// MARK: - Row

struct ClipRow: View {
    let item: ClipItem
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.modelContext) private var context
    @Query(sort: \ClipCategory.createdAt) private var categories: [ClipCategory]
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(item.preview)
                    .lineLimit(2)
                    .font(item.kind.isCode && !item.isSensitive
                          ? .system(.callout, design: .monospaced) : .callout)
                    .foregroundStyle(item.isSensitive ? Color.secondary : Color.primary)
                HStack(spacing: 6) {
                    KindBadge(kind: item.kind)
                    if !item.sourceApp.isEmpty {
                        Text(item.sourceApp).lineLimit(1)
                    }
                    Text(item.lastCopiedAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                        .layoutPriority(1)
                    if item.isSensitive, item.expiresAt != nil {
                        Label("auto-deletes", systemImage: "timer").labelStyle(.iconOnly)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if hovering || item.isPinned {
                Button { monitor.togglePin(item) } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
                .help(item.isPinned ? "Unpin" : "Pin")
            }
            if hovering {
                Button { monitor.delete(item) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Delete")
            }
        }
        .padding(.vertical, 3)
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
                                Label(category.name, systemImage: category.symbol)
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { monitor.delete(item) }
        }
    }

    private func setCategory(_ category: ClipCategory?) {
        item.customCategory = category
        try? context.save()
    }

    @ViewBuilder private var leading: some View {
        if item.kind == .image, !item.imageFileName.isEmpty {
            AsyncImage(url: ClipStore.imageURL(item.imageFileName)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            let tint = item.isSensitive ? Color.orange : item.kind.color
            Image(systemName: item.isSensitive ? "lock.fill" : item.kind.symbol)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Menu bar popover

struct MenuBarView: View {
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var context
    @AppStorage(Pref.autosave) private var autosave = true
    @Query(sort: \ClipCategory.createdAt) private var categories: [ClipCategory]

    @State private var search = ""
    @State private var kind: ClipKind?
    @State private var pinnedOnly = false
    @State private var selectedBoardName: String?
    @State private var selection: PersistentIdentifier?
    @State private var copiedFlash = false

    var body: some View {
        @Bindable var monitor = monitor

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search clips", text: $search)
                    .textFieldStyle(.roundedBorder)
                Menu {
                    Button("All types") { kind = nil }
                    Divider()
                    ForEach(ClipKind.allCases) { k in
                        Button { kind = k } label: { Label(k.title, systemImage: k.symbol) }
                    }
                } label: {
                    Image(systemName: kind == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            HStack(spacing: 8) {
                Picker("History section", selection: $pinnedOnly) {
                    Text("Recent").tag(false)
                    Text("Pinned").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Clipboard history section")

                Menu {
                    Button {
                        selectedBoardName = nil
                    } label: {
                        if selectedBoardName == nil {
                            Label("All Boards", systemImage: "checkmark")
                        } else {
                            Text("All Boards")
                        }
                    }
                    if !categories.isEmpty { Divider() }
                    ForEach(categories) { category in
                        Button {
                            selectedBoardName = category.name
                        } label: {
                            if selectedBoardName == category.name {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Label(category.name, systemImage: category.symbol)
                            }
                        }
                    }
                    if categories.isEmpty {
                        Text("Create boards in Archive")
                    }
                } label: {
                    Label(selectedBoardName ?? "Boards", systemImage: "folder")
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Filter clips by board")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ClipListView(
                search: search, kind: kind, categoryName: selectedBoardName,
                pinnedOnly: pinnedOnly, limit: 1000, singleClick: true,
                selection: $selection,
                onActivate: { item in
                    monitor.copyBack(item)
                    copiedFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedFlash = false }
                }
            )
            // ClipListView builds its SwiftData predicate in init. Recreate it whenever a
            // menu-bar filter changes so search, type, pinned, and board filters stay in sync.
            .id("\(search)|\(kind?.rawValue ?? "all")|\(pinnedOnly)|\(selectedBoardName ?? "all")")
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Toggle("Pause", isOn: $monitor.isPaused)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if copiedFlash {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let note = monitor.lastNote {
                    Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Menu {
                    Button("Open Archive") {
                        openWindow(id: "archive")
                        NSApp.activate()
                    }
                    Divider()
                    Toggle("Autosave to folder", isOn: $autosave)
                    Button("Open Autosave Folder") { AutoSaver.openFolder() }
                    Button("Save All Clips to Folder") { monitor.syncAllToFolder() }
                    Divider()
                    Button("Export as Markdown…") { Exporter.exportMarkdown(context: context) }
                    Divider()
                    SettingsLink { Text("Settings…") }
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(10)
        }
        .frame(width: 380, height: 520)
    }
}

// MARK: - Archive window

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
        case .custom(_, let symbol, _): symbol
        }
    }

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

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x007AFF
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}

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
            List(selection: $filter) {
                Section("Library") {
                    ForEach(filters) { f in
                        Label(f.title, systemImage: f.symbol)
                            .foregroundStyle(f.color)
                            .tag(f)
                    }
                }
                Section {
                    ForEach(categories) { category in
                        let board = SidebarFilter.custom(name: category.name, symbol: category.symbol, colorHex: category.colorHex)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: category.colorHex))
                                .frame(width: 9, height: 9)
                            Label(category.name, systemImage: category.symbol)
                                .foregroundStyle(.primary)
                        }
                        .tag(board)
                            .contextMenu {
                                Button("Delete Board", role: .destructive) {
                                    if filter == board { filter = .all }
                                    context.delete(category)
                                    try? context.save()
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text("Boards")
                        Spacer()
                        Button { showingNewBoard = true } label: { Image(systemName: "plus") }
                            .buttonStyle(.plain)
                            .help("New Board")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .safeAreaInset(edge: .bottom) {
                let total = (try? context.fetchCount(FetchDescriptor<ClipItem>())) ?? 0
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(total) clips stored")
                    Text("This session: \(monitor.sessionSaved) saved, \(monitor.sessionDuplicates) repeats")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
        } content: {
            ClipListView(
                search: search,
                kind: { if case .kind(let k) = active { return k } else { return nil } }(),
                categoryName: active.customCategoryName,
                pinnedOnly: active == .pinned,
                limit: 2000,
                singleClick: false,
                selection: $selection,
                onActivate: { monitor.copyBack($0) }
            )
            // Recreate the query when the sidebar filter changes. SwiftData's
            // @Query descriptor is captured when ClipListView is initialized;
            // NavigationSplitView can otherwise retain the old query for the
            // same content-column identity.
            .id(active)
            .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let id = selection,
               let item = context.model(for: id) as? ClipItem,
               item.modelContext != nil, !item.isDeleted {
                ClipDetailView(item: item, onDelete: { selection = nil })
                    .id(item.persistentModelID)
            } else {
                ContentUnavailableView("Select a clip", systemImage: "doc.text.magnifyingglass")
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
            ToolbarItem {
                Menu {
                    Button("Open Autosave Folder") { AutoSaver.openFolder() }
                    Button("Save All Clips to Folder") { monitor.syncAllToFolder() }
                    Divider()
                    Button("Export as Markdown…") { Exporter.exportMarkdown(context: context) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .frame(minWidth: 860, minHeight: 520)
    }
}

private struct NewBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var existingCategories: [ClipCategory]
    @State private var name = ""
    @State private var symbol = "folder"
    @State private var colorHex = "007AFF"
    @State private var isIconPickerPresented = false
    let onCreate: (String, String, String) -> Void

    private static let palette = [
        ("Blue", "007AFF"), ("Purple", "AF52DE"), ("Pink", "FF2D55"),
        ("Orange", "FF9500"), ("Green", "34C759"), ("Teal", "5AC8FA"),
        ("Yellow", "FFCC00")
    ]

    // Common, recognizable SF Symbols that are suitable for user-created boards.
    private static let availableSymbols: [(name: String, title: String)] = [
        ("folder", "Folder"), ("briefcase", "Work"), ("house", "Home"),
        ("person", "Personal"), ("star", "Favorites"), ("bookmark", "Bookmark"),
        ("cart", "Shopping"), ("creditcard", "Payment"), ("doc.text", "Documents"),
        ("book", "Books"), ("graduationcap", "Study"), ("lightbulb", "Ideas"),
        ("code", "Code"), ("terminal", "Terminal"), ("laptopcomputer", "Computer"),
        ("paperclip", "Attachments"), ("link", "Links"), ("photo", "Photos"),
        ("camera", "Camera"), ("music.note", "Music"), ("film", "Video"),
        ("calendar", "Calendar"), ("clock", "Later"), ("checkmark.circle", "Done"),
        ("heart", "Important"), ("flag", "Flagged"), ("tray", "Inbox"),
        ("archivebox", "Archive"), ("shippingbox", "Package"), ("wrench.and.screwdriver", "Tools"),
        ("paintpalette", "Design"), ("globe", "Web"), ("airplane", "Travel"),
        ("fork.knife", "Food"), ("gamecontroller", "Games"), ("ellipsis", "Other")
    ]

    private var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameIsTaken: Bool { existingCategories.contains { $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Board").font(.title2.weight(.semibold))
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            if nameIsTaken {
                Text("A board with this name already exists.")
                    .font(.caption).foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Choose Icon").font(.subheadline.weight(.medium))
                Button {
                    isIconPickerPresented.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(hex: colorHex))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                        Text(Self.availableSymbols.first(where: { $0.name == symbol })?.title ?? "Custom Icon")
                        Spacer()
                        Text("Choose…").foregroundStyle(.secondary)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                .popover(isPresented: $isIconPickerPresented, arrowEdge: .bottom) {
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
                                            .background(symbol == option.name ? Color(hex: colorHex).opacity(0.14) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Board color").font(.subheadline.weight(.medium))
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
                Spacer()
                Button("Create") {
                    onCreate(normalizedName,
                             symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "folder" : symbol,
                             colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedName.isEmpty || nameIsTaken)
            }
        }
        .padding(20)
        .frame(width: 380)
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
                    Label(category.name, systemImage: category.symbol)
                }
            }
        } label: {
            Label(item.customCategory?.name ?? "Add to Board", systemImage: item.customCategory?.symbol ?? "folder.badge.plus")
        }
        .menuStyle(.borderlessButton)
    }

    private func assign(_ category: ClipCategory?) {
        item.customCategory = category
        try? context.save()
    }
}

struct ClipDetailView: View {
    let item: ClipItem
    let onDelete: () -> Void

    @Environment(ClipboardMonitor.self) private var monitor
    @State private var revealed = false

    private static let displayLimit = 100_000

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                KindBadge(kind: item.kind)
                BoardPicker(item: item)
                if !item.sourceApp.isEmpty {
                    Text(item.sourceApp).font(.headline)
                }
                Spacer()
                Button { monitor.copyBack(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(.borderedProminent)
                Button { monitor.togglePin(item) } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
                Button(role: .destructive) {
                    onDelete()
                    monitor.delete(item)
                } label: { Label("Delete", systemImage: "trash") }
            }

            metadata

            Divider()
            content
        }
        .padding()
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Captured \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
                 + (item.sourceApp.isEmpty ? "" : " from \(item.sourceApp)"))
            Text("Copied \(item.useCount) time\(item.useCount == 1 ? "" : "s") · "
                 + ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
            if !item.tags.isEmpty { Text("Tags: " + item.tags.replacingOccurrences(of: ",", with: ", ")) }
            if item.isSensitive {
                Label(item.sensitiveReason + (item.expiresAt.map {
                    " · deletes \($0.formatted(date: .abbreviated, time: .shortened))"
                } ?? ""), systemImage: "lock.fill")
                .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .image:
            if let image = NSImage(contentsOf: ClipStore.imageURL(item.imageFileName)) {
                ScrollView([.horizontal, .vertical]) { Image(nsImage: image) }
            } else {
                Text("Image file is missing from disk.").foregroundStyle(.secondary)
            }
        case .files:
            List(item.text.split(separator: "\n").map(String.init), id: \.self) { path in
                HStack {
                    Text(path).textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                    .buttonStyle(.link)
                }
            }
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
                }
            }
        }
    }
}
