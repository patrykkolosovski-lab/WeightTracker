import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var selectedUnitSystem: UnitSystem = .metric

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BeFitCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Profile", subtitle: "Practical MVP settings only.")
                        SettingsRow(iconName: "person.crop.circle.fill", title: "Email", value: store.account?.email ?? "--")
                        SettingsRow(iconName: "target", title: "Goal", value: store.profile?.goalType.title ?? "--", accent: BeFitTheme.success)
                    }
                }

                UnitPickerCard(unitSystem: $selectedUnitSystem)
                    .onChange(of: selectedUnitSystem) { _, newValue in
                        store.updatePreferredUnitSystem(newValue)
                    }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("About & Privacy")
                        SettingsRow(iconName: "questionmark.circle", title: "Help", value: "MVP placeholder")
                        SettingsRow(iconName: "info.circle", title: "About BeFit", value: "Weight tracking MVP")
                        SettingsRow(iconName: "lock.shield", title: "Privacy", value: "Placeholder")
                    }
                }

                Button {
                    store.logout()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(BeFitTheme.heart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BeFitTheme.surface.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(BeFitTheme.heart.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .onAppear {
            selectedUnitSystem = store.unitSystem
        }
    }
}
