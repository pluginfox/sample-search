import Foundation

/// One-time carry-over from the app's earlier name, "Trigger Search": library metadata in
/// Application Support, preferences, and the browser-folder location Trigger 2 already points at.
enum Migration {
    static let oldName = "Trigger Search"
    static let oldDefaultsDomain = "local.trigger-search"
    static let flag = "migratedFromTriggerSearch"

    /// Bundle identifiers the app used before `com.pluginfox.samplesearch`, newest first.
    static let previousDefaultsDomains = ["local.sample-search"]
    static let bundleIDFlag = "migratedFromLocalBundleID"

    /// Preferences live under the bundle identifier, so a change of identifier starts with an empty
    /// domain. Copy the previous domain across once. This runs before the Trigger Search migration
    /// and brings its "already migrated" flag along, so older, staler values never win.
    static func migratePreferencesFromPreviousBundleID() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: bundleIDFlag) == nil else { return }
        defer { defaults.set(true, forKey: bundleIDFlag) }
        for domain in previousDefaultsDomains {
            guard let old = defaults.persistentDomain(forName: domain), !old.isEmpty else { continue }
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
            break
        }
    }

    static func runIfNeeded() {
        migratePreferencesFromPreviousBundleID()
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: flag) == nil else { return }
        defer { defaults.set(true, forKey: flag) }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let old = appSupport.appendingPathComponent(oldName, isDirectory: true)
        let new = appSupport.appendingPathComponent("Sample Search", isDirectory: true)
        var hadOldApp = false
        if fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) {
            try? fm.copyItem(at: old, to: new)   // copy, leaving the old folder as a backup
            hadOldApp = true
        }

        if let oldPrefs = defaults.persistentDomain(forName: oldDefaultsDomain), !oldPrefs.isEmpty {
            hadOldApp = true
            for (key, value) in oldPrefs where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        // The old default browser folder was ~/Music/Trigger Search. Keep using it if it exists so
        // Trigger 2's browser, already pointed there, keeps working.
        if hadOldApp, defaults.string(forKey: BrowserFolder.defaultsKey) == nil {
            let oldFolder = fm.homeDirectoryForCurrentUser.appendingPathComponent("Music/\(oldName)")
            if fm.fileExists(atPath: oldFolder.appendingPathComponent(".trigger-search-browser-folder").path) {
                defaults.set(oldFolder.path, forKey: BrowserFolder.defaultsKey)
            }
        }
    }
}
