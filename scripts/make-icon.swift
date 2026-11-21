// Génère scripts/AppIcon.icns : swiftc scripts/make-icon.swift -o /tmp/make-icon && /tmp/make-icon
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Carré arrondi avec la marge du gabarit d'icône macOS
    let body = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.30, green: 0.55, blue: 1.0, alpha: 1),
               ending: NSColor(red: 0.10, green: 0.25, blue: 0.80, alpha: 1))!.draw(in: path, angle: -90)

    // Symbole clavier en blanc
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.4, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = NSImage(size: symbol.size)
        white.lockFocus()
        symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        white.unlockFocus()
        white.draw(in: NSRect(x: (s - symbol.size.width) / 2, y: (s - symbol.size.height) / 2,
                              width: symbol.size.width, height: symbol.size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: base).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base).png"))
    try! render(size: base * 2).write(to: URL(fileURLWithPath: "\(iconset)/icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", "scripts/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
