import SwiftUI

struct BodyMetricsView: View {
    @ObservedObject var store: AppStore
    @State private var form = MetricsFormState.empty()
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BeFitCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle("Live Overview", subtitle: "Updated from your current edits before saving.")

                        HStack {
                            InlineStat(title: "BMI", value: previewBMI)
                            InlineStat(title: "Calories", value: previewCalories, accent: BeFitTheme.warning)
                        }
                    }
                }

                MetricsFormFields(form: $form)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.heart)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PrimaryButton(title: "Update Metrics") {
                    save()
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .onAppear {
            form = store.metricsFormState()
        }
    }

    private var previewBMI: String {
        guard let input = form.makeInput(),
              let bmi = BMICalculator.value(weightKilograms: input.currentWeightKilograms, heightCentimeters: input.heightCentimeters) else {
            return "--"
        }
        return Formatters.compactDecimal.string(from: NSNumber(value: bmi)) ?? "--"
    }

    private var previewCalories: String {
        guard let input = form.makeInput(),
              let calories = CalorieCalculator.dailyTarget(
                age: input.age,
                heightCentimeters: input.heightCentimeters,
                weightKilograms: input.currentWeightKilograms,
                activityLevel: input.activityLevel,
                formulaSex: input.formulaSex,
                goalType: input.goalType
              ) else {
            return "--"
        }

        return "\(calories) kcal"
    }

    private func save() {
        do {
            try store.saveMetrics(form: form)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
