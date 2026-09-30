// Renders the app icon: `swift tool/make_icon.swift assets/icon`
import AppKit

func render(size: Int, background: Bool, mono: Bool = false, path: String) {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: a)
    }

    if background {
        // macOS icon grid: art occupies ~80% of the canvas.
        let inset = s * 0.098
        let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
        let squircle = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: color(0x000000, 0.35))
        ctx.addPath(squircle); ctx.setFillColor(color(0x0B0D12)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(squircle); ctx.clip()
        let bg = CGGradient(colorsSpace: cs, colors: [color(0x1B2030), color(0x0A0C11)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: s * 0.3, y: s * 0.95), end: CGPoint(x: s * 0.7, y: s * 0.05), options: [])
        // soft glow behind the glyph
        let glow = CGGradient(colorsSpace: cs, colors: [color(0x5EE6C8, 0.28), color(0x5EE6C8, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.5, y: s * 0.46), startRadius: 0,
                               endCenter: CGPoint(x: s * 0.5, y: s * 0.46), endRadius: s * 0.42, options: [])
        ctx.restoreGState()
        // hairline edge
        ctx.addPath(squircle); ctx.setStrokeColor(color(0xFFFFFF, 0.10)); ctx.setLineWidth(s * 0.004); ctx.strokePath()
    }

    // Glyph: headband + two earcups, scaled about the canvas centre.
    let g = background ? 1.0 : mono ? 1.4 : 1.22
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: s * (0.5 + (x - 0.5) * g), y: s * (0.5 + (y - 0.5) * g)) }
    let lw = s * (mono ? 0.075 : 0.062) * g

    ctx.saveGState()
    let band = CGMutablePath()
    band.move(to: P(0.295, 0.47))
    band.addCurve(to: P(0.705, 0.47), control1: P(0.295, 0.83), control2: P(0.705, 0.83))
    ctx.addPath(band)
    ctx.setLineWidth(lw); ctx.setLineCap(.round)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    // Menu-bar "template" icons must be black-on-transparent; macOS tints them.
    let ink = mono
        ? CGGradient(colorsSpace: cs, colors: [color(0x000000), color(0x000000)] as CFArray, locations: [0, 1])!
        : CGGradient(colorsSpace: cs, colors: [color(0xF4F7FB), color(0x8FF0D8)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(ink, start: P(0.3, 0.78), end: P(0.7, 0.3), options: [])
    ctx.restoreGState()

    for left in [true, false] {
        let w = s * 0.135 * g, h = s * 0.265 * g
        let cx = left ? P(0.295, 0).x : P(0.705, 0).x
        let cup = CGRect(x: cx - w / 2, y: P(0, 0.47).y - h * 0.78, width: w, height: h)
        let path = CGPath(roundedRect: cup, cornerWidth: w * 0.46, cornerHeight: w * 0.46, transform: nil)
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.drawLinearGradient(ink, start: CGPoint(x: cup.minX, y: cup.maxY), end: CGPoint(x: cup.maxX, y: cup.minY), options: [])
        ctx.restoreGState()
        // inner pad cut-out gives the cups depth
        if background {
            let pad = cup.insetBy(dx: w * 0.3, dy: h * 0.14)
            ctx.addPath(CGPath(roundedRect: pad, cornerWidth: pad.width / 2, cornerHeight: pad.width / 2, transform: nil))
            ctx.setFillColor(color(0x0F1A22, 0.92)); ctx.fillPath()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
render(size: 1024, background: true, path: "\(dir)/icon_1024.png")
render(size: 512, background: false, path: "\(dir)/mark.png")
render(size: 64, background: false, mono: true, path: "\(dir)/tray_template.png")
