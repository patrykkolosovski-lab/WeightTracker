import SwiftUI

struct MetricsFormFields: View {
    @Binding var form: MetricsFormState

    var body: some View {
        VStack(spacing: 18) {
            UnitPickerCard(unitSystem: $form.unitSystem)

            BeFitCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle("Body Metrics", subtitle: "Required for BMI and calorie targets.")

                    BeFitTextField(title: "Age", placeholder: "29", text: $form.ageText, keyboardType: .numberPad)
                    BeFitTextField(title: "Height (\(form.unitSystem.heightUnit))", placeholder: form.unitSystem == .metric ? "178" : "70", text: $form.heightText, keyboardType: .decimalPad)
                    BeFitTextField(title: "Current Weight (\(form.unitSystem.weightUnit))", placeholder: form.unitSystem == .metric ? "82.4" : "181.7", text: $form.currentWeightText, keyboardType: .decimalPad)
                    pickerRow(
                        title: "Activity Level",
                        selection: $form.activityLevel,
                        options: ActivityLevel.allCases,
                        titleProvider: \.title
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Calorie Formula Profile")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textSecondary)
                        GlassSegmentedPicker(options: FormulaSex.allCases, selection: $form.formulaSex)
                    }
                }
            }

            BeFitCard {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle("Goal", subtitle: "Choose a specific target or a flexible direction.")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mode")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textSecondary)
                        GlassSegmentedPicker(options: GoalMode.allCases, selection: $form.goalMode)
                    }

                    if form.goalMode == .target {
                        BeFitTextField(title: "Target Weight (\(form.unitSystem.weightUnit))", placeholder: form.unitSystem == .metric ? "75.0" : "165.3", text: $form.targetWeightText, keyboardType: .decimalPad)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Date")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BeFitTheme.textSecondary)

                            DatePicker("", selection: $form.targetDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.graphical)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(BeFitTheme.backgroundMiddle.opacity(0.95))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                                .colorScheme(.dark)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Goal")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BeFitTheme.textSecondary)
                            GlassSegmentedPicker(options: GoalType.allCases, selection: $form.genericGoalType)
                        }

                        if form.genericGoalType != .maintenance {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Weekly Pace")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BeFitTheme.textSecondary)
                                GlassSegmentedPicker(options: WeeklyPaceOption.allCases, selection: $form.weeklyPaceOption)
                            }
                        }

                        BeFitTextField(title: "Target Weight (\(form.unitSystem.weightUnit))", placeholder: "Optional", text: $form.targetWeightText, keyboardType: .decimalPad)
                    }
                }
            }
        }
        .onChange(of: form.unitSystem) { oldValue, newValue in
            form.convertDisplayedValues(from: oldValue, to: newValue)
        }
    }
}

private extension MetricsFormFields {
    func pickerRow<Option: Hashable & Identifiable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        titleProvider: KeyPath<Option, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(BeFitTheme.textSecondary)

            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option[keyPath: titleProvider]).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(BeFitTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        }
    }
}
