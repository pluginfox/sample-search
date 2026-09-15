// Renders a contact sheet of the DrumIcons at sidebar size (16pt) and large (64pt) to a PNG.
import AppKit
import DrumIcons

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "icons-preview.png")
let icons = DrumIcon.allCases
let cell: CGFloat = 110, width = cell * 7 + 16, height: CGFloat = 2 * 190 + 40

/// Template image painted in a colour, the way AppKit tints it in a sidebar.
func tinted(_ icon: DrumIcon, _ size: CGFloat, _ color: NSColor) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        icon.image(pointSize: size).draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}
let scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray]
let heading: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.black]
for (row, group) in [Array(icons[0..<7]), Array(icons[7...])].enumerated() {
    let top = height - 20 - CGFloat(row) * 190
    (row == 0 ? "Categories" : "Sources").draw(at: NSPoint(x: 16, y: top - 14), withAttributes: heading)
    for (i, icon) in group.enumerated() {
        let x = 16 + CGFloat(i) * cell
        // Large at 64pt.
        let big = icon.image(pointSize: 64); big.isTemplate = false
        big.draw(in: NSRect(x: x, y: top - 96, width: 64, height: 64))
        // Sidebar size 16pt, plus a 20pt variant, tinted like a selected sidebar row.
        let small = icon.image(pointSize: 16); small.isTemplate = false
        small.draw(in: NSRect(x: x, y: top - 126, width: 16, height: 16))
        let mid = icon.image(pointSize: 20); mid.isTemplate = false
        mid.draw(in: NSRect(x: x + 24, y: top - 128, width: 20, height: 20))
        tinted(icon, 16, .systemBlue).draw(in: NSRect(x: x + 52, y: top - 126, width: 16, height: 16))
        tinted(icon, 16, .gray).draw(in: NSRect(x: x + 76, y: top - 126, width: 16, height: 16))
        icon.displayName.draw(at: NSPoint(x: x, y: top - 146), withAttributes: label)
    }
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
