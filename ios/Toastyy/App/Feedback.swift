import AVFoundation
import ToastyyCore
import UIKit

/// Synthesized locally, like the web reference; no audio downloads or background playback.
@MainActor
final class Feedback {
    var muted = false { didSet { if muted { stopAll() } } }
    var haptics = true
    private let engine = AVAudioEngine()
    private let effects = AVAudioPlayerNode()
    private let hum = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notification = UINotificationFeedbackGenerator()
    private var configured = false

    private func prepare() -> Bool {
        guard !muted else { return false }
        do {
            if !configured {
                // Ambient respects the hardware silent switch and other apps' audio.
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                engine.attach(effects)
                engine.attach(hum)
                engine.connect(effects, to: engine.mainMixerNode, format: format)
                engine.connect(hum, to: engine.mainMixerNode, format: format)
                configured = true
            }
            if !engine.isRunning { try engine.start() }
            return true
        } catch { return false } // Gameplay remains available when audio is interrupted.
    }

    private func buffer(frequency: Double, duration: Double, volume: Float, looping: Bool = false) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count), let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        for index in 0..<Int(count) {
            let t = Double(index) / format.sampleRate
            let envelope = looping ? 1 : min(1, t * 150) * pow(max(0, 1 - t / duration), 2)
            samples[index] = Float(sin(2 * .pi * frequency * t) * envelope) * volume
        }
        return buffer
    }

    private func tones(_ frequencies: [Double], duration: Double = 0.13, volume: Float = 0.13) {
        guard prepare() else { return }
        // Replace queued thermal clicks so a result chime always starts immediately.
        effects.stop()
        for frequency in frequencies {
            if let audio = buffer(frequency: frequency, duration: duration, volume: volume) { effects.scheduleBuffer(audio) }
        }
        effects.play()
    }

    func click() { tones([180], duration: 0.035); if haptics { impact.impactOccurred(intensity: 0.4) } }
    func latch() { tones([85, 120], duration: 0.045); if haptics { impact.impactOccurred(intensity: 0.9) } }
    func thermalTick(danger: Double) { tones([500 + danger * 350], duration: 0.018, volume: 0.035) }
    func warning() { if haptics { impact.impactOccurred(intensity: 0.65) } }
    func startHum() {
        guard prepare(), let audio = buffer(frequency: 60, duration: 1, volume: 0.12, looping: true) else { return }
        hum.stop()
        hum.volume = 0.1
        hum.scheduleBuffer(audio, at: nil, options: .loops)
        hum.play()
    }
    func updateHum(heat: Double) { hum.volume = muted ? 0 : Float(0.12 + heat * 0.55) }
    func finish(_ rating: Rating) {
        hum.stop()
        if rating == .miss {
            tones([130, 85], duration: 0.18)
            if haptics { notification.notificationOccurred(.error) }
        } else {
            tones(rating == .perfect ? [440, 660, 880] : [350, 520])
            if haptics { notification.notificationOccurred(rating == .perfect ? .success : .warning) }
        }
    }
    func stopAll() {
        hum.stop()
        effects.stop()
        engine.pause()
    }
}
