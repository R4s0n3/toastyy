import SwiftUI
import ToastyyCore

/// Design tokens copied from the web reference's `style.css`.
enum Palette {
    static let ink = Color(hex: 0x28251f)
    static let paper = Color(hex: 0xf2e9d8)
    static let orange = Color(hex: 0xff5b24)
    static let yellow = Color(hex: 0xffc83d)
    static let green = Color(hex: 0xa8c866)
    static let line = Color(hex: 0x28251f, opacity: 0.16)
    static let dialog = Color(hex: 0xf8f1e4)
    static let progressTrack = Color(hex: 0xe5dac5)
}

/// Manrope and DM Mono are bundled from the web client's Google Fonts selection.
/// CSS letter-spacing is in em, so `tracking(em:size:)` converts it to points.
enum Typeface {
    enum Weight { case medium, bold, extraBold }
    static func sans(_ size: CGFloat, _ weight: Weight = .bold) -> Font {
        switch weight {
        case .medium: .custom("ManropeExtraLight-Medium", fixedSize: size)
        case .bold: .custom("ManropeExtraLight-Bold", fixedSize: size)
        case .extraBold: .custom("ManropeExtraLight-ExtraBold", fixedSize: size)
        }
    }
    static func mono(_ size: CGFloat) -> Font { .custom("DMMono-Medium", fixedSize: size) }
}

extension View {
    func tracking(em: CGFloat, size: CGFloat) -> some View { tracking(em * size) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: opacity)
    }
}

func formatScore(_ value: Int) -> String { String(format: "%04d", max(0, value)) }
func twoDigits(_ value: Int) -> String { String(format: "%02d", value) }

/// The outlined toaster from the web header.
struct BrandMark: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 8)
            .strokeBorder(Palette.ink, lineWidth: 3)
            .overlay(alignment: .top) {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { _ in
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                            .fill(Palette.orange).frame(width: 4, height: 10)
                    }
                }.padding(.top, 7)
            }
            .overlay(alignment: .bottomTrailing) {
                UnevenRoundedRectangle(bottomTrailingRadius: 3, topTrailingRadius: 3)
                    .fill(Palette.ink).frame(width: 4, height: 5).offset(x: 3, y: -8)
            }
            .frame(width: 27, height: 24)
            .accessibilityHidden(true)
    }
}

/// A `<progress>` bar as styled by the web client.
struct ToastProgress: View {
    var value: Double
    var height: CGFloat = 3
    var tint = Color(hex: 0xb98e50)
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.progressTrack)
                Capsule().fill(tint).frame(width: geometry.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded())) percent")
    }
}

/// The fixed paper grain the web app multiplies over the whole page.
struct GrainOverlay: View {
    private static let tile: UIImage = {
        let size = 180
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        var seed: UInt32 = 0x9e37_79b9
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { renderer in
            for y in 0..<size {
                for x in 0..<size {
                    seed = seed &* 1_664_525 &+ 1_013_904_223
                    let value = CGFloat(seed >> 8) / CGFloat(1 << 24)
                    renderer.cgContext.setFillColor(UIColor(white: value, alpha: 0.32).cgColor)
                    renderer.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .blendMode(.multiply)
            .opacity(0.13)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Matches the web's centered `<dialog>` card and blurred backdrop.
struct DialogCard<Content: View>: View {
    var width: CGFloat
    var padding: CGFloat = 30
    var radius: CGFloat = 26
    var border = Color(hex: 0x28251f, opacity: 0.15)
    var closeLabel = "Close"
    var closeIdentifier = "dialogClose"
    var onClose: () -> Void
    @ViewBuilder var content: Content

    private var inner: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
    }

    var body: some View {
        // Grow to fit, then scroll once the dialog reaches the screen's height (`max-height` on web).
        ViewThatFits(in: .vertical) {
            inner
            ScrollView(showsIndicators: false) { inner }
        }
        .frame(width: width)
        .background(Palette.dialog, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(border, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Text("×").font(.system(size: 28, weight: .regular)).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(closeLabel)
            .accessibilityIdentifier(closeIdentifier)
            .padding(.top, 14).padding(.trailing, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: Color(red: 45 / 255, green: 35 / 255, blue: 18 / 255, opacity: 0.35), radius: 50, y: 35)
        .foregroundStyle(Palette.ink)
        .accessibilityAddTraits(.isModal)
    }
}

struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.sans(12, .extraBold)).tracking(em: 0.1, size: 12)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(14)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Port of the web `skinThumbnail()` canvas: a tilted, shadowed slice in its finish.
struct SkinThumbnail: View {
    let skin: ToastSkin
    var body: some View {
        Image(uiImage: SkinPainter.thumbnail(for: skin))
            .resizable().scaledToFit()
            .accessibilityHidden(true)
    }
}
