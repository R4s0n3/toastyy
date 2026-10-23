import Foundation

public struct ToastSkin: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let xp: Int
    public let finish: String
    public let note: String
    public let color: UInt32
    public let metallic: Float
    public let roughness: Float
    public var level: Int { Self.all.firstIndex(of: self)! + 1 }

    public static let all: [ToastSkin] = [
        .init(id: "dry", name: "Dry toast", xp: 0, finish: "THE ORIGINAL", note: "Just a little bread with a big future.", color: 0xb9874b, metallic: 0, roughness: 0.9),
        .init(id: "doodle", name: "Happy camper", xp: 70, finish: "PAINTED", note: "Sunny doodles. Wobbly lines. A very good morning.", color: 0xe39951, metallic: 0, roughness: 0.72),
        .init(id: "berry", name: "Berry groovy", xp: 200, finish: "PAINTED", note: "Pink lemonade and big, juicy swirls.", color: 0xce6289, metallic: 0, roughness: 0.55),
        .init(id: "porcelain", name: "Blue china", xp: 400, finish: "GLAZED CERAMIC", note: "Cobalt brushwork under a glossy porcelain glaze.", color: 0x5473a7, metallic: 0.05, roughness: 0.24),
        .init(id: "copper", name: "Copper club", xp: 700, finish: "BRUSHED METAL", note: "Warm copper with a little hard-earned patina.", color: 0xb96f4c, metallic: 0.88, roughness: 0.3),
        .init(id: "chrome", name: "Silver service", xp: 1100, finish: "POLISHED METAL", note: "A mirror-bright slice for a very smooth operator.", color: 0x8b9ba8, metallic: 1, roughness: 0.15),
        .init(id: "gold", name: "Golden child", xp: 1700, finish: "GOLD LEAF", note: "A little ridiculous. Completely golden. All yours.", color: 0xbd9436, metallic: 0.94, roughness: 0.23),
        .init(id: "prism", name: "Daydream", xp: 2500, finish: "IRIDESCENT", note: "Pearl, lilac, mint. A different color at every turn.", color: 0x9b82bb, metallic: 0.55, roughness: 0.2),
    ]
}

public struct Progression: Codable, Equatable, Sendable {
    public private(set) var xp: Int
    public private(set) var equipped: String
    public private(set) var saves: Int
    public var skin: ToastSkin { ToastSkin.all.first { $0.id == equipped && $0.xp <= xp } ?? ToastSkin.all[0] }
    public var current: ToastSkin { ToastSkin.all.last { $0.xp <= xp } ?? ToastSkin.all[0] }
    public var next: ToastSkin? { ToastSkin.all.first { $0.xp > xp } }
    public var fraction: Double {
        guard let next else { return 1 }
        return Double(xp - current.xp) / Double(next.xp - current.xp)
    }

    public init(xp: Int = 0, equipped: String = "dry", saves: Int = 0) {
        self.xp = min(1_000_000_000, max(0, xp))
        self.equipped = equipped
        self.saves = max(0, saves)
        self.equipped = skin.id
    }

    public mutating func equip(_ skin: ToastSkin) {
        if skin.xp <= xp { equipped = skin.id }
    }

    public mutating func award(rating: Rating, streak: Int) -> (earned: Int, unlocked: [ToastSkin]) {
        let bonus = rating == .miss ? 0 : min(10, max(0, streak - 1) * 2)
        let earned = rating.experience + bonus
        let previous = xp
        xp = min(1_000_000_000, xp + earned)
        if rating != .miss { saves = min(1_000_000_000, saves + 1) }
        let unlocked = ToastSkin.all.filter { $0.xp > previous && $0.xp <= xp }
        if let newest = unlocked.last { equipped = newest.id }
        return (earned, unlocked)
    }

    private enum CodingKeys: CodingKey { case xp, equipped, saves }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(xp: try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0,
                  equipped: try container.decodeIfPresent(String.self, forKey: .equipped) ?? "dry",
                  saves: try container.decodeIfPresent(Int.self, forKey: .saves) ?? 0)
    }
}
