import Foundation
import Testing
@testable import ToastyyCore

@Test func referenceDifficultyDurationsAndRamp() {
    #expect(Difficulty.soft.duration(round: 1, randomUnit: 0) == 3.7)
    #expect(Difficulty.golden.duration(round: 1, randomUnit: 1) == 4.25)
    #expect(Difficulty.crispy.duration(round: 1, randomUnit: 0) == 2.1)
    #expect(Difficulty.chaos.duration(round: 1, randomUnit: 1) == 2.4)
    #expect(abs(Difficulty.golden.duration(round: 20, randomUnit: 0) - 2.8 * 0.82) < 0.000001)
}

@Test(arguments: [
    (0.0, Rating.early, 35),
    (1.4, Rating.early, 125), // The web uses a strict > 50% threshold.
    (1.68, Rating.pale, 216),
    (2.24, Rating.nice, 512),
    (2.6, Rating.golden, 801),
    (2.7, Rating.perfect, 897),
    (2.8, Rating.miss, 0),
    (3.0, Rating.miss, 0),
])
func referenceTimingAndPoints(sample: (Double, Rating, Int)) {
    var game = Game()
    game.start(at: 0, randomUnit: 0)
    game.stop(at: sample.0)
    #expect(game.result?.rating == sample.1)
    #expect(game.result?.points == sample.2)
}

@Test func perfectWindowUsesStrict150Milliseconds() {
    var game = Game()
    game.start(at: 0, randomUnit: 0)
    game.stop(at: 2.649)
    #expect(game.result?.rating == .golden)
    game.nextRound()
    let duration = Difficulty.golden.duration(round: 2, randomUnit: 0)
    game.start(at: 10, randomUnit: 0)
    game.stop(at: 10 + duration - 0.149)
    #expect(game.result?.rating == .perfect)
}

@Test func savesAccumulateAndBurnResetsOnlyTheRun() {
    var game = Game()
    game.start(at: 0, randomUnit: 0)
    game.stop(at: 2.7)
    #expect(game.score == 897)
    #expect(game.streak == 1)
    #expect(game.records.perfects == 1)
    #expect(game.progression.xp == 100)
    #expect(game.progression.skin.id == "doodle")
    game.nextRound()
    game.start(at: 10, randomUnit: 0)
    game.stop(at: 12)
    // Math.round(1000 * (2 / 2.73)^3) = 393, then the prior streak adds 25.
    #expect(game.result?.points == 418)
    #expect(game.score == 1315)
    #expect(game.streak == 2)
    game.nextRound()
    game.start(at: 20, randomUnit: 0)
    game.tick(at: 30)
    #expect(game.result?.rating == .miss)
    #expect(game.score == 1315) // Preserve the run total while displaying the result.
    #expect(game.streak == 0)
    #expect(game.records.best == 1315)
    let xp = game.progression.xp
    game.nextRound()
    #expect(game.score == 0)
    #expect(game.round == 0)
    #expect(game.records.best == 1315)
    #expect(game.progression.xp == xp)
}

@Test func expiredStopsCannotBecomeSavesEvenBetweenFrames() {
    var game = Game(difficulty: .chaos)
    game.start(at: 100, randomUnit: 0)
    game.stop(at: 101.46)
    #expect(game.result?.rating == .miss)
    #expect(game.progression.xp == 5)
    game.tick(at: 102)
    game.stop(at: 102)
    #expect(game.progression.xp == 5) // Exactly one reward per attempt.
}

@Test func roundConfigurationIsLockedWhileToasting() {
    var game = Game()
    game.start(at: 0, randomUnit: 0)
    game.setDifficulty(.chaos)
    game.equip(ToastSkin.all[1])
    game.start(at: 20, randomUnit: 1)
    #expect(game.round == 1)
    #expect(game.difficulty == .golden)
    #expect(game.roundSkin.id == "dry")
    game.stop(at: 2.7)
    game.stop(at: 2.71)
    #expect(game.records.perfects == 1)
    #expect(game.progression.saves == 1)
}

