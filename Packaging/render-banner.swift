import AppKit

// Renders a 1200×360 README hero banner: a gradient field with the app's white
// SF Symbol on the left and the title + tagline on the right.
// Usage: swift render-banner.swift <out.png> <symbol> <topHex> <bottomHex> "<Title>" "<Tagline>"
let args = CommandLine.arguments
guard args.count == 7 else {
    FileHandle.standardError.write(Data("usage: render-banner.swift out symbol topHex bottomHex title tagline\n".utf8))
    exit(1)
}
let outPath = args[1], symbolName = args[2], title = args[5], tagline = args[6]

func color(_ hex: String) -> NSColor {
    var h = hex; if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                   green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}
let top = color(args[3]), bottom = color(args[4])

func tinted(_ image: NSImage, _ c: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus(); c.set()
    let r = NSRect(origin: .zero, size: image.size)
    image.draw(in: r); r.fill(using: .sourceAtop)
    out.unlockFocus(); return out
}

let W: CGFloat = 1200, H: CGFloat = 360
let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()

// Diagonal gradient background.
NSGradient(colors: [top, bottom])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)

// White app glyph on the left.
let glyphPoint: CGFloat = 150
let cfg = NSImage.SymbolConfiguration(pointSize: glyphPoint, weight: .semibold)
if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let glyph = tinted(base, .white)
    glyph.draw(in: NSRect(x: 130, y: (H - glyph.size.height) / 2,
                          width: glyph.size.width, height: glyph.size.height))
}

// Title + tagline on the right. lockFocus gives an upright context, so string
// drawing is right-side up; y is measured from the bottom.
let textX: CGFloat = 360
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 72, weight: .bold),
    .foregroundColor: NSColor.white,
]
(title as NSString).draw(at: NSPoint(x: textX, y: H / 2 + 8), withAttributes: titleAttrs)

let taglineAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.9),
]
(tagline as NSString).draw(at: NSPoint(x: textX + 2, y: H / 2 - 48), withAttributes: taglineAttrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(2) }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
