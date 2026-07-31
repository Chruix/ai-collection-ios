import AppIntents
import SwiftUI

// MARK: - App Intent Router

/// Central handoff point for App Intents that open the app.
/// The main scene observes this to route incoming intents into the web view.
@Observable
final class AppIntentRouter {
    struct PendingIntent: Equatable {
        let id = UUID()
        let section: SectionIntentValue?
        let searchQuery: String?

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }

    static let shared = AppIntentRouter()
    var pending: PendingIntent?

    private init() {}
}

// MARK: - Section Enum

enum SectionIntentValue: String, AppEnum {
    case inbox
    case search
    case add
    case chat
    case settings

    static var typeDisplayName: LocalizedStringResource { "Section" }
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Section"

    static var caseDisplayRepresentations: [SectionIntentValue: DisplayRepresentation] {
        [
            .inbox: "Inbox",
            .search: "Search",
            .add: "Add Item",
            .chat: "AI Chat",
            .settings: "Settings",
        ]
    }
}

// MARK: - Open Section Intent

struct OpenSectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Section"
    static let description = IntentDescription("Open AI Collection to a specific section.")
    static let openAppWhenRun = true

    @Parameter(title: "Section")
    var section: SectionIntentValue

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.pending = .init(section: section, searchQuery: nil)
        }
        return .result()
    }
}

// MARK: - Search Collection Intent

struct SearchCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Collection"
    static let description = IntentDescription("Search your AI Collection directly.")
    static let openAppWhenRun = true

    @Parameter(
        title: "Query",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var query: String

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppIntentRouter.shared.pending = .init(section: .search, searchQuery: query)
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenSectionIntent(),
            phrases: [
                "Open \(.applicationName) to \(\.$section)",
                "Go to \(\.$section) in \(.applicationName)",
                "Show \(\.$section) in \(.applicationName)",
            ],
            shortTitle: "Open Section",
            systemImageName: "square.grid.2x2"
        )

        AppShortcut(
            intent: SearchCollectionIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find in \(.applicationName)",
            ],
            shortTitle: "Search Collection",
            systemImageName: "magnifyingglass"
        )
    }

    init() {}
}
