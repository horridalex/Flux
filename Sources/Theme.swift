import SwiftUI
import UIKit

// Flux's look, in the way of a good Korean finance app: a calm page, rounded cards with room, plain
// sentences with the number that matters in blue, rows led by an icon tile, and two kinds of button:
// solid blue to do something, tinted to look at something. Every colour here keeps 4.5:1 for its
// text, in light and in dark.

private func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    Color(uiColor: UIColor { traits in
        let c = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

/// The brand's colours.
enum Brand {
    static let cyan = Color(red: 0.35, green: 0.90, blue: 1.00)
    static let blue = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let violet = Color(red: 0.60, green: 0.38, blue: 1.00)
    static let magenta = Color(red: 0.88, green: 0.43, blue: 0.90)
    static let flow = LinearGradient(colors: [cyan, blue, violet], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Blue text and symbols: dark enough on white, light enough on the dark cards.
    static let accent = dynamic(light: (0.08, 0.36, 0.80), dark: (0.58, 0.76, 1.00))
    /// A solid button's blue, with white text on it in both modes.
    static let action = dynamic(light: (0.11, 0.42, 0.87), dark: (0.18, 0.43, 0.90))
    /// A tinted button's ground, under `accent` text.
    static let actionTint = dynamic(light: (0.91, 0.95, 1.00), dark: (0.13, 0.17, 0.25))

    /// The page, the cards on it, and the tiles inside a card (icon tiles, the speed boxes).
    static let page = dynamic(light: (0.95, 0.96, 0.97), dark: (0.09, 0.09, 0.11))
    static let card = dynamic(light: (1.00, 1.00, 1.00), dark: (0.13, 0.13, 0.15))
    static let tile = dynamic(light: (0.95, 0.96, 0.97), dark: (0.17, 0.17, 0.20))
    /// Grey text under a title, on a card.
    static let subtext = dynamic(light: (0.36, 0.40, 0.45), dark: (0.62, 0.65, 0.69))
}

extension View {
    /// A card on the page, with rounded corners. `tint` washes it with a colour, for a warning.
    func card(cornerRadius: CGFloat = 26, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background((tint ?? .clear).opacity(0.12), in: shape)
            .background(Brand.card, in: shape)
    }
}

extension View {
    /// A pushed screen's List, on the same page and cards as the main screen.
    func pageList() -> some View {
        scrollContentBackground(.hidden).background(Brand.page)
    }
}

/// Solid blue, white text: a button that does something (share, apply).
struct ActionButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .lineLimit(1)
            .fixedSize(horizontal: !fullWidth, vertical: false)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .foregroundStyle(Color.white)
            .background(Brand.action, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Tinted, blue text: a button that shows something (the history, a QR code).
struct ViewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(Brand.accent)
            .background(Brand.actionTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// A rounded square holding a symbol, at the start of a row.
struct IconTile: View {
    let systemName: String
    var color: Color = .primary
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Brand.tile, in: RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A card with a bold title (and a grey line under it) over what it holds.
struct Tile<Content: View>: View {
    var title: LocalizedStringKey?
    var subtitle: LocalizedStringKey?
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.title3.weight(.heavy))
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Brand.subtext)
                            .lineLimit(1) // a grey line under a title never takes two
                    }
                }
            }
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(tint: tint)
    }
}

/// The second button of a confirmation sheet: grey, to back out.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color.primary)
            .background(Brand.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Solid red, white text: a button that removes or resets something for good.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color.white)
            .background(Brand.danger, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension Brand {
    /// A destructive button's red, with white text on it in both modes.
    static let danger = Color(red: 0.78, green: 0.22, blue: 0.27)
}

/// Asks before something that can't be undone, from the bottom of the screen: a question, what it
/// means, and Cancel beside the red button that does it.
struct ConfirmSheet: View {
    let title: Text
    let message: Text
    let confirm: LocalizedStringKey
    var confirmID = "confirm.do"
    let action: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            title
                .font(.title3.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            message
                .font(.body)
                .foregroundStyle(Brand.subtext)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("confirm.cancel")
                Button(confirm) {
                    dismiss()
                    action()
                }
                .buttonStyle(DestructiveButtonStyle())
                .accessibilityIdentifier(confirmID)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .presentationDetents([.height(300), .medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Brand.card)
    }
}

/// Numbered steps, one line each: a small numbered circle, then the step.
struct Steps: View {
    let steps: [LocalizedStringKey]
    /// An identifier for the first step, for the UI tests.
    var firstID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 10) {
                    Text(verbatim: "\(index + 1)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Brand.accent)
                        .frame(width: 24, height: 24)
                        .background(Brand.actionTint, in: Circle())
                        .accessibilityHidden(true)
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(Brand.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier(index == 0 ? (firstID ?? "") : "")
                }
            }
        }
    }
}
