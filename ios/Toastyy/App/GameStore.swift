import Combine
import CoreGraphics
import Foundation
import ToastyyCore

/// Screen positions of the toaster's physical controls, projected from the 3D scene,
/// so SwiftUI hit areas can sit over them exactly like the web's positioned buttons.
struct ControlLayout: Equatable {
    var leverTop: CGPoint?
    var leverBottom: CGPoint?
    var knob: CGPoint?
    var knobSize: CGFloat = 64
    /// Sound, haptics, settings, records — top to bottom.
    var buttons: [CGPoint] = []
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var game: Game
    @Published private(set) var heat = 0.0
    @Published private(set) var danger = 0.0
    @Published private(set) var visualHeat = 0.0
    @Published private(set) var visualDanger = 0.0
    @Published private(set) var lever: Float = 0
    @Published private(set) var resultAge: Float = 0
    @Published private(set) var lastResult: RoundResult?
    @Published private(set) var newBest = false
    @Published private(set) var displayScore = 0
    @Published private(set) var unseenSkins: [String] = []
    /// Incremented per event, so SwiftUI keyframe animations can replay.
    @Published private(set) var successToken = 0
    @Published private(set) var missToken = 0
    @Published private(set) var perfectToken = 0
    @Published private(set) var comboToken = 0
    @Published private(set) var pressedControl: Int?
    @Published var controls = ControlLayout()
    @Published var muted: Bool {
        didSet {
            feedback.muted = muted
            if !muted && active && game.phase == .toasting { feedback.startHum() }
            save()
        }
    }
    @Published var haptics: Bool { didSet { feedback.haptics = haptics; save() } }
    @Published var dialog: GameDialog?
    @Published var collectionFocus = "dry"
    @Published var sceneError: String?
    @Published var sceneReady = false
    let feedback = Feedback()
    private let defaults: UserDefaults
    private var active = true
    private var previousFrame: Double?
    private var nextTick = 0.0
    private var dangerBuzzed = false
    private var bestBeforeRound = 0
    private var scoreAnimation: (from: Int, to: Int, start: Double)?
    private var isUITesting: Bool

    enum GameDialog: String, Identifiable { case collection, settings, records; var id: String { rawValue } }
    private struct Save: Codable {
        var version = 1
        var records: Records
        var progression: Progression
        var difficulty: Difficulty
        var muted: Bool
        var haptics: Bool
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let saved = isUITesting ? nil : defaults.data(forKey: "toastyy.native.save.v1")
            .flatMap { try? JSONDecoder().decode(Save.self, from: $0) }
        let valid = saved?.version == 1 ? saved : nil
        var records = valid?.records ?? Records()
        records.best = min(1_000_000_000, max(0, records.best))
        records.bestStreak = min(1_000_000_000, max(0, records.bestStreak))
        records.perfects = min(1_000_000_000, max(0, records.perfects))
        game = Game(records: records, progression: valid?.progression ?? Progression(), difficulty: valid?.difficulty ?? .golden)
        muted = valid?.muted ?? false
        haptics = valid?.haptics ?? true
        feedback.muted = muted
        feedback.haptics = haptics
        collectionFocus = game.progression.skin.id
    }

    func start() {
        guard active, sceneReady, game.phase == .ready, dialog == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        bestBeforeRound = game.records.best
        game.start(at: now, randomUnit: isUITesting ? 0 : Double.random(in: 0...1))
        lever = 1
        heat = 0
        danger = 0
        newBest = false
        nextTick = now + 0.62
        dangerBuzzed = false
        feedback.latch()
        feedback.startHum()
    }

    func stop() {
        guard active, game.phase == .toasting else { return }
        game.stop(at: ProcessInfo.processInfo.systemUptime)
        didFinish()
    }

    func dragLever(_ progress: Float) {
        guard active, sceneReady, game.phase == .ready, dialog == nil else { return }
        lever = min(1, max(0, progress))
        if lever >= 0.98 { start() }
    }

    func releaseLever() { if game.phase == .ready { lever = 0 } }

    func setDifficulty(_ value: Difficulty) {
        guard game.phase == .ready, value != game.difficulty else { return }
        game.setDifficulty(value)
        feedback.click()
        save()
    }

    func cycleDifficulty(by step: Int = 1) {
        let all = Difficulty.allCases
        let current = all.firstIndex(of: game.difficulty) ?? 0
        setDifficulty(all[(current + step + all.count) % all.count])
    }

    func equip(_ skin: ToastSkin) {
        guard game.phase != .toasting else { return }
        game.equip(skin)
        feedback.click()
        save()
    }

    func toggleSound() {
        muted.toggle()
        if !muted { feedback.click() }
    }

