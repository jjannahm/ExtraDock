// Draws ExtraDock's app icon and writes Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift                  # writes Resources/AppIcon.icns
//   swift scripts/make-icon.swift --png out.png    # also writes a 1024px preview
//
// Everything is drawn as vectors on a 1024×1024 canvas (Apple's macOS icon grid:
// an 824pt rounded square with a 100pt margin) and re-rendered at each size.
import AppKit

let canvas: CGFloat = 1024

// MARK: - Helpers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// Rounded square with continuous ("squircle") corners, like the macOS icon shape:
/// straight sides that ease into each corner. Each corner is a superellipse quadrant,
/// which meets the straight edges with matching curvature.
func squircle(in rect: CGRect, cornerRadius: CGFloat, exponent: CGFloat = 3.3) -> NSBezierPath {
    // Continuous corners start bending about 1.53× the nominal radius from the corner.
    let reach = min(cornerRadius * 1.528, rect.width / 2, rect.height / 2)
    let steps = 90
    let corners: [(center: CGPoint, start: CGFloat)] = [
        (CGPoint(x: rect.maxX - reach, y: rect.maxY - reach), 0),
        (CGPoint(x: rect.minX + reach, y: rect.maxY - reach), .pi / 2),
        (CGPoint(x: rect.minX + reach, y: rect.minY + reach), .pi),
        (CGPoint(x: rect.maxX - reach, y: rect.minY + reach), .pi * 1.5),
    ]
    let path = NSBezierPath()
    for (cornerIndex, corner) in corners.enumerated() {
        for step in 0...steps {
            let angle = corner.start + CGFloat(step) / CGFloat(steps) * .pi / 2
            let (cosine, sine) = (cos(angle), sin(angle))
            let point = CGPoint(
                x: corner.center.x + reach * copysign(pow(abs(cosine), 2 / exponent), cosine),
                y: corner.center.y + reach * copysign(pow(abs(sine), 2 / exponent), sine)
            )
            if cornerIndex == 0 && step == 0 { path.move(to: point) } else { path.line(to: point) }
        }
    }
    path.close()
    return path
}

func withShadow(_ color: NSColor, blur: CGFloat, offsetY: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func clipped(to path: NSBezierPath, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Pieces

enum Glyph {
    case none, compass, bubble, star, heart
}

struct Tile {
    let top: UInt32
    let bottom: UInt32
    var glyph: Glyph = .none
}

/// Simple white symbols that make the tiles read as apps.
func drawGlyph(_ glyph: Glyph, in tile: CGRect) {
    let size = tile.width
    let center = CGPoint(x: tile.midX, y: tile.midY)
    switch glyph {
    case .none:
        return
    case .compass:
        let ring = NSBezierPath(ovalIn: tile.insetBy(dx: size * 0.2, dy: size * 0.2))
        ring.lineWidth = size * 0.065
        rgb(0xFFFFFF).setStroke()
        ring.stroke()
        let reach = size * 0.19, waist = size * 0.055
        let north = NSBezierPath()
        north.move(to: CGPoint(x: center.x + reach, y: center.y + reach))
        north.line(to: CGPoint(x: center.x - waist, y: center.y + waist))
        north.line(to: CGPoint(x: center.x + waist, y: center.y - waist))
        north.close()
        rgb(0xFFFFFF).setFill()
        north.fill()
        let south = NSBezierPath()
        south.move(to: CGPoint(x: center.x - reach, y: center.y - reach))
        south.line(to: CGPoint(x: center.x - waist, y: center.y + waist))
        south.line(to: CGPoint(x: center.x + waist, y: center.y - waist))
        south.close()
        rgb(0xFFFFFF, 0.55).setFill()
        south.fill()
    case .bubble:
        rgb(0xFFFFFF).setFill()
        let body = CGRect(x: tile.minX + size * 0.2, y: tile.minY + size * 0.33, width: size * 0.6, height: size * 0.42)
        NSBezierPath(roundedRect: body, xRadius: size * 0.21, yRadius: size * 0.21).fill()
        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: body.minX + size * 0.12, y: body.minY + size * 0.08))
        tail.line(to: CGPoint(x: body.minX + size * 0.02, y: tile.minY + size * 0.2))
        tail.line(to: CGPoint(x: body.minX + size * 0.3, y: body.minY + size * 0.02))
        tail.close()
        tail.fill()
    case .star:
        let star = NSBezierPath()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? size * 0.3 : size * 0.13
            let angle = CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y - size * 0.02 + radius * sin(angle))
            if index == 0 { star.move(to: point) } else { star.line(to: point) }
        }
        star.close()
        star.lineJoinStyle = .round
        star.lineWidth = size * 0.04
        rgb(0xFFFFFF).setFill()
        rgb(0xFFFFFF).setStroke()
        star.fill()
        star.stroke()
    case .heart:
        let heart = NSBezierPath()
        let bottom = CGPoint(x: center.x, y: center.y - size * 0.23)
        heart.move(to: bottom)
        heart.curve(
            to: CGPoint(x: center.x, y: center.y + size * 0.13),
            controlPoint1: CGPoint(x: center.x - size * 0.44, y: center.y + size * 0.02),
            controlPoint2: CGPoint(x: center.x - size * 0.16, y: center.y + size * 0.36)
        )
        heart.curve(
            to: bottom,
            controlPoint1: CGPoint(x: center.x + size * 0.16, y: center.y + size * 0.36),
            controlPoint2: CGPoint(x: center.x + size * 0.44, y: center.y + size * 0.02)
        )
        heart.close()
        rgb(0xFFFFFF).setFill()
        heart.fill()
    }
}

