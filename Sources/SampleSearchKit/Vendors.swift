import Foundation

/// Guesses the vendor / manufacturer from folder names, since `.tci` files carry no metadata.
public enum Vendors {
    /// Lower-cased substrings, checked in order, mapped to display names.
    /// A `var` so tests can substitute an invented list; the app never changes it.
    nonisolated(unsafe) static var keywords: [(String, String)] = [
        ("steven slate", "Steven Slate Drums"), ("slate", "Steven Slate Drums"), ("trigger2", "Steven Slate Drums"),
        ("trigger 2", "Steven Slate Drums"), ("ssd5", "Steven Slate Drums"), ("ssd ", "Steven Slate Drums"),
        ("mixwave", "MixWave"), ("mix wave", "MixWave"),
        ("drum soap", "Drum SOAP"), ("drumsoap", "Drum SOAP"),
        ("odeholm", "Odeholm Audio"),
        ("getgood", "GetGood Drums"), ("get good", "GetGood Drums"), ("ggd", "GetGood Drums"),
        ("toontrack", "Toontrack"), ("superior drummer", "Toontrack"), ("ezdrummer", "Toontrack"),
        ("xln", "XLN Audio"), ("addictive drums", "XLN Audio"),
        ("bogren", "Bogren Digital"),
        ("room sound", "Room Sound"), ("roomsound", "Room Sound"),
        ("joey sturgis", "JST"), ("jst ", "JST"),
        ("drumforge", "Drumforge"),
        ("ugritone", "Ugritone"),
        ("nolly", "GetGood Drums"),
        ("that sound", "That Sound"),
        ("kurt ballou", "Kurt Ballou"), ("godcity", "Kurt Ballou"),
        ("sonic drum", "Sonic Drum Samples"),
        ("sample magic", "Sample Magic"),
        ("splice", "Splice"),
        ("native instruments", "Native Instruments"),
        ("bfd", "BFD"),
        ("wavesfactory", "Wavesfactory"),
        ("cymatics", "Cymatics"),
    ]

    /// Vendor named in a single folder name, if any.
    public static func guess(text: String) -> String? {
        let lower = text.lowercased()
        for (keyword, vendor) in keywords where lower.contains(keyword) { return vendor }
        return nil
    }

    /// Checks the pack folder first, then deeper folders, then the root name.
    public static func guess(root: String, folders: [String]) -> String? {
        for text in folders + [(root as NSString).lastPathComponent] {
            if let vendor = guess(text: text) { return vendor }
        }
        // "Vendor - Product" style pack names.
        if let pack = folders.first {
            for separator in [" - ", " – ", " — "] {
                if let range = pack.range(of: separator) {
                    let vendor = pack[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                    if vendor.count >= 2, !vendor.allSatisfy(\.isNumber) { return vendor }
                }
            }
        }
        return nil
    }
}
