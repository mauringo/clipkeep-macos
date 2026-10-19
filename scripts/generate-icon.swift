import AppKit

// Reproducible vector drawing for the app's Dock/Finder icon.
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.28, green: 0.39, blue: 0.95, alpha: 1),
           ending: NSColor(calibratedRed: 0.25, green: 0.16, blue: 0.65, alpha: 1))!
    .draw(in: tile, angle: -80)
let board = NSBezierPath(roundedRect: NSRect(x: 285, y: 230, width: 454, height: 550), xRadius: 50, yRadius: 50)
NSColor.white.setStroke()
board.lineWidth = 34
board.stroke()
let clip = NSBezierPath(roundedRect: NSRect(x: 408, y: 732, width: 208, height: 94), xRadius: 28, yRadius: 28)
NSColor.white.setFill()
clip.fill()
for y in [600, 492, 384] {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 390, y: y))
    line.line(to: NSPoint(x: 634, y: y))
    line.lineWidth = 28
    line.lineCapStyle = .round
    line.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
