import SwiftUI
import UIKit

// Flux's look: clean and calm, in the way of a good Korean finance app. A light grey page (black
// in dark mode), white cards (dark grey) with generous room, big bold numbers, bold plain titles,
// and one blue for what matters. Text keeps the system's colours, so its contrast holds.

/// The brand's colours. `accent` is the one blue of the screens; the icon's sweep stays for the
/// Live Activity and the widgets.
enum Brand {
    static let cyan = Color(red: 0.35, green: 0.90, blue: 1.00)
    static let blue = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let violet = Color(red: 0.60, green: 0.38, blue: 1.00)
    static let magenta = Color(red: 0.88, green: 0.43, blue: 0.90)

    /// For the widgets' symbol: the icon's sweep.
    static let flow = LinearGradient(colors: [cyan, blue, violet], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// The screens' blue: dark enough on white, and light enough on black, for 4.5:1 as text and
    /// for white text on it as a button.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.39, green: 0.62, blue: 1.00, alpha: 1)
            : UIColor(red: 0.11, green: 0.42, blue: 0.87, alpha: 1)
    })

    /// The page behind the cards, and the cards.
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

extension View {
    /// A white card (dark grey in dark mode) with rounded corners. `tint` washes it with a colour,
    /// for a warning.
    func card(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background((tint ?? .clear).opacity(0.12), in: shape)
            .background(Brand.card, in: shape)
    }
}

/// A card with a bold title over what it holds, the main screen's building block.
struct Tile<Content: View>: View {
    var title: LocalizedStringKey?
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(tint: tint)
    }
}
