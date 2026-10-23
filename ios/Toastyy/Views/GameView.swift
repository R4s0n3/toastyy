import SwiftUI
import ToastyyCore

/// A one-to-one port of the web client's layout: topbar, scorebar, the toaster stage, and footer.
struct GameView: View {
    @ObservedObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var copyBottom: CGFloat = 130
    @State private var loadingVisible = true

    var body: some View {
        GeometryReader { window in
            ZStack {
                PageBackground()
                VStack(spacing: 0) {
                    topbar
                    scorebar
                    stage(window: window.size)
                    footer
                }
                .blur(radius: store.dialog == nil ? 0 : 4)
                GrainOverlay().ignoresSafeArea()
                dialogLayer(width: window.size.width)
                if loadingVisible {
                    LoadingScreen(ready: store.sceneReady, error: store.sceneError)
                        .transition(.opacity)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .onChange(of: store.sceneReady) { _, ready in
            guard ready else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.easeInOut(duration: 0.45)) { loadingVisible = false }
            }
        }
    }

    // MARK: Header

    private var topbar: some View {
        HStack(spacing: 10) {
            BrandMark()
            Text("TOASTYY").font(Typeface.sans(18, .extraBold)).tracking(em: -0.04, size: 18)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Toastyy")
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(minHeight: 60)
    }

    private var scorebar: some View {
        HStack {
            scoreItem("SCORE", value: store.displayScore, alignment: .leading)
                .accessibilityIdentifier("score")
            StatusPill(label: status, style: statusStyle)
                .accessibilityIdentifier("gameStatus")
            scoreItem("BEST", value: store.game.records.best, alignment: .trailing, highlighted: store.newBest)
        }
        .padding(.horizontal, 4)
        .padding(.top, 11)
        .padding(.bottom, 13)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
        .padding(.horizontal, 20)
    }

    private func scoreItem(_ title: String, value: Int, alignment: HorizontalAlignment, highlighted: Bool = false) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title).font(Typeface.mono(9)).tracking(em: 0.14, size: 9)
            Text(formatScore(value))
                .font(Typeface.mono(18)).tracking(em: -0.03, size: 18)
                .foregroundStyle(highlighted ? Palette.orange : Palette.ink)
                .shadow(color: highlighted ? Palette.orange.opacity(0.28) : .clear, radius: 6)
                .keyframeAnimator(initialValue: Punch(), trigger: title == "SCORE" ? store.successToken : 0) { content, punch in
                    content.scaleEffect(punch.scale).rotationEffect(.degrees(punch.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.24, duration: 0.19)
                        SpringKeyframe(1, duration: 0.23)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(-2, duration: 0.19)
                        SpringKeyframe(0, duration: 0.23)
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "SCORE" ? "Score" : "Best score")
        .accessibilityValue("\(value)")
    }

    private var status: String {
        if !store.sceneReady { return store.sceneError == nil ? "WARMING" : "OFFLINE" }
        switch store.game.phase {
        case .ready: return "READY"
        case .toasting: return store.danger > 0 ? "ALMOST" : "TOASTING"
        case .result: return store.game.result?.rating == .miss ? "POPPED" : "SAVED"
        }
    }

    private var statusStyle: StatusPill.Style {
        switch store.game.phase {
        case .toasting: store.danger > 0 ? .danger : .hot
        case .result: store.game.result?.rating == .miss ? .missed : .calm
        case .ready: .calm
        }
    }

    // MARK: Stage

    private func stage(window: CGSize) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let phase = store.game.phase
            ZStack(alignment: .topLeading) {
                AmbientShapes(size: size, windowWidth: window.width)
                ToasterView(store: store, reducedMotion: reducedMotion, insets: (copyBottom + 18, 83 + 45))
                    .accessibilityHidden(true)
                SteamLines(visible: phase == .toasting, danger: store.visualDanger, reducedMotion: reducedMotion)
                    .position(x: size.width / 2, y: size.height * 0.34 + 15)
                HeatAura(heat: store.visualHeat, diameter: min(window.width * 0.78, 440))
                    .position(x: size.width / 2, y: size.height * 0.57)
                copy(window: window)
                if phase == .toasting {
                    // Like the web, a touch anywhere on the stage stops the toaster immediately.
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in store.stop() })
                        .accessibilityHidden(true)
                }
                HeatMeter(heat: store.heat, visible: phase == .toasting)
                    .position(x: size.width - 22, y: size.height / 2)
                toasterControls(size: size)
                DangerVignette(danger: store.visualDanger, size: size, reducedMotion: reducedMotion)
                RoundFlashes(store: store, size: size)
                stopButton(size: size, window: window)
                resultCard(size: size)
                ScoreReactions(store: store)
                    .frame(width: size.width, height: size.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .modifier(ShakeEffect(trigger: store.missToken, enabled: !reducedMotion))
            .coordinateSpace(name: "stage")
            .onPreferenceChange(CopyBottomKey.self) { copyBottom = $0 }
        }
    }

    private var copyText: (eyebrow: String, headline: String, subcopy: String) {
        if store.sceneError != nil { return ("YOUR TOASTER, YOUR RULES", "Toaster missing", "Reinstall Toastyy to warm it back up.") }
        switch store.game.phase {
        case .ready:
            return (store.game.round > 0 ? "SET UP THE NEXT SLICE" : "YOUR TOASTER, YOUR RULES", "Set it. Pull it.", "Pull, time it right, and level up your toast.")
        case .toasting:
            return ("\(store.game.difficulty.title) · ROUND \(store.game.round)", "Listen closely…", "Tap anywhere as late as you dare.")
        case .result:
            guard let rating = store.game.result?.rating, rating != .miss else { return ("ROUND OVER", "Too slow!", "Cooling down for another run.") }
            return ("ROUND COMPLETE", rating.headline, "Your next slice is almost ready.")
        }
    }

    private func copy(window: CGSize) -> some View {
        let text = copyText
        let headlineSize = min(52, max(30, window.width * 0.08))
        return VStack(spacing: 0) {
            Text(text.eyebrow)
                .font(Typeface.mono(10)).tracking(em: 0.18, size: 10)
                .foregroundStyle(Color(hex: 0x766d5d))
                .padding(.bottom, 6)
            Text(text.headline)
                .font(Typeface.sans(headlineSize, .extraBold)).tracking(em: -0.065, size: headlineSize)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Text(text.subcopy)
                .font(Typeface.sans(13, .medium))
                .foregroundStyle(Color(hex: 0x665f53))
                .padding(.top, 9)
        }
        .multilineTextAlignment(.center)
        .frame(width: min(window.width * 0.9, 440))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: CopyBottomKey.self, value: proxy.frame(in: .named("stage")).maxY)
        })
        .frame(maxWidth: .infinity)
        .padding(.top, min(46, max(20, window.height * 0.042)))
    }

    // MARK: Toaster controls

    /// Hit areas over the projected physical controls, as the web positions its buttons.
    @ViewBuilder
    private func toasterControls(size: CGSize) -> some View {
        let ready = store.game.phase == .ready && store.sceneReady
        let layout = store.controls
        ZStack(alignment: .topLeading) {
            if let top = layout.leverTop, let bottom = layout.leverBottom {
                LeverHandle(store: store, top: top, bottom: bottom)
            }
            if let knob = layout.knob {
                KnobControl(store: store, size: layout.knobSize).position(knob)
            }
            ForEach(Array(layout.buttons.enumerated()), id: \.offset) { index, point in
                FrontButton(store: store, index: index, height: frontButtonHeight(layout.buttons)).position(point)
            }
            collectionTray
                .position(x: size.width / 2, y: size.height - min(26, max(10, size.height * 0.022)) - 41.5)
        }
        .opacity(ready ? 1 : 0)
        .offset(y: ready || !store.sceneReady ? 0 : 9)
        .animation(.easeOut(duration: 0.22), value: ready)
        .allowsHitTesting(ready && store.dialog == nil)
        .accessibilityHidden(!ready)
    }

    private func frontButtonHeight(_ points: [CGPoint]) -> CGFloat {
        guard let first = points.first, let last = points.last, points.count > 1 else { return 30 }
        return min(44, abs(last.y - first.y) / CGFloat(points.count - 1) * 0.96)
    }

    private var collectionTray: some View {
        let progression = store.game.progression
        let skin = progression.skin
        let next = progression.next
        let nextText = next.map { "\($0.xp - progression.xp) XP to \($0.name)" } ?? "Every toast, earned."
        let hasNew = !store.unseenSkins.isEmpty
        return Button { store.openCollection() } label: {
            HStack(spacing: 11) {
                SkinThumbnail(skin: skin).frame(width: 51, height: 57)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LV. \(twoDigits(progression.current.level))")
                        .font(Typeface.mono(7)).tracking(em: 0.08, size: 7).foregroundStyle(Color(hex: 0xa3733d))
                    Text(skin.name).font(Typeface.sans(12, .bold)).tracking(em: -0.03, size: 12)
                    ToastProgress(value: progression.fraction).padding(.vertical, 2)
                    Text(nextText).font(Typeface.sans(8, .medium)).foregroundStyle(Color(hex: 0x8b7a60)).lineLimit(1)
                }
                VStack(alignment: .trailing, spacing: 5) {
                    Text("YOUR TOASTS")
                    Text("\(progression.current.level) / \(ToastSkin.all.count)")
                        .font(Typeface.mono(10)).foregroundStyle(Color(hex: 0x4e493c))
                    Text("↗")
                    if hasNew { Text("NEW").font(Typeface.mono(6)).foregroundStyle(Color(hex: 0xb65c30)) }
                }
                .font(Typeface.mono(7)).tracking(em: 0.06, size: 7)
                .foregroundStyle(hasNew ? Color(hex: 0xbd5c31) : Color(hex: 0x8d7b61))
            }
            .padding(.vertical, 10).padding(.leading, 9).padding(.trailing, 14)
            .frame(width: min(UIScreen.main.bounds.width * 0.86, 355), alignment: .leading)
            .frame(minHeight: 83)
            .background(Color(red: 250 / 255, green: 245 / 255, blue: 232 / 255, opacity: 0.94), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color(hex: 0xd7cbb5), lineWidth: 1))
            .shadow(color: Color(red: 91 / 255, green: 67 / 255, blue: 34 / 255, opacity: 0.06), radius: 11, y: 7)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Toast collection. Level \(progression.current.level). Equipped: \(skin.name). \(nextText)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("collectionButton")
    }

    // MARK: Stop button and result

    private func stopButton(size: CGSize, window: CGSize) -> some View {
        let visible = store.game.phase == .toasting
        return Button(action: store.stop) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(lineWidth: 2).frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("STOP TOASTER").font(Typeface.sans(14, .extraBold)).tracking(em: 0.04, size: 14)
                    Text("tap anywhere").font(Typeface.mono(9)).tracking(em: 0.1, size: 9)
                        .foregroundStyle(Color(red: 45 / 255, green: 33 / 255, blue: 25 / 255, opacity: 0.68))
                }
            }
            .foregroundStyle(Color(hex: 0x2d2119))
            .frame(width: min(size.width * 0.86, 360))
            .frame(minHeight: 70)
        }
        .buttonStyle(StopButtonStyle(urgent: store.danger > 0.22 && !reducedMotion))
        .accessibilityIdentifier("stopButton")
        .accessibilityHidden(!visible)
        .disabled(!visible)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 98)
        .animation(visible ? .spring(response: 0.28, dampingFraction: 0.62) : .easeOut(duration: 0.2), value: visible)
        .position(x: size.width / 2, y: size.height - min(34, max(15, window.height * 0.03)) - 35)
    }

    @ViewBuilder
    private func resultCard(size: CGSize) -> some View {
        let visible = store.game.phase == .result
        if let result = store.lastResult {
            ResultCard(result: result, score: store.game.score, newBest: store.newBest) { skin in
                store.openCollection(focus: skin.id)
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.92)
            .offset(y: visible ? 0 : 12)
            .rotationEffect(.degrees(-2))
            .animation(visible ? .spring(response: 0.32, dampingFraction: 0.62) : .easeOut(duration: 0.22), value: visible)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .fixedSize()
            .frame(maxWidth: .infinity)
            .padding(.top, size.height * 0.17)
        }
    }

    // MARK: Footer

    private var footer: some View {
        let streak = store.game.streak
        return HStack {
            HStack(spacing: 7) {
                Text("◆").font(.system(size: 12)).foregroundStyle(Palette.orange)
                    .modifier(FlameDance(active: streak >= 3 && !reducedMotion))
                Text("STREAK").font(Typeface.mono(9)).tracking(em: 0.14, size: 9)
                Text("\(streak)").font(Typeface.mono(15))
                    .keyframeAnimator(initialValue: Punch(), trigger: store.successToken) { content, punch in
                        content.scaleEffect(punch.scale).rotationEffect(.degrees(punch.rotation))
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) { CubicKeyframe(1.42, duration: 0.15); SpringKeyframe(1, duration: 0.19) }
                        KeyframeTrack(\.rotation) { CubicKeyframe(5, duration: 0.15); SpringKeyframe(0, duration: 0.19) }
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Streak")
            .accessibilityValue("\(streak)")
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(store.game.difficulty.title) · \(store.game.difficulty.multiplierText)×")
                .font(Typeface.mono(9)).tracking(em: 0.04, size: 9)
                .foregroundStyle(Color(hex: 0x675f53))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.white.opacity(0.22), in: Capsule())
                .overlay(Capsule().stroke(Color(hex: 0x28251f, opacity: 0.1), lineWidth: 1))
                .fixedSize()
                .accessibilityLabel("\(store.game.difficulty.title.capitalized) difficulty, \(store.game.difficulty.multiplierText) times points")
            Button(action: store.openSettings) {
                Text("?").font(Typeface.mono(15))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.25), in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .disabled(store.game.phase != .ready || !store.sceneReady)
            .accessibilityLabel("How to play and settings")
            .accessibilityIdentifier("helpButton")
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 7)
        .padding(.bottom, 2)
        .frame(minHeight: 60)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    // MARK: Dialogs

    @ViewBuilder
    private func dialogLayer(width: CGFloat) -> some View {
        ZStack {
            if store.dialog != nil {
                Color(red: 42 / 255, green: 35 / 255, blue: 24 / 255, opacity: store.dialog == .collection ? 0.42 : 0.38)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            Group {
                switch store.dialog {
                case .settings: SettingsDialog(store: store, width: min(width * 0.88, 380)).transition(.dialog)
                case .records: RecordsDialog(store: store, width: min(width * 0.88, 380)).transition(.dialog)
                case .collection: CollectionDialog(store: store, width: min(width * 0.94, 420)).transition(.dialog)
                case nil: EmptyView()
                }
            }
            .padding(.vertical, 14)
        }
        .animation(.easeOut(duration: 0.2), value: store.dialog)
    }
}

// MARK: - Pieces

private struct CopyBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 130
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct Punch { var scale: CGFloat = 1; var rotation: Double = 0 }

extension AnyTransition {
    static var dialog: AnyTransition { .opacity.combined(with: .scale(scale: 0.96)) }
}

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.98
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// The page's paper color with the soft white light behind the toaster.
private struct PageBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let radius = hypot(size.width / 2, size.height * 0.54)
            ZStack {
                Palette.paper
                RadialGradient(stops: [
                    .init(color: .white.opacity(0.7), location: 0),
                    .init(color: .white.opacity(0.7), location: 0.15),
                    .init(color: .white.opacity(0), location: 0.45),
                ], center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0, endRadius: radius)
            }
        }
        .ignoresSafeArea()
    }
}

