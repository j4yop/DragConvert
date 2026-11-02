import AppKit
import Foundation

// Generates a tiny synthetic PDF for headless engine tests.
// Run from the repo root: swift scripts/make-fixtures.swift

let fixtures = URL(fileURLWithPath: "Tests/Fixtures", isDirectory: true)
try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
let url = fixtures.appendingPathComponent("sample.pdf")

var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
    fatalError("could not create PDF context")
}

context.beginPDFPage(nil)
context.setFillColor(NSColor.white.cgColor)
context.fill(mediaBox)
context.setFillColor(NSColor.systemOrange.cgColor)
context.fill(CGRect(x: 72, y: 560, width: 120, height: 120))

let graphics = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let text = "DragConvert fixture" as NSString
text.draw(
    at: NSPoint(x: 72, y: 700),
    withAttributes: [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black]
)
NSGraphicsContext.restoreGraphicsState()
context.endPDFPage()
context.closePDF()
print("wrote \(url.path)")
