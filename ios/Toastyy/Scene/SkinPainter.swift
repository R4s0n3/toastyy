import RealityKit
import ToastyyCore
import UIKit

/// Native equivalents of the web canvas finishes, shared by the 3D bread and collection.
@MainActor
enum SkinPainter {
    private static var images: [String: UIImage] = [:]
    private static var textures: [String: TextureResource] = [:]

    static func texture(for skin: ToastSkin) -> TextureResource? {
        if let texture = textures[skin.id] { return texture }
        guard let image = image(for: skin).cgImage,
              let texture = try? TextureResource.generate(from: image, options: .init(semantic: .color)) else { return nil }
        textures[skin.id] = texture
        return texture
    }

    static func image(for skin: ToastSkin) -> UIImage {
        if let image = images[skin.id] { return image }
        let palettes: [String: [UInt32]] = [
            "dry": [0xf6d698, 0xe8b568], "doodle": [0xfff0c2, 0xf3d486],
            "berry": [0xffd4da, 0xf298ba], "porcelain": [0xfffcf0, 0xdfede9],
            "copper": [0xe5ac85, 0x94553b], "chrome": [0xd3dee4, 0xa0aebc],
            "gold": [0xffe6a0, 0xc19332], "prism": [0xc8e9dc, 0xc8b2e3],
        ]
        let palette = palettes[skin.id] ?? palettes["dry"]!
        var seed: UInt32 = 31 + skin.id.utf8.reduce(0) { $0 + UInt32($1) }
        func random() -> CGFloat {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return CGFloat(seed) / CGFloat(UInt32.max)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { renderer in
            let c = renderer.cgContext
            let colors = palette.map { UIColor(hex: $0).cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 512, y: 512), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            c.setLineCap(.round)
            if skin.id == "doodle" {
                let colors: [UInt32] = [0xda653b, 0x397f71, 0xdca022, 0x71549c, 0xc64d7c]
                for i in 0..<16 {
                    c.saveGState()
                    c.translateBy(x: CGFloat(i % 4) * 137 + 45, y: CGFloat(i / 4) * 135 + 45)
                    c.rotate(by: random() * 0.7 - 0.35)
                    c.setStrokeColor(UIColor(hex: colors[i % colors.count]).cgColor)
                    c.setLineWidth(6)
                    if i % 2 == 0 {
                        c.strokeEllipse(in: CGRect(x: -8, y: -8, width: 52, height: 52))
                        c.move(to: CGPoint(x: 4, y: 20)); c.addQuadCurve(to: CGPoint(x: 31, y: 20), control: CGPoint(x: 17, y: 43)); c.strokePath()
                        c.setFillColor(UIColor(hex: colors[i % colors.count]).cgColor)
                        c.fillEllipse(in: CGRect(x: 4, y: 6, width: 5, height: 5))
                        c.fillEllipse(in: CGRect(x: 27, y: 6, width: 5, height: 5))
                    } else {
                        c.move(to: .zero)
                        c.addCurve(to: CGPoint(x: 65, y: 8), control1: CGPoint(x: 25, y: -38), control2: CGPoint(x: 32, y: 55))
                        c.strokePath()
                    }
                    c.restoreGState()
                }
            } else if skin.id == "berry" {
                let colors: [UInt32] = [0xe25884, 0xad436e, 0xfff0bb, 0xf6a450]
                for i in -2..<8 {
                    c.setStrokeColor(UIColor(hex: colors[(i + 4) % 4]).cgColor)
                    c.setLineWidth(CGFloat(25 + (i % 2) * 8))
                    let y = CGFloat(i * 100)
                    c.move(to: CGPoint(x: -70, y: y))
                    c.addCurve(to: CGPoint(x: 580, y: y + 70), control1: CGPoint(x: 210, y: y - 190), control2: CGPoint(x: 70, y: y + 250))
                    c.strokePath()
                }
            } else if skin.id == "porcelain" {
                c.setStrokeColor(UIColor(hex: 0x275899).cgColor)
                c.setLineWidth(3.5)
                for row in 0..<5 {
                    for col in 0..<5 {
                        c.saveGState()
                        c.translateBy(x: CGFloat(col * 128), y: CGFloat(row * 126))
                        for _ in 0..<6 {
                            c.strokeEllipse(in: CGRect(x: -8, y: -45, width: 16, height: 42))
                            c.rotate(by: .pi / 3)
                        }
                        c.restoreGState()
                    }
                }
            } else if ["copper", "chrome", "gold"].contains(skin.id) {
                for _ in 0..<1700 {
                    c.setStrokeColor(UIColor.white.withAlphaComponent(random() * 0.08).cgColor)
                    c.setLineWidth(random() + 0.3)
                    let y = random() * 512
                    c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: 512, y: y + random() * 1.5)); c.strokePath()
                }
            } else if skin.id == "prism" {
                for color: UInt32 in [0xe6b6df, 0xb4ddce, 0xf8e2b3] {
                    c.setFillColor(UIColor(hex: color).withAlphaComponent(0.3).cgColor)
                    c.fillEllipse(in: CGRect(x: random() * 400 - 100, y: random() * 400 - 100, width: 350, height: 350))
                }
            }
            // Fine, deterministic pores keep bread from looking like a flat plastic slab.
            for _ in 0..<900 {
                c.setFillColor(UIColor(hex: 0x89592f).withAlphaComponent(skin.id == "dry" ? 0.12 : 0.035).cgColor)
                let size = 0.8 + random() * 3
                c.fillEllipse(in: CGRect(x: random() * 512, y: random() * 512, width: size, height: size))
            }
        }
        images[skin.id] = image
        return image
    }
}