private struct AmbientShapes: View {
    let size: CGSize
    let windowWidth: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().fill(Color(red: 1, green: 200 / 255, blue: 61 / 255, opacity: 0.1))
                .frame(width: windowWidth * 0.52, height: windowWidth * 0.52)
                .offset(x: -windowWidth * 0.28, y: size.height * 0.28)
            Circle().fill(Color(red: 168 / 255, green: 200 / 255, blue: 102 / 255, opacity: 0.13))
                .frame(width: windowWidth * 0.42, height: windowWidth * 0.42)
                .offset(x: size.width + windowWidth * 0.24 - windowWidth * 0.42, y: size.height * 0.14)
        }
        .blur(radius: 2)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct StatusPill: View {
    enum Style { case calm, hot, danger, missed }
    let label: String
    let style: Style
    @State private var blink = false

    var body: some View {
        let hot = style == .hot || style == .danger
        let dot: Color = hot ? Palette.orange : style == .missed ? Color(hex: 0xbe372d) : Palette.green
        HStack(spacing: 7) {
            Circle().fill(dot).frame(width: 6, height: 6)
                .background(Circle().fill(dot.opacity(style == .danger ? 0.22 : hot ? 0.16 : 0.18)).frame(width: style == .danger ? 14 : 12, height: style == .danger ? 14 : 12))
                .shadow(color: style == .danger ? Palette.orange.opacity(0.45) : .clear, radius: 6)
                .opacity(hot && blink ? 0.3 : 1)
                .animation(hot ? .easeInOut(duration: style == .danger ? 0.28 : 0.75).repeatForever(autoreverses: true) : .default, value: blink)
            Text(label).font(Typeface.mono(9)).tracking(em: 0.14, size: 9)
        }
        .foregroundStyle(hot ? Color(hex: 0xa93a17) : Palette.ink)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .frame(minWidth: 79)
        .background(hot ? Palette.orange.opacity(0.08) : Color.white.opacity(0.2), in: Capsule())
        .overlay(Capsule().stroke(hot ? Palette.orange.opacity(0.3) : Palette.line, lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: style)
        .onChange(of: hot) { _, value in blink = value }
        .onAppear { blink = hot }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Toaster status")
        .accessibilityValue(label.capitalized)
    }
}

private struct HeatMeter: View {
    let heat: Double
    let visible: Bool
    var body: some View {
        let lit = min(5, Int(ceil(heat * 5)))
        VStack(spacing: 7) {
            Text("HEAT").font(Typeface.mono(7)).tracking(em: 0.15, size: 7)
                .foregroundStyle(Color(hex: 0x6d6253))
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 10, height: 26)
            VStack(spacing: 5) {
                ForEach((0..<5).reversed(), id: \.self) { index in
                    Capsule()
                        .fill(index < lit ? Palette.orange : Color(hex: 0x28251f, opacity: 0.12))
                        .frame(width: 5, height: 17)
                        .scaleEffect(y: index < lit ? 1.08 : 1)
                        .shadow(color: index < lit ? Palette.orange.opacity(0.55) : .clear, radius: 5)
                        .animation(.easeOut(duration: 0.18), value: lit)
                }
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : 8)
        .animation(.easeOut(duration: 0.25), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HeatAura: View {
    let heat: Double
    let diameter: CGFloat
    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: Color(red: 1, green: 91 / 255, blue: 36 / 255, opacity: 0.31), location: 0),
                .init(color: Color(red: 1, green: 174 / 255, blue: 42 / 255, opacity: 0.08), location: 0.45),
                .init(color: .clear, location: 0.7),
            ], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .blur(radius: 12)
            .scaleEffect(0.7 + heat * 0.35)
            .opacity(heat * 0.82)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The five soft steam wisps above the slots.
private struct SteamLines: View {
    let visible: Bool
    let danger: Double
    let reducedMotion: Bool
    private let delays = [0, -0.22, -0.48, -0.7, -0.92]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !visible || reducedMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let duration = 1.2 - danger * 0.72
            HStack(spacing: 0) {
                ForEach(delays.indices, id: \.self) { index in
                    let phase = ((time - delays[index]) / duration).truncatingRemainder(dividingBy: 1)
                    let opacity = phase < 0.35 ? phase / 0.35 * 0.9 : 0.9 * (1 - (phase - 0.35) / 0.65)
                    Ellipse()
                        .fill(RadialGradient(stops: [
                            .init(color: Color(red: 1, green: 248 / 255, blue: 230 / 255, opacity: 0.92), location: 0),
                            .init(color: Color(red: 1, green: 186 / 255, blue: 92 / 255, opacity: 0.38), location: 0.42),
                            .init(color: .clear, location: 0.72),
                        ], center: .center, startRadius: 0, endRadius: 16))
                        .frame(width: 12, height: 30)
                        .blur(radius: 2.4)
                        .scaleEffect(y: 0.7 + 0.4 * phase)
                        .offset(y: 12 - 24 * phase)
                        .opacity(reducedMotion ? 0.5 : opacity)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 132)
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DangerVignette: View {
    let danger: Double
    let size: CGSize
    let reducedMotion: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.4 * 1.24, style: .continuous)
            .stroke(Color(red: 190 / 255, green: 42 / 255, blue: 20 / 255, opacity: 0.42), lineWidth: 70)
            .blur(radius: 40)
            .frame(width: size.width * 1.24, height: size.height * 1.24)
            .position(x: size.width / 2, y: size.height / 2)
            .opacity(danger * 0.72)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The red flash on a burn and the golden bloom on a perfect stop.
private struct RoundFlashes: View {
    @ObservedObject var store: GameStore
    let size: CGSize
    var body: some View {
        ZStack {
            Color(red: 1, green: 80 / 255, blue: 40 / 255, opacity: 0.2)
                .keyframeAnimator(initialValue: 0.0, trigger: store.missToken) { content, value in content.opacity(value) } keyframes: { _ in
                    KeyframeTrack { MoveKeyframe(1); CubicKeyframe(0, duration: 0.55) }
                }
            RadialGradient(colors: [Color(red: 1, green: 224 / 255, blue: 105 / 255, opacity: 0.46), .clear],
                           center: UnitPoint(x: 0.5, y: 0.58), startRadius: 0, endRadius: max(size.width, size.height) * 0.62)
                .keyframeAnimator(initialValue: 0.0, trigger: store.perfectToken) { content, value in content.opacity(value) } keyframes: { _ in
                    KeyframeTrack { CubicKeyframe(1, duration: 0.16); CubicKeyframe(0, duration: 0.56) }
                }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScoreReactions: View {
    @ObservedObject var store: GameStore
    private struct Fly { var opacity = 0.0; var y: CGFloat = 12; var scale: CGFloat = 0.6; var rotation = -5.0 }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Text("+\(store.lastResult?.points ?? 0)")
                .font(Typeface.mono(18)).fontWeight(.bold)
                .foregroundStyle(Palette.orange)
                .keyframeAnimator(initialValue: Fly(), trigger: store.successToken) { content, fly in
                    content.scaleEffect(fly.scale).rotationEffect(.degrees(fly.rotation)).offset(y: fly.y).opacity(fly.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.opacity) { CubicKeyframe(1, duration: 0.2); LinearKeyframe(1, duration: 0.43); CubicKeyframe(0, duration: 0.27) }
                    KeyframeTrack(\.y) { CubicKeyframe(0, duration: 0.2); CubicKeyframe(-46, duration: 0.7) }
                    KeyframeTrack(\.scale) { CubicKeyframe(1.15, duration: 0.2); CubicKeyframe(0.85, duration: 0.7) }
                    KeyframeTrack(\.rotation) { CubicKeyframe(2, duration: 0.2); CubicKeyframe(0, duration: 0.7) }
                }
                .position(x: size.width / 2, y: size.height * 0.28)
            HStack(spacing: 7) {
                Text("STREAK").font(Typeface.mono(7)).tracking(em: 0.12, size: 7).foregroundStyle(Color(hex: 0x706656))
                Text("×\(store.game.streak)").font(Typeface.mono(12)).foregroundStyle(Palette.orange)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(red: 248 / 255, green: 241 / 255, blue: 227 / 255, opacity: 0.86), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: 0x28251f, opacity: 0.13), lineWidth: 1))
            .shadow(color: Color(red: 75 / 255, green: 53 / 255, blue: 22 / 255, opacity: 0.12), radius: 11, y: 8)
            .keyframeAnimator(initialValue: Fly(y: 8, scale: 0.75, rotation: 0), trigger: store.comboToken) { content, fly in
                content.scaleEffect(fly.scale).offset(y: fly.y).opacity(fly.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) { CubicKeyframe(1, duration: 0.2); LinearKeyframe(1, duration: 0.63); CubicKeyframe(0, duration: 0.32) }
                KeyframeTrack(\.y) { CubicKeyframe(0, duration: 0.2); LinearKeyframe(0, duration: 0.63); CubicKeyframe(-10, duration: 0.32) }
                KeyframeTrack(\.scale) { CubicKeyframe(1, duration: 0.2); LinearKeyframe(1, duration: 0.63); CubicKeyframe(0.92, duration: 0.32) }
            }
            .position(x: size.width / 2, y: size.height * 0.39 + 14)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ResultCard: View {
    let result: RoundResult
    let score: Int
    let newBest: Bool
    let openSkin: (ToastSkin) -> Void

    var body: some View {
        let miss = result.rating == .miss
        let perfect = result.rating == .perfect
        let missColor = Color(hex: 0xaf3128)
        VStack(spacing: 0) {
            Text(result.rating.title)
                .font(Typeface.mono(10)).tracking(em: 0.15, size: 10)
                .foregroundStyle(miss ? missColor : Palette.orange)
            Text(miss ? "BURNT" : "+\(result.points)")
                .font(Typeface.sans(40, .extraBold)).tracking(em: -0.06, size: 40)
                .foregroundStyle(miss ? missColor : Palette.ink)
                .padding(.vertical, 1)
            Text("+\(result.earnedXP) XP · \(miss ? "keep going" : "toast experience")")
                .font(Typeface.sans(12, .bold)).tracking(em: 0.01, size: 12)
                .foregroundStyle(miss ? Color(hex: 0x8a3a32) : Color(hex: 0xa06328))
                .padding(.top, 2)
            Text(miss ? (score > 0 ? "run score \(formatScore(score))" : "the toaster got you") : String(format: "%.2fs to spare", result.remaining))
                .font(Typeface.mono(9)).tracking(em: 0.08, size: 9)
                .foregroundStyle(Color(hex: 0x736a5b))
            if let skin = result.unlocked.last {
                Button { openSkin(skin) } label: {
                    Text("LEVEL \(skin.level) · \(skin.name) unlocked ↗")
                        .font(Typeface.sans(10, .extraBold))
                        .foregroundStyle(Color(hex: 0x766027))
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .frame(maxWidth: 235)
                        .background(Color(hex: 0xf0e3b7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(red: 131 / 255, green: 112 / 255, blue: 51 / 255, opacity: 0.2)))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 13).padding(.horizontal, -4).padding(.bottom, -4)
                .accessibilityIdentifier("resultUnlock")
            }
        }
        .padding(.vertical, 18).padding(.horizontal, 22)
        .frame(minWidth: 180)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(perfect ? Color(red: 1, green: 248 / 255, blue: 220 / 255, opacity: 0.94) : Color(red: 250 / 255, green: 245 / 255, blue: 234 / 255, opacity: 0.88))
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(perfect ? Color(red: 1, green: 174 / 255, blue: 32 / 255, opacity: 0.52) : Color(hex: 0x28251f, opacity: 0.12), lineWidth: 1))
        .background(RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(perfect ? Color(red: 1, green: 200 / 255, blue: 61 / 255, opacity: 0.12) : .clear).padding(-5))
        .shadow(color: perfect ? Color(red: 187 / 255, green: 101 / 255, blue: 14 / 255, opacity: 0.22) : Color(red: 72 / 255, green: 56 / 255, blue: 30 / 255, opacity: 0.16),
                radius: perfect ? 27 : 22, y: perfect ? 18 : 16)
        .overlay(alignment: .topTrailing) {
            if perfect {
                Text("✦").font(.system(size: 28)).foregroundStyle(Color(hex: 0xf5a900))
                    .offset(x: -15, y: -19)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if newBest {
                Text("NEW BEST")
                    .font(Typeface.mono(7)).tracking(em: 0.12, size: 7)
                    .foregroundStyle(Color(hex: 0xfff8e7))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Palette.ink, in: Capsule())
                    .rotationEffect(.degrees(2))
                    .offset(y: 9)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roundResult")
    }
}

struct StopButtonStyle: ButtonStyle {
    var urgent: Bool
    func makeBody(configuration: Configuration) -> some View {
        StopButtonBody(label: configuration.label, pressed: configuration.isPressed, urgent: urgent)
    }
}

/// The web's chunky orange key: a solid 9 pt "side" that compresses when pressed, pulsing near the pop.
private struct StopButtonBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    let urgent: Bool
    @State private var pulse = false

    var body: some View {
        let glowing = urgent && pulse && !pressed
        label
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.orange))
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0xc83e13)).offset(y: pressed ? 3 : 9))
            .offset(y: pressed ? 6 : 0)
            .shadow(color: glowing ? Color(red: 1, green: 65 / 255, blue: 20 / 255, opacity: 0.38) : Color(red: 115 / 255, green: 42 / 255, blue: 16 / 255, opacity: 0.2),
                    radius: glowing ? 21 : 15, y: 18)
            .scaleEffect(glowing ? 1.015 : 1)
            .offset(y: glowing ? -2 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(urgent ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: pulse)
            .onChange(of: urgent) { _, value in pulse = value }
            .onAppear { pulse = urgent }
    }
}

private struct ShakeEffect: ViewModifier {
    let trigger: Int
    let enabled: Bool
    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: enabled ? trigger : 0) { view, x in view.offset(x: x) } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-5, duration: 0.085)
                LinearKeyframe(5, duration: 0.085)
                LinearKeyframe(-2, duration: 0.085)
                LinearKeyframe(0, duration: 0.085)
            }
        }
    }
}

