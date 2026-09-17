// Renders the app icon at all sizes into an .iconset and builds Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift  (or compile with swiftc)
import AppKit

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size
    // Standard macOS app-icon tile: 824pt square centred on a 1024pt canvas, ~22.5% corner radius.
    // Everything is drawn inside this shape; artwork or shadows outside it make macOS 26 treat the
    // icon as non-standard and shrink it into a grey container.
    let inset = s * (100.0 / 1024.0)
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // No baked-in drop shadow: the system supplies its own.
    NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1).setFill()
    path.fill()
    // Clip all remaining drawing to the tile.
    ctx.saveGState()
    path.addClip()

    // Gradient background: deep charcoal to warm orange at the bottom.
    ctx.saveGState()
    path.addClip()
    let gradient = NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1), 0.0),
        (NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1), 0.55),
        (NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.10, alpha: 1), 1.0))!
    gradient.draw(in: rect, angle: -90)
    // Subtle top highlight.
    let highlight = NSGradient(starting: NSColor.white.withAlphaComponent(0.10), ending: NSColor.white.withAlphaComponent(0))!
    highlight.draw(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: 90)
    ctx.restoreGState()

    // Drum head: thick ring, slightly above centre-left to leave room for the magnifier.
    let center = CGPoint(x: rect.midX - rect.width * 0.06, y: rect.midY + rect.height * 0.06)
    let r = rect.width * 0.30
    let ring = NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    ring.lineWidth = s * 0.045
    NSColor(calibratedWhite: 0.96, alpha: 1).setStroke()
    ring.stroke()
    let hoop = NSBezierPath(ovalIn: CGRect(x: center.x - r * 0.84, y: center.y - r * 0.84, width: 2 * r * 0.84, height: 2 * r * 0.84))
    hoop.lineWidth = s * 0.012
    NSColor(calibratedWhite: 0.96, alpha: 0.45).setStroke()
    hoop.stroke()

    // Waveform across the head.
    let wave = NSBezierPath()
    wave.lineWidth = s * 0.035
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    let heights: [CGFloat] = [0.15, 0.45, 0.95, 0.55, 0.25, 0.7, 0.4, 0.12]
    let span = r * 1.3
    let x0 = center.x - span / 2
    let step = span / CGFloat(heights.count - 1)
    for (i, h) in heights.enumerated() {
        let x = x0 + step * CGFloat(i)
        let amp = r * 0.62 * h
        wave.move(to: CGPoint(x: x, y: center.y - amp))
        wave.line(to: CGPoint(x: x, y: center.y + amp))
    }
    NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 1).setStroke()
    wave.stroke()

    // Magnifier: bottom-right, white with dark stroke so it reads on the orange.
    let mr = rect.width * 0.14
    let mc = CGPoint(x: rect.maxX - rect.width * 0.31, y: rect.minY + rect.height * 0.31)
    let lens = NSBezierPath(ovalIn: CGRect(x: mc.x - mr, y: mc.y - mr, width: 2 * mr, height: 2 * mr))
    lens.lineWidth = s * 0.05
    let handle = NSBezierPath()
    handle.lineWidth = s * 0.07
    handle.lineCapStyle = .round
    handle.move(to: CGPoint(x: mc.x + mr * 0.75, y: mc.y - mr * 0.75))
    handle.line(to: CGPoint(x: mc.x + mr * 1.5, y: mc.y - mr * 1.5))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.02, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 0.9).setFill()
    NSBezierPath(ovalIn: CGRect(x: mc.x - mr, y: mc.y - mr, width: 2 * mr, height: 2 * mr)).fill()
    NSColor(calibratedWhite: 0.97, alpha: 1).setStroke()
    lens.stroke()
    handle.stroke()
    ctx.restoreGState()

    ctx.restoreGState()   // tile clip
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources")
let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! png(draw(size: CGFloat(pixels)), pixels: pixels).write(to: iconset.appendingPathComponent(name))
    }
}
try! png(draw(size: 1024), pixels: 1024).write(to: out.appendingPathComponent("AppIcon-preview.png"))
print("wrote \(iconset.path)")
