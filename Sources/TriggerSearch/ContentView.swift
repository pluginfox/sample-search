import SwiftUI
import TriggerSearchKit

struct ContentView: View {
    @EnvironmentObject var model: LibraryModel
    @EnvironmentObject var updates: UpdateChecker
    @AppStorage("showInspector") private var showInspector = true

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            FileTableView()
                .inspector(isPresented: $showInspector) {
                    InspectorView()
                        .inspectorColumnWidth(min: 240, ideal: 300, max: 520)
                }
        }
        .searchable(text: $model.searchText, placement: .toolbar,
                    prompt: "Search all \(model.mode == .all ? "files" : model.mode.title.lowercased())…")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $model.mode) {
                    ForEach(LibraryMode.allCases) { mode in
                        Text(label(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Instruments are Trigger .tci files; One-Shots are .wav / .aiff samples")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
                    .help("Show or hide the inspector (⌥⌘I)")
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if model.isScanning { ProgressView().controlSize(.small) }
                Toggle(isOn: $model.autoPlay) {
                    Label("Play on Select", systemImage: model.autoPlay ? "speaker.wave.2.fill" : "speaker.slash")
                }
                .help("Audition one-shots automatically when selected")
                Button { model.rescan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                    .help("Rescan library folders (⌘R)")
                    .disabled(model.isScanning)
                Button { model.showFolders = true } label: { Label("Folders", systemImage: "folder.badge.gearshape") }
                    .help("Choose library folders")
                Button { model.updateBrowserFolder() } label: { Label("Update Browser Folder", systemImage: "square.and.arrow.up.on.square") }
                    .help("Rebuild the folder of links Trigger 2's own browser can navigate (⌘E)")
            }
        }
        .sheet(isPresented: $model.showFolders) { FoldersSheet() }
        .alert(updateTitle, isPresented: Binding(get: { updates.outcome != nil }, set: { if !$0 { updates.outcome = nil } })) {
            if case .available(let release, _) = updates.outcome {
                Button("Download") { NSWorkspace.shared.open(release.downloadURL) }
                Button("Release Notes") { NSWorkspace.shared.open(URL(string: release.html_url) ?? UpdateChecker.releasesPage) }
                Button("Later", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { Text(updateMessage) }
        .alert("Trigger Browser Folder", isPresented: Binding(get: { model.browserFolderMessage != nil },
                                                              set: { if !$0 { model.browserFolderMessage = nil } })) {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([BrowserFolder.url]) }
            Button("OK", role: .cancel) {}
        } message: { Text(model.browserFolderMessage ?? "") }
        .onAppear { if !model.roots.isEmpty { model.rescan() } }
        .onChange(of: model.selection) { _ in model.selectionChanged() }
        .frame(minWidth: 900, minHeight: 500)
    }

    private var updateTitle: String {
        switch updates.outcome {
        case .available: return "Update Available"
        case .upToDate: return "You're Up to Date"
        case .failed: return "Couldn't Check for Updates"
        case .none: return ""
        }
    }

    private var updateMessage: String {
        switch updates.outcome {
        case .available(let release, let current):
            let notes = (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = notes.isEmpty ? "" : "\n\n" + String(notes.prefix(400))
            return "Trigger Search \(release.tag_name) is available; you have \(current).\(summary)"
        case .upToDate(let current): return "Trigger Search \(current) is the latest version."
        case .failed(let reason): return reason
        case .none: return ""
        }
    }

    private func label(for mode: LibraryMode) -> String {
        switch mode {
        case .instruments: return "Instruments (\(model.instrumentCount))"
        case .oneShots: return "One-Shots (\(model.oneShotCount))"
        case .all: return "All"
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var model: LibraryModel
    @State private var renaming: String?
    @State private var renameDraft = ""
    @State private var collapsedPacks: Set<String> = []
    /// Pending pack/kit rename: (title, current name, apply closure).
    @State private var groupRename: (title: String, apply: (String) -> Void)?

    private func expansion(for pack: String) -> Binding<Bool> {
        Binding(get: { !collapsedPacks.contains(pack) },
                set: { open in if open { collapsedPacks.remove(pack) } else { collapsedPacks.insert(pack) } })
    }

    var body: some View {
        List(selection: $model.filter) {
            Section("Library") {
                row("All Samples", "square.grid.2x2", model.visibleFiles.count, .all)
                row("Favourites", "star.fill", model.favoriteCount, .favorites)
                row("Untagged", "tag.slash", model.untaggedCount, .untagged)
            }
            Section("Categories") {
                ForEach(model.categoryCounts, id: \.0) { category, count in
                    row(category.displayName, category.symbol, count, .category(category))
                }
            }
            Section("Source") {
                ForEach(model.sourceCounts, id: \.0) { source, count in
                    row(source.displayName, source.symbol, count, .source(source))
                }
            }
            Section("Vendors") {
                ForEach(model.vendorCounts, id: \.0) { vendor, count in
                    row(vendor, "building.2", count, .vendor(vendor == "Unknown" ? "" : vendor))
                }
            }
            Section("Packs") {
                ForEach(model.packCounts, id: \.0) { pack, count in
                    let kits = model.kitCounts(inPack: pack)
                    if kits.isEmpty {
                        row(pack, "shippingbox", count, .pack(pack))
                            .contextMenu { renameButton("Rename Pack…", pack) { model.renamePack(pack, to: $0) } }
                    } else {
                        DisclosureGroup(isExpanded: expansion(for: pack)) {
                            ForEach(kits, id: \.0) { kit, kitCount in
                                row(kit, "music.note.list", kitCount, .kit(pack: pack, kit: kit))
                                    .contextMenu { renameButton("Rename Kit…", kit) { model.renameKit(kit, inPack: pack, to: $0) } }
                            }
                        } label: {
                            row(pack, "shippingbox", count, .pack(pack))
                                .contextMenu { renameButton("Rename Pack…", pack) { model.renamePack(pack, to: $0) } }
                        }
                    }
                }
            }
            Section("Tags") {
                if model.tagCounts.isEmpty {
                    Text("Tag a sample in the inspector to see it here.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.tagCounts, id: \.0) { tag, count in
                    row(tag, "tag", count, .tag(tag))
                        .contextMenu {
                            Button("Rename Tag…") { renameDraft = tag; renaming = tag }
                            Button("Delete Tag from All Samples", role: .destructive) { model.deleteTagEverywhere(tag) }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .alert(groupRename?.title ?? "Rename", isPresented: Binding(get: { groupRename != nil }, set: { if !$0 { groupRename = nil } })) {
            TextField("Name", text: $renameDraft)
            Button("Rename") { groupRename?.apply(renameDraft); groupRename = nil }
            Button("Cancel", role: .cancel) { groupRename = nil }
        } message: {
            Text("Applies to every file in that folder. Leave empty to go back to the folder name.")
        }
        .alert("Rename Tag", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Tag name", text: $renameDraft)
            Button("Rename") { if let old = renaming { model.renameTag(old, to: renameDraft) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func renameButton(_ title: String, _ current: String, apply: @escaping (String) -> Void) -> some View {
        Button(title) {
            renameDraft = current
            groupRename = (title, apply)
        }
    }

    private func row(_ title: String, _ symbol: String, _ count: Int, _ filter: SidebarFilter) -> some View {
        Label {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                Text("\(count)").foregroundStyle(.secondary).font(.callout).monospacedDigit()
            }
        } icon: {
            Image(systemName: symbol)
        }
        .tag(filter)
    }
}

// MARK: - Table

struct FileTableView: View {
    @EnvironmentObject var model: LibraryModel
    @ObservedObject private var preview = LibraryModel.shared.preview

    var body: some View {
        let rows = model.filteredRows
        Group {
            if model.roots.isEmpty {
                EmptyLibraryView()
            } else if rows.isEmpty {
                ContentUnavailableCompat(
                    title: model.files.isEmpty && model.isScanning ? "Scanning…" : "No Samples",
                    detail: model.files.isEmpty && !model.isScanning
                        ? "No .tci, .wav or .aiff files were found in the library folders."
                        : model.visibleFiles.isEmpty
                            ? "No \(model.mode == .oneShots ? "one-shots (.wav / .aiff)" : "Trigger instruments (.tci)") in the library folders. Switch mode or add a folder."
                            : "Nothing matches the current search and filter.")
            } else {
                Table(selection: $model.selection, sortOrder: $model.sortOrder) {
                    TableColumn("", value: \.favoriteRank) { row in
                        Button { model.toggleFavorite([row.id]) } label: {
                            Image(systemName: row.favorite ? "star.fill" : "star")
                                .foregroundStyle(row.favorite ? Color.yellow : Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .width(24)
                    TableColumn("Name", value: \.name) { row in
                        HStack(spacing: 6) {
                            if row.isPlayable {
                                Button { model.preview.toggle(row.file.url) } label: {
                                    Image(systemName: model.preview.playingPath == row.id ? "stop.circle.fill" : "play.circle")
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Preview")
                            }
                            Text(row.name).lineLimit(1)
                        }
                    }
                    .width(min: 160, ideal: 240)
                    TableColumn("Type", value: \.format) { row in
                        Text(row.format).font(.caption).monospaced().foregroundStyle(.secondary)
                    }
                    .width(min: 40, ideal: 44)
                    TableColumn("Variant", value: \.variant) { row in
                        Text(row.variant).foregroundStyle(.secondary).monospaced()
                    }
                    .width(min: 50, ideal: 64)
                    TableColumn("DrumCategory", value: \.category) { row in
                        Label(row.categoryName, systemImage: row.category.symbol).lineLimit(1)
                    }
                    .width(min: 80, ideal: 110)
                    TableColumn("Source", value: \.source) { row in
                        Label(row.sourceName, systemImage: row.source.symbol).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 100)
                    TableColumn("Vendor", value: \.vendor) { row in
                        Text(row.vendor.isEmpty ? "—" : row.vendor).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .width(min: 90, ideal: 130)
                    Group {
                    TableColumn("Pack", value: \Row.pack) { (row: Row) in
                        Text(row.pack).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .width(min: 100, ideal: 170)
                    TableColumn("Kit", value: \Row.kit) { (row: Row) in
                        Text(row.kit.isEmpty ? "—" : row.kit).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 120)
                    TableColumn("Folder", value: \Row.folder) { (row: Row) in
                        Text(row.folder).lineLimit(1).foregroundStyle(.secondary).help(row.folder)
                    }
                    .width(min: 100, ideal: 200)
                    TableColumn("Tags", value: \Row.tagsJoined) { (row: Row) in
                        Text(row.tagsJoined).lineLimit(1).foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 160)
                    TableColumn("Notes", value: \Row.notesOneLine) { (row: Row) in
                        Text(row.notesOneLine).lineLimit(1).foregroundStyle(.secondary).help(row.notes)
                    }
                    .width(min: 80, ideal: 200)
                    }
                } rows: {
                    ForEach(rows) { row in
                        TableRow(row)
                            .itemProvider { NSItemProvider(object: row.file.url as NSURL) }
                    }
                }
                .contextMenu(forSelectionType: String.self) { ids in
                    let targets = ids.isEmpty ? model.selection : ids
                    Button("Toggle Favourite") { model.toggleFavorite(targets) }
                    Button("Reveal in Finder") { model.revealInFinder(targets) }
                    Button("Copy Path") { model.copyPaths(targets) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(rows.count) of \(model.visibleFiles.count) samples")
                if model.isSearching { Text("· searching all \(model.mode == .all ? "files" : model.mode.title.lowercased())") }
                if !model.selection.isEmpty { Text("· \(model.selection.count) selected") }
                Spacer()
                if model.isExporting {
                    ProgressView().controlSize(.mini)
                    Text("Updating Trigger browser folder…").foregroundStyle(.tertiary)
                } else if let last = model.lastExport {
                    Text("Trigger browser folder updated \(last.formatted(date: .omitted, time: .shortened))").foregroundStyle(.tertiary)
                } else if !model.autoExport {
                    Text("Automatic browser-folder updates are off").foregroundStyle(.tertiary)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}

struct ContentUnavailableCompat: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.slash").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(title).font(.title2).bold()
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct EmptyLibraryView: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus").font(.system(size: 44)).foregroundStyle(.tertiary)
            Text("No Library Folders").font(.title2).bold()
            Text("Add the folders that hold your Trigger 2 .tci files.\nTrigger Search never moves or changes them.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Choose Folders…") { model.showFolders = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
