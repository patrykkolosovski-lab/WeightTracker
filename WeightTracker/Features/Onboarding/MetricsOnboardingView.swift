import SwiftUI

struct MetricsOnboardingView: View {
    @ObservedObject var store: AppStore
    @State private var form = MetricsFormState.empty()
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Complete your profile")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(BeFitTheme.textPrimary)

                    Text("These numbers power your BMI, calorie target, and progress tracking.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BeFitTheme.textSecondary)
                }

                MetricsFormFields(form: $form)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.heart)
                }

                PrimaryButton(title: "Save Metrics") {
                    save()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
    }

    private func save() {
        do {
            try store.saveMetrics(form: form)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
