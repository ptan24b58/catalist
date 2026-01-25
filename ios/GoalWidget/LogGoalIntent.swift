import AppIntents
import WidgetKit

struct LogGoalIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Goal Progress"
    static var description = IntentDescription("Log progress for a daily goal")
    
    @Parameter(title: "Goal ID")
    var goalId: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log progress for \(\.$goalId)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Write action to shared storage for Flutter app to process
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.catalist"
        ) else {
            throw IntentError.appGroupNotFound
        }
        
        let actionURL = appGroupURL.appendingPathComponent("widget_action.json")
        let actionData: [String: Any] = [
            "action": "log_progress",
            "goalId": goalId,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: actionData) {
            try? jsonData.write(to: actionURL)
        }
        
        // Request widget reload
        WidgetCenter.shared.reloadTimelines(ofKind: "Catalist")
        
        // Open app to process action
        if let appURL = URL(string: "catalist://log?goalId=\(goalId)") {
            await UIApplication.shared.open(appURL)
        }
        
        return .result()
    }
}

enum IntentError: Error {
    case appGroupNotFound
}
