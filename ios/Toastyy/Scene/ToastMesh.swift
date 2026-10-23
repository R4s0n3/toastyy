import RealityKit
import UIKit
import simd
import ToastyyCore

enum ToastMesh {
    /// A convex bread silhouette, extruded in the same coordinates as the web bread.
    static func make(width: Float, height: Float, depth: Float) throws -> MeshResource {
        let geometry = BreadMesh.make(width: width, height: height, depth: depth)
        var descriptor = MeshDescriptor(name: "Bread")
        descriptor.positions = MeshBuffers.Positions(geometry.positions)
        descriptor.normals = MeshBuffers.Normals(geometry.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(geometry.textureCoordinates)
        descriptor.primitives = .triangles(geometry.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    @MainActor
    static func material(skin: ToastSkin, heat: Float, burnt: Bool, glow: Bool = false) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        let base = UIColor.white
        let shade: CGFloat = burnt ? 0.32 : CGFloat(1 - heat * (skin.id == "dry" ? 0.28 : 0.07))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        material.baseColor = .init(tint: UIColor(red: r * shade, green: g * shade, blue: b * shade, alpha: 1),
                                   texture: SkinPainter.texture(for: skin).map { .init($0) })
        material.roughness = .init(floatLiteral: skin.roughness)
        material.metallic = .init(floatLiteral: skin.metallic)
        if glow {
            // A perfect stop warms the bread, like the web's emissive flash.
            material.emissiveColor = .init(color: UIColor(hex: 0xff7b20))
            material.emissiveIntensity = 0.28
        }
        return material
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