private struct FlameDance: ViewModifier {
    let active: Bool
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(45))
            .scaleEffect(active && on ? 1.3 : 1)
            .shadow(color: active ? Palette.orange.opacity(0.7) : .clear, radius: 5)
            .animation(active ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : .default, value: on)
            .onChange(of: active) { _, value in on = value }
            .onAppear { on = active }
    }
}

// MARK: - Physical control hit areas

private struct LeverHandle: View {
    @ObservedObject var store: GameStore
    let top: CGPoint
    let bottom: CGPoint
    @State private var dragging = false

    var body: some View {
        let progress = CGFloat(store.lever)
        let travel = max(20, bottom.y - top.y)
        Color.white.opacity(0.001)
            .frame(width: 60, height: 44)
            .contentShape(Capsule())
            .position(x: top.x + (bottom.x - top.x) * progress, y: top.y + travel * progress)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("stage"))
                .onChanged { value in
                    dragging = true
                    store.dragLever(Float(value.translation.height / travel))
                }
                .onEnded { value in
                    dragging = false
                    if abs(value.translation.height) < 6 && abs(value.translation.width) < 6 { store.start() } else { store.releaseLever() }
                })
            .accessibilityElement()
            .accessibilityLabel("Pull toaster lever down")
            .accessibilityHint("Starts toasting.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.start() }
            .accessibilityIdentifier("leverControl")
    }
}

