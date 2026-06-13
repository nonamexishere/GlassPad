import AppKit

// Renders a single 1024×1024 app-icon PNG: a rounded-rect gradient tile with a
// white SF Symbol centered.
// Usage: swift render-icon.swift <out.png> <symbol> <topHex> <bottomHex>
let args = CommandLine.arguments
guard args.count == 5 else {
    FileHandle.standardError.write(Data("usage: render-icon.swift out.png symbol topHex bottomHex\n".utf8))
    exit(1)
}
let outPath = args[1]
let symbolName = args[2]

func color(_ hex: String) -> NSColor {
    var h = hex
    if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                   green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}
let top = color(args[3])
let bottom = color(args[4])

func tinted(_ image: NSImage, _ c: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    c.set()
    let r = NSRect(origin: .zero, size: image.size)
    image.draw(in: r)
    r.fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset = S * 0.085
let rect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let radius = rect.width * 0.2237 // ≈ Apple's continuous-corner ratio
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
NSGradient(colors: [top, bottom])!.draw(in: path, angle: -90)

let cfg = NSImage.SymbolConfiguration(pointSize: S * 0.42, weight: .semibold)
if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let glyph = tinted(base, .white)
    let gr = NSRect(x: (S - glyph.size.width) / 2, y: (S - glyph.size.height) / 2,
                    width: glyph.size.width, height: glyph.size.height)
    glyph.draw(in: gr)
}
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(2) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
