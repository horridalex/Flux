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
            .listRowBackground(Brand.card)
        }
        .pageList()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AutoStop {
    var title: LocalizedStringKey {
        switch self {
        case .five: "5 minutes"
        case .ten: "10 minutes"
        case .thirty: "30 minutes"
        case .never: "Never"
        }
    }
}

/// Settings > Auto-stop: how long Flux waits with no hotspot before it stops, see `AutoStop`.
struct AutoStopView: View {
    @AppStorage(AutoStop.key) private var autoStop: AutoStop = .ten

    var body: some View {
        List {
            Section {
                ForEach(AutoStop.allCases) { choice in
                    Button {
                        autoStop = choice
                    } label: {
                        HStack {
                            Text(choice.title).foregroundStyle(Color.primary)
                            Spacer()
                            if autoStop == choice {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Brand.accent)
                            }
                        }
                    }
                    .accessibilityAddTraits(autoStop == choice ? .isSelected : [])
                    .accessibilityIdentifier("autoStop.\(choice.rawValue)")
                }
            } footer: {
                Text(autoStop == .never ? "Never stopping uses more battery." : "With no hotspot for this long, Flux stops to save battery.")
            }
            .listRowBackground(Brand.card)
        }
        .pageList()
        .navigationTitle("Auto-stop")
        .navigationBarTitleDisplayMode(.inline)
    }
}
