import AppKit

_ = NSApplication.shared
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url) else {
    fputs("Could not read compiled icon\n", stderr)
    exit(1)
}
let side = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: side * 4,
    bitsPerPixel: 32
), let raw = rep.bitmapData else {
    fputs("Could not allocate icon bitmap\n", stderr)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSAppearance.current = NSAppearance(named: .aqua)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()
image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
let margin = side / 6
for y in 0..<side {
    for x in 0..<side {
        let edge = x < margin || y < margin || x >= side - margin || y >= side - margin
        if !edge { continue }
        let pixel = (y * side + x) * 4
        if raw[pixel + 3] < 200 { continue }
        let r = Double(raw[pixel]), g = Double(raw[pixel + 1]), b = Double(raw[pixel + 2])
        if max(r, g, b) - min(r, g, b) < 36 { continue }
        red += r
        green += g
        blue += b
        count += 1
    }
}
if count < 100 {
    fputs("Compiled icon has no chromatic edge pixels\n", stderr)
    exit(1)
}
fputs("sampled \(Int(count)) chromatic edge pixels from \(side)px aqua draw\n", stderr)
print(red / count, green / count, blue / count)
