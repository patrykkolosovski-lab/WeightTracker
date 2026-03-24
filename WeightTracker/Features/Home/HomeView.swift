import SwiftUI

struct HomeView: View {
    @ObservedObject var store: AppStore
    @State private var isBMISheetPresented = false
    @State private var isGoalSheetPresented = false
    @State private var isWeeklyAverageSheetPresented = false
    @State private var isCaloriesSheetPresented = false

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
                            .font(.system(size: 60, weight: .heavy, design: .rounded))
                            .foregroundStyle(BeFitTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .offset(y: 37)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        statButtonCard(title: "BMI", value: store.bmiDisplay, accent: bmiAccent) {
                            isBMISheetPresented = true
                        }
                        statButtonCard(title: "Weekly Average", value: store.weeklyAverageDisplay, accent: BeFitTheme.textPrimary) {
                            isWeeklyAverageSheetPresented = true
                        }
                    }

                    HStack(spacing: 14) {
                        statButtonCard(title: "Daily Calories", value: store.dailyCaloriesDisplay, accent: BeFitTheme.warning) {
                            isCaloriesSheetPresented = true
                        }
                        statButtonCard(title: store.goalCardTitle, value: store.goalButtonDisplay, accent: BeFitTheme.success) {
                            isGoalSheetPresented = true
                        }
                    }
                }
                .padding(.top, 26)

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
        .sheet(isPresented: $isGoalSheetPresented) {
            GoalDetailsView(
                isTargetMode: store.isTargetMode,
                goalTypeTitle: store.goalButtonDisplay,
                targetWeight: store.targetWeightDisplay,
                targetDateText: store.targetDateDisplay,
                paceText: store.goalSheetPaceDisplay,
                progressText: store.targetProgressDisplay
            )
        }
        .sheet(isPresented: $isWeeklyAverageSheetPresented) {
            WeeklyAverageSheetView(rows: store.weeklyAverageRows)
        }
        .sheet(isPresented: $isCaloriesSheetPresented) {
            CaloriesInfoView()
        }
        .onAppear {
            store.handleHomeAppeared()
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
