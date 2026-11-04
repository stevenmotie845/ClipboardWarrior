import AppKit
import SwiftData
import SwiftUI

// MARK: - Menu bar popover
//
// Layout, top to bottom:
//   Recently Copied title + Open Archive + actions menu
//   search          directly under the title
//   filters         Pinned · Categories · Boards
//   clip list       takes all remaining height
//   footer          pause switch

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
    @FocusState private var searchFocused: Bool

    /// Tall enough to give the list most of the space, but never taller than the screen allows.
    private static var popoverHeight: CGFloat {
        let visible = NSScreen.main?.visibleFrame.height ?? 800
        return min(700, max(520, visible - 90))
    }

    private var sectionTitle: String {
        if pinnedOnly { return "Pinned" }
        return selectedBoardName ?? "Recently Copied"
    }

    private var sectionSubtitle: String {
        var parts = [pinnedOnly ? "Pinned clips" : (selectedBoardName == nil ? "Newest first" : "Board")]
        if pinnedOnly, let selectedBoardName { parts.append(selectedBoardName) }
        if let kind { parts.append(kind.title) }
        return parts.joined(separator: " · ")
    }

    private var hasActiveFilter: Bool { pinnedOnly || kind != nil || selectedBoardName != nil }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            searchBar
            filterBar

            ClipListView(
                search: search,
                kind: kind,
                categoryName: selectedBoardName,
                pinnedOnly: pinnedOnly,
                limit: 1000,
                style: .popover,
                selection: $selection,
                onActivate: { item in
                    monitor.copyBack(item)
                    withAnimation(.easeOut(duration: 0.18)) { copiedFlash = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut(duration: 0.18)) { copiedFlash = false }
                    }
                },
                onDelete: { monitor.delete($0) }
            )
            .id("\(search)|\(kind?.rawValue ?? "all")|\(pinnedOnly)|\(selectedBoardName ?? "all")")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { copiedToast }

            Divider().overlay(CWStyle.separator)
            footer
        }
        .frame(width: 420, height: Self.popoverHeight)
        .background(.regularMaterial)
        .background(CWStyle.canvas.opacity(0.22))
        .onAppear {
            WindowActivation.activateApp()
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    // MARK: Actions menu

    private var actionsMenu: some View {
        Menu {
            Button("Open Archive") { openArchive() }
            Button("Quick Paste…") {
                DispatchQueue.main.async { QuickPasteController.shared.show() }
            }
            Button("Export as Markdown…") { Exporter.exportMarkdown(context: context) }
            Divider()
            Menu("Manage Clipboard History") {
                Button("Clear Pinned Clips…", role: .destructive) {
                    monitor.confirmDeletePinnedClips { selection = nil }
                }
                Button("Delete All Clips…", role: .destructive) {
                    monitor.confirmDeleteAllClips { selection = nil }
                }
            }
            Menu("Autosave to Folder") {
                Toggle("Autosave enabled", isOn: $autosave)
                Button("Choose Destination…") { openSettings() }
                Button("Open Destination in Finder") { AutoSaver.openFolder() }
                Button("Save Existing Clips Now") { monitor.syncAllToFolder() }
            }
            Divider()
            SettingsLink { Text("Settings…") }
            Button("Quit ClipboardWarrior") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(CWStyle.subtleFill, in: Circle())
                .overlay(Circle().strokeBorder(CWStyle.hairline, lineWidth: 0.7))
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More ClipboardWarrior actions")
    }

    // MARK: Recently Copied + search + filters

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sectionTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(sectionSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: openArchive) {
                HStack(spacing: 5) {
                    Text("Open Archive")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CWStyle.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(CWStyle.accent.opacity(0.10), in: Capsule())
                .overlay(Capsule().strokeBorder(CWStyle.accent.opacity(0.18), lineWidth: 0.8))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Open the full clipboard archive")
            actionsMenu
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search clips, apps, tags…", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .accessibilityLabel("Search clipboard history")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(CWStyle.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(searchFocused ? CWStyle.accent.opacity(0.45) : CWStyle.hairline, lineWidth: searchFocused ? 1.2 : 0.8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                Button { pinnedOnly.toggle() } label: {
                    CWChip(title: "Pinned", symbol: pinnedOnly ? "pin.fill" : "pin",
                           tint: CWStyle.accent, isActive: pinnedOnly)
                }
                .buttonStyle(.plain)
                .help(pinnedOnly ? "Show all recent clips" : "Show only pinned clips")
                .accessibilityAddTraits(pinnedOnly ? .isSelected : [])

                categoriesMenu
                boardsMenu

                if hasActiveFilter {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            pinnedOnly = false
                            kind = nil
                            selectedBoardName = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(CWStyle.subtleFill, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear filters")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private var categoriesMenu: some View {
        Menu {
            Button { kind = nil } label: {
                if kind == nil { Label("All Categories", systemImage: "checkmark") }
                else { Text("All Categories") }
            }
            Divider()
            ForEach(ClipKind.allCases) { clipKind in
                Button { kind = clipKind } label: {
                    if kind == clipKind { Label(clipKind.title, systemImage: "checkmark") }
                    else { Label(clipKind.title, systemImage: clipKind.symbol) }
                }
            }
        } label: {
            CWChip(title: kind?.title ?? "Categories",
                   symbol: kind?.symbol ?? "line.3.horizontal.decrease",
                   tint: kind?.color ?? .secondary,
                   isActive: kind != nil,
                   showsChevron: true)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filter by clip category")
    }

    private var boardsMenu: some View {
        let board = categories.first { $0.name == selectedBoardName }
        return Menu {
            Button {
                selectedBoardName = nil
            } label: {
                if selectedBoardName == nil { Label("All Clips", systemImage: "checkmark") }
                else { Text("All Clips") }
            }
            if !categories.isEmpty { Divider() }
            ForEach(categories) { category in
                Button {
                    selectedBoardName = category.name
                } label: {
                    if selectedBoardName == category.name { Label(category.name, systemImage: "checkmark") }
                    else { Label(category.name, systemImage: CWSymbol.resolved(category.symbol)) }
                }
            }
            if categories.isEmpty { Text("Create boards in the Archive") }
            Divider()
            Button("Manage Boards…") { openArchive() }
        } label: {
            CWChip(title: selectedBoardName ?? "Boards",
                   symbol: board.map { CWSymbol.resolved($0.symbol) } ?? "square.grid.2x2",
                   tint: board.map { Color(hex: $0.colorHex) } ?? CWStyle.accent,
                   isActive: selectedBoardName != nil,
                   showsChevron: true)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(selectedBoardName.map { "Board: \($0)" } ?? "Choose a board")
    }

    // MARK: Toast + footer

    @ViewBuilder private var copiedToast: some View {
        if copiedFlash {
            Label("Copied to clipboard", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CWStyle.success)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(CWStyle.hairline, lineWidth: 0.8))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Toggle("Pause Capture", isOn: Binding(
                    get: { monitor.isPaused },
                    set: { monitor.isPaused = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .help("Pause or resume clipboard capture")
            }
            Spacer(minLength: 8)
            if let note = monitor.lastNote {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Actions

    private func openSettings() {
        WindowActivation.activateApp()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func openArchive() {
        WindowActivation.activateApp()
        openWindow(id: "archive")
        DispatchQueue.main.async {
            WindowActivation.bringWindowToFront(titled: "Clipboard Warrior")
        }
    }
}

