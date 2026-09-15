import Foundation

/// Heuristics that turn file and folder names into a category and variant.
public enum Classifier {
    /// Keywords matched as substrings of the lower-cased text.
    private static let substringKeywords: [(DrumCategory, [String])] = [
        (.kick, ["kick", "bass drum", "bassdrum", "bdrum"]),
        (.snare, ["snare", "snr", "sidestick", "side stick", "rimshot", "cross stick", "xstick"]),
        (.tom, ["tom", "floor"]),
        (.hihat, ["hihat", "hi-hat", "hi hat", "hat"]),
        (.cymbal, ["ride", "crash", "china", "splash", "cymbal", "stack", "bell"]),
        (.percussion, ["clap", "perc", "cowbell", "tamb", "shaker", "snap", "block", "bongo", "conga"]),
    ]

    /// Short keywords only matched as whole words.
    private static let tokenKeywords: [(DrumCategory, Set<String>)] = [
        (.kick, ["bd", "kck", "kik"]),
        (.snare, ["sn", "sd"]),
        (.tom, ["t1", "t2", "t3", "t4", "ft", "rt", "ht", "mt", "lt"]),
        (.hihat, ["hh", "hats"]),
        (.cymbal, ["cym", "cyms", "cr", "rd"]),
    ]

    /// Source keywords: substrings and whole-word tokens. Checked in order; first hit wins.
    private static let sourceSubstrings: [(SourceType, [String])] = [
        (.overheads, ["overhead", "over head"]),
        (.rooms, ["room", "ambience", "ambient", "amb "]),
        (.fx, ["fx", "effect", "reverb", "verb", "crush", "smash", "distort", "trash", "lo-fi", "lofi", "wet"]),
        (.direct, ["direct", "close", "dry"]),
    ]
    private static let sourceTokens: [(SourceType, Set<String>)] = [
        (.overheads, ["oh", "ohs"]),
        (.rooms, ["rm", "rms", "amb", "far"]),
        (.fx, ["fx"]),
        (.direct, ["dir", "di", "in", "out", "sub"]),
    ]

    private static let effectKeywords: [(EffectCategory, [String])] = [
        (.reverse, ["reverse", "reversed", "backward", "rev "]),
        (.riser, ["riser", "uplifter", "upsweep", "up sweep", "rise", "build", "tension"]),
        (.subdrop, ["sub drop", "subdrop", "sub-drop", "bass drop", "808 drop", "sub bass", "sub "]),
        (.downlifter, ["downlifter", "downsweep", "down sweep", "downer", "fall", "faller", "drop"]),
        (.impact, ["impact", "boom", "slam", "explosion", "crash fx", "cinematic hit"]),
        (.hit, ["hit", "stab", "punch", "one shot fx", "shot"]),
        (.cymbal, ["cymbal", "crash", "china", "splash", "ride", "swell", "cym "]),
        (.whoosh, ["whoosh", "swoosh", "sweep", "swish", "wind", "flyby", "fly by", "pass"]),
        (.drone, ["drone", "pad", "texture", "atmos", "ambien", "noise", "bed", "soundscape"]),
    ]

    /// Effect type from the file name first, then folders nearest-first; `.other` when nothing matches.
    /// "Reverse" anywhere in the name wins, so a reversed cymbal or crash files under Reverses.
    public static func effectCategory(name: String, folders: [String]) -> EffectCategory {
        for text in [name] + folders.reversed() {
            let lower = text.lowercased()
            if effectKeywords[0].1.contains(where: { lower.contains($0) }) { return .reverse }
            var best: (EffectCategory, Int)?
            for (category, keywords) in effectKeywords {
                for keyword in keywords {
                    if let range = lower.range(of: keyword) {
                        let index = lower.distance(from: lower.startIndex, to: range.lowerBound)
                        if best == nil || index < best!.1 { best = (category, index) }
                    }
                }
            }
            if let best { return best.0 }
        }
        return .other
    }

    /// Source from the file name first, then folders nearest-first; Direct when nothing matches.
    public static func source(name: String, folders: [String]) -> SourceType {
        for text in [name] + folders.reversed() {
            if let s = source(in: text) { return s }
        }
        return .direct
    }

    static func source(in text: String) -> SourceType? {
        let lower = text.lowercased().replacingOccurrences(of: "roomy", with: " ")
        var best: (SourceType, Int)?
        for (source, keywords) in sourceSubstrings {
            for keyword in keywords {
                if let range = lower.range(of: keyword) {
                    let index = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    if best == nil || index < best!.1 { best = (source, index) }
                }
            }
        }
        var offset = 0
        for token in lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let t = String(token)
            let index = lower.range(of: t, range: lower.index(lower.startIndex, offsetBy: offset)..<lower.endIndex)
                .map { lower.distance(from: lower.startIndex, to: $0.lowerBound) } ?? offset
            offset = index + t.count
            for (source, set) in sourceTokens where set.contains(t) {
                if best == nil || index < best!.1 { best = (source, index) }
            }
        }
        return best?.0
    }

    /// Words that contain a keyword by accident and should be ignored.
    private static let falseFriends = ["custom", "bottom", "atom", "tomorrow", "automation", "phantom", "stacked", "chatter", "that", "what", "whatever", "shatter", "thatch", "roomy"]

    /// Categorises using the file name first, then folders from nearest to furthest.
    public static func category(name: String, folders: [String]) -> DrumCategory {
        for text in [name] + folders.reversed() {
            if let c = category(in: text) { return c }
        }
        return .other
    }

    /// Returns the category whose keyword appears earliest in `text`, or nil.
    static func category(in text: String) -> DrumCategory? {
        var lower = text.lowercased()
        for word in falseFriends { lower = lower.replacingOccurrences(of: word, with: " ") }
        var best: (DrumCategory, Int)?
        for (category, keywords) in substringKeywords {
            for keyword in keywords {
                if let range = lower.range(of: keyword) {
                    let index = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    if best == nil || index < best!.1 { best = (category, index) }
                }
            }
        }
        let tokens = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        var offset = 0
        for token in tokens {
            let t = String(token)
            let index = lower.range(of: t, range: lower.index(lower.startIndex, offsetBy: offset)..<lower.endIndex)
                .map { lower.distance(from: lower.startIndex, to: $0.lowerBound) } ?? offset
            offset = index + t.count
            for (category, set) in tokenKeywords where set.contains(t) {
                if best == nil || index < best!.1 { best = (category, index) }
            }
        }
        return best?.0
    }

    /// Splits "Snare 5 SSDR" into ("Snare 5", "SSDR"). A variant is a short trailing token made
    /// of capitals and digits containing at least one letter, e.g. SSDR, NRG, Z1, Z3, SB, V2.
    public static func splitVariant(_ name: String) -> (base: String, variant: String?) {
        let parts = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count > 1, let last = parts.last else { return (name, nil) }
        let isVariant = last.count <= 5
            && last.allSatisfy { ($0.isUppercase && $0.isLetter) || $0.isNumber }
            && last.contains { $0.isLetter }
        guard isVariant else { return (name, nil) }
        return (parts.dropLast().joined(separator: " "), last)
    }
}
