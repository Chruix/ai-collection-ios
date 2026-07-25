import SwiftUI

@main
struct AI_CollectionApp: App {
    @AppStorage("apiBaseURL") private var apiBaseURL = "http://localhost:8777"
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                WebViewContainer(apiBaseURL: apiBaseURL, showSettings: $showSettings)
                    .ignoresSafeArea()
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showSettings) {
                SettingsView(apiBaseURL: $apiBaseURL, isDarkMode: $isDarkMode)
            }
        }
    }
}
