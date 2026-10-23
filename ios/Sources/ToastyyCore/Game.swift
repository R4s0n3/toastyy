import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case soft, golden, crispy, chaos
    public var id: String { rawValue }
    public var title: String { rawValue.uppercased() }
    public var multiplier: Double {
        switch self { case .soft: 0.8; case .golden: 1; case .crispy: 1.25; case .chaos: 1.6 }
    }
    public func duration(round: Int, randomUnit: Double) -> Double {
        let minimum: Double
        let range: Double
        switch self {
        case .soft: (minimum, range) = (3.7, 1.5)
        case .golden: (minimum, range) = (2.8, 1.45)
        case .crispy: (minimum, range) = (2.1, 1.15)
        case .chaos: (minimum, range) = (1.45, 0.95)
        }
        return (minimum + range * min(1, max(0, randomUnit))) * (1 - min(Double(max(0, round - 1)) * 0.025, 0.18))
    }
}

public enum Rating: String, Codable, Sendable {
    case early, pale, nice, golden, perfect, miss
    public var title: String {
        switch self {
        case .early: "TOO EARLY"; case .pale: "A LITTLE PALE"; case .nice: "NICE SAVE"
        case .golden: "GOLDEN!"; case .perfect: "PERFECT!"; case .miss: "TOO LATE!"
        }
    }
    public var headline: String {
        switch self {
        case .early: "Still doughy."; case .pale: "A bit shy."; case .nice: "Still edible."
        case .golden: "Breakfast is served."; case .perfect: "Chef’s kiss."; case .miss: "Too slow!"
        }
    }
    public var experience: Int {
        switch self { case .early: 12; case .pale: 25; case .nice: 45; case .golden: 70; case .perfect: 100; case .miss: 5 }
    }
}

public struct RoundResult: Equatable, Sendable {
    public let rating: Rating
    public let points: Int
    public let remaining: Double
    public let heat: Double
    public let earnedXP: Int
    public let unlocked: [ToastSkin]
}

public struct Records: Codable, Equatable, Sendable {
    public var best = 0
    public var bestStreak = 0
    public var perfects = 0
    public init() {}
}

/// Time is supplied by the caller, allowing a monotonic clock on iOS and deterministic tests.
public struct Game: Sendable {
    public enum Phase: Equatable, Sendable { case ready, toasting, result }
    public private(set) var phase: Phase = .ready
    public private(set) var score = 0
    public private(set) var streak = 0
    public private(set) var round = 0
    public private(set) var result: RoundResult?
    public private(set) var records: Records
    public private(set) var progression: Progression
    public private(set) var difficulty: Difficulty
    public private(set) var roundSkin: ToastSkin
    private var startedAt = 0.0
    private var duration = 0.0
    private var pausedAt: Double?

    public init(records: Records = Records(), progression: Progression = Progression(), difficulty: Difficulty = .golden) {
        self.records = records
        self.progression = progression
        self.difficulty = difficulty
        self.roundSkin = progression.skin
    }

    public mutating func setDifficulty(_ value: Difficulty) {
        guard phase == .ready else { return }
        difficulty = value
    }

    public mutating func equip(_ skin: ToastSkin) {
        guard phase == .ready else { return }
        progression.equip(skin)
    }

    public mutating func start(at now: Double, randomUnit: Double) {
        guard phase == .ready, pausedAt == nil else { return }
        round += 1
        duration = difficulty.duration(round: round, randomUnit: randomUnit)
        startedAt = now
        roundSkin = progression.skin
        result = nil
        phase = .toasting
    }

    public func heat(at now: Double) -> Double {
        guard phase == .toasting else { return result?.heat ?? 0 }
        return min(1, max(0, ((pausedAt ?? now) - startedAt) / duration))
    }

    public func danger(at now: Double) -> Double {
        guard phase == .toasting else { return 0 }
        return min(1, max(0, ((pausedAt ?? now) - startedAt - duration + 0.72) / 0.72))
    }

    public mutating func tick(at now: Double) {
        guard phase == .toasting, pausedAt == nil else { return }
        if now - startedAt >= duration { finish(rating: .miss, points: 0, remaining: 0, heat: 1) }
    }

    public mutating func stop(at now: Double) {
        guard phase == .toasting, pausedAt == nil else { return }
        let elapsed = max(0, now - startedAt)
        guard elapsed < duration else {
            finish(rating: .miss, points: 0, remaining: 0, heat: 1)
            return
        }
        let remaining = duration - elapsed
        let heat = elapsed / duration
        let rating: Rating = remaining < 0.15 ? .perfect : heat > 0.9 ? .golden : heat > 0.74 ? .nice : heat > 0.5 ? .pale : .early
        let timingScore = (1000 * pow(heat, 3)).rounded()
        let points = max(35, Int(((timingScore + Double(min(streak * 25, 250))) * difficulty.multiplier).rounded()))
        finish(rating: rating, points: points, remaining: remaining, heat: heat)
    }

    private mutating func finish(rating: Rating, points: Int, remaining: Double, heat: Double) {
        phase = .result
        if rating == .miss { streak = 0 } else {
            score += points
            streak += 1
            records.best = max(records.best, score)
            records.bestStreak = max(records.bestStreak, streak)
            if rating == .perfect { records.perfects += 1 }
        }
        let reward = progression.award(rating: rating, streak: streak)
        result = RoundResult(rating: rating, points: points, remaining: remaining, heat: heat, earnedXP: reward.earned, unlocked: reward.unlocked)
    }

    public mutating func nextRound() {
        guard phase == .result, pausedAt == nil else { return }
        if result?.rating == .miss { score = 0; round = 0 }
        phase = .ready
        result = nil
    }

    public mutating func pause(at now: Double) {
        guard pausedAt == nil else { return }
        // Resolve an already expired round before freezing it.
        tick(at: now)
        pausedAt = now
    }

    public mutating func resume(at now: Double) {
        guard let pausedAt else { return }
        if phase == .toasting { startedAt += max(0, now - pausedAt) }
        self.pausedAt = nil
    }
}
