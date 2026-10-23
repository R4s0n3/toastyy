import SwiftUI
import ToastyyCore

struct CollectionView: View {
    @ObservedObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A little bread. A big future.").font(.system(size: 29, design: .serif)).tracking(-0.7)
                        Text("Every slice earns XP. New levels unlock new toast.").font(.subheadline).foregroundStyle(Palette.secondary)
                        HStack {
                            Text("LEVEL \(store.game.progression.current.level)")
                            Spacer()
                            Text("\(store.game.progression.xp) XP")
                        }.font(.system(size: 11, design: .monospaced)).padding(.top, 8)
                        ProgressView(value: store.game.progression.fraction).tint(Palette.copper)
                        if let next = store.game.progression.next {
                            Text("\(next.xp - store.game.progression.xp) XP to \(next.name)").font(.caption).foregroundStyle(Palette.secondary)
                        } else { Text("The whole breakfast club is yours.").font(.caption) }
                    }
                    ForEach(ToastSkin.all) { skin in
                        let unlocked = skin.xp <= store.game.progression.xp
                        let equipped = skin.id == store.game.progression.equipped
                        HStack(spacing: 16) {
                            SkinSwatch(skin: skin).frame(width: 56, height: 64).opacity(unlocked ? 1 : 0.4)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(skin.finish).font(.system(size: 8, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.copper)
                                Text(skin.name).font(.system(size: 19, weight: .medium, design: .serif))
                                Text(skin.note).font(.caption).foregroundStyle(Palette.secondary)
                                if !unlocked {
                                    Label("Level \(skin.level) · \(skin.xp) XP", systemImage: "lock").font(.caption2)
                                }
                            }
                            Spacer(minLength: 0)
                            if unlocked {
                                Button { store.equip(skin) } label: {
                                    Image(systemName: equipped ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 23)).frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(equipped ? "\(skin.name), equipped" : "Equip \(skin.name)")
                            }
                        }
                        .padding(16).background(.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 18))
                    }
                }.padding(24)
            }
            .background(Palette.cream).foregroundStyle(Palette.ink)
            .navigationTitle("Toast collection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(Palette.copper)
    }
}

struct SkinSwatch: View {
    let skin: ToastSkin
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: 0xb97637)
                Image(uiImage: SkinPainter.image(for: skin))
                    .resizable().scaledToFill().padding(geometry.size.width * 0.09)
                    .clipShape(RoundedRectangle(cornerRadius: geometry.size.width * 0.18))
            }
            .clipShape(BreadShape())
        }.accessibilityHidden(true)
    }
}

struct BreadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.92), control: CGPoint(x: rect.width * 0.08, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.4))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: 0), control1: CGPoint(x: -rect.width * 0.2, y: 0), control2: CGPoint(x: rect.width * 0.2, y: 0))
        path.addCurve(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.4), control1: CGPoint(x: rect.width * 0.8, y: 0), control2: CGPoint(x: rect.width * 1.2, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.92))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.85, y: rect.height), control: CGPoint(x: rect.width * 0.92, y: rect.height))
        path.closeSubpath()
        return path
    }
}
