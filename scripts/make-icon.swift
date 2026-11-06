import AppKit
let path = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let rect = NSRect(x: 76, y: 76, width: 872, height: 872)
let shape = NSBezierPath(roundedRect: rect, xRadius: 196, yRadius: 196)
NSGradient(starting: NSColor(calibratedRed: 0.18, green: 0.64, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0, green: 0.32, blue: 0.90, alpha: 1))!.draw(in: shape, angle: -90)
NSColor.white.setStroke()
let key = NSBezierPath(); key.lineWidth = 54; key.lineCapStyle = .round; key.lineJoinStyle = .round
key.move(to: NSPoint(x: 282, y: 468)); key.line(to: NSPoint(x: 282, y: 362)); key.line(to: NSPoint(x: 742, y: 362)); key.line(to: NSPoint(x: 742, y: 468)); key.stroke()
let title = "space" as NSString
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 108, weight: .medium), .foregroundColor: NSColor.white]
let textSize = title.size(withAttributes: attrs)
title.draw(at: NSPoint(x: (1024-textSize.width)/2, y: 565), withAttributes: attrs)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
