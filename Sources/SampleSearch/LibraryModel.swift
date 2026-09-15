import Foundation
import SwiftUI
import SampleSearchKit

enum SidebarFilter: Hashable {
    case all
    case favorites
    case untagged
    case category(DrumCategory)
    case source(SourceType)
    case effectCategory(EffectCategory)
    case pack(String)
    case tag(String)
    case vendor(String)
    case kit(pack: String, kit: String)
}

/// Which kinds of file the window shows.
enum LibraryMode: String, CaseIterable, Identifiable {
    case instruments, oneShots, all, effects
    var id: String { rawValue }
    var title: String {
        switch self {
        case .instruments: return "Instruments"
        case .oneShots: return "One-Shots"
        case .all: return "All Trigger"
        case .effects: return "Effects"
        }
    }
    /// Lower-case noun for prompts and footers.
    var noun: String {
        switch self {
        case .instruments: return "instruments"
        case .oneShots: return "one-shots"
        case .all: return "the Trigger library"
        case .effects: return "effects"
        }
    }
    /// Where a search looks when this mode has no matches: the rest of the Trigger library, then Effects
    /// (or the Trigger library when starting from Effects).
    var searchFallbacks: [LibraryMode] {
        switch self {
        case .instruments: return [.oneShots, .effects]
        case .oneShots: return [.instruments, .effects]
        case .all: return [.effects]
        case .effects: return [.all]
        }
    }
    /// Effects are a separate library; "All" means the whole Trigger library.
    func includes(_ kind: FileKind) -> Bool {
        switch self {
        case .instruments: return kind == .instrument
        case .oneShots: return kind == .oneShot
        case .all: return kind.isTriggerLibrary
        case .effects: return kind == .effect
        }
    }
    var isEffects: Bool { self == .effects }
}

/// One table row: a scanned file plus the user's metadata for it.
struct Row: Identifiable, Hashable {
    let file: TCIFile
    let meta: ItemMeta
    /// Effective vendor: pack override, else the guess from folder names.
    let vendor: String
    /// Effective pack name: override, else the inferred folder name.
    let pack: String
    /// Effective kit name, empty when the pack has no kit layer.
    let kit: String

    var id: String { file.path }
    var name: String { file.name }
    var kind: FileKind { file.kind }
    var format: String { file.formatName }
    var isPlayable: Bool { file.kind == .oneShot || file.kind == .effect }
    var variant: String { file.variant ?? "" }
    var category: DrumCategory { meta.category ?? file.category }
    var isEffect: Bool { file.kind == .effect }
    var effectCategory: EffectCategory? { isEffect ? (meta.effectCategory ?? file.effectCategory ?? .other) : nil }
    /// Drum category for Trigger-library files, effect type for effects.
    var categoryName: String { effectCategory?.singularName ?? category.singularName }
    var categorySymbol: String { effectCategory?.symbol ?? category.symbol }
    var source: SourceType { meta.source ?? file.source }
    var sourceName: String { source.displayName }
    var folder: String { file.folder }
    var tags: [String] { meta.tags }
    var notes: String { meta.notes }
    var notesOneLine: String { meta.notes.replacingOccurrences(of: "\n", with: " ") }
    var tagsJoined: String { meta.tags.joined(separator: ", ") }
    var favorite: Bool { meta.favorite }
    var favoriteRank: Int { meta.favorite ? 0 : 1 }
    var modified: Date { file.modified }
}

@MainActor
final class LibraryModel: ObservableObject {
    static let shared = LibraryModel()