func drawTile(_ tile: Tile, in rect: CGRect, alpha: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.24, yRadius: rect.width * 0.24)
    withShadow(rgb(0x1B0B3A, 0.28 * alpha), blur: rect.width * 0.14, offsetY: -rect.width * 0.05) {
        rgb(tile.bottom, alpha).setFill()
        path.fill()
    }
    clipped(to: path) {
        NSGradient(colors: [rgb(tile.top, alpha), rgb(tile.bottom, alpha)])!.draw(in: rect, angle: -90)
        NSGradient(colors: [rgb(0xFFFFFF, 0.3 * alpha), rgb(0xFFFFFF, 0)])!
            .draw(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)
    }
    drawGlyph(tile.glyph, in: rect)
}

/// A frosted dock bar holding a row of tiles, centered on `center`.
func drawDock(
    tiles: [Tile],
    tileSize: CGFloat,
    center: CGPoint,
    glassAlpha: CGFloat,
    tileAlpha: CGFloat,
    running: Set<Int>
) {
    let padding = tileSize * 0.27
    let gap = tileSize * 0.22
    let indicator = tileSize * 0.15
    let count = CGFloat(tiles.count)
    let length = padding * 2 + count * tileSize + (count - 1) * gap
    let depth = padding * 2 + tileSize + indicator
    let bar = CGRect(x: center.x - length / 2, y: center.y - depth / 2, width: length, height: depth)
    let barPath = NSBezierPath(roundedRect: bar, xRadius: depth * 0.3, yRadius: depth * 0.3)

    withShadow(rgb(0x1B0B3A, 0.35), blur: tileSize * 0.5, offsetY: -tileSize * 0.16) {
        rgb(0xFFFFFF, glassAlpha).setFill()
        barPath.fill()
    }
    clipped(to: barPath) {
        NSGradient(colors: [rgb(0xFFFFFF, glassAlpha), rgb(0xFFFFFF, 0)])!
            .draw(in: CGRect(x: bar.minX, y: bar.midY, width: bar.width, height: bar.height / 2), angle: -90)
    }
    barPath.lineWidth = tileSize * 0.03
    rgb(0xFFFFFF, min(1, glassAlpha * 2.2)).setStroke()
    barPath.stroke()

    for (index, tile) in tiles.enumerated() {
        let offset = padding + CGFloat(index) * (tileSize + gap)
        let rect = CGRect(x: bar.minX + offset, y: bar.minY + padding + indicator, width: tileSize, height: tileSize)
        let dot = CGPoint(x: rect.midX, y: bar.minY + padding + indicator * 0.3)
        drawTile(tile, in: rect, alpha: tileAlpha)
        if running.contains(index) {
            let diameter = tileSize * 0.085
            rgb(0xFFFFFF, 0.95).setFill()
            NSBezierPath(ovalIn: CGRect(x: dot.x - diameter / 2, y: dot.y - diameter / 2, width: diameter, height: diameter)).fill()
        }
    }
}

