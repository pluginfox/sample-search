import SwiftUI

/// Chips for the current tags plus a text field to add one, with quick-add suggestions.
struct TagEditor: View {
    var tags: [String]
    var suggestions: [String]
    var onAdd: (String) -> Void
    var onRemove: (String) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tags.isEmpty {
                Text("No tags").foregroundStyle(.secondary).font(.callout)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag, removable: true) { onRemove(tag) }
                    }
                }
            }
            TextField("Add tag…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    onAdd(draft)
                    draft = ""
                    focused = true
                }
            let unused = suggestions.filter { !tags.contains($0) }
                .filter { draft.isEmpty || $0.localizedCaseInsensitiveContains(draft) }
                .prefix(12)
            if !unused.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(unused), id: \.self) { tag in
                        Button { onAdd(tag) } label: { TagChip(tag: tag, removable: false, dimmed: true) {} }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TagChip: View {
    var tag: String
    var removable: Bool
    var dimmed = false
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(tag)
            if removable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill").imageScale(.small)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else if dimmed {
                Image(systemName: "plus").imageScale(.small).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(dimmed ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.accentColor.opacity(0.18)),
                    in: Capsule())
    }
}

/// Minimal wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
