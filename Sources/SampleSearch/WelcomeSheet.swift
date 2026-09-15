import SwiftUI

/// First-run walkthrough. Shown when no folders are configured, and from Help › Welcome.
struct WelcomeSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Sample Search").font(.title2).bold()
                    Text("A searchable, taggable front end for your drum sample and sound effects library.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            step(1, "Add your drum sample folders",
                 "Point the app at the folders holding your .wav / .aiff one-shots and, if you use Slate Trigger 2, its .tci instruments. “Find TCI Files Automatically” uses Spotlight to suggest Trigger folders. Nothing is moved or renamed.")
            step(2, "Optionally add an Effects library",
                 "Risers, impacts, whooshes and the like live in their own folders and their own Effects mode, so they never mix with the Trigger library.")
            step(3, "Trigger 2 users: point its browser at the Sample Search folder") {
                VStack(alignment: .leading, spacing: 6) {
                    (Text("The app keeps a folder of links at ")
                        + Text(abbreviated(BrowserFolder.url.path)).bold().foregroundColor(.primary)
                        + Text(", grouped by favourites, tags, kits, categories, sources and vendors, with your current selection at the top level."))
                    Text("Add that folder in Trigger 2's browser once. It updates itself as you tag and select, but Trigger 2 caches its listing, so click its refresh button after each selection change to see the latest files.")
                    Text("One-shots and effects can simply be dragged onto a DAW track or sampler.")
                }
            }

            Text("Tags, favourites, notes, kits and vendors are stored in the app's own library file, not in your sample folders. Settings can be reset at any time from the Sample Search menu without losing them.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Spacer()
                if model.hasAnyRoots {
                    Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                } else {
                    Button("Choose Folders…") { dismiss(); model.showFolders = true }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        step(n, title) { Text(detail) }
    }

    private func step<Detail: View>(_ n: Int, _ title: String, @ViewBuilder detail: () -> Detail) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                detail().font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func abbreviated(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }
}
