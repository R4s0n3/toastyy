import Combine
import RealityKit
import SwiftUI
import ToastyyCore
import UIKit

struct ToasterView: UIViewRepresentable {
    @ObservedObject var store: GameStore
    var reducedMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(hex: 0xf2e9d8))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        view.isAccessibilityElement = false
        context.coordinator.install(in: view)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) { context.coordinator.reducedMotion = reducedMotion }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.tearDown() }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let store: GameStore
        weak var view: ARView?
        var reducedMotion = false
        private let anchor = AnchorEntity(world: .zero)
        private let stage = Entity()
        private let camera = PerspectiveCamera()
        private let heater = PointLight()
        private var toaster: Entity?
        private var knob: Entity?
        private var leverParts: [(entity: Entity, rest: SIMD3<Float>)] = []
        private var slices: [Entity] = []
        private var faces: [ModelEntity] = []
        private var crumbs: [(entity: ModelEntity, velocity: SIMD3<Float>)] = []
        private var displayLink: CADisplayLink?
        private var load: AnyCancellable?
        private var previousPhase: Game.Phase = .ready
        private var previousTime = 0.0
        private var lastSize = CGSize.zero
        private var presentation: Float = 0
        private var visualLever: Float = 0
        private var popStart: Float = -ToastMotion.travel
        private var dragStart: CGPoint?
        private var pendingDragTarget: String?
        private var draggingKnob = false
        private var dragDifficulty = 0
        private var leverTouch: Entity?
        // Derived from the reference asset's rail and handle, including 2 mm end clearances.
        private let leverTravel: Float = 0.05639124
        private let leverTopOffset: Float = 0.01198582

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
            camera.camera.fieldOfViewInDegrees = 27
            camera.camera.near = 0.01
            camera.camera.far = 10
            view.scene.addAnchor(anchor)

            let key = DirectionalLight()
            key.light.color = UIColor(hex: 0xffedd3)
            key.light.intensity = 2400
            key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 2, depthBias: 1)
            key.look(at: [0, 0.08, 0], from: [-0.6, 1, 0.8], relativeTo: nil)
            anchor.addChild(key)
            let fill = DirectionalLight()
            fill.light.color = UIColor(hex: 0xe2ebff)
            fill.light.intensity = 1100
            fill.look(at: [0, 0.08, 0], from: [0.5, 0.4, -0.6], relativeTo: nil)
            anchor.addChild(fill)
            heater.light.color = UIColor(hex: 0xff661a)
            heater.light.attenuationRadius = 0.4
            heater.light.intensity = 0
            heater.position = [0, 0.16, 0]
            stage.addChild(heater)

            let floor = ModelEntity(mesh: .generatePlane(width: 200, depth: 200),
                                    materials: [SimpleMaterial(color: UIColor(hex: 0xf2e9d8), roughness: 1, isMetallic: false)])
            floor.position.y = -0.001
            anchor.addChild(floor)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            view.addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
            tap.require(toFail: pan)
            view.addGestureRecognizer(tap)

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
                        self.addTouchTargets()
                        try self.makeBread()
                        self.addMarkings()
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

        private func addTouchTargets() {
            guard let toaster else { return }
            func target(_ name: String, at position: SIMD3<Float>, size: SIMD3<Float>) -> Entity {
                let entity = Entity()
                entity.name = name
                entity.position = position
                entity.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
                toaster.addChild(entity)
                return entity
            }
            leverTouch = target("leverTouch", at: [-0.123, 0.12927765, 0], size: [0.025, 0.024, 0.034])
            _ = target("knobTouch", at: [-0.13, 0.03694, 0], size: [0.026, 0.038, 0.038])
            for (index, name) in ["soundTouch", "hapticsTouch", "settingsTouch", "recordsTouch"].enumerated() {
                _ = target(name, at: [-0.123, 0.113 - Float(index) * 0.015, -0.036], size: [0.025, 0.013, 0.019])
            }
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

        private func addMarkings() {
            guard let toaster else { return }
            let text = MeshResource.generateText("TOASTYY", extrusionDepth: 0.00005,
                                                  font: .monospacedSystemFont(ofSize: 0.007, weight: .bold))
            let label = ModelEntity(mesh: text, materials: [SimpleMaterial(color: UIColor(hex: 0x474337), isMetallic: false)])
            // Text faces the negative-X front of the original model.
            label.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
            label.position = [-0.1143, 0.145, -0.017]
            toaster.addChild(label)
            if let knob {
                let marker = ModelEntity(mesh: .generateBox(size: [0.0015, 0.006, 0.0018]),
                                         materials: [UnlitMaterial(color: UIColor(hex: 0xffe3a1))])
                marker.position = [-0.0133, 0.009, 0]
                knob.addChild(marker)
            }
        }

        private func frame(_ link: CADisplayLink) {
            guard let view else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let dt = Float(min(0.05, max(0, now - (previousTime == 0 ? now : previousTime))))
            previousTime = now
            store.frame(at: now)
            if view.bounds.size != lastSize { lastSize = view.bounds.size; frameCamera() }
            let phase = store.game.phase
            if phase == .result && previousPhase != .result {
                popStart = -ToastMotion.travel * visualLever
                for index in crumbs.indices {
                    crumbs[index].entity.position = [Float.random(in: -0.04...0.04), 0.19, Float.random(in: -0.028...0.028)]
                    crumbs[index].entity.isEnabled = !reducedMotion
                    crumbs[index].velocity = [Float.random(in: -0.07...0.07), Float.random(in: 0.12...0.22), Float.random(in: -0.06...0.06)]
                }
            }
            previousPhase = phase
            let blend: Float = reducedMotion ? 1 : 1 - exp(-dt * 16)
            visualLever += (store.lever - visualLever) * blend
            for part in leverParts { part.entity.position = part.rest - SIMD3(0, leverTravel * visualLever, 0) }
            leverTouch?.position.y = 0.12927765 - leverTravel * visualLever
            let index = Float(Difficulty.allCases.firstIndex(of: store.game.difficulty) ?? 1)
            knob?.orientation = simd_quatf(angle: (index - 1.5) * 0.65, axis: [-1, 0, 0])

            let target: Float = phase == .toasting ? 1 : 0
            presentation += (target - presentation) * (reducedMotion ? 1 : 1 - exp(-dt * 4.4))
            stage.orientation = simd_quatf(angle: -7 * .pi / 180 + presentation * 0.26, axis: [0, 1, 0])
            heater.light.intensity = phase == .toasting ? Float(store.heat) * 90 : 0
            let skin = phase == .ready ? store.game.progression.skin : store.game.roundSkin
            let material = ToastMesh.material(skin: skin, heat: Float(store.heat), burnt: store.game.result?.rating == .miss)
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
        }

        private func frameCamera() {
            guard lastSize.width > 0, lastSize.height > 0 else { return }
            let aspect = Float(lastSize.width / lastSize.height)
            let halfFov = Float(27.0 * .pi / 360)
            // Fit both axes, including the highest bread pop, on compact and large iPhones.
            let distance = max(0.19 / tan(halfFov), 0.155 / (tan(halfFov) * aspect))
            let target = SIMD3<Float>(0, 0.115, 0)
            let direction = simd_normalize(SIMD3<Float>(-1, 0.33, 0.10))
            camera.look(at: target, from: target + direction * distance, relativeTo: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view, store.game.phase == .ready, store.sceneReady else { return false }
            // Hit-test at touch-down, before UIKit's pan threshold moves the finger off the handle.
            pendingDragTarget = view.entity(at: touch.location(in: view))?.name
            return pendingDragTarget == "leverTouch" || pendingDragTarget == "knobTouch"
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            store.game.phase == .ready && (pendingDragTarget == "leverTouch" || pendingDragTarget == "knobTouch")
        }

        @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view else { return }
            switch recognizer.state {
            case .began:
                dragStart = recognizer.location(in: view)
                draggingKnob = pendingDragTarget == "knobTouch"
                dragDifficulty = Difficulty.allCases.firstIndex(of: store.game.difficulty) ?? 1
            case .changed:
                guard dragStart != nil else { return }
                let translation = recognizer.translation(in: view)
                if draggingKnob {
                    let index = min(3, max(0, dragDifficulty + Int((translation.x / 32).rounded())))
                    let mode = Difficulty.allCases[index]
                    if mode != store.game.difficulty { store.setDifficulty(mode) }
                } else if let toaster,
                          let top = view.project(toaster.convert(position: [-0.123, 0.12927765, 0], to: nil)),
                          let bottom = view.project(toaster.convert(position: [-0.123, 0.12927765 - leverTravel, 0], to: nil)) {
                    store.dragLever(Float(translation.y / max(20, bottom.y - top.y)))
                }
            case .ended, .cancelled, .failed:
                dragStart = nil
                pendingDragTarget = nil
                store.releaseLever()
            default: break
            }
        }

        @objc private func tap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            if store.game.phase == .toasting { store.stop(); return }
            let name = view.entity(at: recognizer.location(in: view))?.name
            if name == "knobTouch" { store.cycleDifficulty() }
            if name == "leverTouch" { store.start() }
            guard store.game.phase == .ready else { return }
            switch name {
            case "soundTouch": store.muted.toggle()
            case "hapticsTouch": store.haptics.toggle()
            case "settingsTouch": store.sheet = .settings
            case "recordsTouch": store.sheet = .records
            default: break
            }
        }
    }
}
