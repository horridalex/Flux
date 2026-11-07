import SwiftUI

/// Light, dark, or the iPhone's own setting, chosen under Settings > Appearance. Kept in the
/// app's defaults, so it holds across launches.
enum Appearance: String, CaseIterable, Identifiable {
    case automatic, light, dark

    static let key = "appearance"

    var id: String { rawValue }

    /// Nil follows the iPhone.
    var scheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Settings > Appearance: the three choices, the current one ticked.
struct AppearanceView: View {
    @AppStorage(Appearance.key) private var appearance: Appearance = .automatic

    var body: some View {
        List {
            Section {
                ForEach(Appearance.allCases) { choice in
                    Button {
                        appearance = choice
                    } label: {
                        HStack {
                            Text(choice.title).foregroundStyle(Color.primary)
                            Spacer()
                            if appearance == choice {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Brand.accent)
                            }
                        }
                    }
                    .accessibilityAddTraits(appearance == choice ? .isSelected : [])
                    .accessibilityIdentifier("appearance.\(choice.rawValue)")
                }
            } footer: {
                Text("Automatic follows the iPhone's setting.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
