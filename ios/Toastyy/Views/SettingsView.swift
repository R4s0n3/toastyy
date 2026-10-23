import SwiftUI

/// The web's "Toaster settings" dialog, including its how-to-play list.
struct SettingsDialog: View {
    @ObservedObject var store: GameStore
    let width: CGFloat
    private let steps: [(String, String)] = [
        ("Turn", " the round knob to set difficulty."),
        ("Start", " with dry toast. Earn XP to unlock painted designs, ceramics, and metals."),
        ("Pull", " the side lever down."),
        ("Wait", " while the toaster heats up."),
        ("Tap", " as late as you dare—before it pops. Nail it for bonus XP and your next toast level."),
    ]

    var body: some View {
        DialogCard(width: width, onClose: close) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "bolt.horizontal")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Palette.orange)
                    .frame(height: 38, alignment: .center)
                    .accessibilityHidden(true)
                Text("Toaster settings")
                    .font(Typeface.sans(27, .bold)).tracking(em: -0.05, size: 27)
                    .padding(.top, 7).padding(.bottom, 18)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 7) {
                    settingRow("Sound", on: !store.muted, identifier: "soundSetting", action: store.toggleSound)
                    settingRow("Haptics", on: store.haptics, identifier: "hapticsSetting", action: store.toggleHaptics)
                }
                Text("How to play")
                    .font(Typeface.sans(12, .bold)).tracking(em: 0.04, size: 12)
                    .padding(.top, 24).padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("\(index + 1).").frame(width: 22, alignment: .trailing).padding(.trailing, 5)
                            Text("\(Text(steps[index].0).font(Typeface.sans(14, .bold)))\(steps[index].1)")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(Typeface.sans(14, .medium))
                        .foregroundStyle(Color(hex: 0x514b40))
                    }
                }
                .accessibilityElement(children: .combine)
                Button("GOT IT", action: close)
                    .buttonStyle(InkButtonStyle())
                    .padding(.top, 20)
                    .accessibilityIdentifier("settingsDone")
            }
        }
    }

    private func close() { store.dialog = nil }

    private func settingRow(_ title: String, on: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(Typeface.sans(13, .bold))
            Spacer()
            Button(action: action) {
                Text(on ? "ON" : "OFF")
                    .font(Typeface.mono(9))
                    .foregroundStyle(on ? Palette.ink : .white)
                    .frame(minWidth: 30)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(on ? Palette.green : Color(hex: 0x676055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .accessibilityLabel(title)
            .accessibilityValue(on ? "ON" : "OFF")
            .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: 0x28251f, opacity: 0.1), lineWidth: 1))
    }
}

/// The web's "Cabinet records" dialog.
struct RecordsDialog: View {
    @ObservedObject var store: GameStore
    let width: CGFloat

    var body: some View {
        let records = store.game.records
        DialogCard(width: width, onClose: { store.dialog = nil }) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "crown")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Palette.orange)
                    .frame(height: 38, alignment: .center)
                    .accessibilityHidden(true)
                Text("Cabinet records")
                    .font(Typeface.sans(27, .bold)).tracking(em: -0.05, size: 27)
                    .padding(.top, 7).padding(.bottom, 18)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 7) {
                    rankRow(1, "BEST SCORE", formatScore(records.best), highlighted: true)
                    rankRow(2, "BEST STREAK", "\(records.bestStreak)")
                    rankRow(3, "PERFECT STOPS", "\(records.perfects)")
                }
                Text("Records are stored on this device. Keep toasting to make this little machine proud.")
                    .font(Typeface.sans(12, .medium)).lineSpacing(6)
                    .foregroundStyle(Color(hex: 0x776e60))
                    .padding(.vertical, 19)
                    .fixedSize(horizontal: false, vertical: true)
                Button("BACK TO TOASTER") { store.dialog = nil }
                    .buttonStyle(InkButtonStyle())
                    .accessibilityIdentifier("recordsDone")
            }
        }
    }

    private func rankRow(_ rank: Int, _ title: String, _ value: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(twoDigits(rank)).font(Typeface.mono(10)).frame(width: 27, alignment: .leading)
            Text(title).font(Typeface.sans(10, .bold)).tracking(em: 0.04, size: 10)
            Spacer()
            Text(value).font(Typeface.mono(10))
        }
        .foregroundStyle(highlighted ? Color(hex: 0xa63b18) : Color(hex: 0x675f53))
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(highlighted ? Palette.orange.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(highlighted ? Palette.orange.opacity(0.3) : Color(hex: 0x28251f, opacity: 0.1), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.capitalized)
        .accessibilityValue(value)
    }
}