    @Published private(set) var files: [TCIFile] = []
    @Published private(set) var data: LibraryData
    @Published var searchText = "" {
        didSet {
            if searchText != oldValue { pruneSelectionToVisible() }
            scheduleSelectionSync()
        }
    }
    @Published var filter: SidebarFilter? = .all {
        didSet {
            // Choosing a sidebar group is a new starting point: drop any active search so the
            // group is what you see, not the search hits.
            if filter != oldValue {
                if isSearching { searchText = "" }
                if !selection.isEmpty { selection = [] }
            }
            scheduleSelectionSync()
        }
    }
    @Published var selection: Set<String> = []
    @Published var sortOrder: [KeyPathComparator<Row>] = [KeyPathComparator(\Row.name)]
    @Published private(set) var isScanning = false
    @Published var lastScan: Date?
    @Published var showFolders = false
    @Published var mode: LibraryMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "libraryMode")
            guard mode != oldValue else { return }
            // A mode switch is a fresh start too: clear the search and selection.
            if isSearching { searchText = "" }
            if !selection.isEmpty { selection = [] }
            resetFilterIfStale()
            scheduleSelectionSync()
        }
    }

    /// Falls back to All Samples when the chosen sidebar group has nothing in the current mode
    /// (e.g. a vendor with no one-shots), so the table never sits empty on an invisible filter.
    private func resetFilterIfStale() {
        guard let filter, filter != .all else { return }
        let rows = allRows
        if !rows.contains(where: { matches(filter, row: $0) }) { self.filter = .all }
    }
    @Published var autoPlay: Bool {
        didSet { UserDefaults.standard.set(autoPlay, forKey: "autoPlay") }
    }
    let preview = AudioPreview()
    @Published var autoExport: Bool {
        didSet { UserDefaults.standard.set(autoExport, forKey: "autoExport"); if autoExport { scheduleAutoExport() } }
    }
    @Published private(set) var lastExport: Date?
    @Published private(set) var isExporting = false
    private var exportTask: Task<Void, Never>?
    @Published var mirrorSelection: Bool {
        didSet { UserDefaults.standard.set(mirrorSelection, forKey: "mirrorSelection"); scheduleSelectionSync() }
    }
    private var selectionSyncTask: Task<Void, Never>?

    private let store = LibraryStore()

    init() {
        Migration.runIfNeeded()
        data = store.load()
        mode = LibraryMode(rawValue: UserDefaults.standard.string(forKey: "libraryMode") ?? "") ?? .instruments
        autoPlay = UserDefaults.standard.bool(forKey: "autoPlay")
        autoExport = UserDefaults.standard.object(forKey: "autoExport") as? Bool ?? true
        mirrorSelection = UserDefaults.standard.object(forKey: "mirrorSelection") as? Bool ?? true
        if data.roots.isEmpty { showFolders = true }
    }

    /// Files that match the current mode.
    var visibleFiles: [TCIFile] { files.filter { mode.includes($0.kind) } }

    var instrumentCount: Int { files.filter { $0.kind == .instrument }.count }
    var oneShotCount: Int { files.filter { $0.kind == .oneShot }.count }
    var effectCount: Int { files.filter { $0.kind == .effect }.count }

    private func pruneSelection() {
        let visible = Set(visibleFiles.map(\.path))
        selection = selection.filter { visible.contains($0) }
    }

    /// Drops selected rows that the current search/filter no longer shows, so hidden rows never
    /// accumulate behind a new selection.
    private func pruneSelectionToVisible() {
        guard !selection.isEmpty else { return }
        let visible = Set(filteredRows.map(\.id))
        let kept = selection.filter { visible.contains($0) }
        if kept.count != selection.count { selection = kept }
    }

    /// Only rows that are actually visible count as selected.
    var selectedRows: [Row] {
        let byID = Dictionary(uniqueKeysWithValues: filteredRows.map { ($0.id, $0) })
        return selection.compactMap { byID[$0] }.sorted { $0.name < $1.name }
    }

    /// Plays the selected one-shot (space bar / Sample menu).
    func playSelection() {
        guard let row = selectedRows.first(where: \.isPlayable) else { return }
        preview.toggle(row.file.url)
    }

    /// Called when the selection changes so play-on-select can audition one-shots.
    func selectionChanged() {
        scheduleSelectionSync()
        guard autoPlay, selection.count == 1, let row = selectedRows.first, row.isPlayable else { return }
        preview.play(row.file.url)
    }

    /// Cap on how many links the top level takes when mirroring a whole group rather than a selection.
    static let topLevelLimit = 2000

    /// What the top level of the browser folder should show: the selected rows, or, with nothing
    /// selected, everything the sidebar filter or search currently shows (except plain "All Samples").
    var topLevelRows: [Row] {
        guard mirrorSelection, !mode.isEffects else { return [] }
        if !selection.isEmpty { return selectedRows.filter(\.file.kind.isTriggerLibrary) }
        let showingGroup = isSearching || (filter != nil && filter != .all)
        guard showingGroup else { return [] }
        return Array(filteredRows.filter(\.file.kind.isTriggerLibrary).prefix(Self.topLevelLimit))
    }

    /// Mirrors `topLevelRows` as links at the top level of the browser folder, debounced.
    private func scheduleSelectionSync() {
        selectionSyncTask?.cancel()
        let rows = topLevelRows
        selectionSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self, !self.isExporting else { return }
            let entries = BrowserFolder.entries(for: rows)
            let base = BrowserFolder.url
            let failure = await Task.detached(priority: .utility) { () -> String? in
                do { try BrowserFolderExporter.setTopLevel(entries, in: base); return nil }
                catch { return error.localizedDescription }
            }.value
            if let failure, self.browserFolderMessage == nil { self.browserFolderMessage = failure }
        }
    }

    var roots: [URL] { data.roots.map { URL(fileURLWithPath: $0) } }
    var effectRoots: [URL] { data.effectRoots.map { URL(fileURLWithPath: $0) } }
    var hasAnyRoots: Bool { !data.roots.isEmpty || !data.effectRoots.isEmpty }

    // MARK: - Rows and filtering

    var allRows: [Row] {
        visibleFiles.map { Row(file: $0, meta: data.items[$0.path] ?? ItemMeta(),
                               vendor: data.vendors[$0.packKey] ?? $0.vendor ?? "",
                               pack: data.packNames[$0.packKey] ?? $0.pack,
                               kit: (data.items[$0.path]?.kit) ?? $0.kitPath.flatMap { data.kitNames[$0] } ?? $0.kit ?? "") }
    }

    /// True while a search is active: the sidebar filter is ignored and only the mode narrows results.
    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Rows of every file the given mode includes.
    private func rows(in mode: LibraryMode) -> [Row] {
        files.filter { mode.includes($0.kind) }.map { Row(file: $0, meta: data.items[$0.path] ?? ItemMeta(),
                                                          vendor: data.vendors[$0.packKey] ?? $0.vendor ?? "",
                                                          pack: data.packNames[$0.packKey] ?? $0.pack,
                                                          kit: (data.items[$0.path]?.kit) ?? $0.kitPath.flatMap { data.kitNames[$0] } ?? $0.kit ?? "") }
    }

    private func search(_ rows: [Row], terms: [String]) -> [Row] {
        rows.filter { row in
            let haystack = [row.name, row.folder, row.pack, row.kit, row.categoryName, row.sourceName, row.tagsJoined, row.variant, row.vendor, row.notes]
                .joined(separator: " ").lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    /// Search result plus the library it came from when the current mode had no matches.
    struct SearchOutcome {
        var rows: [Row]
        var fallback: LibraryMode?
    }

    var searchOutcome: SearchOutcome {
        let terms = searchText.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else {
            return SearchOutcome(rows: allRows.filter { matches(filter, row: $0) }.sorted(using: sortOrder), fallback: nil)
        }
        let own = search(allRows, terms: terms)
        if !own.isEmpty { return SearchOutcome(rows: own.sorted(using: sortOrder), fallback: nil) }
        for stage in mode.searchFallbacks {
            let hits = search(rows(in: stage), terms: terms)
            if !hits.isEmpty { return SearchOutcome(rows: hits.sorted(using: sortOrder), fallback: stage) }
        }
        return SearchOutcome(rows: [], fallback: nil)
    }

    var filteredRows: [Row] { searchOutcome.rows }

    /// Set while a search is showing results from another library than the current mode.
    var searchFallback: LibraryMode? { searchOutcome.fallback }

    private func matches(_ filter: SidebarFilter?, row: Row) -> Bool {
        switch filter {
        case .none, .all: return true
        case .favorites: return row.favorite
        case .untagged: return row.tags.isEmpty
        case .category(let c): return row.category == c
        case .source(let s): return row.source == s
        case .effectCategory(let e): return row.effectCategory == e
        case .pack(let p): return row.pack == p
        case .tag(let t): return row.tags.contains(t)
        case .vendor(let v): return row.vendor == v
        case .kit(let p, let k): return row.pack == p && row.kit == k
        }
    }

    var favoriteCount: Int { allRows.filter(\.favorite).count }
    var untaggedCount: Int { allRows.filter { $0.tags.isEmpty }.count }

    var categoryCounts: [(DrumCategory, Int)] {
        var counts: [DrumCategory: Int] = [:]
        for row in allRows { counts[row.category, default: 0] += 1 }
        return DrumCategory.allCases.compactMap { c in counts[c].map { (c, $0) } }
    }

    var effectCategoryCounts: [(EffectCategory, Int)] {
        var counts: [EffectCategory: Int] = [:]
        for row in allRows { if let e = row.effectCategory { counts[e, default: 0] += 1 } }
        return EffectCategory.allCases.compactMap { e in counts[e].map { (e, $0) } }
    }

    func setEffectCategory(_ category: EffectCategory?, for ids: Set<String>) {
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        update(ids) { $0.effectCategory = category }
        for id in ids where (byPath[id]?.effectCategory ?? .other) == category {
            update([id]) { $0.effectCategory = nil }
        }
    }

    var sourceCounts: [(SourceType, Int)] {
        var counts: [SourceType: Int] = [:]
        for row in allRows { counts[row.source, default: 0] += 1 }
        return SourceType.allCases.compactMap { s in counts[s].map { (s, $0) } }
    }

    func setSource(_ source: SourceType?, for ids: Set<String>) {
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        update(ids) { $0.source = source }
        for id in ids where byPath[id]?.source == source {
            update([id]) { $0.source = nil }   // matches the guess: no override needed
        }
    }

    var packCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for row in allRows { counts[row.pack, default: 0] += 1 }
        return counts.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    /// Kits inside a pack with their counts, sorted by name. Empty when the pack has no kit layer.
    func kitCounts(inPack pack: String) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for row in allRows where row.pack == pack && !row.kit.isEmpty { counts[row.kit, default: 0] += 1 }
        return counts.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    /// Assigns the given files to a kit (empty clears the manual assignment).
    func setKit(_ raw: String, for ids: Set<String>) {
        let kit = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        update(ids) { $0.kit = kit.isEmpty ? nil : kit }
    }

    /// Kits already used inside the given packs, for quick picking.
    func kits(inPacks packs: Set<String>) -> [String] {
        Array(Set(allRows.filter { packs.contains($0.pack) && !$0.kit.isEmpty }.map(\.kit)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Sets (or clears, when empty) the display name of the folder-based kits containing the given files.
    func setKitName(_ raw: String, forKitsOf ids: Set<String>) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let keys = Set(files.filter { ids.contains($0.path) }.compactMap(\.kitPath))
        for key in keys {
            if value.isEmpty { data.kitNames.removeValue(forKey: key) } else { data.kitNames[key] = value }
        }
        persist()
        if case .kit(let pack, _) = filter ?? .all, let file = files.first(where: { keys.contains($0.kitPath ?? "") }) {
            filter = .kit(pack: pack, kit: data.kitNames[file.kitPath!] ?? file.kit ?? "")
        }
    }

    /// Rename a pack or kit from the sidebar, by display name.
    func renamePack(_ pack: String, to newName: String) {
        setPackName(newName, forPacksOf: Set(allRows.filter { $0.pack == pack }.map(\.id)))
    }

    /// Renames a kit: folder-based members get a folder override, manually assigned members are reassigned.
    func renameKit(_ kit: String, inPack pack: String, to newName: String) {
        let members = allRows.filter { $0.pack == pack && $0.kit == kit }
        let manual = Set(members.filter { $0.meta.kit != nil }.map(\.id))
        let folderBased = Set(members.filter { $0.meta.kit == nil }.map(\.id))
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty { setKit(name, for: manual) }
        if !folderBased.isEmpty { setKitName(name, forKitsOf: folderBased) }
    }

    var vendorCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for row in allRows { counts[row.vendor.isEmpty ? "Unknown" : row.vendor, default: 0] += 1 }
        return counts.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    /// Sets (or clears, when empty) the vendor for every file in the packs of the given files.
    func setVendor(_ raw: String, forPacksOf ids: Set<String>) {
        setPackOverride(raw, keyPath: \.vendors, forPacksOf: ids)
    }

    /// Sets (or clears, when empty) the display name of the packs containing the given files.
    func setPackName(_ raw: String, forPacksOf ids: Set<String>) {
        let keys = Set(files.filter { ids.contains($0.path) }.map(\.packKey))
        let old = Set(keys.compactMap { key in files.first { $0.packKey == key } }.map { data.packNames[$0.packKey] ?? $0.pack })
        setPackOverride(raw, keyPath: \.packNames, forPacksOf: ids)
        // Keep the sidebar pointing at the renamed pack.
        if case .pack(let current) = filter ?? .all, old.contains(current),
           let file = files.first(where: { keys.contains($0.packKey) }) {
            filter = .pack(data.packNames[file.packKey] ?? file.pack)
        }
    }

    private func setPackOverride(_ raw: String, keyPath: WritableKeyPath<LibraryData, [String: String]>, forPacksOf ids: Set<String>) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let keys = Set(files.filter { ids.contains($0.path) }.map(\.packKey))
        for key in keys {
            if value.isEmpty { data[keyPath: keyPath].removeValue(forKey: key) } else { data[keyPath: keyPath][key] = value }
        }
        persist()
    }

    var tagCounts: [(String, Int)] {
        var counts: [String: Int] = [:]
        for row in allRows { for tag in row.tags { counts[tag, default: 0] += 1 } }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    var allTags: [String] { tagCounts.map(\.0) }

    // MARK: - Scanning

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let roots = self.roots
        let effectRoots = self.effectRoots
        Task.detached(priority: .userInitiated) {
            let found = Scanner.scan(roots: roots, effectRoots: effectRoots)
            await MainActor.run {
                self.files = found
                self.data.reconcile(with: found)
                self.isScanning = false
                self.lastScan = .now
                let present = Set(found.map(\.path))
                self.selection = self.selection.filter { present.contains($0) }
                self.persist()
                self.resetFilterIfStale()
                self.scheduleSelectionSync()
            }
        }
    }

    func addRoot(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard !data.roots.contains(path) else { return }
        data.roots.append(path)
        persist()
        rescan()
    }

    func removeRoot(_ path: String) {
        data.roots.removeAll { $0 == path }
        persist()
        rescan()
    }

    func addEffectRoot(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard !data.effectRoots.contains(path) else { return }
        data.effectRoots.append(path)
        persist()
        rescan()
    }

    func removeEffectRoot(_ path: String) {
        data.effectRoots.removeAll { $0 == path }
        persist()
        rescan()
    }

    // MARK: - Metadata edits

    /// Notes are per file and never affect the browser folder, so saving them skips the export.
    func setNotes(_ text: String, for id: String) {
        update([id], triggersExport: false) { $0.notes = text.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func update(_ ids: Set<String>, triggersExport: Bool = true, _ change: (inout ItemMeta) -> Void) {
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        for id in ids {
            var meta = data.items[id] ?? ItemMeta()
            if let file = byPath[id] {
                meta.fileName = file.url.lastPathComponent
                meta.fileSize = file.size
            }
            change(&meta)
            if meta.isEmpty { data.items.removeValue(forKey: id) } else { data.items[id] = meta }
        }
        persist(triggersExport: triggersExport)
    }

    func toggleFavorite(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let allFavorite = ids.allSatisfy { data.items[$0]?.favorite == true }
        update(ids) { $0.favorite = !allFavorite }
    }

    func toggleFavoriteOfSelection() { toggleFavorite(selection) }

    /// Tags keep the capitalisation you type, but match ignoring case: a new tag reuses the spelling
    /// of an existing one so "Punchy" and "punchy" never coexist.
    private func canonicalTag(_ raw: String) -> String? {
        let typed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        return allTags.first { $0.caseInsensitiveCompare(typed) == .orderedSame } ?? typed
    }

    func addTag(_ raw: String, to ids: Set<String>) {
        guard let tag = canonicalTag(raw), !ids.isEmpty else { return }
        update(ids) { meta in
            if !meta.tags.contains(tag) {
                meta.tags.append(tag)
                meta.tags.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }
        }
    }

    func removeTag(_ tag: String, from ids: Set<String>) {
        update(ids) { $0.tags.removeAll { $0 == tag } }
    }

    func deleteTagEverywhere(_ tag: String) {
        update(Set(data.items.keys)) { $0.tags.removeAll { $0 == tag } }
        if filter == .tag(tag) { filter = .all }
    }

    func renameTag(_ tag: String, to newName: String) {
        let typed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty, typed != tag else { return }
        // Renaming to a different casing of itself is allowed; otherwise merge into an existing spelling.
        let new = typed.caseInsensitiveCompare(tag) == .orderedSame ? typed : (canonicalTag(typed) ?? typed)
        update(Set(data.items.keys)) { meta in
            if meta.tags.contains(tag) {
                meta.tags.removeAll { $0 == tag }
                if !meta.tags.contains(new) { meta.tags.append(new) }
                meta.tags.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            }
        }
        if filter == .tag(tag) { filter = .tag(new) }
    }

    func setCategory(_ category: DrumCategory?, for ids: Set<String>) {
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        update(ids) { meta in
            // Clear the override when it matches the auto-detected value.
            meta.category = category
        }
        for id in ids {
            if let file = byPath[id], data.items[id]?.category == file.category {
                update([id]) { $0.category = nil }
            }
        }
    }

    /// Copies the full paths of the given files, one per line, for pasting into Trigger's open dialog.
    func copyPaths(_ ids: Set<String>) {
        let paths = selectedRows.filter { ids.contains($0.id) }.map(\.file.path)
        guard !paths.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    @Published var browserFolderMessage: String?

    /// Rows for every Trigger-library file regardless of the current mode. Effects are never exported.
    private var exportRows: [Row] {
        files.filter(\.kind.isTriggerLibrary).map { Row(file: $0, meta: data.items[$0.path] ?? ItemMeta(),
                        vendor: data.vendors[$0.packKey] ?? $0.vendor ?? "",
                        pack: data.packNames[$0.packKey] ?? $0.pack,
                        kit: (data.items[$0.path]?.kit) ?? $0.kitPath.flatMap { data.kitNames[$0] } ?? $0.kit ?? "") }
    }

    /// Manual rebuild of the symlink folder Trigger's browser navigates; reports the result in an alert.
    func updateBrowserFolder() {
        exportTask?.cancel()
        Task { await runExport(report: true) }
    }

    /// Debounced background rebuild, triggered by every metadata change and rescan.
    private func scheduleAutoExport() {
        guard autoExport, !files.isEmpty else { return }
        exportTask?.cancel()
        exportTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.runExport(report: false)
        }
    }

    private func runExport(report: Bool) async {
        guard !isExporting else { scheduleAutoExport(); return }
        isExporting = true
        let entries = BrowserFolder.entries(for: exportRows)
        let selected = BrowserFolder.entries(for: topLevelRows)
        let base = BrowserFolder.url
        let outcome = await Task.detached(priority: .utility) { () -> Result<BrowserFolderExporter.Result, Error> in
            Result {
                let result = try BrowserFolderExporter.export(entries, to: base)
                try BrowserFolderExporter.setTopLevel(selected, in: base)
                return result
            }
        }.value
        isExporting = false
        switch outcome {
        case .success(let result):
            lastExport = .now
            if report {
                browserFolderMessage = "Wrote \(result.links) links in \(result.folders) folders to \(base.path). Point Trigger 2's browser at that folder."
            }
        case .failure(let error):
            browserFolderMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ ids: Set<String>) {
        let urls = ids.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func persist(triggersExport: Bool = true) {
        do { try store.save(data) } catch { NSLog("Sample Search: failed to save library: \(error)") }
        if triggersExport { scheduleAutoExport() }
    }
}
