import SwiftUI

struct HomeView: View {
    @ObservedObject var store: AppStore
    @State private var isBMISheetPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if store.isTargetMode {
                    HorseshoeProgressView(
                        progress: store.progressValue,
                        centerValue: store.currentWeightDisplay,
                        supportingText: store.heroSupportingText
                    )
                } else {
                    VStack(spacing: 6) {
                        Text(store.currentWeightDisplay)
                            .font(.system(size: 80, weight: .heavy, design: .rounded))
                            .foregroundStyle(BeFitTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(store.goalSummaryDisplay)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }

                HStack(spacing: 14) {
                    statButtonCard(title: "BMI", value: store.bmiDisplay, accent: bmiAccent) {
                        isBMISheetPresented = true
                    }
                    statCard(title: "Weekly Average", value: store.weeklyAverageDisplay)
                }

                HStack(spacing: 14) {
                    statCard(title: "Daily Calories", value: store.dailyCaloriesDisplay, accent: BeFitTheme.warning)
                    statCard(title: store.goalCardTitle, value: store.goalSummaryDisplay, accent: BeFitTheme.success)
                }

                if let targetModeWarning = store.targetModeWarning {
                    BeFitCard {
                        Text(targetModeWarning)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.warning)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $isBMISheetPresented) {
            BMIScaleView(bmiValue: store.bmiValue)
        }
    }

    private var bmiAccent: Color {
        guard let bmi = store.bmiValue else { return BeFitTheme.textPrimary }
        switch bmi {
        case ..<16:
            return BeFitTheme.danger
        case ..<18.5:
            return BeFitTheme.warning
        case ..<25:
            return BeFitTheme.success
        case ..<30:
            return BeFitTheme.warning
        default:
            return BeFitTheme.danger
        }
    }

    private func statCard(title: String, value: String, accent: Color = BeFitTheme.textPrimary) -> some View {
        BeFitCard {
            InlineStat(title: title, value: value, accent: accent)
        }
    }

    private func statButtonCard(title: String, value: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            statCard(title: title, value: value, accent: accent)
        }
        .buttonStyle(.plain)
    }
}
