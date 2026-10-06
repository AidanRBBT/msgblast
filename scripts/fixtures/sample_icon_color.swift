import AppKit

let image = NSImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
var rect = NSRect(origin: .zero, size: NSSize(width: 64, height: 64))
guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
    fputs("Could not read compiled icon\n", stderr)
    exit(1)
}
let width = cg.width
let height = cg.height
let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
defer { bytes.deallocate() }
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}
context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
var red = 0.0, green = 0.0, blue = 0.0, count = 0.0
let marginX = width / 8
let marginY = height / 8
for y in 0..<height {
    for x in 0..<width {
        let edge = x < marginX || y < marginY || x >= width - marginX || y >= height - marginY
        if !edge { continue }
        let pixel = (y * width + x) * 4
        let alpha = Double(bytes[pixel + 3])
        if alpha < 16 { continue }
        red += Double(bytes[pixel])
        green += Double(bytes[pixel + 1])
        blue += Double(bytes[pixel + 2])
        count += 1
    }
}
if count == 0 { exit(1) }
print(red / count, green / count, blue / count)
