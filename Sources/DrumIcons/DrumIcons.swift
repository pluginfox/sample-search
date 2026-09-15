import AppKit

/// Hand-drawn monochrome drum and mic-source icons, designed on a 24×24 grid, rendered as template
/// images so they tint like SF Symbols in sidebars and lists.
public enum DrumIcon: String, CaseIterable {
    case kick, snare, tom, hihat, cymbal, percussion, other
    case direct, overheads, rooms, fx

    public var displayName: String { rawValue.capitalized }

    /// Path in a 24×24 coordinate space with the origin at the bottom-left (AppKit convention).
    public func path() -> (strokes: NSBezierPath, fills: NSBezierPath) {
        let s = NSBezierPath(), f = NSBezierPath()
        s.lineWidth = 1.7; s.lineCapStyle = .round; s.lineJoinStyle = .round
        switch self {
        case .kick:
            // Bass drum, front view: outer hoop, head, port hole low-right, two spur legs.
            s.appendOval(in: R(3, 4, 18, 18))
            s.appendOval(in: R(5.2, 6.2, 13.6, 13.6))
            f.appendOval(in: R(14, 7.5, 3.4, 3.4))
            s.move(to: P(6.5, 5.3)); s.line(to: P(4.5, 2.2))
            s.move(to: P(17.5, 5.3)); s.line(to: P(19.5, 2.2))
        case .snare:
            // Shallow shell, side view, with hoops, lugs, and snare wires below.
            s.appendRoundedRect(R(3, 9, 18, 8), xRadius: 1.2, yRadius: 1.2)
            s.move(to: P(3, 15.2)); s.line(to: P(21, 15.2))
            s.move(to: P(3, 10.8)); s.line(to: P(21, 10.8))
            for x in [7.5, 12, 16.5] { s.move(to: P(x, 15.2)); s.line(to: P(x, 10.8)) }
            for x in [6.0, 9, 12, 15, 18] { s.move(to: P(x, 7)); s.line(to: P(x + 0.01, 4.5)) }
        case .tom:
            // Deeper shell, slight perspective: top head ellipse, shell sides, bottom arc, lugs.
            s.appendOval(in: R(4, 15, 16, 5.5))
            s.move(to: P(4, 17.75)); s.line(to: P(4, 6.5))
            s.move(to: P(20, 17.75)); s.line(to: P(20, 6.5))
            s.move(to: P(4, 6.5)); s.curve(to: P(20, 6.5), controlPoint1: P(4, 3.2), controlPoint2: P(20, 3.2))
            for x in [8.0, 16.0] { s.move(to: P(x, 14)); s.line(to: P(x, 9)) }
        case .hihat:
            // Two cymbals on a rod with a clutch; slight gap between them.
            s.move(to: P(3, 14)); s.curve(to: P(21, 14), controlPoint1: P(8, 17.5), controlPoint2: P(16, 17.5))
            s.move(to: P(3, 11)); s.curve(to: P(21, 11), controlPoint1: P(8, 7.5), controlPoint2: P(16, 7.5))
            s.move(to: P(12, 21)); s.line(to: P(12, 3))
            f.appendRoundedRect(R(10.6, 15.2, 2.8, 2.2), xRadius: 0.6, yRadius: 0.6)
        case .cymbal:
            // Single cymbal, side view, with bell, on a tilted stand.
            s.move(to: P(2.5, 12)); s.curve(to: P(9.5, 14.2), controlPoint1: P(5, 13.2), controlPoint2: P(7.5, 13.9))
            s.curve(to: P(14.5, 14.2), controlPoint1: P(10.5, 16.8), controlPoint2: P(13.5, 16.8))
            s.curve(to: P(21.5, 12), controlPoint1: P(16.5, 13.9), controlPoint2: P(19, 13.2))
            s.move(to: P(12, 15.8)); s.line(to: P(12, 3))
            s.move(to: P(8.5, 3)); s.line(to: P(15.5, 3))
        case .percussion:
            // Cowbell: tapered body with a top mount, plus a beater line.
            s.move(to: P(6, 17)); s.line(to: P(18, 17)); s.line(to: P(20, 5)); s.line(to: P(4, 5)); s.close()
            s.move(to: P(10, 17)); s.line(to: P(10, 20)); s.line(to: P(14, 20)); s.line(to: P(14, 17))
            s.move(to: P(4, 5)); s.line(to: P(20, 5))
        case .other:
            s.appendOval(in: R(3, 3, 18, 18))
            s.move(to: P(9, 14.5)); s.curve(to: P(12, 16.5), controlPoint1: P(9, 16), controlPoint2: P(10.3, 16.5))
            s.curve(to: P(12, 11), controlPoint1: P(14.5, 16.5), controlPoint2: P(14.8, 12.6))
            s.line(to: P(12, 9.8))
            f.appendOval(in: R(11, 6, 2, 2))
        case .direct:
            // Close mic: dynamic capsule with grille lines and a handle angled toward the drum.
            let head = NSBezierPath(ovalIn: R(11, 12, 9, 9)); s.append(head)
            s.move(to: P(13, 15.5)); s.line(to: P(18, 15.5))
            s.move(to: P(13.6, 17.8)); s.line(to: P(17.4, 17.8))
            s.move(to: P(12.5, 13)); s.line(to: P(5, 5.5))
            s.move(to: P(6.6, 4)); s.line(to: P(3.5, 7))
        case .overheads:
            // Bar across the top with two hanging pencil condensers pointing down.
            s.move(to: P(3, 20)); s.line(to: P(21, 20))
            for x in [7.5, 16.5] {
                s.move(to: P(x, 20)); s.line(to: P(x, 14))
                s.appendRoundedRect(R(x - 1.6, 6, 3.2, 8), xRadius: 1.6, yRadius: 1.6)
                s.move(to: P(x - 1.6, 8.5)); s.line(to: P(x + 1.6, 8.5))
            }
        case .rooms:
            // Room: wall and floor meeting in a corner, with sound spreading out from it.
            s.move(to: P(4, 21)); s.line(to: P(4, 4)); s.line(to: P(21, 4))
            f.appendOval(in: R(5.6, 5.6, 2.8, 2.8))
            for r in [6.0, 10.5, 15.0] {
                s.move(to: P(7 + r, 7))   // appendArc joins from the current point, so start on the arc
                s.appendArc(withCenter: P(7, 7), radius: r, startAngle: 0, endAngle: 90)
            }
        case .fx:
            // Processed signal: a clean wave on the left becomes a hard-clipped square on the right.
            s.move(to: P(2.5, 12)); s.curve(to: P(7.5, 12), controlPoint1: P(3.5, 18), controlPoint2: P(6.5, 18))
            s.curve(to: P(12.5, 12), controlPoint1: P(8.5, 6), controlPoint2: P(11.5, 6))
            s.line(to: P(12.5, 18)); s.line(to: P(17, 18)); s.line(to: P(17, 6)); s.line(to: P(21.5, 6)); s.line(to: P(21.5, 12))
            s.move(to: P(20, 21.5)); s.line(to: P(20, 17.5))
            s.move(to: P(18, 19.5)); s.line(to: P(22, 19.5))
        }
        return (s, f)
    }

    /// Template image (black on clear) at the requested point size; AppKit tints it in place.
    public func image(pointSize: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            let (strokes, fills) = self.path()
            let scale = rect.width / 24
            let transform = AffineTransform(scale: scale)
            strokes.transform(using: transform)
            fills.transform(using: transform)
            strokes.lineWidth = 1.7 * scale
            NSColor.black.setStroke(); NSColor.black.setFill()
            strokes.stroke()
            fills.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

private func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }
private func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x, y: y, width: w, height: h) }
