import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func render(_ size: Int, status: Bool = false) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    ctx.scaleBy(x: CGFloat(size)/1024, y: CGFloat(size)/1024)
    if !status {
        NSColor(calibratedRed: 47/255, green: 84/255, blue: 235/255, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 206, yRadius: 206).fill()
    }
    let color = status ? NSColor.black : .white
    color.setStroke(); color.setFill()
    let radius: CGFloat = status ? 365 : 272
    let width: CGFloat = status ? 85 : 62
    let center = NSPoint(x: 512, y: 512)
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: radius, startAngle: 43, endAngle: 350, clockwise: false)
    ring.lineWidth = width; ring.lineCapStyle = .round; ring.stroke()
    let theta = 350.0 * Double.pi / 180
    let end = NSPoint(x: center.x + radius * cos(theta), y: center.y + radius * sin(theta))
    let tangent = NSPoint(x: -sin(theta), y: cos(theta))
    let normal = NSPoint(x: cos(theta), y: sin(theta))
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: end.x + tangent.x * width, y: end.y + tangent.y * width))
    arrow.line(to: NSPoint(x: end.x - tangent.x * width * 0.7 + normal.x * width, y: end.y - tangent.y * width * 0.7 + normal.y * width))
    arrow.line(to: NSPoint(x: end.x - tangent.x * width * 0.7 - normal.x * width, y: end.y - tangent.y * width * 0.7 - normal.y * width))
    arrow.close(); arrow.fill()
    let base: CGFloat = 413
    for (i, height) in [85.0, 140.0, 195.0].enumerated() {
        let bar = NSBezierPath(roundedRect: NSRect(x: 393 + CGFloat(i)*81, y: base, width: 53, height: height), xRadius: 15, yRadius: 15)
        bar.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for size in [16,32,64,128,256,512,1024] { try render(size).write(to: URL(fileURLWithPath: output + "/AppIcon-\(size).png")) }
try render(36, status: true).write(to: URL(fileURLWithPath: output + "/StatusIcon.png"))
