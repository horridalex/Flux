import Charts
import SwiftUI

/// The last 30 days, this month, and the monthly limit, opened from the main screen's usage tile.
struct UsageView: View {
    @ObservedObject var model: Model
    @State private var limitOn = false
    @State private var limitGB = 50

    /// The kept days with today as it is now, oldest first.
    private var days: [Usage] {
        model.usageHistory.filter { $0.day != model.usageToday.day } + [model.usageToday]
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: Format.bytes(model.usageThisMonth.total))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                    if model.usageLimit.bytes > 0 {
                        ProgressView(value: min(1, Double(model.usageThisMonth.total) / Double(model.usageLimit.bytes)))
                            .tint(model.usageThisMonth.total >= model.usageLimit.bytes ? .orange : Brand.action)
                        Text("of \(Format.bytes(model.usageLimit.bytes)) this month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("usage.month")
            } header: {
                Text("This month")
            }
            .listRowBackground(Brand.card)

            Section {
                Chart(days, id: \.day) { day in
                    BarMark(x: .value("Day", Self.date(of: day.day), unit: .day),
                            y: .value("Data", Double(day.all.total) / 1_000_000_000))
                        .foregroundStyle(Brand.accent)
                        .cornerRadius(3)
                }
                .chartYAxisLabel("GB")
                .frame(height: 180)
                .padding(.vertical, 8)
                .accessibilityIdentifier("usage.chart")

                ForEach(days.reversed(), id: \.day) { day in
                    LabeledContent {
                        Text(verbatim: Format.bytes(day.all.total)).monospacedDigit()
                    } label: {
                        Text(Self.date(of: day.day), format: .dateTime.month().day().weekday())
                    }
                }
            } header: {
                Text("Last 30 days")
            }
            .listRowBackground(Brand.card)

            Section {
                Toggle("Monthly limit", isOn: $limitOn)
                    .accessibilityIdentifier("usage.limitOn")
                if limitOn {
                    Stepper(value: $limitGB, in: 1...2000, step: limitGB < 10 ? 1 : 5) {
                        Text("\(limitGB) GB")
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("usage.limitGB")
                }
            } footer: {
                Text("Flux sends a notification at 80 and at 100 percent of the limit, once each a month. It only counts what Flux shared, not what the iPhone used itself.")
            }
            .listRowBackground(Brand.card)
        }
        .pageList()
        .navigationTitle("Usage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            limitOn = model.usageLimit.bytes > 0
            if limitOn { limitGB = max(1, Int(model.usageLimit.bytes / 1_000_000_000)) }
        }
        .onChange(of: limitOn) { applyLimit() }
        .onChange(of: limitGB) { applyLimit() }
    }

    private func applyLimit() {
        let bytes = limitOn ? UInt64(limitGB) * 1_000_000_000 : 0
        if bytes != model.usageLimit.bytes { model.setUsageLimit(bytes: bytes) }
    }

    /// The day key, yyyy-MM-dd, as a date at its local midnight.
    static func date(of day: String) -> Date {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
    }
}
