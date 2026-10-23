import Combine
import RealityKit
import SwiftUI
import ToastyyCore
import UIKit

/// The 3D toaster. Like the web canvas it is transparent, framed between the copy and
/// the bottom tray, and leaves touch handling to the SwiftUI hit areas laid over it.
struct ToasterView: UIViewRepresentable {
    @ObservedObject var store: GameStore
    var reducedMotion: Bool
    /// Space reserved above (copy) and below (tray) the toaster, in points.
    var insets: (top: CGFloat, bottom: CGFloat)

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.clear)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.layer.isOpaque = false
        view.environment.lighting.intensityExponent = 0.55
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        view.isAccessibilityElement = false
        view.isUserInteractionEnabled = false
        context.coordinator.install(in: view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.reducedMotion = reducedMotion
        context.coordinator.setInsets(top: insets.top, bottom: insets.bottom)
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.tearDown() }

    @MainActor
    final class Coordinator: NSObject {
        let store: GameStore
        weak var view: ARView?
        var reducedMotion = false
        private let anchor = AnchorEntity(world: .zero)
        private let stage = Entity()
        private let camera = PerspectiveCamera()
        private let heater = PointLight()
        private var toaster: Entity?
        private var knob: Entity?
        private var markings: ModelEntity?
        private var markingsKey = ""
        private var heaters: [(entity: Entity, materials: [any RealityKit.Material])] = []
        private var leverParts: [(entity: Entity, rest: SIMD3<Float>)] = []
        private var slices: [Entity] = []
        private var faces: [ModelEntity] = []
        private var crumbs: [(entity: ModelEntity, velocity: SIMD3<Float>)] = []
        private var framingCorners: [SIMD3<Float>] = []
        private var displayLink: CADisplayLink?
        private var load: AnyCancellable?
        private var previousPhase: Game.Phase = .ready
        private var previousTime = 0.0
        private var lastSize = CGSize.zero
        private var insetTop: CGFloat = 130
        private var insetBottom: CGFloat = 128
        private var presentation: Float = 0
        private var visualLever: Float = 0
        private var knobAngle: Float = 0
        private var latchKick: Float = 0
        private var popStart: Float = -ToastMotion.travel
        // Derived from the reference asset's rail and handle, including 2 mm end clearances.
        private let leverTravel: Float = 0.05639124
        private let leverTopOffset: Float = 0.01198582
        private let leverHandle = SIMD3<Float>(-0.123, 0.12927765, 0)
        private let knobCenter = SIMD3<Float>(-0.13, 0.03694, 0)
        private let buttonPoints: [SIMD3<Float>] = [0.1141, 0.0988, 0.0835, 0.0682].map { [-0.1161, $0, -0.0379] }
        private let knobAngles: [Float] = [-0.86, -0.29, 0.29, 0.86]

        init(store: GameStore) { self.store = store }

        @MainActor
        private final class DisplayTarget: NSObject {
            weak var owner: Coordinator?
            init(_ owner: Coordinator) { self.owner = owner }
            @objc func step(_ link: CADisplayLink) { owner?.frame(link) }
        }

        func install(in view: ARView) {
            self.view = view
            anchor.addChild(stage)
            anchor.addChild(camera)
            camera.camera.fieldOfViewInDegrees = 28
            camera.camera.near = 0.01
            camera.camera.far = 10
            view.scene.addAnchor(anchor)

            // Same rig as the web scene: warm key with shadows, cool-warm fill, orange rim.
            let key = DirectionalLight()
            key.light.color = UIColor(hex: 0xfff2d7)
            key.light.intensity = 4200
            key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.5, depthBias: 1)
            key.look(at: [0, 0.08, 0], from: [-1.2, 1.9, 1.8], relativeTo: nil)
            anchor.addChild(key)
            let sky = DirectionalLight()
            sky.light.color = UIColor(hex: 0xfff5dc)
            sky.light.intensity = 1900
            sky.look(at: [0, 0, 0], from: [-0.4, 1.2, -0.2], relativeTo: nil)
            anchor.addChild(sky)
            let front = DirectionalLight()
            front.light.color = UIColor(hex: 0xfff8ec)
            front.light.intensity = 1500
            front.look(at: [0, 0.09, 0], from: [-1, 0.25, -0.15], relativeTo: nil)
            anchor.addChild(front)
            let rim = DirectionalLight()
            rim.light.color = UIColor(hex: 0xff9b4a)
            rim.light.intensity = 1100
            rim.look(at: [0, 0.08, 0], from: [1.2, 0.7, -1.1], relativeTo: nil)
            anchor.addChild(rim)
            heater.light.color = UIColor(hex: 0xff5a20)
            heater.light.attenuationRadius = 0.48
            heater.light.intensity = 0
            heater.position = [-0.02, 0.165, 0]
            stage.addChild(heater)
            addContactShadow()

            let target = DisplayTarget(self)
            let link = CADisplayLink(target: target, selector: #selector(DisplayTarget.step(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
            loadToaster()
        }

        func tearDown() {
            displayLink?.invalidate()
            displayLink = nil
            load?.cancel()
            view?.scene.anchors.removeAll()
        }

        func setInsets(top: CGFloat, bottom: CGFloat) {
            guard abs(top - insetTop) > 0.5 || abs(bottom - insetBottom) > 0.5 else { return }
            insetTop = top
            insetBottom = bottom
            frameCamera()
        }

        private func loadToaster() {
            guard let url = Bundle.main.url(forResource: "Toaster", withExtension: "usdz") else {
                store.sceneError = "The toaster model is missing from the app bundle."
                return
            }
            load = Entity.loadAsync(contentsOf: url)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion { self?.store.sceneError = error.localizedDescription }
                }, receiveValue: { [weak self] entity in
                    guard let self else { return }
                    do {
                        self.toaster = entity
                        self.stage.addChild(entity)
                        self.knob = entity.findEntity(named: "rotate_button_mesh")
                        for name in ["scroll_button_mesh", "lever_insert_mesh"] {
                            guard let part = entity.findEntity(named: name) else { throw SceneError.missingPart(name) }
                            var rest = part.position
                            rest.y += self.leverTopOffset
                            self.leverParts.append((part, rest))
                        }
                        self.collectHeaters(in: entity)
                        try self.makeBread()
                        self.addMarkings()
                        self.measureFraming()
                        self.frameCamera()
                        self.store.sceneReady = true
                    } catch { self.store.sceneError = error.localizedDescription }
                })
        }

        private enum SceneError: LocalizedError {
            case missingPart(String)
            var errorDescription: String? {
                switch self { case .missingPart(let name): "The toaster model is missing its \(name) part." }
            }
        }

        private func collectHeaters(in entity: Entity) {
            if entity.name.contains("heater_002"), let model = entity.components[ModelComponent.self] {
                heaters.append((entity, model.materials))
            }
            for child in entity.children { collectHeaters(in: child) }
        }

        /// The web's soft radial contact shadow, instead of an opaque floor.
        private func addContactShadow() {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { renderer in
                let shade = UIColor(red: 62 / 255, green: 45 / 255, blue: 25 / 255, alpha: 1)
                let colors = [shade.withAlphaComponent(0.48), shade.withAlphaComponent(0.24), shade.withAlphaComponent(0)].map(\.cgColor) as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.48, 1]) {
                    renderer.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 5,
                                                          endCenter: CGPoint(x: 64, y: 64), endRadius: 62, options: [])
                }
            }
            guard let cgImage = image.cgImage,
                  let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) else { return }
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 0.52))
            let shadow = ModelEntity(mesh: .generatePlane(width: 0.46, depth: 0.25), materials: [material])
            shadow.position = [0, 0.0015, 0.012]
            stage.addChild(shadow)
        }

        private func makeBread() throws {
            guard let toaster else { return }
            let crust = try ToastMesh.make(width: 0.075, height: 0.079, depth: 0.0136)
            let crumb = try ToastMesh.make(width: 0.063, height: 0.068, depth: 0.014)
            for z in ToastMotion.slotCenters {
                let slice = Entity()
                slice.position = [0, ToastMotion.baseY, z]
                let outer = ModelEntity(mesh: crust, materials: [SimpleMaterial(color: UIColor(hex: 0xb97637), roughness: 0.86, isMetallic: false)])
                let inner = ModelEntity(mesh: crumb, materials: [ToastMesh.material(skin: store.game.progression.skin, heat: 0, burnt: false)])
                slice.addChild(outer)
                slice.addChild(inner)
                toaster.addChild(slice)
                slices.append(slice)
                faces.append(inner)
            }
            let mesh = MeshResource.generateBox(size: 0.002)
            let material = SimpleMaterial(color: UIColor(hex: 0xce934b), roughness: 1, isMetallic: false)
            for _ in 0..<20 {
                let crumb = ModelEntity(mesh: mesh, materials: [material])
                crumb.isEnabled = false
                toaster.addChild(crumb)
                crumbs.append((crumb, .zero))
            }
        }

        // MARK: Printed housing

        private func addMarkings() {
            guard let toaster else { return }
            let plane = ModelEntity(mesh: .generatePlane(width: 0.112, height: 0.154), materials: [])
            // The plane faces +Z; turn it to the model's negative-X front, like the web decal.
            plane.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
            plane.position = [-0.1144, 0.09, 0]
            toaster.addChild(plane)
            markings = plane
            if let knob {
                let marker = ModelEntity(mesh: .generateBox(size: [0.0015, 0.006, 0.0018]),
                                         materials: [UnlitMaterial(color: UIColor(hex: 0xffe3a1))])
                marker.position = [-0.0133, 0.009, 0]
                knob.addChild(marker)
            }
            paintMarkings()
        }

        /// Port of the web's `paintSurfaceMarkings()`: labels, indicator lights, browning dial.
        private func paintMarkings() {
            let key = "\(store.muted)-\(store.haptics)-\(store.game.difficulty.rawValue)"
            guard let markings, key != markingsKey else { return }
            markingsKey = key
            let width: CGFloat = 1024
            let scale = width / 0.112
            let x = { (z: CGFloat) in (z + 0.056) * scale }
            let y = { (height: CGFloat) in (0.167 - height) * scale }
            let ink = UIColor(hex: 0x474337)
            let accent = UIColor(hex: 0x9e5e2e)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: 1408), format: format).image { renderer in
                let c = renderer.cgContext
                func print(_ label: String, _ z: CGFloat, _ height: CGFloat, size: CGFloat = 0.003, color: UIColor = ink, spacing: CGFloat = 0.00035) {
                    let font = UIFont(name: "DMMono-Medium", size: size * scale) ?? .monospacedSystemFont(ofSize: size * scale, weight: .medium)
                    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: spacing * scale]
                    let text = NSAttributedString(string: label, attributes: attributes)
                    let bounds = text.size()
                    // Trailing kern is not visible, so center the glyphs alone.
                    text.draw(at: CGPoint(x: x(z) - (bounds.width - spacing * scale) / 2, y: y(height) - bounds.height / 2))
                }
                func line(_ points: [(CGFloat, CGFloat)], color: UIColor = accent, width lineWidth: CGFloat = 0.00035) {
                    c.setStrokeColor(color.cgColor)
                    c.setLineWidth(lineWidth * scale)
                    c.setLineCap(.round)
                    c.setLineJoin(.round)
                    for (index, point) in points.enumerated() {
                        let p = CGPoint(x: x(point.0), y: y(point.1))
                        if index == 0 { c.move(to: p) } else { c.addLine(to: p) }
                    }
                    c.strokePath()
                }
                print("TOASTYY", 0, 0.151, size: 0.0043, spacing: 0.0011)
                for (index, point) in buttonPoints.enumerated() {
                    let z = CGFloat(point.z), height = CGFloat(point.y)
                    print(["SOUND", "HAPTIC", "SETTINGS", "RECORDS"][index], z, height + 0.0067, size: 0.0036, spacing: 0.0002)
                    if index < 2 {
                        let active = index == 0 ? !store.muted : store.haptics
                        let radius = 0.00095 * scale
                        c.setFillColor((active ? accent : UIColor(hex: 0xaaa497)).cgColor)
                        c.fillEllipse(in: CGRect(x: x(z + 0.013) - radius, y: y(height) - radius, width: radius * 2, height: radius * 2))
                    }
                }
                print("PULL", 0.022, 0.125, size: 0.0036)
                line([(0.021, 0.117), (0.021, 0.099)])
                line([(0.0185, 0.102), (0.021, 0.099), (0.0235, 0.102)])
                print("BROWNING", 0.034, 0.047, size: 0.0028, spacing: 0.0002)
                print(store.game.difficulty.title, 0.034, 0.0405, size: 0.0039, color: accent, spacing: 0.00025)
                let selectedIndex = Difficulty.allCases.firstIndex(of: store.game.difficulty) ?? 1
                for (index, angle) in knobAngles.enumerated() {
                    let centerY = CGFloat(knobCenter.y)
                    let radius: CGFloat = 0.019
                    let a = CGFloat(angle)
                    let selected = index == selectedIndex
                    line([(sin(a) * radius, centerY + cos(a) * radius), (sin(a) * (radius + 0.0023), centerY + cos(a) * (radius + 0.0023))],
                         color: selected ? accent : UIColor(hex: 0x8c8578), width: selected ? 0.0007 : 0.00035)
                }
            }
            guard let cgImage = image.cgImage,
                  let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) else { return }
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            markings.model?.materials = [material]
        }

        // MARK: Camera

        /// Bounds of the toaster and resting bread at the ready pose, like the web's `framingPoints`.
        private func measureFraming() {
            guard let toaster else { return }
            stage.orientation = simd_quatf(angle: -7 * .pi / 180, axis: [0, 1, 0])
            let bounds = toaster.visualBounds(recursive: true, relativeTo: nil)
            framingCorners = [bounds.min.x, bounds.max.x].flatMap { x in
                [bounds.min.y, bounds.max.y].flatMap { y in [bounds.min.z, bounds.max.z].map { z in SIMD3(x, y, z) } }
            }
        }

        private func basis(eye: SIMD3<Float>, target: SIMD3<Float>) -> (forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>) {
            let forward = simd_normalize(target - eye)
            let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
            return (forward, right, simd_cross(right, forward))
        }

        private func screenBounds(eye: SIMD3<Float>, target: SIMD3<Float>, fov: Float, size: CGSize) -> CGRect {
            let (forward, right, up) = basis(eye: eye, target: target)
            let tanHalf = tan(fov * .pi / 360)
            let aspect = Float(size.width / size.height)
            let points = framingCorners.map { point -> CGPoint in
                let v = point - eye
                let depth = max(0.001, simd_dot(v, forward))
                let x = simd_dot(v, right) / (depth * tanHalf * aspect)
                let y = simd_dot(v, up) / (depth * tanHalf)
                return CGPoint(x: CGFloat((x + 1) / 2) * size.width, y: CGFloat((1 - y) / 2) * size.height)
            }
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }

        /// Fit the toaster to 88% of the width, or the space between copy and tray, then
        /// slide the camera so it is centered there (the web uses a projection view offset).
        private func frameCamera() {
            let size = lastSize
            guard size.width > 0, size.height > 0 else { return }
            // Relative to the toaster origin; the web stage sits at (0.012, -0.02, 0).
            var eye = SIMD3<Float>(-0.752, 0.28, 0)
            var target = SIMD3<Float>(-0.012, 0.105, 0)
            guard !framingCorners.isEmpty else {
                camera.look(at: target, from: eye, relativeTo: nil)
                return
            }
            let contentTop = min(insetTop, size.height - 100)
            let contentBottom = max(contentTop + 100, size.height - insetBottom)
            var fov: Float = 28
            var bounds = screenBounds(eye: eye, target: target, fov: fov, size: size)
            let fit = Float(min(size.width * 0.88 / bounds.width, (contentBottom - contentTop) / bounds.height))
            fov = 2 * atan(tan(fov * .pi / 360) / fit) * 180 / .pi
            bounds = screenBounds(eye: eye, target: target, fov: fov, size: size)
            let dx = Float(bounds.midX - size.width / 2)
            let dy = Float(bounds.midY - (contentTop + contentBottom) / 2)
            let (_, right, up) = basis(eye: eye, target: target)
            let perPoint = 2 * simd_length(target - eye) * tan(fov * .pi / 360) / Float(size.height)
            let shift = right * dx * perPoint - up * dy * perPoint
            eye += shift
            target += shift
            camera.camera.fieldOfViewInDegrees = fov
            camera.look(at: target, from: eye, relativeTo: nil)
        }

        // MARK: Frame loop

        private func frame(_ link: CADisplayLink) {
            guard let view else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let dt = Float(min(0.05, max(0, now - (previousTime == 0 ? now : previousTime))))
            previousTime = now
            store.frame(at: now)
            if view.bounds.size != lastSize { lastSize = view.bounds.size; frameCamera() }
            let phase = store.game.phase
            if phase == .toasting && previousPhase != .toasting { latchKick = 1 }
            if phase == .result && previousPhase != .result {
                popStart = -ToastMotion.travel * visualLever
                for index in crumbs.indices {
                    crumbs[index].entity.position = [Float.random(in: -0.04...0.04), 0.19, Float.random(in: -0.028...0.028)]
                    crumbs[index].entity.isEnabled = !reducedMotion
                    crumbs[index].velocity = [Float.random(in: -0.07...0.07), Float.random(in: 0.12...0.22), Float.random(in: -0.06...0.06)]
                }
            }
            previousPhase = phase
            paintMarkings()

            let blend: Float = reducedMotion ? 1 : 1 - exp(-dt * 16)
            visualLever += (store.lever - visualLever) * blend
            for part in leverParts { part.entity.position = part.rest - SIMD3(0, leverTravel * visualLever, 0) }
            let index = Difficulty.allCases.firstIndex(of: store.game.difficulty) ?? 1
            knobAngle += (knobAngles[index] - knobAngle) * (reducedMotion ? 1 : min(dt * 13, 1))
            knob?.orientation = simd_quatf(angle: knobAngle, axis: [1, 0, 0])

            let target: Float = phase == .toasting ? 1 : 0
            presentation += (target - presentation) * (reducedMotion ? 1 : 1 - exp(-dt * 4.4))
            let pose = presentation * presentation * (3 - 2 * presentation)
            latchKick *= exp(-dt * 10)
            stage.orientation = simd_quatf(angle: -7 * .pi / 180 + pose * 0.26, axis: [0, 1, 0])
            stage.scale = SIMD3(repeating: 1 + 0.09 * pose)
            stage.position = [-0.006 * pose, -0.004 * pose - latchKick * 0.0028, 0]

            let heat = Float(store.visualHeat), danger = Float(store.visualDanger)
            heater.light.intensity = (heat * 2.2 + danger * 3.8) * 1000
            updateHeaters(heat: heat, danger: danger)
            if let toaster {
                // Same idle drift and danger rattle as the web, in seconds rather than milliseconds.
                let drift = phase == .ready && !reducedMotion ? 0.00035 : 0
                let rattle = phase == .toasting && !reducedMotion ? Double(danger) : 0
                let roll = sin(now * (0.5 + rattle * 25)) * (drift * 2 + rattle * 0.006)
                toaster.orientation = simd_quatf(angle: Float(roll), axis: [0, 0, 1])
                toaster.position = [Float(sin(now * 47) * rattle * 0.0012), Float(sin(now * (1 + rattle * 38)) * (drift + rattle * 0.0009)), 0]
            }

            let skin = phase == .ready ? store.game.progression.skin : store.game.roundSkin
            let material = ToastMesh.material(skin: skin, heat: Float(store.heat), burnt: store.game.result?.rating == .miss,
                                              glow: store.game.result?.rating == .perfect)
            for face in faces { face.model?.materials = [material] }
            for (index, slice) in slices.enumerated() {
                var offset = -ToastMotion.travel * visualLever
                if phase == .result {
                    let strength: Float = store.game.result?.rating == .miss ? 0.38 : store.game.result?.rating == .perfect ? 0.35 : 0.32
                    offset = reducedMotion ? 0 : ToastMotion.pop(start: popStart, velocity: strength + Float(index) * 0.008, age: store.resultAge)
                }
                slice.position.y = ToastMotion.baseY + offset
            }
            for index in crumbs.indices where crumbs[index].entity.isEnabled {
                if phase != .result || store.resultAge > 0.8 { crumbs[index].entity.isEnabled = false; continue }
                crumbs[index].velocity.y -= dt * 0.72
                crumbs[index].entity.position += crumbs[index].velocity * dt
            }
            if phase == .ready { publishControls(in: view) }
        }

        private var heaterGlow: Float = -1
        private func updateHeaters(heat: Float, danger: Float) {
            let glow = heat * 1.5 + danger * 1.2
            guard abs(glow - heaterGlow) > 0.01 || (glow == 0 && heaterGlow != 0) else { return }
            heaterGlow = glow
            for heater in heaters {
                guard var model = heater.entity.components[ModelComponent.self] else { continue }
                model.materials = heater.materials.map { original in
                    guard var material = original as? PhysicallyBasedMaterial else { return original }
                    material.emissiveColor = .init(color: UIColor(red: 1, green: 0.11, blue: 0.02, alpha: 1))
                    material.emissiveIntensity = glow
                    return material
                }
                heater.entity.components.set(model)
            }
        }

        /// Project the lever, knob and front buttons for the SwiftUI hit areas.
        private func publishControls(in view: ARView) {
            guard let toaster else { return }
            func project(_ point: SIMD3<Float>) -> CGPoint? { view.project(toaster.convert(position: point, to: nil)) }
            var layout = ControlLayout()
            layout.leverTop = project(leverHandle)
            layout.leverBottom = project(leverHandle - [0, leverTravel, 0])
            layout.knob = project(knobCenter)
            if let center = layout.knob, let edge = project(knobCenter + [0, 0, 0.017]) {
                layout.knobSize = max(44, abs(edge.x - center.x) * 2 + 10)
            }
            layout.buttons = buttonPoints.compactMap(project)
            func rounded(_ point: CGPoint?) -> CGPoint? { point.map { CGPoint(x: ($0.x * 2).rounded() / 2, y: ($0.y * 2).rounded() / 2) } }
            layout.leverTop = rounded(layout.leverTop)
            layout.leverBottom = rounded(layout.leverBottom)
            layout.knob = rounded(layout.knob)
            layout.knobSize = layout.knobSize.rounded()
            layout.buttons = layout.buttons.compactMap(rounded)
            if layout != store.controls { store.controls = layout }
        }
    }
}
