import Foundation

/// Coarse drum category, derived from file and folder names (overridable per file).
public enum DrumCategory: String, Codable, CaseIterable, Hashable, Comparable {
    case kick, snare, tom, hihat, cymbal, percussion, other

    public var displayName: String {
        switch self {
        case .kick: return "Kicks"
        case .snare: return "Snares"
        case .tom: return "Toms"
        case .hihat: return "Hi-Hats"
        case .cymbal: return "Cymbals"
        case .percussion: return "Percussion"
        case .other: return "Other"
        }
    }

    public var singularName: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .tom: return "Tom"
        case .hihat: return "Hi-Hat"
        case .cymbal: return "Cymbal"
        case .percussion: return "Percussion"
        case .other: return "Other"
        }
    }

    /// SF Symbol name used in the sidebar.
    public var symbol: String {
        switch self {
        case .kick: return "circle.fill"
        case .snare: return "circle.circle"
        case .tom: return "circle.dotted"
        case .hihat: return "line.3.horizontal"
        case .cymbal: return "sun.max"
        case .percussion: return "hands.clap"
        case .other: return "questionmark.circle"
        }
    }

    public static func < (lhs: DrumCategory, rhs: DrumCategory) -> Bool {
        let order = DrumCategory.allCases
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// Which microphone / signal the sample comes from. A sub-category of the drum category.
public enum SourceType: String, Codable, CaseIterable, Hashable, Comparable {
    case direct, overheads, rooms, fx

    public var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .overheads: return "Overheads"
        case .rooms: return "Rooms"
        case .fx: return "FX"
        }
    }

    public var symbol: String {
        switch self {
        case .direct: return "mic.fill"
        case .overheads: return "arrow.up.to.line"
        case .rooms: return "building.columns"
        case .fx: return "wand.and.stars"
        }
    }

    public static func < (lhs: SourceType, rhs: SourceType) -> Bool {
        let order = SourceType.allCases
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// What kind of file a library entry is.
public enum FileKind: String, Codable, Hashable, Comparable {
    /// Slate Trigger `.tci` compressed instrument.
    case instrument
    /// Plain `.wav` / `.aif` / `.aiff` one-shot sample.
    case oneShot

    public static let extensions: [String: FileKind] = [
        "tci": .instrument, "wav": .oneShot, "wave": .oneShot, "aif": .oneShot, "aiff": .oneShot,
    ]

    public var displayName: String { self == .instrument ? "Instrument" : "One-Shot" }

    public static func < (lhs: FileKind, rhs: FileKind) -> Bool { lhs == .instrument && rhs == .oneShot }
}

/// One library file found on disk. Everything here is derived from the filesystem.
public struct TCIFile: Identifiable, Hashable, Codable {
    public var id: String { path }
    public let path: String
    public let kind: FileKind
    /// File name without the `.tci` extension.
    public let name: String
    /// Name with the trailing variant token removed, e.g. "Snare 5" for "Snare 5 SSDR".
    public let baseName: String
    /// Trailing variant token such as SSDR, NRG, Z1, Z3 (nil if none).
    public let variant: String?
    /// Library root this file was found under.
    public let root: String
    /// Inferred pack name: the top-level folder under the root, or the root's own name when that
    /// folder looks like a category ("Trigger2 Snares") or the file sits at the top level.
    public let pack: String
    /// Directory the pack name was inferred from; used as the key for pack-level overrides.
    public let packPath: String
    /// Inferred kit inside the pack (e.g. "Kit C" in Vendor One), nil when the pack has no kit layer.
    public let kit: String?
    /// Directory the kit name was inferred from; key for kit-level overrides.
    public let kitPath: String?
    /// Directory path relative to the root.
    public let folder: String
    public let category: DrumCategory
    /// Mic source guessed from the name (OH, Room, FX …); Direct when nothing says otherwise.
    public let source: SourceType
    /// Vendor guessed from folder names; nil when unknown.
    public let vendor: String?
    public let size: Int64
    public let modified: Date

    /// Key used for per-pack settings such as a vendor or name override.
    public var packKey: String { packPath }

    public var url: URL { URL(fileURLWithPath: path) }
    /// Upper-cased extension, e.g. "TCI", "WAV".
    public var formatName: String { url.pathExtension.uppercased() }

    public init(path: String, kind: FileKind = .instrument, name: String, baseName: String, variant: String?, root: String,
                pack: String, packPath: String? = nil, kit: String? = nil, kitPath: String? = nil,
                folder: String, category: DrumCategory, source: SourceType = .direct, vendor: String? = nil,
                size: Int64, modified: Date) {
        self.path = path
        self.source = source
        self.packPath = packPath ?? (root + "/" + pack)
        self.kit = kit
        self.kitPath = kitPath ?? kit.map { (packPath ?? (root + "/" + pack)) + "/" + $0 }
        self.kind = kind
        self.vendor = vendor
        self.name = name
        self.baseName = baseName
        self.variant = variant
        self.root = root
        self.pack = pack
        self.folder = folder
        self.category = category
        self.size = size
        self.modified = modified
    }
}

/// User-added metadata for one file. Keyed by path in `LibraryData`.
public struct ItemMeta: Codable, Hashable {
    public var tags: [String] = []
    public var favorite: Bool = false
    /// Manual category override.
    public var category: DrumCategory?
    /// Manual source override.
    public var source: SourceType?
    /// Manual kit assignment; wins over the folder-based kit.
    public var kit: String?
    /// Free-text notes; searchable, not exported to the browser folder.
    public var notes: String = ""
    /// File name and size, kept so metadata can follow a file that moves to another folder.
    public var fileName: String = ""
    public var fileSize: Int64 = 0

    public init(tags: [String] = [], favorite: Bool = false, category: DrumCategory? = nil, source: SourceType? = nil,
                kit: String? = nil, notes: String = "", fileName: String = "", fileSize: Int64 = 0) {
        self.tags = tags
        self.favorite = favorite
        self.category = category
        self.source = source
        self.kit = kit
        self.notes = notes
        self.fileName = fileName
        self.fileSize = fileSize
    }

    public var isEmpty: Bool {
        tags.isEmpty && !favorite && category == nil && source == nil && kit == nil && notes.isEmpty
    }

    enum CodingKeys: String, CodingKey { case tags, favorite, category, source, kit, notes, fileName, fileSize }

    /// Tolerant decoding: an old "room" category override becomes a Rooms source override.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        let rawCategory = try c.decodeIfPresent(String.self, forKey: .category)
        category = rawCategory.flatMap(DrumCategory.init(rawValue:))
        source = try c.decodeIfPresent(String.self, forKey: .source).flatMap(SourceType.init(rawValue:))
        if rawCategory == "room", source == nil { source = .rooms }
        kit = try c.decodeIfPresent(String.self, forKey: .kit)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
    }
}

