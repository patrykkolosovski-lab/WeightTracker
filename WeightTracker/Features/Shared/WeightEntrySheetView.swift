import SwiftUI

struct WeightEntrySheetView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var form = WeightEntryFormState.new(latestWeightKilograms: nil, unitSystem: .metric)
    @State private var errorMessage: String?

    private var isEditing: Bool {
        store.activeWeightEntryID != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Date")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.textSecondary)

                    DatePicker("Date", selection: $form.date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(BeFitTheme.heart)
                        .foregroundStyle(BeFitTheme.textPrimary)

                    BeFitTextField(
                        title: "Weight (\(form.unitSystem.weightUnit))",
                        placeholder: form.unitSystem == .metric ? "81.8" : "180.3",
                        text: $form.weightText,
                        keyboardType: .decimalPad
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BeFitTheme.textSecondary)

                        TextField("Optional notes", text: $form.notes, axis: .vertical)
                            .lineLimit(3...5)
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

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BeFitTheme.heart)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PrimaryButton(title: isEditing ? "Save Changes" : "Save Entry") {
                    save()
                }

                Spacer()
            }
            .padding(22)
            .navigationTitle(isEditing ? "Edit Weight" : "Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        store.dismissWeightEntrySheet()
                        dismiss()
                    }
                    .foregroundStyle(BeFitTheme.textPrimary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(BeFitTheme.backgroundMiddle)
        .toolbarBackground(BeFitTheme.backgroundMiddle, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            form = store.weightEntryFormState()
        }
    }

    private func save() {
        do {
            try store.saveWeightEntry(form: form)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
