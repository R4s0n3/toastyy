import Foundation

public enum ToastMotion {
    public static let baseY: Float = 0.177
    public static let travel: Float = 0.035
    public static let slotCenters: [Float] = [-0.0215, 0.0215]

    public static func pop(start: Float, velocity: Float, age: Float) -> Float {
        let gravity: Float = 0.85
        let landing = (velocity + sqrt(velocity * velocity + 2 * gravity * start)) / gravity
        return age >= landing ? 0 : start + velocity * age - gravity * age * age / 2
    }
}
