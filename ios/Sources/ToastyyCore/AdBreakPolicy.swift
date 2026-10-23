/// Ads can only interrupt the break after a burnt run, never an active round.
public struct AdBreakPolicy: Sendable {
    private var rounds = 0
    private var lastBreak: Double
    public init(now: Double) { lastBreak = now }
    public mutating func completedRound() { rounds += 1 }
    public func isEligible(afterBurn: Bool, now: Double) -> Bool {
        afterBurn && rounds >= 6 && now - lastBreak >= 120
    }
    public mutating func didPresent(now: Double) { rounds = 0; lastBreak = now }
}
