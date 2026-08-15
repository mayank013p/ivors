import Cocoa
import CoreGraphics

func generateAppIcon() {
    let logoPath = "/Users/mayank/Documents/ivors-website/public/ivors_logo.png"
    guard let sourceImage = NSImage(contentsOfFile: logoPath) else {
        print("❌ Could not load logo image at \(logoPath)")
        exit(1)
    }

    let iconsetDir = "/tmp/IvorsAppIcon.iconset"
    let fileManager = FileManager.default
    try? fileManager.removeItem(atPath: iconsetDir)
    try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (filename, dimension) in sizes {
        let size = CGSize(width: dimension, height: dimension)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("Failed to create context for size \(dimension)")
            continue
        }

        let rect = CGRect(origin: .zero, size: size)

        // Draw smooth macOS Squircle clip path with 22% corner radius
        let cornerRadius = CGFloat(dimension) * 0.225
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.clip()

        // Draw source logo image centered inside squircle
        if let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: rect)
        }

        guard let outputCGImage = context.makeImage() else { continue }
        let imageRep = NSBitmapImageRep(cgImage: outputCGImage)
        guard let pngData = imageRep.representation(using: .png, properties: [:]) else { continue }

        let outPath = "\(iconsetDir)/\(filename)"
        try? pngData.write(to: URL(fileURLWithPath: outPath))
    }

    // Convert iconset to ICNS using iconutil
    let outputPath = "/Users/mayank/Documents/Ivors/AppIcon.icns"
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", iconsetDir, "-o", outputPath]
    try? task.run()
    task.waitUntilExit()

    print("✅ Created RGBA AppIcon.icns successfully at \(outputPath)")
}

generateAppIcon()
