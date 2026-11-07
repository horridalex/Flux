import SwiftUI

// Flux's look: an aurora that flows behind the main screen while Flux shares, and opaque cards on
// it, so text keeps its contrast. Before iOS 18, which has no mesh gradient, the aurora is a plain
// gradient that doesn't move.

/// The brand's colours, from the app icon: cyan into blue into violet.
enum Brand {
    static let cyan = Color(red: 0.35, green: 0.90, blue: 1.00)
    static let blue = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let violet = Color(red: 0.60, green: 0.38, blue: 1.00)
    static let magenta = Color(red: 0.88, green: 0.43, blue: 0.90)

    /// For a symbol or a big number: the icon's sweep.
    static let flow = LinearGradient(colors: [cyan, blue, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Behind every screen. `flowing` moves it, while Flux shares, unless Reduce Motion is on.
/// `calm` veils it more, for a List, whose headers and footers sit on it with no glass between.
struct AuroraBackground: View {
    var flowing: Bool
    var calm = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A 3 by 3 grid, row by row. Dark enough at night and light enough by day for text on glass.
    private static let night: [Color] = [
        Color(red: 0.03, green: 0.05, blue: 0.16), Color(red: 0.05, green: 0.16, blue: 0.36), Color(red: 0.12, green: 0.07, blue: 0.30),
        Color(red: 0.04, green: 0.30, blue: 0.46), Color(red: 0.13, green: 0.17, blue: 0.52), Color(red: 0.34, green: 0.13, blue: 0.50),
        Color(red: 0.03, green: 0.10, blue: 0.24), Color(red: 0.24, green: 0.11, blue: 0.44), Color(red: 0.44, green: 0.14, blue: 0.44),
    ]
    private static let day: [Color] = [
        Color(red: 0.93, green: 0.96, blue: 1.00), Color(red: 0.82, green: 0.93, blue: 1.00), Color(red: 0.90, green: 0.88, blue: 1.00),
        Color(red: 0.78, green: 0.95, blue: 0.99), Color(red: 0.86, green: 0.88, blue: 1.00), Color(red: 0.93, green: 0.85, blue: 1.00),
        Color(red: 0.90, green: 0.95, blue: 1.00), Color(red: 0.91, green: 0.87, blue: 1.00), Color(red: 0.98, green: 0.88, blue: 0.96),
    ]

    private var palette: [Color] { scheme == .dark ? Self.night : Self.day }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                if flowing && !reduceMotion {
                    // 30 frames a second is plenty for something this slow, and only on screen.
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        mesh(at: context.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    mesh(at: 0)
                }
            } else {
                LinearGradient(colors: [palette[0], palette[4], palette[8]], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        // A veil of the system background, so secondary text on glass keeps its contrast where the
        // aurora is brightest. The accessibility audit's contrast test fails without it.
        .overlay(Color(uiColor: .systemBackground).opacity(calm ? 0.8 : (scheme == .dark ? 0.3 : 0.4)))
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// The grid's inner points drift on slow circles, so the colours flow into each other.
    @available(iOS 18.0, *)
    private func mesh(at time: Double) -> some View {
        let t = Float(time.truncatingRemainder(dividingBy: 10_000) / 5)
        let top = SIMD2<Float>(0.5 + 0.2 * sin(t), 0)
        let left = SIMD2<Float>(0, 0.5 + 0.15 * cos(t * 0.8))
        let middle = SIMD2<Float>(0.5 + 0.18 * sin(t * 1.3), 0.5 + 0.18 * cos(t))
        let right = SIMD2<Float>(1, 0.5 + 0.15 * sin(t * 0.9))
        let bottom = SIMD2<Float>(0.5 + 0.2 * cos(t * 0.7), 1)
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0), top, SIMD2(1, 0),
            left, middle, right,
            SIMD2(0, 1), bottom, SIMD2(1, 1),
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: palette)
    }
}

extension View {
    /// A tile on the aurora: an opaque card. `tint` colours it a little, for the status.
    func glassTile(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // An opaque card: glass let the aurora show through the text, and the accessibility
        // audit failed it, even in the primary colour. `tint` colours the card lightly, for
        // the status, and the rim keeps a little of the glass look.
        return self
            .background((tint ?? .clear).opacity(0.5), in: shape)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// A List keeps the system's grouped background: its headers and footers sit straight on it,
    /// with no card between, and on the aurora they failed the contrast audit. `flowing` stays for
    /// the callers, the aurora being the main screen's alone.
    func auroraList(flowing: Bool = false) -> some View {
        self
    }
}

/// A tile with a small title over what it holds, the bento grid's building block.
struct Tile<Content: View>: View {
    var title: LocalizedStringKey?
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.primary.opacity(0.8)) // .secondary is too faint on glass
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassTile(tint: tint)
    }
}
