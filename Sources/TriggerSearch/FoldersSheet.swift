import SwiftUI
import TriggerSearchKit

struct FoldersSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var searching = false
    @State private var suggestions: [(root: URL, count: Int)]?
    @State private var chosen: Set<String> = []
    @State private var browserPath = BrowserFolder.url.path

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Library Folders").font(.title2).bold()
            Text("Trigger Search scans these folders (and everything inside them) for .tci files.")
                .foregroundStyle(.secondary)

            List {
                if model.roots.isEmpty {
                    Text("No folders yet.").foregroundStyle(.secondary)
                }
                ForEach(model.data.roots, id: \.self) { root in
                    HStack {
                        Image(systemName: "folder")
                        VStack(alignment: .leading) {
                            Text(URL(fileURLWithPath: root).lastPathComponent)
                            Text(abbreviated(root)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.removeRoot(root) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).help("Remove folder")
                    }
                }
            }
            .frame(minHeight: 120)

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Trigger browser folder").font(.headline)
                Text("Links to every sample are written here, grouped by Favourites, Tags, Kits and Categories, for Trigger 2's own browser. File › Update Trigger Browser Folder (⌘E) rebuilds it on demand.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(abbreviated(browserPath)).font(.callout).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { chooseBrowserFolder() }.controlSize(.small)
                }
                Toggle("Update automatically after tagging, favouriting or rescanning", isOn: $model.autoExport)
                    .font(.callout)
                Toggle("Show the current selection (or the whole sidebar group when nothing is selected) at the top level of the folder", isOn: $model.mirrorSelection)
                    .font(.callout)
            }
            Divider()

            HStack {
                Button("Add Folder…") { addFolder() }
                Button {
                    Task { await findAutomatically() }
                } label: {
                    HStack {
                        if searching { ProgressView().controlSize(.small) }
                        Text("Find TCI Files Automatically")
                    }
                }
                .disabled(searching)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }

            if let suggestions {
                Divider()
                if suggestions.isEmpty {
                    Text("Spotlight found no .tci files.").foregroundStyle(.secondary)
                } else {
                    Text("Spotlight found .tci files in these folders. Tick the ones to add:").font(.callout)
                    List {
                        ForEach(suggestions, id: \.root) { item in
                            let path = item.root.path
                            let already = model.data.roots.contains(path)
                            Toggle(isOn: Binding(
                                get: { already || chosen.contains(path) },
                                set: { on in if on { chosen.insert(path) } else { chosen.remove(path) } }
                            )) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.root.lastPathComponent)
                                        Text(abbreviated(path)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(item.count) files").foregroundStyle(.secondary).font(.callout)
                                }
                            }
                            .disabled(already)
                        }
                    }
                    .frame(minHeight: 120)
                    HStack {
                        Spacer()
                        Button("Add Selected") {
                            for path in chosen { model.addRoot(URL(fileURLWithPath: path)) }
                            chosen = []
                            self.suggestions = nil
                        }
                        .disabled(chosen.isEmpty)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func abbreviated(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
            .replacingOccurrences(of: "~/Library/Mobile Documents/com~apple~CloudDocs", with: "iCloud Drive")
    }

    private func chooseBrowserFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose an empty folder for Trigger Search to fill with links"
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url {
            BrowserFolder.url = url
            browserPath = url.path
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Choose folders containing Trigger 2 .tci files"
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            for url in panel.urls { model.addRoot(url) }
        }
    }

    @MainActor
    private func findAutomatically() async {
        searching = true
        let finder = TCIFinder()
        let files = await finder.findAll()
        suggestions = TCIFinder.suggestRoots(for: files)
        searching = false
    }
}
