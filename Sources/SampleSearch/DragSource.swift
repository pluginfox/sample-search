import AppKit
import SwiftUI

/// An AppKit drag source that puts real file URLs on the pasteboard, exactly like dragging from
/// Finder, so plug-in windows (Trigger 2, other JUCE hosts) accept the drop.
struct FileDragSource: NSViewRepresentable {
    var urls: [URL]

    func makeNSView(context: Context) -> DragSourceView { DragSourceView() }

    func updateNSView(_ view: DragSourceView, context: Context) { view.urls = urls }
}

final class DragSourceView: NSView, NSDraggingSource {
    var urls: [URL] = []
    private var mouseDownPoint: NSPoint?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty, let start = mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) > 3 else { return }
        mouseDownPoint = nil

        let iconSize: CGFloat = 40
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: iconSize, height: iconSize)
            let offset = CGFloat(min(index, 4)) * 3
            item.setDraggingFrame(NSRect(x: point.x - iconSize / 2 + offset, y: point.y - iconSize / 2 - offset,
                                         width: iconSize, height: iconSize),
                                  contents: index < 5 ? icon : nil)
            return item
        }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.draggingFormation = urls.count > 1 ? .stack : .none

        // Finder also publishes the legacy filenames type, which older plug-in builds still read.
        // The legacy API adds it to the first pasteboard item without disturbing the file URLs.
        let legacy = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        let pasteboard = session.draggingPasteboard
        pasteboard.addTypes([legacy], owner: nil)
        pasteboard.setPropertyList(urls.map(\.path), forType: legacy)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .generic, .link]
    }
}
