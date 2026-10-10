import AppKit
let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedWhite: 245/255, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
func text(_ string: String, _ y: CGFloat, _ font: CGFloat, _ color: NSColor) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    (string as NSString).draw(in: NSRect(x: 30, y: y, width: 600, height: 46), withAttributes: [.font: NSFont.systemFont(ofSize: font), .foregroundColor: color, .paragraphStyle: style])
}
text("Install Ads Recovery", 338, 29, NSColor(calibratedWhite: 26/255, alpha: 1))
text("Drag the app into Applications", 298, 16, NSColor(calibratedWhite: 98/255, alpha: 1))
text("→", 180, 38, NSColor(calibratedRed: 47/255, green: 84/255, blue: 235/255, alpha: 1))
text("Then open Ads Recovery from Applications", 74, 15, NSColor(calibratedWhite: 26/255, alpha: 1))
text("Free Mac utility by PAD team", 28, 12, NSColor(calibratedWhite: 98/255, alpha: 1))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