private struct KnobControl: View {
    @ObservedObject var store: GameStore
    let size: CGFloat
    @State private var startIndex: Int?

    var body: some View {
        Color.white.opacity(0.001)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let all = Difficulty.allCases
                    if startIndex == nil { startIndex = all.firstIndex(of: store.game.difficulty) ?? 1 }
                    guard abs(value.translation.width) > 6, let startIndex else { return }
                    let index = min(all.count - 1, max(0, startIndex + Int((value.translation.width / 30).rounded())))
                    store.setDifficulty(all[index])
                }
                .onEnded { value in
                    if abs(value.translation.width) <= 6 { store.cycleDifficulty() }
                    startIndex = nil
                })
            .accessibilityElement()
            .accessibilityLabel("Difficulty knob")
            .accessibilityValue(store.game.difficulty.title.capitalized)
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if store.game.difficulty != Difficulty.allCases.last { store.cycleDifficulty(by: 1) }
                case .decrement: if store.game.difficulty != Difficulty.allCases.first { store.cycleDifficulty(by: -1) }
                @unknown default: break
                }
            }
            .accessibilityAction { store.cycleDifficulty() }
            .accessibilityIdentifier("knobControl")
    }
}

private struct FrontButton: View {
    @ObservedObject var store: GameStore
    let index: Int
    let height: CGFloat

