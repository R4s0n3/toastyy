import Combine
import Foundation
import ToastyyCore

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var game: Game
    @Published private(set) var heat = 0.0
    @Published private(set) var danger = 0.0
    @Published private(set) var lever: Float = 0
    @Published private(set) var resultAge: Float = 0
    @Published var muted: Bool {
        didSet {
            feedback.muted = muted
            if !muted && active && game.phase == .toasting { feedback.startHum() }
            save()
        }
    }
    @Published var haptics: Bool { didSet { feedback.haptics = haptics; save() } }
    @Published var sheet: GameSheet?
    @Published var sceneError: String?
    @Published var sceneReady = false
    let feedback = Feedback()
    private let defaults: UserDefaults
    private var active = true
    private var previousFrame: Double?
    private var nextTick = 0.0
    private var dangerBuzzed = false
    private var isUITesting: Bool

    enum GameSheet: String, Identifiable { case collection, settings, records; var id: String { rawValue } }
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
    }

    func start() {
        guard active, sceneReady, game.phase == .ready, sheet == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        game.start(at: now, randomUnit: isUITesting ? 0 : Double.random(in: 0...1))
        lever = 1
        heat = 0
        danger = 0
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
        guard active, sceneReady, game.phase == .ready, sheet == nil else { return }
        lever = min(1, max(0, progress))
        if lever >= 0.98 { start() }
    }

    func releaseLever() { if game.phase == .ready { lever = 0 } }

    func setDifficulty(_ value: Difficulty) {
        guard game.phase == .ready else { return }
        game.setDifficulty(value)
        feedback.click()
        save()
    }

    func cycleDifficulty() {
        let all = Difficulty.allCases
        let current = all.firstIndex(of: game.difficulty) ?? 0
        setDifficulty(all[(current + 1) % all.count])
    }

    func equip(_ skin: ToastSkin) { game.equip(skin); feedback.click(); save() }

    func frame(at now: Double) {
        defer { previousFrame = now }
        guard active else { return }
        let delta = min(0.05, max(0, now - (previousFrame ?? now)))
        switch game.phase {
        case .ready: break
        case .toasting:
            game.tick(at: now)
            if game.phase == .result { didFinish(); return }
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
    }

    private func didFinish() {
        guard let result = game.result else { return }
        resultAge = 0
        lever = 0
        heat = result.heat
        danger = 0
        feedback.finish(result.rating)
        save()
    }

    func nextRound() {
        guard game.phase == .result else { return }
        game.nextRound()
        heat = 0
        danger = 0
        resultAge = 0
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
