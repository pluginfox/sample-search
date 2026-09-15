import SwiftUI
import TriggerSearchKit

struct InspectorView: View {
    @EnvironmentObject var model: LibraryModel
    @ObservedObject private var preview = LibraryModel.shared.preview

    var body: some View {
        let rows = model.selectedRows
        Group {
            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click.2").font(.system(size: 34)).foregroundStyle(.tertiary)
                    Text("Select a sample").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(rows)
                        let oneShots = rows.filter(\.isPlayable)
                        if !oneShots.isEmpty { DragTile(urls: oneShots.map(\.file.url)) }
                        if rows.count == 1, rows[0].isPlayable { playButton(rows[0]) }
                        favoriteSection(rows)
                        Divider()
                        tagSection(rows)
                        if rows.count == 1 { Divider(); NotesSection(row: rows[0]) }
                        Divider()
                        if rows.allSatisfy(\.isEffect) {
                            effectCategorySection(rows)
                        } else if !rows.contains(where: \.isEffect) {
                            categorySection(rows)
                            sourceSection(rows)
                        }
                        Divider()
                        PackOverrideSection(title: "Pack", rows: rows,
                                            current: { $0.pack },
                                            overridden: { model.data.packNames[$0.file.packKey] != nil },
                                            resetTitle: "Use Folder Name",
                                            apply: { model.setPackName($0, forPacksOf: model.selection) })
                        Divider()
                        KitSection(rows: rows)
                        Divider()
                        PackOverrideSection(title: "Vendor", rows: rows,
                                            current: { $0.vendor },
                                            overridden: { model.data.vendors[$0.file.packKey] != nil },
                                            resetTitle: "Use Guessed Vendor",
                                            apply: { model.setVendor($0, forPacksOf: model.selection) })
                        if rows.count == 1 { Divider(); fileSection(rows[0]) }
                    }
                    .padding(16)
                }
            }
        }
        .background(.background)
    }

    private var ids: Set<String> { model.selection }

    @ViewBuilder
    private func header(_ rows: [Row]) -> some View {
        if rows.count == 1 {
            let row = rows[0]
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name).font(.title3).bold().textSelection(.enabled)
                HStack(spacing: 6) {
                    if row.isEffect {
                        Label(row.categoryName, systemImage: row.categorySymbol)
                    } else {
                        Label { Text(row.categoryName) } icon: { CategoryIcon(category: row.category) }
                        Text("·"); Label(row.sourceName, systemImage: row.source.symbol)
                    }
                    Text("·"); Text(row.format).monospaced()
                    if !row.variant.isEmpty { Text("·"); Text(row.variant).monospaced() }
                }
                .font(.callout).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(rows.count) samples").font(.title3).bold()
                Text(rows.prefix(4).map(\.name).joined(separator: ", ") + (rows.count > 4 ? ", …" : ""))
                    .font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    private func playButton(_ row: Row) -> some View {
        let playing = model.preview.playingPath == row.id
        return Button { model.preview.toggle(row.file.url) } label: {
            Label(playing ? "Stop" : "Play Preview", systemImage: playing ? "stop.fill" : "play.fill")
                .frame(maxWidth: .infinity)
        }
        .help("Preview the one-shot (Space)")
    }

    private func favoriteSection(_ rows: [Row]) -> some View {
        let allFav = rows.allSatisfy(\.favorite)
        return Button { model.toggleFavorite(ids) } label: {
            Label(allFav ? (rows.count == 1 ? "Favourite" : "Remove from Favourites") : "Add to Favourites",
                  systemImage: allFav ? "star.fill" : "star")
                .frame(maxWidth: .infinity)
        }
        .tint(allFav ? .yellow : nil)
        .help("Toggle favourite (⌘D)")
    }

    private func tagSection(_ rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags").font(.headline)
            if rows.count > 1 {
                Text("Adding a tag applies it to all selected samples.").font(.caption).foregroundStyle(.secondary)
            }
            // For multiple rows show tags common to all of them.
            let common = rows.map { Set($0.tags) }.reduce(Set(rows[0].tags)) { $0.intersection($1) }
            TagEditor(tags: common.sorted(), suggestions: model.allTags,
                      onAdd: { model.addTag($0, to: ids) },
                      onRemove: { model.removeTag($0, from: ids) })
        }
    }

    private func categorySection(_ rows: [Row]) -> some View {
        let categories = Set(rows.map(\.category))
        let overridden = rows.contains { $0.meta.category != nil }
        return VStack(alignment: .leading, spacing: 6) {
            Text("DrumCategory").font(.headline)
            Picker("Category", selection: Binding<DrumCategory?>(
                get: { categories.count == 1 ? categories.first : nil },
                set: { if let c = $0 { model.setCategory(c, for: ids) } }
            )) {
                if categories.count != 1 { Text("Mixed").tag(DrumCategory?.none) }
                ForEach(DrumCategory.allCases, id: \.self) { Text($0.singularName).tag(DrumCategory?.some($0)) }
            }
            .labelsHidden()
            if overridden {
                Button("Use Auto-Detected") { model.setCategory(nil, for: ids) }
                    .controlSize(.small)
            } else {
                Text("Detected from the file and folder names.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func effectCategorySection(_ rows: [Row]) -> some View {
        let categories = Set(rows.compactMap(\.effectCategory))
        let overridden = rows.contains { $0.meta.effectCategory != nil }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Type").font(.headline)
            Picker("Type", selection: Binding<EffectCategory?>(
                get: { categories.count == 1 ? categories.first : nil },
                set: { if let c = $0 { model.setEffectCategory(c, for: ids) } }
            )) {
                if categories.count != 1 { Text("Mixed").tag(EffectCategory?.none) }
                ForEach(EffectCategory.allCases, id: \.self) { Text($0.singularName).tag(EffectCategory?.some($0)) }
            }
            .labelsHidden()
            if overridden {
                Button("Use Auto-Detected") { model.setEffectCategory(nil, for: ids) }
                    .controlSize(.small)
            } else {
                Text("Detected from the file and folder names.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func sourceSection(_ rows: [Row]) -> some View {
        let sources = Set(rows.map(\.source))
        let overridden = rows.contains { $0.meta.source != nil }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Source").font(.headline)
            Picker("Source", selection: Binding<SourceType?>(
                get: { sources.count == 1 ? sources.first : nil },
                set: { if let s = $0 { model.setSource(s, for: ids) } }
            )) {
                if sources.count != 1 { Text("Mixed").tag(SourceType?.none) }
                ForEach(SourceType.allCases, id: \.self) { Text($0.displayName).tag(SourceType?.some($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if overridden {
                Button("Use Auto-Detected") { model.setSource(nil, for: ids) }
                    .controlSize(.small)
            } else {
                Text("Direct unless the name says OH, Room, Amb, FX…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func fileSection(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("File").font(.headline)
            Grid(alignment: .leading, verticalSpacing: 4) {
                GridRow { Text("Type").foregroundStyle(.secondary); Text("\(row.kind.displayName) (\(row.format))") }
                if row.isPlayable { GridRow { Text("Audio").foregroundStyle(.secondary); AudioInfoText(url: row.file.url) } }
                GridRow { Text("Vendor").foregroundStyle(.secondary); Text(row.vendor.isEmpty ? "—" : row.vendor) }
                GridRow { Text("Pack").foregroundStyle(.secondary); Text(row.pack) }
                if !row.kit.isEmpty { GridRow { Text("Kit").foregroundStyle(.secondary); Text(row.kit) } }
                GridRow { Text("Folder").foregroundStyle(.secondary); Text(row.folder.isEmpty ? "—" : row.folder) }
                GridRow { Text("Size").foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: row.file.size, countStyle: .file)) }
                GridRow { Text("Modified").foregroundStyle(.secondary)
                    Text(row.modified.formatted(date: .abbreviated, time: .omitted)) }
            }
            .font(.callout)
            Text(row.file.path).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
            Button("Reveal in Finder") { model.revealInFinder(ids) }
                .controlSize(.small)
        }
    }
}

/// Free-text notes for one file. Saved as you type (debounced); searchable but not exported.
struct NotesSection: View {
    @EnvironmentObject var model: LibraryModel
    var row: Row
    @State private var draft = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.headline)
            TextEditor(text: $draft)
                .font(.callout)
                .frame(minHeight: 60, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Anything worth remembering about this sample…")
                            .font(.callout).foregroundStyle(.tertiary)
                            .padding(.horizontal, 9).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
        .onAppear { draft = row.notes }
        .onChange(of: row.id) { _, _ in saveNow(); draft = row.notes }
        .onChange(of: draft) { _, new in
            guard new != row.notes else { return }
            saveTask?.cancel()
            let id = row.id
            saveTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                model.setNotes(new, for: id)
            }
        }
        .onDisappear { saveNow() }
    }

    private func saveNow() {
        saveTask?.cancel()
        if draft != row.notes { model.setNotes(draft, for: row.id) }
    }
}

/// Kit is per file: type a name or pick an existing kit to group the selected files, whatever folder they sit in.
struct KitSection: View {
    @EnvironmentObject var model: LibraryModel
    var rows: [Row]
    @State private var draft = ""

    private var kits: Set<String> { Set(rows.map(\.kit)) }
    private var manual: Bool { rows.contains { $0.meta.kit != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kit").font(.headline)
            TextField(kits.count == 1 ? (kits.first!.isEmpty ? "No kit" : kits.first!) : "Mixed", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.setKit(draft, for: model.selection); draft = "" }
            let existing = model.kits(inPacks: Set(rows.map(\.pack))).filter { !(kits.count == 1 && kits.first == $0) }
            if !existing.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(existing, id: \.self) { kit in
                        Button { model.setKit(kit, for: model.selection) } label: {
                            TagChip(tag: kit, removable: false, dimmed: true) {}
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(rows.count == 1 ? "Groups this file with others in the same kit." : "Applies to the \(rows.count) selected files.")
                .font(.caption).foregroundStyle(.secondary)
            if manual {
                Button(rows.contains { $0.file.kit != nil } ? "Use Folder Kit" : "Remove from Kit") {
                    model.setKit("", for: model.selection)
                }
                .controlSize(.small)
            }
        }
        .onChange(of: rows.map(\.id)) { _ in draft = "" }
    }
}

/// Pack-level text property (pack name, vendor): editing it applies to every file in the selected packs.
struct PackOverrideSection: View {
    var title: String
    var rows: [Row]
    var current: (Row) -> String
    var overridden: (Row) -> Bool
    var resetTitle: String
    /// Folder whose files the edit applies to (pack folder by default, kit folder for kits).
    var scope: KeyPath<Row, String?> = \.file.packPath.optional
    var apply: (String) -> Void
    @State private var draft = ""

    private var packFolders: [String] { Array(Set(rows.compactMap { $0[keyPath: scope] })).sorted() }
    private var values: Set<String> { Set(rows.map(current)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            TextField(values.count == 1 ? (values.first!.isEmpty ? "Unknown" : values.first!) : "Mixed", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { apply(draft); draft = "" }
            Text(packFolders.count == 1
                 ? "Applies to every file in “\((packFolders[0] as NSString).lastPathComponent)”."
                 : "Applies to every file in \(packFolders.count) pack folders.")
                .font(.caption).foregroundStyle(.secondary)
            if rows.contains(where: overridden) {
                Button(resetTitle) { apply("") }.controlSize(.small)
            }
        }
        .onChange(of: rows.map(\.id)) { _ in draft = "" }
    }
}

extension String {
    /// Lets a non-optional key path stand in where an optional one is expected.
    var optional: String? { self }
}

/// Reads duration / sample rate / channels off the main thread and shows them.
struct AudioInfoText: View {
    var url: URL
    @State private var info: AudioInfo?

    var body: some View {
        Text(info?.summary ?? "…")
            .task(id: url) {
                let url = self.url
                info = await Task.detached { AudioInfo.read(url) }.value
            }
    }
}

/// Drag handle for one-shots: drop them on a DAW track, a sampler or a Finder window.
/// Hidden for `.tci` files, which Trigger 2 loads through its own browser instead.
struct DragTile: View {
    var urls: [URL]

    var body: some View {
        ZStack {
            FileDragSource(urls: urls)
            VStack(spacing: 6) {
                Image(systemName: "hand.draw").font(.system(size: 26))
                Text(urls.count == 1 ? "Drag one-shot to DAW or Finder" : "Drag \(urls.count) one-shots to DAW or Finder")
                    .font(.callout).bold()
                Text("Grab here or drag the row itself").font(.caption).foregroundStyle(.secondary)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
    }
}
