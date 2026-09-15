import SwiftUI
import SampleSearchKit

struct FoldersSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var searching = false
    @State private var suggestions: [(root: URL, count: Int)]?
    @State private var chosen: Set<String> = []
    @State private var browserPath = BrowserFolder.url.path
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Library Folders").font(.title2).bold().padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Trigger library",
                            "Scanned for .tci instruments and .wav / .aiff one-shots.") {
                        folderList(model.data.roots, remove: model.removeRoot)
                        HStack {
                            Button("Add Folder…") { addFolder(effects: false) }
                            Button {
                                Task { await findAutomatically() }
                            } label: {
                                HStack(spacing: 6) {
                                    if searching { ProgressView().controlSize(.small) }
                                    Text("Find TCI Files Automatically")
                                }
                            }
                            .disabled(searching)
                        }
                        .controlSize(.small)
                        suggestionsView
                    }

                    section("Effects library",
                            "A separate set of folders for .wav / .aiff effects (risers, impacts…). Never exported to Trigger's browser folder.") {
                        folderList(model.data.effectRoots, remove: model.removeEffectRoot)
                        Button("Add Effects Folder…") { addFolder(effects: true) }.controlSize(.small)
                    }

                    section("Trigger browser folder",
                            "Links to every Trigger-library sample are written here, grouped by Favourites, Tags, Kits, Categories, Sources and Vendors, for Trigger 2's own browser. File › Update Trigger Browser Folder (⌘E) rebuilds it on demand.") {
                        HStack {
                            Image(systemName: "folder")
                            Text(abbreviated(browserPath)).font(.callout).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button("Change…") { chooseBrowserFolder() }.controlSize(.small)
                        }
                        Toggle("Update automatically after tagging, favouriting or rescanning", isOn: $model.autoExport)
                        Toggle("Show the current selection at the top level (or the whole sidebar group when nothing is selected)", isOn: $model.mirrorSelection)
                    }

                    section("Updates",
                            "Checks GitHub releases for a newer version.") {
                        Toggle("Check for updates automatically, once a day", isOn: $autoCheckUpdates)
                    }
                }
                .padding(.trailing, 4)
            }

            Divider().padding(.vertical, 12)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 580, height: 760)
    }

    /// A titled block with a wrapping caption and its controls, visually separated from the next.
    private func section<Content: View>(_ title: String, _ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(caption).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var suggestionsView: some View {
        if let suggestions {
            if suggestions.isEmpty {
                Text("Spotlight found no .tci files.").font(.callout).foregroundStyle(.secondary)
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
                .frame(height: 140)
                HStack {
                    Spacer()
                    Button("Add Selected") {
                        for path in chosen { model.addRoot(URL(fileURLWithPath: path)) }
                        chosen = []
                        self.suggestions = nil
                    }
                    .controlSize(.small)
                    .disabled(chosen.isEmpty)
                }
            }
        }
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
        panel.message = "Choose an empty folder for Sample Search to fill with links"
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url {
            BrowserFolder.url = url
            browserPath = url.path
        }
    }

    private func folderList(_ roots: [String], remove: @escaping (String) -> Void) -> some View {
        List {
            if roots.isEmpty { Text("No folders yet.").foregroundStyle(.secondary) }
            ForEach(roots, id: \.self) { root in
                HStack {
                    Image(systemName: "folder")
                    VStack(alignment: .leading) {
                        Text(URL(fileURLWithPath: root).lastPathComponent)
                        Text(abbreviated(root)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { remove(root) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain).help("Remove folder")
                }
            }
        }
        .frame(height: max(52, CGFloat(min(roots.count, 4)) * 44 + 8))
        .scrollContentBackground(.hidden)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
    }

    private func addFolder(effects: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = effects ? "Choose folders containing .wav / .aiff effects" : "Choose folders containing Trigger 2 .tci files"
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            for url in panel.urls { effects ? model.addEffectRoot(url) : model.addRoot(url) }
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