    func toggleHaptics() {
        haptics.toggle()
        feedback.click()
    }

    /// Mirrors the web's front-panel buttons: sound, haptics, settings, records.
    func pressControl(_ index: Int) {
        guard game.phase == .ready, dialog == nil else { return }
        pressedControl = index
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(105))
            if self?.pressedControl == index { self?.pressedControl = nil }
        }
        switch index {
        case 0: toggleSound()
        case 1: toggleHaptics()
        case 2: feedback.click(); openSettings()
        default: feedback.click(); openRecords()
        }
    }

    func openSettings() { if game.phase == .ready { dialog = .settings } }
    func openRecords() { if game.phase == .ready { dialog = .records } }
    func openCollection(focus: String? = nil) {
        guard game.phase != .toasting else { return }
        collectionFocus = focus ?? game.progression.skin.id
        unseenSkins = []
        dialog = .collection
    }

    func frame(at now: Double) {
        defer { previousFrame = now }
        guard active else { return }
        let delta = min(0.05, max(0, now - (previousFrame ?? now)))
        switch game.phase {
        case .ready: break
        case .toasting:
            game.tick(at: now)
            if game.phase == .result { didFinish(); break }
            heat = game.heat(at: now)
            danger = game.danger(at: now)
            feedback.updateHum(heat: heat)
            if now >= nextTick {
                feedback.thermalTick(danger: danger)
                nextTick = now + 0.61 + (0.115 - 0.61) * max(heat, danger)
            }
            if danger > 0.42 && !dangerBuzzed { feedback.warning(); dangerBuzzed = true }
        case .result:
            resultAge += Float(delta)
            let cooldown: Float = game.result?.rating == .perfect ? 2.25 : game.result?.rating == .miss ? 2.2 : 1.85
            if resultAge >= cooldown { nextRound() }
        }
        smoothEffects(delta: delta)
        if let animation = scoreAnimation {
            let progress = min(1, max(0, (now - animation.start) / 0.52))
            let eased = 1 - pow(1 - progress, 3)
            let value = Int((Double(animation.from) + Double(animation.to - animation.from) * eased).rounded())
            if value != displayScore { displayScore = value }
            if progress >= 1 { scoreAnimation = nil }
        }
    }

    /// The web eases its glow and vignette toward the heat, and lets them cool down after a round.
    private func smoothEffects(delta: Double) {
        let toasting = game.phase == .toasting
        let heatTarget = toasting ? heat : 0
        let dangerTarget = toasting ? danger : 0
        var nextHeat = visualHeat + (heatTarget - visualHeat) * min(delta * (toasting ? 7 : 2.8), 1)
        var nextDanger = visualDanger + (dangerTarget - visualDanger) * min(delta * (toasting ? 9 : 5), 1)
        if !toasting && nextHeat < 0.002 { nextHeat = 0 }
        if !toasting && nextDanger < 0.002 { nextDanger = 0 }
        if nextHeat != visualHeat { visualHeat = nextHeat }
        if nextDanger != visualDanger { visualDanger = nextDanger }
    }

    private func didFinish() {
        guard let result = game.result else { return }
        resultAge = 0
        lever = 0
        heat = result.heat
        danger = 0
        lastResult = result
        if result.rating == .miss {
            missToken += 1
        } else {
            newBest = game.records.best > bestBeforeRound
            scoreAnimation = (displayScore, game.score, ProcessInfo.processInfo.systemUptime)
            successToken += 1
            if result.rating == .perfect { perfectToken += 1 }
            if game.streak > 1 { comboToken += 1 }
        }
        for skin in result.unlocked where !unseenSkins.contains(skin.id) { unseenSkins.append(skin.id) }
        feedback.finish(result.rating)
        save()
    }

    func nextRound() {
        guard game.phase == .result else { return }
        game.nextRound()
        heat = 0
        danger = 0
        resultAge = 0
        newBest = false
        if game.score == 0 { scoreAnimation = nil; displayScore = 0 }
    }

    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        let now = ProcessInfo.processInfo.systemUptime
        if value {
            game.resume(at: now)
            previousFrame = now
            nextTick = now + 0.2
            if game.phase == .toasting { feedback.startHum() }
        } else {
            let previousPhase = game.phase
            game.pause(at: now)
            if previousPhase == .toasting && game.phase == .result { didFinish() }
            lever = game.phase == .toasting ? 1 : 0
            feedback.stopAll()
            save()
        }
    }

    private func save() {
        guard !isUITesting else { return }
        let saved = Save(records: game.records, progression: game.progression, difficulty: game.difficulty, muted: muted, haptics: haptics)
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: "toastyy.native.save.v1") }
    }
}
