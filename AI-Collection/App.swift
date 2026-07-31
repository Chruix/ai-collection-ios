import SwiftUI
import AppIntents

@main
struct AI_CollectionApp: App {
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8777"
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var intentSection: String?
    @State private var intentSearchQuery: String?
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                WebViewContainer(
                    apiBaseURL: apiBaseURL,
                    intentSection: $intentSection,
                    intentSearchQuery: $intentSearchQuery,
                    showSettings: $showSettings
                )
                    .ignoresSafeArea()
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showSettings) {
                SettingsView(apiBaseURL: $apiBaseURL, isDarkMode: $isDarkMode)
            }
            .onAppear {
                consumePendingIntent()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    consumePendingIntent()
                }
            }
        }
    }

    private func consumePendingIntent() {
        guard let pending = AppIntentRouter.shared.pending else { return }
        AppIntentRouter.shared.pending = nil
        if let section = pending.section {
            intentSection = section.rawValue
        }
        if let query = pending.searchQuery {
            intentSearchQuery = query
        }
    }
}
