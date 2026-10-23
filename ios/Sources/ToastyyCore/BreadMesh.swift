import Foundation

public enum BreadMesh {
    public struct Geometry: Sendable {
        public let positions: [SIMD3<Float>]
        public let normals: [SIMD3<Float>]
        public let textureCoordinates: [SIMD2<Float>]
        public let indices: [UInt32]
    }

    /// Extrude a bread silhouette in the reference toaster's local XY plane.
    public static func make(width: Float, height: Float, depth: Float) -> Geometry {
        let normalized: [SIMD2<Float>] = [
            [-0.44, -0.5], [0.44, -0.5], [0.49, -0.44], [0.49, 0.18],
            [0.55, 0.27], [0.54, 0.37], [0.44, 0.47], [0.25, 0.53],
            [0, 0.55], [-0.25, 0.53], [-0.44, 0.47], [-0.54, 0.37],
            [-0.55, 0.27], [-0.49, 0.18], [-0.49, -0.44],
        ]
        let outline = normalized.map { SIMD2<Float>($0.x * width, $0.y * height) }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        func vertex(_ point: SIMD2<Float>, z: Float, normal: SIMD3<Float>) {
            positions.append([point.x, point.y, z])
            normals.append(normal)
            uvs.append([point.x / width + 0.5, point.y / height + 0.5])
        }
        for side in [Float(1), -1] {
            let base = UInt32(positions.count)
            vertex(.zero, z: side * depth / 2, normal: [0, 0, side])
            for point in outline { vertex(point, z: side * depth / 2, normal: [0, 0, side]) }
            for i in outline.indices {
                let a = base + 1 + UInt32(i)
                let b = base + 1 + UInt32((i + 1) % outline.count)
                indices += side > 0 ? [base, a, b] : [base, b, a]
            }
        }
        for i in outline.indices {
            let a = outline[i], b = outline[(i + 1) % outline.count]
            let edge = b - a
            let length = sqrt(edge.x * edge.x + edge.y * edge.y)
            let normal = SIMD3<Float>(edge.y / length, -edge.x / length, 0)
            let base = UInt32(positions.count)
            vertex(a, z: -depth / 2, normal: normal)
            vertex(b, z: -depth / 2, normal: normal)
            vertex(b, z: depth / 2, normal: normal)
            vertex(a, z: depth / 2, normal: normal)
            indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        return Geometry(positions: positions, normals: normals, textureCoordinates: uvs, indices: indices)
    }
}
