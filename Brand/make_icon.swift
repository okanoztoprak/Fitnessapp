// Tekent het app-icoon (1024×1024) met CoreGraphics. Gebruik: swift Brand/make_icon.swift <uitvoer.png> [tinted]
import AppKit
import CoreGraphics

let size = 1024.0
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let tinted = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "tinted"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// CoreGraphics telt y van onder; draai om zodat de coördinaten van boven lezen.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let lime: UInt32 = 0xCCFA45

// Achtergrond: bijna zwart met een zachte gloed in het midden.
if !tinted {
    let bg = CGGradient(colorsSpace: space, colors: [color(0x1B1C21), color(0x08080A)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [color(lime, 0.16), color(lime, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 470, options: [])
}
let ink = tinted ? color(0xFFFFFF) : color(lime)

// Ring: spoor en een voortgangsboog van 300°, beginnend bovenaan.
let center = CGPoint(x: 512, y: 512)
ctx.setLineWidth(66)
ctx.setLineCap(.round)
ctx.setStrokeColor(tinted ? color(0xFFFFFF, 0.25) : color(lime, 0.16))
ctx.addArc(center: center, radius: 352, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()
ctx.setStrokeColor(ink)
let start = -CGFloat.pi / 2
ctx.addArc(center: center, radius: 352, startAngle: start, endAngle: start + .pi * 2 * 300 / 360, clockwise: false)
ctx.strokePath()

// Bliksem, optisch in het midden.
let bolt: [CGPoint] = [(548, 238), (660, 238), (566, 446), (668, 446), (452, 792), (504, 540), (396, 540)]
    .map { CGPoint(x: $0.0 - 20, y: $0.1 - 3) }
ctx.setFillColor(ink)
ctx.setLineJoin(.round)
ctx.setLineWidth(18)
ctx.setStrokeColor(ink)
ctx.addLines(between: bolt)
ctx.closePath()
ctx.drawPath(using: .fillStroke)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
print("Geschreven: \(path)")
