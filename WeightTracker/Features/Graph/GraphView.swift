import Charts
import SwiftUI

struct GraphView: View {
    @ObservedObject var store: AppStore
    @State private var selectedTimeframe: GraphTimeframe = .month

    private var filteredEntries: [WeightEntryRecord] {
        store.entries(for: selectedTimeframe)
    }

    private var chartEntries: [(entry: WeightEntryRecord, displayWeight: Double)] {
        filteredEntries.map { entry in
            (entry, UnitConverter.weightToDisplay(entry.weightKilograms, unitSystem: store.unitSystem))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BeFitCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Weight Trend", subtitle: "Filter your progress over time.")

                        timeframeSelector

                        if filteredEntries.isEmpty {
                            Text("No entries yet. Use the + button to add your first weigh-in.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(BeFitTheme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 220)
                                .multilineTextAlignment(.center)
                        } else {
                            Chart {
                                ForEach(chartEntries, id: \.entry.id) { item in
                                    AreaMark(
                                        x: .value("Date", item.entry.date),
                                        y: .value("Weight", item.displayWeight)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [BeFitTheme.success.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                    LineMark(
                                        x: .value("Date", item.entry.date),
                                        y: .value("Weight", item.displayWeight)
                                    )
                                    .lineStyle(.init(lineWidth: 3, lineCap: .round))
                                    .foregroundStyle(BeFitTheme.success)

                                    PointMark(
                                        x: .value("Date", item.entry.date),
                                        y: .value("Weight", item.displayWeight)
                                    )
                                    .foregroundStyle(BeFitTheme.textPrimary)
                                }

                            }
                            .frame(height: 220)
                            .chartPlotStyle { plotArea in
                                plotArea
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .chartXAxis {
                                AxisMarks(position: .bottom) { value in
                                    AxisValueLabel {
                                        if let dateValue = value.as(Date.self) {
                                            Text(Formatters.dayMonth.string(from: dateValue))
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .chartYScale(domain: yDomain)
                            .chartYAxisLabel(position: .leading) {
                                Text(store.unitSystem.weightUnit.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(BeFitTheme.textSecondary)
                            }
                            .chartXScale(domain: xDomain)
                        }
                    }
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Recent Entries", subtitle: "Tap an entry to edit it.")

                        if store.entries.isEmpty {
                            Text("Your saved weigh-ins will appear here.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(BeFitTheme.textSecondary)
                        } else {
                            ForEach(store.entries.reversed()) { entry in
                                Button {
                                    store.presentWeightEntrySheet(for: entry.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(Formatters.date.string(from: entry.date))
                                                .foregroundStyle(BeFitTheme.textPrimary)
                                            Text(entry.notes.isEmpty ? "No notes" : entry.notes)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(BeFitTheme.textSecondary)
                                        }

                                        Spacer()

                                        Text(weightLabel(for: entry.weightKilograms))
                                            .foregroundStyle(BeFitTheme.success)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if entry.id != store.entries.first?.id {
                                    Divider()
                                        .background(BeFitTheme.divider)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
    }

    private var xDomain: ClosedRange<Date> {
        let start = filteredEntries.first?.date ?? Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let end = filteredEntries.last?.date ?? .now
        return start...max(end, .now)
    }

    private var yDomain: ClosedRange<Double> {
        let weights = chartEntries.map(\.displayWeight)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...100
        }

        let lowerBound = max(0, floor(minWeight - 5))
        let upperBound = ceil(maxWeight + 5)
        return lowerBound...max(upperBound, lowerBound + 1)
    }

    private var timeframeSelector: some View {
        HStack(spacing: 8) {
            ForEach(GraphTimeframe.allCases) { timeframe in
                Button {
                    selectedTimeframe = timeframe
                } label: {
                    Text(timeframe.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTimeframe == timeframe ? BeFitTheme.textPrimary : BeFitTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedTimeframe == timeframe ? BeFitTheme.elevatedSurface : BeFitTheme.backgroundMiddle.opacity(0.95))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weightLabel(for kilograms: Double) -> String {
        let value = UnitConverter.weightToDisplay(kilograms, unitSystem: store.unitSystem)
        let text = Formatters.weightDisplay.string(from: NSNumber(value: value)) ?? "--"
        return "\(text) \(store.unitSystem.weightUnit)"
    }
}
