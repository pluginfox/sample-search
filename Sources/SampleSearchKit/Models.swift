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
        case .overheads: return "point.3.filled.connected.trianglepath.dotted"
        case .rooms: return "building.columns"
        case .fx: return "sparkles"
        }
    }

    public static func < (lhs: SourceType, rhs: SourceType) -> Bool {
        let order = SourceType.allCases
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

/// A sound-effect type for the separate Effects library. User-editable: name, icon and the
/// keywords that classify files. Matching runs in list order, so position is priority.
public struct EffectType: Codable, Hashable, Identifiable {
    public var id: String
    /// Plural label for the sidebar, e.g. "Risers".
    public var name: String
    /// Singular label for a row, e.g. "Riser".
    public var singular: String
    /// SF Symbol name.
    public var symbol: String
    /// Lower-cased substrings matched against file and folder names.
    public var keywords: [String]

    public init(id: String, name: String, singular: String, symbol: String, keywords: [String]) {
        self.id = id
        self.name = name
        self.singular = singular
        self.symbol = symbol
        self.keywords = keywords
    }

    /// The implicit fallback for files no type matches; never stored in the list.
    public static let other = EffectType(id: "other", name: "Other", singular: "Other", symbol: "questionmark.circle", keywords: [])

    public static let defaults: [EffectType] = [
        EffectType(id: "reverse", name: "Reverses", singular: "Reverse", symbol: "wave.3.forward",
                   keywords: ["reverse", "reversed", "backward", "rev "]),
        EffectType(id: "riser", name: "Risers", singular: "Riser", symbol: "arrow.up.right",
                   keywords: ["riser", "uplifter", "upsweep", "up sweep", "rise", "build", "tension"]),
        EffectType(id: "subdrop", name: "Sub Drops", singular: "Sub Drop", symbol: "arrow.down.to.line",
                   keywords: ["sub drop", "subdrop", "sub-drop", "bass drop", "808 drop", "sub bass", "sub "]),
        EffectType(id: "downlifter", name: "Downlifters", singular: "Downlifter", symbol: "arrow.down.right",
                   keywords: ["downlifter", "downsweep", "down sweep", "downer", "fall", "faller", "drop"]),
        EffectType(id: "impact", name: "Impacts", singular: "Impact", symbol: "burst.fill",
                   keywords: ["impact", "boom", "slam", "explosion", "crash fx", "cinematic hit"]),
        EffectType(id: "hit", name: "Hits & Stabs", singular: "Hit", symbol: "hammer",
                   keywords: ["hit", "stab", "punch", "one shot fx", "shot"]),
        EffectType(id: "cymbal", name: "Cymbals", singular: "Cymbal", symbol: "sun.max",
                   keywords: ["cymbal", "crash", "china", "splash", "ride", "swell", "cym "]),
        EffectType(id: "whoosh", name: "Whooshes & Sweeps", singular: "Whoosh", symbol: "wind",
                   keywords: ["whoosh", "swoosh", "sweep", "swish", "wind", "flyby", "fly by", "pass"]),
        EffectType(id: "drone", name: "Drones & Textures", singular: "Drone", symbol: "waveform.path",
                   keywords: ["drone", "pad", "texture", "atmos", "ambien", "noise", "bed", "soundscape"]),
    ]

    /// Looks a type up by id in a list, falling back to Other.
    public static func resolve(_ id: String?, in types: [EffectType]) -> EffectType {
        guard let id, id != other.id else { return other }
        return types.first { $0.id == id } ?? other
    }
}

/// What kind of file a library entry is.
public enum FileKind: String, Codable, Hashable, Comparable {
    /// Slate Trigger `.tci` compressed instrument.
    case instrument
    /// Plain `.wav` / `.aif` / `.aiff` one-shot sample.
    case oneShot
    /// A `.wav` / `.aiff` from the separate Effects library (risers, impacts…).
    case effect

    public static let extensions: [String: FileKind] = [
        "tci": .instrument, "wav": .oneShot, "wave": .oneShot, "aif": .oneShot, "aiff": .oneShot,
    ]

    public var displayName: String {
        switch self {
        case .instrument: return "Instrument"
        case .oneShot: return "One-Shot"
        case .effect: return "Effect"
        }
    }

    /// Part of the Trigger library (exported to the browser folder) rather than the Effects library.
    public var isTriggerLibrary: Bool { self != .effect }

    public static func < (lhs: FileKind, rhs: FileKind) -> Bool {
        let order: [FileKind] = [.instrument, .oneShot, .effect]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
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
    /// Effect type id (see `EffectType`), only for `.effect` files; nil means Other.
    public let effectType: String?
    /// Vendor guessed from folder names; nil when unknown.
    public let vendor: String?
    public let size: Int64
    public let modified: Date

    /// Key used for per-pack settings such as a vendor or name override.
    public var packKey: String { packPath }

    /// Copy with a different auto-detected effect type (used when the user edits the type list).
    public func withEffectType(_ id: String?) -> TCIFile {
        TCIFile(path: path, kind: kind, name: name, baseName: baseName, variant: variant, root: root, pack: pack,
                packPath: packPath, kit: kit, kitPath: kitPath, folder: folder, category: category, source: source,
                effectType: id, vendor: vendor, size: size, modified: modified)
    }

    public var url: URL { URL(fileURLWithPath: path) }
    /// Upper-cased extension, e.g. "TCI", "WAV".
    public var formatName: String { url.pathExtension.uppercased() }

    public init(path: String, kind: FileKind = .instrument, name: String, baseName: String, variant: String?, root: String,
                pack: String, packPath: String? = nil, kit: String? = nil, kitPath: String? = nil,
                folder: String, category: DrumCategory, source: SourceType = .direct,
                effectType: String? = nil, vendor: String? = nil,
                size: Int64, modified: Date) {
        self.path = path
        self.source = source
        self.effectType = effectType
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
    /// Manual effect-type override by type id (Effects library only).
    public var effectType: String?
    /// Manual kit assignment; wins over the folder-based kit.
    public var kit: String?
    /// Free-text notes; searchable, not exported to the browser folder.
    public var notes: String = ""
    /// File name and size, kept so metadata can follow a file that moves to another folder.
    public var fileName: String = ""
    public var fileSize: Int64 = 0

    public init(tags: [String] = [], favorite: Bool = false, category: DrumCategory? = nil, source: SourceType? = nil,
                effectType: String? = nil, kit: String? = nil, notes: String = "", fileName: String = "", fileSize: Int64 = 0) {
        self.tags = tags
        self.favorite = favorite
        self.category = category
        self.source = source
        self.effectType = effectType
        self.kit = kit
        self.notes = notes
        self.fileName = fileName
        self.fileSize = fileSize
    }

    public var isEmpty: Bool {
        tags.isEmpty && !favorite && category == nil && source == nil && effectType == nil && kit == nil && notes.isEmpty
    }

    enum CodingKeys: String, CodingKey { case tags, favorite, category, source, effectCategory, effectType, kit, notes, fileName, fileSize }

    /// Tolerant decoding: an old "room" category override becomes a Rooms source override.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        let rawCategory = try c.decodeIfPresent(String.self, forKey: .category)
        category = rawCategory.flatMap(DrumCategory.init(rawValue:))
        source = try c.decodeIfPresent(String.self, forKey: .source).flatMap(SourceType.init(rawValue:))
        if rawCategory == "room", source == nil { source = .rooms }
        // "effectCategory" is the old key; its values were the same ids.
        effectType = try c.decodeIfPresent(String.self, forKey: .effectType)
            ?? c.decodeIfPresent(String.self, forKey: .effectCategory)
        kit = try c.decodeIfPresent(String.self, forKey: .kit)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tags, forKey: .tags)
        try c.encode(favorite, forKey: .favorite)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(effectType, forKey: .effectType)
        try c.encodeIfPresent(kit, forKey: .kit)
        if !notes.isEmpty { try c.encode(notes, forKey: .notes) }
        try c.encode(fileName, forKey: .fileName)
        try c.encode(fileSize, forKey: .fileSize)
    }
}

/// Everything persisted between launches.
public struct LibraryData: Codable {
    public var roots: [String] = []
    /// Folders holding the separate Effects library (scanned for .wav/.aiff as `.effect`).
    public var effectRoots: [String] = []
    public var items: [String: ItemMeta] = [:]
    /// Vendor overrides keyed by `TCIFile.packKey`.
    public var vendors: [String: String] = [:]
    /// Pack name overrides keyed by `TCIFile.packKey`.
    public var packNames: [String: String] = [:]
    /// Kit name overrides keyed by `TCIFile.kitPath`.
    public var kitNames: [String: String] = [:]
    /// Effect types in priority order. Defaults until the user edits them.
    public var effectTypes: [EffectType] = EffectType.defaults

    public init(roots: [String] = [], items: [String: ItemMeta] = [:], vendors: [String: String] = [:],
                packNames: [String: String] = [:], kitNames: [String: String] = [:],
                effectTypes: [EffectType] = EffectType.defaults) {
        self.roots = roots
        self.items = items
        self.vendors = vendors
        self.packNames = packNames
        self.kitNames = kitNames
        self.effectTypes = effectTypes
    }

    enum CodingKeys: String, CodingKey { case roots, effectRoots, items, vendors, packNames, kitNames, effectTypes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roots = try c.decodeIfPresent([String].self, forKey: .roots) ?? []
        effectRoots = try c.decodeIfPresent([String].self, forKey: .effectRoots) ?? []
        items = try c.decodeIfPresent([String: ItemMeta].self, forKey: .items) ?? [:]
        vendors = try c.decodeIfPresent([String: String].self, forKey: .vendors) ?? [:]
        packNames = try c.decodeIfPresent([String: String].self, forKey: .packNames) ?? [:]
        kitNames = try c.decodeIfPresent([String: String].self, forKey: .kitNames) ?? [:]
        effectTypes = try c.decodeIfPresent([EffectType].self, forKey: .effectTypes) ?? EffectType.defaults
    }
}