@Test func interruptionsFreezeTheMonotonicClock() {
    var game = Game()
    game.start(at: 10, randomUnit: 0)
    game.pause(at: 11)
    let heat = game.heat(at: 11)
    game.tick(at: 300)
    game.stop(at: 300)
    #expect(game.phase == .toasting)
    #expect(game.heat(at: 300) == heat)
    game.resume(at: 301)
    game.stop(at: 302.7)
    #expect(game.result?.rating == .perfect)
}

@Test func pausingAnExpiredRoundDoesNotSaveIt() {
    var game = Game()
    game.start(at: 0, randomUnit: 0)
    game.pause(at: 3)
    #expect(game.result?.rating == .miss)
    game.resume(at: 100)
    game.nextRound()
    #expect(game.phase == .ready)
}

@Test func xpThresholdsEquipmentAndStreakCap() {
    var progression = Progression()
    progression.equip(ToastSkin.all[7])
    #expect(progression.skin.id == "dry")
    let reward = progression.award(rating: .golden, streak: 1)
    #expect(reward.earned == 70)
    #expect(reward.unlocked.map(\.id) == ["doodle"])
    #expect(progression.current.level == 2)
    #expect(progression.fraction == 0)
    #expect(progression.award(rating: .perfect, streak: 100).earned == 110)
    #expect(progression.award(rating: .miss, streak: 100).earned == 5)
    progression.equip(ToastSkin.all[0])
    #expect(progression.skin.id == "dry")
    #expect(progression.xp == 185)
}

@Test func savesRoundTripAndInvalidEquipmentRecovers() throws {
    var progression = Progression(xp: 1100, equipped: "chrome", saves: 10)
    let data = try JSONEncoder().encode(progression)
    #expect(try JSONDecoder().decode(Progression.self, from: data) == progression)
    progression = try JSONDecoder().decode(Progression.self, from: Data(#"{"xp":-100,"equipped":"gold","saves":-5}"#.utf8))
    #expect(progression.xp == 0)
    #expect(progression.skin.id == "dry")
    #expect(progression.saves == 0)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(Progression.self, from: Data("broken".utf8))
    }
}

@Test func popStartsAtTheCarriageAndLandsOnTheRaisedStop() {
    for velocity: Float in [0.32, 0.35, 0.38] {
        #expect(ToastMotion.pop(start: -0.035, velocity: velocity, age: 0) == -0.035)
        #expect(ToastMotion.pop(start: -0.035, velocity: velocity, age: 0.2) > 0)
        #expect(ToastMotion.pop(start: -0.035, velocity: velocity, age: 2) == 0)
    }
}

@Test func nativeBreadHasConsistentWindingAndFitsTheReferenceSlots() {
    let geometry = BreadMesh.make(width: 0.075, height: 0.079, depth: 0.014)
    #expect(geometry.positions.count == geometry.normals.count)
    #expect(geometry.positions.count == geometry.textureCoordinates.count)
    #expect(geometry.positions.allSatisfy { abs($0.x) <= 0.04126 && abs($0.z) <= 0.00701 })
    for index in stride(from: 0, to: geometry.indices.count, by: 3) {
        let a = Int(geometry.indices[index]), b = Int(geometry.indices[index + 1]), c = Int(geometry.indices[index + 2])
        let ab = geometry.positions[b] - geometry.positions[a]
        let ac = geometry.positions[c] - geometry.positions[a]
        let cross = SIMD3<Float>(ab.y * ac.z - ab.z * ac.y, ab.z * ac.x - ab.x * ac.z, ab.x * ac.y - ab.y * ac.x)
        let normal = geometry.normals[a]
        #expect(cross.x * normal.x + cross.y * normal.y + cross.z * normal.z > 0)
    }
}
