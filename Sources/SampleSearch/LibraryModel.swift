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
    /// Lower-cased text the search box matches against, built once.
    let haystack: String
    /// Case-folded, number-aware key so "Snare 2" sorts before "Snare 10".
    let nameKey: String

    init(file: TCIFile, meta: ItemMeta, vendor: String, pack: String, kit: String) {
        self.file = file
        self.meta = meta
        self.vendor = vendor
        self.pack = pack
        self.kit = kit
        let effect = file.kind == .effect ? (meta.effectCategory ?? file.effectCategory ?? .other) : nil
        let categoryName = effect?.singularName ?? (meta.category ?? file.category).singularName
        haystack = [file.name, file.folder, pack, kit, categoryName, (meta.source ?? file.source).displayName,
                    meta.tags.joined(separator: ", "), file.variant ?? "", vendor, meta.notes]
            .joined(separator: " ").lowercased()
        nameKey = Row.naturalKey(file.name)
    }

    /// Lower-cases and zero-pads digit runs so plain string comparison gives natural order.
    static func naturalKey(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count + 8)
        var digits = ""
        func flush() {
            if !digits.isEmpty { out += String(repeating: "0", count: max(0, 10 - digits.count)) + digits; digits = "" }
        }
        for ch in text.lowercased() {
            if ch.isNumber { digits.append(ch) } else { flush(); out.append(ch) }
        }
        flush()
        return out
    }

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

    @Published private(set) var files: [TCIFile] = [] { didSet { rebuildRows() } }
    @Published private(set) var data: LibraryData { didSet { rebuildRows() } }
    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            refilter()
            pruneSelectionToVisible()
            scheduleSelectionSync()
        }
    }
    @Published var filter: SidebarFilter? = .all {
        didSet {
            // Choosing a sidebar group is a new starting point: drop any active search so the
            // group is what you see, not the search hits.
            if filter != oldValue {
                if isSearching { searchText = "" }   // refilters via its own observer
                refilter()
                if !selection.isEmpty { selection = [] }
            }
            scheduleSelectionSync()
        }
    }
    @Published var selection: Set<String> = []
    @Published var sortOrder: [KeyPathComparator<Row>] = [KeyPathComparator(\Row.name)] {
        didSet { refilter() }
    }

    // MARK: Cached derived data (rebuilt only when inputs change; see rebuildRows / refilter)

    /// Every file as a row, all modes.
    private var everyRow: [Row] = []
    /// Rows in the current mode.
    @Published private(set) var allRows: [Row] = []
    /// What the table shows: sidebar filter or search applied, sorted.
    @Published private(set) var filteredRows: [Row] = []
    /// Set while a search is showing results from another library than the current mode.
    @Published private(set) var searchFallback: LibraryMode?
    private var filteredByID: [String: Row] = [:]
    @Published private(set) var instrumentCount = 0
    @Published private(set) var oneShotCount = 0
    @Published private(set) var effectCount = 0
    @Published private(set) var favoriteCount = 0
    @Published private(set) var untaggedCount = 0
    @Published private(set) var categoryCounts: [(DrumCategory, Int)] = []
    @Published private(set) var effectCategoryCounts: [(EffectCategory, Int)] = []
    @Published private(set) var sourceCounts: [(SourceType, Int)] = []
    @Published private(set) var packCounts: [(String, Int)] = []
    @Published private(set) var vendorCounts: [(String, Int)] = []
    @Published private(set) var tagCounts: [(String, Int)] = []
    private var kitsByPack: [String: [(String, Int)]] = [:]
    @Published private(set) var isScanning = false
    @Published var lastScan: Date?
    @Published var showFolders = false
    @Published var showWelcome = false
    @Published var confirmReset = false
    @Published var mode: LibraryMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "libraryMode")
            guard mode != oldValue else { return }
            rebuildRows()
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
        if !hasAnyRoots { showWelcome = true }
        rebuildRows()
    }

    /// Preference keys the app owns. Library data (tags, favourites, notes, folders) lives in
    /// library.json and is untouched by a reset.
    static let preferenceKeys = ["libraryMode", "autoPlay", "autoExport", "mirrorSelection", "browserFolder",
                                 "showInspector", "tableColumns", "autoCheckUpdates", "lastUpdateCheck",
                                 "NSWindow Frame MainWindow", "NSToolbar Configuration main"]

    /// Clears preferences only: window, columns, toolbar, toggles, mode, browser-folder location.
    func resetSettings() {
        let defaults = UserDefaults.standard
        for key in Self.preferenceKeys { defaults.removeObject(forKey: key) }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("NSToolbar Configuration") || key.hasPrefix("NSWindow Frame") {
            defaults.removeObject(forKey: key)
        }
        mode = .instruments
        autoPlay = false
        autoExport = true
        mirrorSelection = true
        searchText = ""
        selection = []
        filter = .all
        showWelcome = true
    }

    /// Files that match the current mode.
    var visibleFiles: [TCIFile] { allRows.map(\.file) }

    private func pruneSelection() {
        let visible = Set(allRows.map(\.id))
        selection = selection.filter { visible.contains($0) }
    }

    /// Drops selected rows that the current search/filter no longer shows, so hidden rows never
    /// accumulate behind a new selection.
    private func pruneSelectionToVisible() {
        guard !selection.isEmpty else { return }
        let kept = selection.filter { filteredByID[$0] != nil }
        if kept.count != selection.count { selection = kept }
    }

    /// Only rows that are actually visible count as selected.
    var selectedRows: [Row] {
        selection.compactMap { filteredByID[$0] }.sorted { $0.nameKey < $1.nameKey }
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

    private func makeRow(_ file: TCIFile) -> Row {
        let meta = data.items[file.path] ?? ItemMeta()
        return Row(file: file, meta: meta,
                   vendor: data.vendors[file.packKey] ?? file.vendor ?? "",
                   pack: data.packNames[file.packKey] ?? file.pack,
                   kit: meta.kit ?? file.kitPath.flatMap { data.kitNames[$0] } ?? file.kit ?? "")
    }

    /// Rebuilds every cached row and count. Called when files, metadata or the mode change.
    private func rebuildRows() {
        everyRow = files.map(makeRow)
        allRows = everyRow.filter { mode.includes($0.kind) }
        instrumentCount = 0; oneShotCount = 0; effectCount = 0
        for row in everyRow {
            switch row.kind {
            case .instrument: instrumentCount += 1
            case .oneShot: oneShotCount += 1
            case .effect: effectCount += 1
            }
        }
        var favorites = 0, untagged = 0
        var categories: [DrumCategory: Int] = [:], effects: [EffectCategory: Int] = [:], sources: [SourceType: Int] = [:]
        var packs: [String: Int] = [:], vendors: [String: Int] = [:], tags: [String: Int] = [:]
        var kits: [String: [String: Int]] = [:]
        for row in allRows {
            if row.favorite { favorites += 1 }
            if row.tags.isEmpty { untagged += 1 }
            if let e = row.effectCategory { effects[e, default: 0] += 1 } else { categories[row.category, default: 0] += 1 }
            if !row.isEffect { sources[row.source, default: 0] += 1 }
            packs[row.pack, default: 0] += 1
            vendors[row.vendor.isEmpty ? "Unknown" : row.vendor, default: 0] += 1
            for tag in row.tags { tags[tag, default: 0] += 1 }
            if !row.kit.isEmpty { kits[row.pack, default: [:]][row.kit, default: 0] += 1 }
        }
        favoriteCount = favorites
        untaggedCount = untagged
        categoryCounts = DrumCategory.allCases.compactMap { c in categories[c].map { (c, $0) } }
        effectCategoryCounts = EffectCategory.allCases.compactMap { e in effects[e].map { (e, $0) } }
        sourceCounts = SourceType.allCases.compactMap { s in sources[s].map { (s, $0) } }
        let byName: ((String, Int), (String, Int)) -> Bool = { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        packCounts = packs.map { ($0.key, $0.value) }.sorted(by: byName)
        vendorCounts = vendors.map { ($0.key, $0.value) }.sorted(by: byName)
        tagCounts = tags.map { ($0.key, $0.value) }.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : byName($0, $1) }
        kitsByPack = kits.mapValues { $0.map { ($0.key, $0.value) }.sorted(by: byName) }
        refilter()
    }

    /// True while a search is active: the sidebar filter is ignored and only the mode narrows results.
    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private func search(_ rows: [Row], terms: [String]) -> [Row] {
        rows.filter { row in terms.allSatisfy { row.haystack.contains($0) } }
    }

    /// Recomputes the table rows from the cached rows. Called when search, filter or sort change.
    private func refilter() {
        let terms = searchText.lowercased().split(separator: " ").map(String.init)
        var rows: [Row]
        var fallback: LibraryMode?
        if terms.isEmpty {
            rows = allRows.filter { matches(filter, row: $0) }
        } else {
            rows = search(allRows, terms: terms)
            if rows.isEmpty {
                for stage in mode.searchFallbacks {
                    let hits = search(everyRow.filter { stage.includes($0.kind) }, terms: terms)
                    if !hits.isEmpty { rows = hits; fallback = stage; break }
                }
            }
        }
        filteredRows = sorted(rows)
        searchFallback = fallback
        filteredByID = Dictionary(uniqueKeysWithValues: filteredRows.map { ($0.id, $0) })
    }

    /// Sorts by the table's first comparator using precomputed string keys (natural order for
    /// text), ties broken by name. Far cheaper than the locale-aware comparator SwiftUI supplies.
    private func sorted(_ rows: [Row]) -> [Row] {
        guard let comparator = sortOrder.first else { return rows.sorted { $0.nameKey < $1.nameKey } }
        let keyPath = comparator.keyPath
        let reverse = comparator.order == .reverse
        let keys = rows.map { Self.sortKey(for: $0[keyPath: keyPath]) }
        let order = rows.indices.sorted { a, b in
            if keys[a] != keys[b] { return reverse ? keys[a] > keys[b] : keys[a] < keys[b] }
            return rows[a].nameKey < rows[b].nameKey
        }
        return order.map { rows[$0] }
    }

    private static func sortKey(for value: Any) -> String {
        switch value {
        case let text as String: return Row.naturalKey(text)
        case let number as Int: return String(format: "%012d", number)
        case let category as DrumCategory: return String(format: "%03d", DrumCategory.allCases.firstIndex(of: category) ?? 0)
        case let source as SourceType: return String(format: "%03d", SourceType.allCases.firstIndex(of: source) ?? 0)
        case let kind as FileKind: return kind.rawValue
        case let date as Date: return String(format: "%020.3f", date.timeIntervalSince1970)
        default: return String(describing: value)
        }
    }

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

    func setEffectCategory(_ category: EffectCategory?, for ids: Set<String>) {
        // An override equal to the auto-detected value is dropped rather than stored.
        updateEach(ids) { file, meta in meta.effectCategory = (file?.effectCategory ?? .other) == category ? nil : category }
    }

    func setSource(_ source: SourceType?, for ids: Set<String>) {
        updateEach(ids) { file, meta in meta.source = file?.source == source ? nil : source }
    }

    /// Kits inside a pack with their counts, sorted by name. Empty when the pack has no kit layer.
    func kitCounts(inPack pack: String) -> [(String, Int)] { kitsByPack[pack] ?? [] }

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
        var names = data.kitNames
        for key in keys {
            if value.isEmpty { names.removeValue(forKey: key) } else { names[key] = value }
        }
        data.kitNames = names
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
        var overrides = data[keyPath: keyPath]
        for key in keys {
            if value.isEmpty { overrides.removeValue(forKey: key) } else { overrides[key] = value }
        }
        data[keyPath: keyPath] = overrides
        persist()
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
        updateEach(ids, triggersExport: triggersExport) { _, meta in change(&meta) }
    }

    /// Applies a change to the metadata of each file, writing `data` once so the cached rows are
    /// rebuilt a single time however many files are involved.
    private func updateEach(_ ids: Set<String>, triggersExport: Bool = true, _ change: (TCIFile?, inout ItemMeta) -> Void) {
        guard !ids.isEmpty else { return }
        let byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        var items = data.items
        for id in ids {
            var meta = items[id] ?? ItemMeta()
            let file = byPath[id]
            if let file {
                meta.fileName = file.url.lastPathComponent
                meta.fileSize = file.size
            }
            change(file, &meta)
            if meta.isEmpty { items.removeValue(forKey: id) } else { items[id] = meta }
        }
        data.items = items
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
        // An override equal to the auto-detected value is dropped rather than stored.
        updateEach(ids) { file, meta in meta.category = file?.category == category ? nil : category }
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
