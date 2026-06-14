#!/usr/bin/env swift
import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let apps: [(String, String)] = [
    ("finder", "/System/Library/CoreServices/Finder.app"),
    ("safari", "/Applications/Safari.app"),
    ("messages", "/System/Applications/Messages.app"),
    ("mail", "/System/Applications/Mail.app"),
    ("maps", "/System/Applications/Maps.app"),
    ("photos", "/System/Applications/Photos.app"),
    ("facetime", "/System/Applications/FaceTime.app"),
    ("calendar", "/System/Applications/Calendar.app"),
    ("contacts", "/System/Applications/Contacts.app"),
    ("reminders", "/System/Applications/Reminders.app"),
    ("notes", "/System/Applications/Notes.app"),
    ("tv", "/System/Applications/TV.app"),
    ("music", "/System/Applications/Music.app"),
    ("podcasts", "/System/Applications/Podcasts.app"),
    ("appstore", "/System/Applications/App Store.app"),
    ("settings", "/System/Applications/System Settings.app"),
]

func saveTrashIcon(name: String, size: CGFloat) throws {
    guard let icon = NSImage(named: NSImage.trashEmptyName) else { return }
    icon.size = NSSize(width: size, height: size)
    guard let tiff = icon.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    let url = outDir.appendingPathComponent("\(name).png")
    try png.write(to: url)
    print("Wrote \(url.path)")
}

func saveIcon(for path: String, name: String, size: CGFloat) throws {
    let icon = NSWorkspace.shared.icon(forFile: path)
    icon.size = NSSize(width: size, height: size)

    guard let tiff = icon.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(name)\n", stderr)
        return
    }

    let url = outDir.appendingPathComponent("\(name).png")
    try png.write(to: url)
    print("Wrote \(url.path)")
}

for (name, path) in apps {
    try saveIcon(for: path, name: name, size: 256)
}

try saveTrashIcon(name: "trash", size: 256)

// Headroom custom icon — gradient H badge matching the app brand
let headroomSize: CGFloat = 256
let image = NSImage(size: NSSize(width: headroomSize, height: headroomSize))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: headroomSize, height: headroomSize)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 56, yRadius: 56)

let gradient = NSGradient(colors: [
    NSColor(red: 0.49, green: 0.51, blue: 1.0, alpha: 1),
    NSColor(red: 0.13, green: 0.77, blue: 0.49, alpha: 1),
])!
gradient.draw(in: path, angle: 135)

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 128, weight: .bold),
    .foregroundColor: NSColor.white,
]
let text = "H" as NSString
let textSize = text.size(withAttributes: attrs)
let textPoint = NSPoint(
    x: (headroomSize - textSize.width) / 2,
    y: (headroomSize - textSize.height) / 2 - 6
)
text.draw(at: textPoint, withAttributes: attrs)

image.unlockFocus()

if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let url = outDir.appendingPathComponent("headroom.png")
    try png.write(to: url)
    print("Wrote \(url.path)")
}
