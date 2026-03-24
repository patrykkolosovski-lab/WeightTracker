import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = AppStore()

    var body: some View {
        ZStack {
            BeFitBackground()

            switch store.destination {
            case .loading:
                ProgressView()
                    .tint(BeFitTheme.textPrimary)
            case .auth(let mode):
                AuthenticationView(store: store, mode: mode)
            case .metricsOnboarding:
                MetricsOnboardingView(store: store)
            case .main:
                MainShellView(store: store)
            }
        }
        .task {
            store.configureIfNeeded(modelContext: modelContext)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [AccountRecord.self, ProfileRecord.self, WeightEntryRecord.self], inMemory: true)
}
