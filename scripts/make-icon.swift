// Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
//
// Usage: swift scripts/make-icon.swift <output.iconset>
// Draws the FreeDial icon (a white telephone handset on a teal gradient tile) at every size
// iconutil expects. assets/AppIcon.icns is made from this:
//   swift scripts/make-icon.swift /tmp/AppIcon.iconset && iconutil -c icns /tmp/AppIcon.iconset -o assets/AppIcon.icns
import Cocoa

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(px)
    // macOS icon grid: the tile fills 80.5% of the canvas, with room for a drop shadow.
    let tile = NSRect(x: s * 0.0975, y: s * 0.0975, width: s * 0.805, height: s * 0.805)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(starting: NSColor(calibratedRed: 0.22, green: 0.83, blue: 0.74, alpha: 1),
               ending: NSColor(calibratedRed: 0.05, green: 0.42, blue: 0.58, alpha: 1))!
        .draw(in: shape, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .semibold)
    guard let symbol = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { fatalError("phone.fill symbol unavailable") }
    let glyph = tile.width * 0.52
    let ratio = symbol.size.width / symbol.size.height
    let size = ratio >= 1 ? NSSize(width: glyph, height: glyph / ratio) : NSSize(width: glyph * ratio, height: glyph)
    let white = NSImage(size: size, flipped: false) { r in
        symbol.draw(in: r)
        NSColor.white.set()
        r.fill(using: .sourceAtop)
        return true
    }
    white.draw(in: NSRect(x: tile.midX - size.width / 2, y: tile.midY - size.height / 2,
                          width: size.width, height: size.height))

    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(px: base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try render(px: base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