/// Everything persisted between launches.
public struct LibraryData: Codable {
    public var roots: [String] = []
    public var items: [String: ItemMeta] = [:]
    /// Vendor overrides keyed by `TCIFile.packKey`.
    public var vendors: [String: String] = [:]
    /// Pack name overrides keyed by `TCIFile.packKey`.
    public var packNames: [String: String] = [:]
    /// Kit name overrides keyed by `TCIFile.kitPath`.
    public var kitNames: [String: String] = [:]

    public init(roots: [String] = [], items: [String: ItemMeta] = [:], vendors: [String: String] = [:],
                packNames: [String: String] = [:], kitNames: [String: String] = [:]) {
        self.roots = roots
        self.items = items
        self.vendors = vendors
        self.packNames = packNames
        self.kitNames = kitNames
    }

    enum CodingKeys: String, CodingKey { case roots, items, vendors, packNames, kitNames }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roots = try c.decodeIfPresent([String].self, forKey: .roots) ?? []
        items = try c.decodeIfPresent([String: ItemMeta].self, forKey: .items) ?? [:]
        vendors = try c.decodeIfPresent([String: String].self, forKey: .vendors) ?? [:]
        packNames = try c.decodeIfPresent([String: String].self, forKey: .packNames) ?? [:]
        kitNames = try c.decodeIfPresent([String: String].self, forKey: .kitNames) ?? [:]
    }
}