// MARK: - Icon

let appTiles = [
    Tile(top: 0x6FD3FF, bottom: 0x1E7BFF, glyph: .compass),
    Tile(top: 0x8BF0A0, bottom: 0x1FB65A, glyph: .bubble),
    Tile(top: 0xFFD66B, bottom: 0xFF9A1F, glyph: .star),
    Tile(top: 0xFF9CC2, bottom: 0xFF3B7A, glyph: .heart),
]

func drawBackground(_ body: CGRect, _ bodyPath: NSBezierPath) {
    withShadow(rgb(0x000000, 0.3), blur: 22, offsetY: -9) {
        rgb(0x7B5CF5).setFill()
        bodyPath.fill()
    }
    clipped(to: bodyPath) {
        NSGradient(
            colors: [rgb(0x3E63F5), rgb(0x8A4FF0), rgb(0xF0529C)],
            atLocations: [0, 0.52, 1],
            colorSpace: .sRGB
        )!.draw(in: body, angle: -75)
        NSGradient(colors: [rgb(0xFFFFFF, 0.3), rgb(0xFFFFFF, 0)])!
            .draw(fromCenter: CGPoint(x: 330, y: 880), radius: 0, toCenter: CGPoint(x: 330, y: 880), radius: 640, options: [])
    }
}

func drawIcon() {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = squircle(in: body, cornerRadius: 185.4)
    drawBackground(body, bodyPath)

    clipped(to: bodyPath) {
        // The extra dock, floating behind: a softer mirror of the main one.
        drawDock(
            tiles: [
                Tile(top: 0xD6F1FF, bottom: 0xA9CCFF),
                Tile(top: 0xDDFBE3, bottom: 0xAFE8BF),
                Tile(top: 0xFFF1CF, bottom: 0xFFD49A),
                Tile(top: 0xFFE0EC, bottom: 0xFFB3CF),
            ],
            tileSize: 86, center: CGPoint(x: 512, y: 668),
            glassAlpha: 0.17, tileAlpha: 0.85, running: []
        )
        // The main dock in front.
        drawDock(
            tiles: appTiles, tileSize: 130, center: CGPoint(x: 512, y: 402),
            glassAlpha: 0.24, tileAlpha: 1, running: [0, 2]
        )
    }

    // Hairline edge so the icon holds its shape on light backgrounds.
    rgb(0xFFFFFF, 0.18).setStroke()
    bodyPath.lineWidth = 2
    bodyPath.stroke()
}

// MARK: - Rendering

func renderPNG(pixels: Int) -> Data {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

let arguments = CommandLine.arguments
let scriptDirectory = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
let resources = scriptDirectory.deletingLastPathComponent().appendingPathComponent("Resources")
let fileManager = FileManager.default

if let flag = arguments.firstIndex(of: "--png"), arguments.indices.contains(flag + 1) {
    try renderPNG(pixels: 1024).write(to: URL(fileURLWithPath: arguments[flag + 1]))
}

let iconset = fileManager.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let output = resources.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
print("Wrote \(output.path)")
