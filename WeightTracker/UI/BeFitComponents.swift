import SwiftUI

struct BeFitBackground: View {
    var body: some View {
        ZStack {
            BeFitTheme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(BeFitTheme.heart.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 12)
                .offset(x: 130, y: -320)

            Circle()
                .fill(BeFitTheme.success.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 10)
                .offset(x: -160, y: 320)
        }
    }
}

struct BeFitHeader: View {
    var body: some View {
        HStack {
            Spacer()
            Text("BeFit")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}

struct BeFitCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BeFitTheme.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BeFitTheme.textSecondary)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BeFitTheme.elevatedSurface, BeFitTheme.backgroundBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct InlineStat: View {
    let title: String
    let value: String
    var accent: Color = BeFitTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricPillButton: View {
    let title: String
    let value: String
    var accent: Color = BeFitTheme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(BeFitTheme.textSecondary)
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(BeFitTheme.elevatedSurface.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }
}

struct BeFitTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BeFitTheme.backgroundMiddle.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .foregroundStyle(BeFitTheme.textPrimary)
        }
    }
}

struct BeFitSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)

            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BeFitTheme.backgroundMiddle.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .foregroundStyle(BeFitTheme.textPrimary)
        }
    }
}

struct GlassSegmentedPicker<Selection: Hashable & Identifiable>: View where Selection: RawRepresentable, Selection.RawValue == String {
    let options: [Selection]
    @Binding var selection: Selection

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.rawValue.capitalized)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(selection == option ? BeFitTheme.textPrimary : BeFitTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection == option ? BeFitTheme.elevatedSurface : BeFitTheme.backgroundMiddle.opacity(0.9))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct UnitPickerCard: View {
    @Binding var unitSystem: UnitSystem

    var body: some View {
        BeFitCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle("Units")
                GlassSegmentedPicker(options: UnitSystem.allCases, selection: $unitSystem)
            }
        }
    }
}

struct BeFitTabBar: View {
    @Binding var selectedTab: AppTab
    let onAddTapped: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach([AppTab.home, .graph]) { tab in
                tabButton(tab)
            }

            Spacer(minLength: 64)

            ForEach([AppTab.metrics, .settings]) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(BeFitTheme.backgroundMiddle.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(BeFitTheme.textPrimary)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [BeFitTheme.heart, BeFitTheme.warning],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: BeFitTheme.heart.opacity(0.4), radius: 20, y: 10)
            }
            .offset(y: 5)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selectedTab == tab ? BeFitTheme.textPrimary : BeFitTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct HorseshoeProgressView: View {
    let progress: Double
    let centerValue: String
    let supportingText: String

    var body: some View {
        ZStack {
            HorseshoeShape()
                .stroke(BeFitTheme.elevatedSurface.opacity(0.45), style: StrokeStyle(lineWidth: 24, lineCap: .round))

            HorseshoeShape()
                .trim(from: 0, to: progress.clamped(to: 0...1))
                .stroke(BeFitTheme.success, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .shadow(color: BeFitTheme.success.opacity(0.45), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text(centerValue)
                    .font(.system(size: 68, weight: .heavy, design: .rounded))
                    .foregroundStyle(BeFitTheme.textPrimary)
                Text(supportingText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(BeFitTheme.textSecondary)
            }
            .offset(y: 20)
        }
        .frame(height: 190)
    }
}

struct HorseshoeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY * 0.8)
        let radius = min(rect.width * 0.36, rect.height * 0.68)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(150),
            endAngle: .degrees(390),
            clockwise: false
        )
        return path
    }
}

struct BMIScaleView: View {
    let bmiValue: Double?

    private let segments: [(String, ClosedRange<Double>, Color)] = [
        ("Low", 0...16, BeFitTheme.danger),
        ("Under", 16...18.5, BeFitTheme.warning),
        ("Healthy", 18.5...25, BeFitTheme.success),
        ("Over", 25...30, BeFitTheme.warning),
        ("High", 30...40, BeFitTheme.danger)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("BMI Scale")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)

            GeometryReader { proxy in
                let width = proxy.size.width
                let normalized = ((bmiValue ?? 0).clamped(to: 10...40) - 10) / 30

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            Rectangle()
                                .fill(segment.2)
                                .frame(height: 18)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.clear)
                            .frame(height: 26)

                        Circle()
                            .fill(BeFitTheme.textPrimary)
                            .frame(width: 22, height: 22)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                            .offset(x: max(0, min(width - 22, width * normalized - 11)))
                    }
                }
            }
            .frame(height: 52)

            if let bmiValue {
                Text("Your BMI is \(Formatters.compactDecimal.string(from: NSNumber(value: bmiValue)) ?? "--").")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BeFitTheme.textSecondary)
            }
        }
        .padding(24)
        .presentationDetents([.fraction(0.36)])
        .presentationBackground(BeFitTheme.backgroundMiddle)
    }
}

struct GoalDetailsView: View {
    let isTargetMode: Bool
    let goalTypeTitle: String
    let targetWeight: String
    let targetDateText: String
    let paceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isTargetMode ? "Target Goal" : "Generic Goal")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                if isTargetMode {
                    goalDetailRow(label: "Target Weight", value: targetWeight)
                    goalDetailRow(label: "End Date", value: targetDateText)
                    goalDetailRow(label: "Pace", value: paceText)
                } else {
                    goalDetailRow(label: "Direction", value: goalTypeTitle)
                    goalDetailRow(label: "Pace", value: paceText)
                }
            }
        }
        .padding(24)
        .presentationDetents([.fraction(0.32)])
        .presentationBackground(BeFitTheme.backgroundMiddle)
    }

    @ViewBuilder
    private func goalDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)
        }
    }
}

struct CaloriesInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calories")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)

            Text("This is how much you need to eat to reach your goals!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .presentationDetents([.fraction(0.22)])
        .presentationBackground(BeFitTheme.backgroundMiddle)
    }
}

struct WeeklyAverageSheetView: View {
    let rows: [WeeklyAverageRow]

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Past Week")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(BeFitTheme.textPrimary)

            VStack(spacing: 10) {
                ForEach(rows) { row in
                    HStack {
                        Text("\(dayFormatter.string(from: row.date)), \(dateFormatter.string(from: row.date))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textSecondary)
                        Spacer()
                        Text(row.value)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textPrimary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(24)
        .presentationDetents([.fraction(0.5)])
        .presentationBackground(BeFitTheme.backgroundMiddle)
    }
}

struct SettingsRow: View {
    let iconName: String
    let title: String
    let value: String?
    var accent: Color = BeFitTheme.textPrimary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .foregroundStyle(accent)
                .frame(width: 22)

            Text(title)
                .foregroundStyle(BeFitTheme.textPrimary)

            Spacer()

            if let value {
                Text(value)
                    .foregroundStyle(BeFitTheme.textSecondary)
            }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .padding(.vertical, 4)
    }
}
