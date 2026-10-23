import SwiftUI
import ToastyyCore

enum Palette {
    static let cream = Color(hex: 0xf2e9d8)
    static let ink = Color(hex: 0x403c32)
    static let secondary = Color(hex: 0x827969)
    static let copper = Color(hex: 0xa65c35)
    static let line = Color(hex: 0xd8cdb8)
}

struct GameView: View {
    @ObservedObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24)
            scorebar.padding(.horizontal, 24).padding(.top, 16)
            copy.padding(.top, 22).padding(.horizontal, 20)
            ZStack(alignment: .bottom) {
                ToasterView(store: store, reducedMotion: reducedMotion)
                    .accessibilityHidden(true)
                if !store.sceneReady && store.sceneError == nil {
                    ProgressView("Warming up…")
                        .tint(Palette.copper)
                        .frame(maxHeight: .infinity)
                }
                if let error = store.sceneError {
                    ContentUnavailableView("Couldn’t warm up", systemImage: "exclamationmark.triangle", description: Text(error))
                        .frame(maxHeight: .infinity)
                }
                if store.game.phase == .result, let result = store.game.result {
                    resultCard(result).padding(.horizontal, 28).padding(.bottom, 12)
                        .allowsHitTesting(false)
                } else if store.game.phase == .ready && store.sceneReady {
                    Label("DRAG THE LEVER TO START", systemImage: "arrow.down")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.3).foregroundStyle(Palette.secondary)
                        .padding(.bottom, 6).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if store.game.phase == .toasting {
                    VStack(spacing: 6) {
                        Text("HEAT").font(.system(size: 9, weight: .medium, design: .monospaced))
                        ForEach(0..<5) { index in
                            Capsule().fill(Double(4 - index) < ceil(store.heat * 5) ? Palette.copper : Palette.line)
                                .frame(width: 5, height: 16)
                        }
                    }
                    .foregroundStyle(Palette.secondary).padding(24).accessibilityHidden(true)
                }
            }
            controls.padding(.horizontal, 24)
            collectionBar.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 10)
        }
        .background(Palette.cream.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .sheet(item: $store.sheet) { sheet in
            switch sheet {
            case .collection: CollectionView(store: store)
            case .settings: SettingsView(store: store)
            case .records: RecordsView(store: store)
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                BreadShape().stroke(Palette.ink, lineWidth: 1.8).frame(width: 18, height: 20)
                Text("TOASTYY").font(.system(size: 17, weight: .black, design: .rounded)).tracking(2)
            }
            Spacer()
            iconButton(store.muted ? "speaker.slash" : "speaker.wave.2", label: store.muted ? "Turn sound on" : "Mute sound") {
                store.muted.toggle()
            }
            iconButton("slider.horizontal.3", label: "Settings") { store.sheet = .settings }
                .disabled(store.game.phase != .ready)
        }.frame(height: 48)
    }

    private var scorebar: some View {
        HStack(alignment: .center) {
            scoreItem("SCORE", value: store.game.score).accessibilityIdentifier("score")
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(store.game.phase == .toasting ? Palette.copper : Palette.secondary).frame(width: 5, height: 5)
                Text(status).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
            .accessibilityIdentifier("gameStatus")
            Spacer()
            scoreItem("BEST", value: store.game.records.best, alignment: .trailing)
        }
        .padding(.bottom, 15)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private var status: String {
        if !store.sceneReady { return "WARMING" }
        switch store.game.phase {
        case .ready: return "READY"
        case .toasting: return store.danger > 0 ? "ALMOST" : "TOASTING"
        case .result: return store.game.result?.rating == .miss ? "POPPED" : "SAVED"
        }
    }

    private var copy: some View {
        VStack(spacing: 6) {
            Text(store.game.phase == .toasting ? "\(store.game.difficulty.title) · ROUND \(store.game.round)" : "YOUR TOASTER, YOUR RULES")
                .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Palette.copper)
            Text(store.game.phase == .toasting ? "Listen closely…" : store.game.result?.rating.headline ?? "Set it. Pull it.")
                .font(.system(size: 38, weight: .regular, design: .serif)).tracking(-1.8)
                .lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityAddTraits(.isHeader)
            Text(store.game.phase == .toasting ? "Tap anywhere as late as you dare." : "Pull, time it right, and level up your toast.")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }.accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if store.game.phase == .ready {
                HStack(spacing: 4) {
                    ForEach(Difficulty.allCases) { mode in
                        Button { store.setDifficulty(mode) } label: {
                            VStack(spacing: 3) {
                                Text(mode.title).font(.system(size: 10, weight: .semibold, design: .monospaced))
                                Text(String(format: "%.1f×", mode.multiplier)).font(.system(size: 9, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity).frame(height: 45)
                            .background(store.game.difficulty == mode ? Palette.ink : .clear, in: RoundedRectangle(cornerRadius: 11))
                            .foregroundStyle(store.game.difficulty == mode ? Palette.cream : Palette.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(mode.title) difficulty, \(String(format: "%.1f", mode.multiplier)) times points")
                        .accessibilityAddTraits(store.game.difficulty == mode ? .isSelected : [])
                    }
                }
                .padding(4).background(Palette.line.opacity(0.4), in: RoundedRectangle(cornerRadius: 15))
                Button(action: store.start) {
                    Label("PULL TO START", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity).frame(height: 50)
                }
                .accessibilityLabel("Start toasting")
                .accessibilityIdentifier("startButton")
                .disabled(!store.sceneReady || store.sceneError != nil)
            } else {
                HStack {
                    Label("STREAK ×\(store.game.streak)", systemImage: "flame")
                    Spacer()
                    Text("\(store.game.difficulty.title) · \(String(format: "%.1f×", store.game.difficulty.multiplier))")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.secondary).frame(height: 53)
                if store.game.phase == .toasting {
                    Button(action: store.stop) {
                        Text("STOP TOASTER").frame(maxWidth: .infinity).frame(height: 50)
                    }.accessibilityIdentifier("stopButton")
                } else {
                    Button(action: store.nextRound) {
                        Text("ANOTHER SLICE").frame(maxWidth: .infinity).frame(height: 50)
                    }.accessibilityIdentifier("nextButton")
                }
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .tracking(1.3)
        .buttonStyle(ToastButtonStyle())
    }

    private var collectionBar: some View {
        HStack(spacing: 12) {
            SkinSwatch(skin: store.game.progression.skin).frame(width: 34, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(store.game.progression.skin.name).font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("LVL \(store.game.progression.current.level)").font(.system(size: 9, design: .monospaced))
                }
                ProgressView(value: store.game.progression.fraction).tint(Palette.copper)
                    .accessibilityLabel("Level progress")
            }
            Button { store.sheet = .collection } label: {
                Image(systemName: "square.grid.2x2").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Toast collection").accessibilityIdentifier("collectionButton")
            .disabled(store.game.phase != .ready)
        }
    }

    private func resultCard(_ result: RoundResult) -> some View {
        VStack(spacing: 5) {
            Text(result.rating.title).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
            Text(result.rating == .miss ? "BURNT" : "+\(result.points)")
                .font(.system(size: 34, weight: .medium, design: .serif))
            Text(result.rating == .miss ? "Run score \(store.game.score) · +\(result.earnedXP) XP" : String(format: "%.2fs to spare · +%d XP", result.remaining, result.earnedXP))
                .font(.system(size: 10, design: .monospaced))
            if let skin = result.unlocked.last {
                Label("Unlocked \(skin.name)", systemImage: "sparkles").font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(result.rating == .miss ? Palette.ink : Palette.copper)
        .frame(maxWidth: .infinity).padding(14)
        .background(Palette.cream.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        .accessibilityElement(children: .combine).accessibilityIdentifier("roundResult")
    }

    private func scoreItem(_ title: String, value: Int, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title).font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(Palette.secondary)
            Text(String(format: "%04d", value)).font(.system(size: 26, weight: .medium, design: .monospaced)).tracking(-1)
                .contentTransition(.numericText())
        }.accessibilityElement(children: .combine)
    }

    private func iconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 17)).frame(width: 44, height: 44) }
            .accessibilityLabel(label)
    }
}

struct ToastButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Palette.cream)
            .background(Palette.ink.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}
