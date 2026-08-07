import AppKit

enum IORouteStatusIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 14), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let input = NSBezierPath()
            input.lineWidth = 1.55
            input.lineCapStyle = .round
            input.lineJoinStyle = .round
            input.move(to: NSPoint(x: 1.2, y: 7))
            input.line(to: NSPoint(x: 6.2, y: 7))
            input.move(to: NSPoint(x: 4.2, y: 9.2))
            input.line(to: NSPoint(x: 6.4, y: 7))
            input.line(to: NSPoint(x: 4.2, y: 4.8))
            input.stroke()

            // A tiny capsule reads as both a microphone and an I/O port.
            NSBezierPath(
                roundedRect: NSRect(x: 7.9, y: 3.1, width: 2.9, height: 7.8),
                xRadius: 1.45,
                yRadius: 1.45
            ).fill()

            let output = NSBezierPath()
            output.lineWidth = 1.55
            output.lineCapStyle = .round
            output.lineJoinStyle = .round
            output.move(to: NSPoint(x: 11.2, y: 7))
            output.line(to: NSPoint(x: 16.6, y: 7))
            output.move(to: NSPoint(x: 14.5, y: 9.2))
            output.line(to: NSPoint(x: 16.8, y: 7))
            output.line(to: NSPoint(x: 14.5, y: 4.8))
            output.stroke()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Audio input and output route"
        return image
    }()
}
