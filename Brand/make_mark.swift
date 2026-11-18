// Haalt het lime R-symbool uit het app-icoon als transparante PNG (bijgesneden).
// Gebruik: swift Brand/make_mark.swift Brand/rivo-appicoon.png <uitvoer.png>
import AppKit

let source = NSImage(contentsOfFile: CommandLine.arguments[1])!
let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let width = cg.width, height = cg.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

// Achtergrond is bosgroen (#142522), symbool lime (#C5F264). Dekking volgt de groenwaarde, zodat randen zacht blijven.
let bgG = 37.0, fgG = 242.0
var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        let alpha = max(0, min(1, (Double(pixels[i + 1]) - bgG) / (fgG - bgG)))
        let a = UInt8((alpha * 255).rounded())
        // Lime, voorvermenigvuldigd met de nieuwe dekking.
        pixels[i] = UInt8(197 * alpha); pixels[i + 1] = UInt8(242 * alpha); pixels[i + 2] = UInt8(100 * alpha); pixels[i + 3] = a
        if a > 20 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
    }
}
let full = ctx.makeImage()!
let pad = 8
let crop = CGRect(x: max(0, minX - pad), y: max(0, minY - pad),
                  width: min(width, maxX + pad) - max(0, minX - pad), height: min(height, maxY + pad) - max(0, minY - pad))
let cropped = full.cropping(to: crop)!
try! NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Symbool: \(cropped.width)×\(cropped.height)")