    private var label: String {
        switch index {
        case 0: store.muted ? "Turn sound on" : "Mute sound"
        case 1: store.haptics ? "Turn haptics off" : "Turn haptics on"
        case 2: "Open settings"
        default: "Open local records"
        }
    }

    var body: some View {
        Button { store.pressControl(index) } label: {
            Ellipse()
                .fill(store.pressedControl == index ? Palette.orange.opacity(0.2) : Color.white.opacity(0.001))
                .frame(width: 44, height: height)
        }
        .buttonStyle(PressableStyle(scale: 0.88))
        .accessibilityLabel(label)
        .accessibilityIdentifier(["soundControl", "hapticsControl", "settingsControl", "recordsControl"][min(index, 3)])
    }
}

// MARK: - Loading

private struct LoadingScreen: View {
    let ready: Bool
    let error: String?
    @State private var bounce = false
    @State private var progress = 0.12

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 15) {
                ZStack(alignment: .top) {
                    ForEach([-1.0, 1.0], id: \.self) { side in
                        UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5)
                            .fill(Color(hex: 0xf0c46d))
                            .overlay(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5)
                                .strokeBorder(Color(hex: 0xb9662c), lineWidth: 3))
                            .frame(width: 13, height: 25)
                            .offset(x: side * 6.5, y: -9 + (bounce ? 6 : 0))
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(side > 0 ? 0.08 : 0), value: bounce)
                    }
                    UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 17)
                        .fill(Palette.paper)
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 17)
                            .strokeBorder(Palette.ink, lineWidth: 4))
                        .overlay(alignment: .top) { Capsule().fill(Palette.ink).frame(height: 4).padding(.horizontal, 17).padding(.top, 12) }
                        .overlay(alignment: .topTrailing) {
                            UnevenRoundedRectangle(bottomTrailingRadius: 6, topTrailingRadius: 6)
                                .strokeBorder(Palette.ink, lineWidth: 3)
                                .frame(width: 9, height: 19).offset(x: 6, y: 21)
                        }
                        .frame(width: 68, height: 54)
                }
                .frame(width: 68, height: 54)
                .background(alignment: .bottom) {
                    Ellipse().fill(Color(red: 70 / 255, green: 50 / 255, blue: 25 / 255, opacity: 0.16))
                        .frame(width: 52, height: 5).blur(radius: 3).offset(y: 8)
                }
                .offset(y: bounce ? 3 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bounce)
                Text(error == nil ? "BUTTERING UP" : "COULDN’T WARM UP")
                    .font(Typeface.mono(9)).tracking(em: 0.2, size: 9)
                Capsule().fill(Color(hex: 0x28251f, opacity: 0.12))
                    .frame(width: 112, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.orange).frame(width: 112 * progress, height: 3)
                    }
                if let error {
                    Text(error).font(Typeface.sans(12, .medium)).foregroundStyle(Color(hex: 0x665f53))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            }
            .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(error == nil ? "Buttering up" : "Couldn’t warm up")
        .onAppear {
            bounce = true
            withAnimation(.easeOut(duration: 1.6)) { progress = 0.7 }
        }
        .onChange(of: ready) { _, value in if value { withAnimation(.easeOut(duration: 0.22)) { progress = 1 } } }
        .onChange(of: error) { _, value in if value != nil { withAnimation(.easeOut(duration: 0.22)) { progress = 1 } } }
    }
}

extension Difficulty {
    /// One decimal, rounded half up like the web's `toFixed(1)` (Crispy reads 1.3).
    var multiplierText: String { String(format: "%.1f", (multiplier * 10).rounded() / 10) }
}
