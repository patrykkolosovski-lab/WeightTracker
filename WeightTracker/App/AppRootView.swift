import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()

    var body: some View {
        ZStack {
            BeFitBackground()

            switch store.destination {
            case .loading:
                ProgressView()
                    .tint(BeFitTheme.textPrimary)
            case .metricsOnboarding:
                MetricsOnboardingView(store: store)
            case .main:
                MainShellView(store: store)
            }
        }
        .task {
            await store.configureIfNeeded(modelContext: modelContext)
        }
        .sheet(isPresented: $store.isICloudInfoPresented) {
            ICloudInfoSheet {
                store.dismissICloudInfo()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            store.handleScenePhaseChange(newValue)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [AccountRecord.self, LocalAccountStateRecord.self, ProfileRecord.self, WeightEntryRecord.self], inMemory: true)
}
