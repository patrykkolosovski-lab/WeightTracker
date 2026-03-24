import SwiftUI

struct HomeView: View {
    @ObservedObject var store: AppStore
    @State private var isBMISheetPresented = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BeFitCard {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text("CURRENT WEIGHT")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(BeFitTheme.textSecondary)
                            Text(store.currentWeightDisplay)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(BeFitTheme.textPrimary)
                        }

                        MetricPillButton(title: "BMI", value: store.bmiDisplay, accent: bmiAccent) {
                            isBMISheetPresented = true
                        }
                    }
                }

                HStack(spacing: 14) {
                    BeFitCard {
                        InlineStat(title: "Weekly Average", value: store.weeklyAverageDisplay)
                    }

                    BeFitCard {
                        InlineStat(title: "Daily Calories", value: store.dailyCaloriesDisplay, accent: BeFitTheme.warning)
                    }
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Progress", subtitle: store.progressSubtitle)
                        HorseshoeProgressView(progress: store.progressValue)

                        HStack {
                            InlineStat(title: "Current", value: store.currentWeightDisplay)
                            InlineStat(title: "Target", value: store.targetWeightDisplay, accent: BeFitTheme.success)
                        }
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
}
