import SwiftUI
import ToastyyCore

/// The web's "Toast, evolved." dialog, in its phone layout.
struct CollectionDialog: View {
    @ObservedObject var store: GameStore
    let width: CGFloat
    @State private var tilt = CGSize.zero
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    private var progression: Progression { store.game.progression }
    private var selected: ToastSkin { ToastSkin.all.first { $0.id == store.collectionFocus } ?? progression.skin }

    var body: some View {
        DialogCard(width: width, padding: 21, radius: 21, border: Color(hex: 0xd8cdb8),
                   closeLabel: "Close toast collection", closeIdentifier: "collectionClose", onClose: { store.dialog = nil }) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SMALL SLICE. BIG POTENTIAL.")
                    .font(Typeface.mono(8)).tracking(em: 0.18, size: 8)
                    .foregroundStyle(Color(hex: 0x766d5d))
                Text("Toast, evolved.")
                    .font(Typeface.sans(30, .bold)).tracking(em: -0.06, size: 30)
                    .padding(.top, 5).padding(.bottom, 5).padding(.trailing, 32)
                    .accessibilityAddTraits(.isHeader)
                Text("From humble bread to a little work of art.")
                    .font(Typeface.sans(11, .medium)).foregroundStyle(Color(hex: 0x8b7b65))
                levelRow.padding(.vertical, 18)
                detail
                grid.padding(.top, 21)
                Text("Every slice earns XP. Perfect timing earns more. New levels equip your new toast automatically.")
                    .font(Typeface.sans(9, .medium)).lineSpacing(4)
                    .foregroundStyle(Color(hex: 0x8b7b64))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xe4d9c6)).frame(height: 1) }
                    .padding(.top, 18)
            }
        }
    }

    private var levelRow: some View {
        let next = progression.next
        return HStack(spacing: 8) {
            Text("LEVEL \(twoDigits(progression.current.level))")
            ToastProgress(value: progression.fraction, height: 4)
            Text(next.map { "\(progression.xp.formatted()) XP / \($0.xp.formatted()) XP" } ?? "\(progression.xp.formatted()) XP · COLLECTION COMPLETE")
        }
        .font(Typeface.mono(7)).tracking(em: 0.06, size: 7)
        .foregroundStyle(Color(hex: 0x8b7351))
        .lineLimit(1).fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xe4d9c6)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xe4d9c6)).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private var detail: some View {
        let skin = selected
        let unlocked = skin.xp <= progression.xp
        let equipped = skin.id == progression.skin.id
        let tint = Color(hex: skin.color)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                preview(skin)
                VStack(alignment: .leading, spacing: 0) {
                    Text("LV. \(twoDigits(skin.level)) / \(skin.finish)")
                        .font(Typeface.mono(6)).tracking(em: 0.08, size: 6)
                        .foregroundStyle(tint).padding(.top, 3)
                    Text(skin.name)
                        .font(Typeface.sans(24, .bold)).tracking(em: -0.05, size: 24)
                        .padding(.vertical, 6)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(skin.note)
                        .font(Typeface.sans(10, .medium)).lineSpacing(6)
                        .foregroundStyle(Color(hex: 0x82745f))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(unlocked ? (skin.id == "dry" ? "Your first slice. Everybody starts here." : "Level \(skin.level) reached. Yours to keep.")
                         : "Reach level \(skin.level) · \(skin.xp.formatted()) total XP")
                        .font(Typeface.sans(9, .bold)).lineSpacing(4)
                        .padding(.vertical, 7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ToastProgress(value: unlocked ? 1 : Double(progression.xp) / Double(max(1, skin.xp)), tint: tint)
                Text(unlocked ? "UNLOCKED" : "\(skin.xp - progression.xp) XP TO GO")
                    .font(Typeface.mono(7)).foregroundStyle(Color(hex: 0x8b7d69))
                    .fixedSize()
            }
            .padding(.top, 13)
            Button {
                store.equip(skin)
                store.dialog = nil
            } label: {
                Text(equipped ? "YOUR CURRENT TOAST" : unlocked ? "MAKE THIS MY TOAST" : "UNLOCKS AT LEVEL \(skin.level)")
                    .font(Typeface.mono(8)).tracking(em: 0.06, size: 8)
                    .foregroundStyle(unlocked && !equipped ? Color(hex: 0xfff9ed) : Color(hex: 0x8c7e66))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(unlocked && !equipped ? Color(hex: 0x3c392e) : Color(hex: 0xe9dfcc), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .disabled(!unlocked || equipped)
            .padding(.top, 12)
            .accessibilityIdentifier("equipButton")
        }
    }

    /// Stands in for the web's draggable 3D preview: the slice tilts toward your finger.
    private func preview(_ skin: ToastSkin) -> some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0xfffcf3), Color(hex: 0xe9deca)], center: UnitPoint(x: 0.4, y: 0.38), startRadius: 0, endRadius: 120)
            SkinThumbnail(skin: skin)
                .padding(12)
                .rotation3DEffect(.radians(Double(tilt.width) * 0.65), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .rotation3DEffect(.radians(Double(-tilt.height) * 0.22), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .shadow(color: Color(red: 0.3, green: 0.22, blue: 0.1, opacity: 0.17), radius: 6, x: 4 - tilt.width * 6, y: 6)
        }
        .frame(width: 115, height: 154)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !reducedMotion else { return }
                tilt = CGSize(width: min(0.5, max(-0.5, value.location.x / 115 - 0.5)), height: min(0.5, max(-0.5, value.location.y / 154 - 0.5)))
            }
            .onEnded { _ in withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { tilt = .zero } })
        .accessibilityElement()
        .accessibilityLabel("Preview of \(skin.name) toast")
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(ToastSkin.all) { skin in
                let unlocked = skin.xp <= progression.xp
                let isSelected = skin.id == selected.id
                Button {
                    store.collectionFocus = skin.id
                    tilt = .zero
                } label: {
                    VStack(spacing: 0) {
                        SkinThumbnail(skin: skin)
                            .frame(width: 49, height: 55)
                            .saturation(unlocked || isSelected ? 1 : 0.55)
                            .opacity(unlocked || isSelected ? 1 : 0.74)
                        Text(skin.name)
                            .font(Typeface.sans(8, .extraBold)).tracking(em: -0.02, size: 8)
                            .multilineTextAlignment(.center).lineSpacing(1)
                            .frame(minHeight: 20)
                        Text(skin.id == progression.skin.id ? "EQUIPPED" : unlocked ? skin.finish : "\(skin.xp.formatted()) XP")
                            .font(Typeface.mono(5)).tracking(em: 0.05, size: 5)
                            .foregroundStyle(Color(hex: 0x948268))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.top, 4)
                    }
                    .padding(.top, 17).padding(.bottom, 9).padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
                    .background(isSelected ? Color(hex: 0xfffaf0) : Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(isSelected ? Color(hex: skin.color) : Color(hex: 0xe2d7c3), lineWidth: 1))
                    .shadow(color: isSelected ? Color(hex: 0x66502e, opacity: 0.035) : .clear, radius: 6, y: 3)
                    .overlay(alignment: .topLeading) {
                        Text("LV. \(twoDigits(skin.level))")
                            .font(Typeface.mono(5)).tracking(em: 0.04, size: 5)
                            .foregroundStyle(Color(hex: 0x9a876b))
                            .padding(.top, 8).padding(.leading, 6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if !unlocked {
                            Image(systemName: "lock")
                                .font(.system(size: 6, weight: .medium))
                                .foregroundStyle(Color(hex: 0xa39172))
                                .padding(.top, 6).padding(.trailing, 5)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(Palette.ink)
                .accessibilityLabel("\(skin.name), level \(skin.level). \(unlocked ? "Unlocked" : "\(skin.xp) XP required")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
