import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                BeFitCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitle("Profile", subtitle: "Practical MVP settings only.")
                        SettingsRow(iconName: "person.crop.circle.fill", title: "Email", value: store.accountEmailDisplay)
                    }
                }

                BeFitCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle("Notifications", subtitle: "Weight reminders on your schedule.")
                        SettingsToggleRow(
                            iconName: "bell.badge.fill",
                            title: "Daily Weight Reminder",
                            subtitle: store.reminderPermissionDisplay,
                            isOn: Binding(
                                get: { store.isDailyReminderEnabled },
                                set: { store.setDailyReminderEnabled($0) }
                            )
                        )
                        SettingsActionRow(
                            iconName: "clock.fill",
                            title: "Reminder Time",
                            value: store.reminderTimeDisplay,
                            accent: BeFitTheme.warning
                        ) {
                            store.presentReminderTimeEditor()
                        }

                        if store.shouldShowNotificationRecovery {
                            Button {
                                store.openSystemSettings()
                            } label: {
                                Text("Open iPhone Settings")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(BeFitTheme.warning)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(BeFitTheme.backgroundMiddle.opacity(0.95))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(BeFitTheme.warning.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
    }
}
