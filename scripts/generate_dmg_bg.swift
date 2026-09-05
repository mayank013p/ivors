import Cocoa
import CoreGraphics

func generateDMGBackground() {
    let width = 560
    let height = 340
    let size = CGSize(width: width, height: height)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        print("Failed to create context")
        exit(1)
    }

    // 1. Dark Glassmorphism Background
    context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
    context.fill(CGRect(origin: .zero, size: size))

    // 2. Subtle Top Gradient Accent
    let gradientColors = [
        CGColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 0.15),
        CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: CGFloat(width)/2.0, y: CGFloat(height)),
            end: CGPoint(x: CGFloat(width)/2.0, y: CGFloat(height) - 100),
            options: []
        )
    }

    // Convert context to NSImage and draw text using Cocoa string drawing
    guard let cgImage = context.makeImage() else { exit(1) }
    let img = NSImage(cgImage: cgImage, size: size)

    img.lockFocus()

    // Title
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: titleStyle
    ]
    ("Install Ivors Dynamic Island" as NSString).draw(
        in: CGRect(x: 0, y: CGFloat(height) - 45, width: CGFloat(width), height: 30),
        withAttributes: titleAttrs
    )

    // Subtitle instruction arrow
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor(calibratedRed: 0.65, green: 0.65, blue: 0.70, alpha: 1.0),
        .paragraphStyle: titleStyle
    ]
    ("Drag Ivors to Applications folder" as NSString).draw(
        in: CGRect(x: 0, y: 35, width: CGFloat(width), height: 25),
        withAttributes: subAttrs
    )

    let hintAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.0, alpha: 1.0),
        .paragraphStyle: titleStyle
    ]
    ("💡 First Launch: Right-click Ivors ➔ Select Open" as NSString).draw(
        in: CGRect(x: 0, y: 14, width: CGFloat(width), height: 20),
        withAttributes: hintAttrs
    )

    img.unlockFocus()

    guard let finalCGImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
    let rep = NSBitmapImageRep(cgImage: finalCGImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else { exit(1) }

    let scriptURL = URL(fileURLWithPath: #filePath)
    let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    let outPath = repoRoot.appendingPathComponent("scripts/dmg_background.png").path
    try? pngData.write(to: URL(fileURLWithPath: outPath))
    print("✅ Created DMG background graphic at \(outPath)")
}

generateDMGBackground()
