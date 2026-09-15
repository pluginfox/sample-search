import SwiftUI
import SampleSearchKit

/// Editor for the effect-type list: rename, change icon and keywords, reorder, add, remove.
struct EffectTypesSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var types: [EffectType] = []
    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effect Types").font(.title2).bold()
            Text("Types are matched top to bottom against file and folder names using their keywords; the first match wins, so drag to set priority. Files nothing matches are “Other”.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    List(selection: $selected) {
                        ForEach(types) { type in
                            Label(type.name, systemImage: type.symbol).tag(type.id)
                        }
                        .onMove { from, to in types.move(fromOffsets: from, toOffset: to) }
                    }
                    .frame(width: 220, height: 300)
                    HStack {
                        Button { add() } label: { Image(systemName: "plus") }
                        Button { remove() } label: { Image(systemName: "minus") }.disabled(selected == nil)
                        Spacer()
                        Button("Restore Defaults") { types = EffectType.defaults; selected = nil }.controlSize(.small)
                    }
                }
                if let index = types.firstIndex(where: { $0.id == selected }) {
                    editor(for: index)
                } else {
                    Text("Select a type to edit it, or add one.")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { model.setEffectTypes(cleaned()); dismiss() }.keyboardShortcut(.defaultAction)
                    .disabled(types.contains { $0.name.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }
        .padding(20)
        .frame(width: 640)
        .onAppear { types = model.effectTypes; selected = types.first?.id }
    }

    private func editor(for index: Int) -> some View {
        Form {
            TextField("Name (plural)", text: $types[index].name, prompt: Text("Risers"))
            TextField("Singular", text: $types[index].singular, prompt: Text("Riser"))
            HStack {
                TextField("SF Symbol", text: $types[index].symbol, prompt: Text("arrow.up.right"))
                Image(systemName: types[index].symbol.isEmpty ? "questionmark.circle" : types[index].symbol)
                    .frame(width: 20)
            }
            TextField("Keywords", text: Binding(
                get: { types[index].keywords.joined(separator: ", ") },
                set: { types[index].keywords = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty } }
            ), prompt: Text("riser, uplifter, rise"))
            Text("Keywords are matched as lower-case substrings; separate them with commas. Add a trailing space to match a whole word, e.g. “sub ”.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Browse SF Symbols names", destination: URL(string: "https://developer.apple.com/sf-symbols/")!)
                .font(.caption)
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity)
    }

    private func add() {
        var n = types.count + 1
        var id = "custom-\(n)"
        while types.contains(where: { $0.id == id }) { n += 1; id = "custom-\(n)" }
        types.append(EffectType(id: id, name: "New Type", singular: "New Type", symbol: "tag", keywords: []))
        selected = id
    }

    private func remove() {
        guard let selected else { return }
        types.removeAll { $0.id == selected }
        self.selected = types.first?.id
    }

    private func cleaned() -> [EffectType] {
        types.map { t in
            var t = t
            t.name = t.name.trimmingCharacters(in: .whitespaces)
            t.singular = t.singular.trimmingCharacters(in: .whitespaces).isEmpty ? t.name : t.singular.trimmingCharacters(in: .whitespaces)
            t.symbol = t.symbol.trimmingCharacters(in: .whitespaces).isEmpty ? "tag" : t.symbol.trimmingCharacters(in: .whitespaces)
            return t
        }
    }
}
