import WidgetKit
import SwiftUI

struct GoalWidget: Widget {
    let kind: String = "GoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoalTimelineProvider()) { entry in
            GoalWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Goal Tracker")
        .description("Track your daily and long-term goals with a reactive cat mascot")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GoalTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(
            date: Date(),
            topGoal: TopGoal(
                id: "placeholder",
                title: "Learn Spanish",
                progress: 0.6,
                goalType: "longTerm",
                progressType: "percentage",
                nextDueEpoch: Int(Date().timeIntervalSince1970) + 86400 * 30,
                urgency: 0.3,
                progressLabel: "60%"
            ),
            mascot: MascotState(emotion: "neutral", frameIndex: 0)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> ()) {
        let entry = loadSnapshot()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> ()) {
        let entry = loadSnapshot()
        
        // Refresh at key times: morning (8 AM), midday (12 PM), evening (6 PM), midnight
        let calendar = Calendar.current
        let now = Date()
        var refreshDates: [Date] = []
        
        let times = [8, 12, 18, 0] // Hours
        for hour in times {
            var date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            if date <= now {
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            }
            refreshDates.append(date)
        }
        
        let nextRefresh = refreshDates.min() ?? calendar.date(byAdding: .hour, value: 1, to: now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
    
    private func loadSnapshot() -> GoalEntry {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.goalwidget") else {
            return GoalEntry(date: Date(), topGoal: nil, mascot: MascotState(emotion: "neutral", frameIndex: 0))
        }
        
        let snapshotURL = appGroupURL.appendingPathComponent("widget_snapshot.json")
        
        guard let data = try? Data(contentsOf: snapshotURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return GoalEntry(date: Date(), topGoal: nil, mascot: MascotState(emotion: "neutral", frameIndex: 0))
        }
        
        let topGoal: TopGoal?
        if let goalDict = json["topGoal"] as? [String: Any] {
            topGoal = TopGoal(
                id: goalDict["id"] as? String ?? "",
                title: goalDict["title"] as? String ?? "",
                progress: (goalDict["progress"] as? NSNumber)?.doubleValue ?? 0.0,
                goalType: goalDict["goalType"] as? String ?? "daily",
                progressType: goalDict["progressType"] as? String ?? "completion",
                nextDueEpoch: (goalDict["nextDueEpoch"] as? NSNumber)?.intValue,
                urgency: (goalDict["urgency"] as? NSNumber)?.doubleValue ?? 0.0,
                progressLabel: goalDict["progressLabel"] as? String
            )
        } else {
            topGoal = nil
        }
        
        let mascotDict = json["mascot"] as? [String: Any] ?? [:]
        let mascot = MascotState(
            emotion: mascotDict["emotion"] as? String ?? "neutral",
            frameIndex: (mascotDict["frameIndex"] as? NSNumber)?.intValue ?? 0
        )
        
        return GoalEntry(date: Date(), topGoal: topGoal, mascot: mascot)
    }
}

struct GoalEntry: TimelineEntry {
    let date: Date
    let topGoal: TopGoal?
    let mascot: MascotState
}

struct TopGoal {
    let id: String
    let title: String
    let progress: Double       // 0-1 normalized progress
    let goalType: String       // "daily" or "longTerm"
    let progressType: String   // "completion", "percentage", "milestones", "numeric"
    let nextDueEpoch: Int?
    let urgency: Double
    let progressLabel: String? // Human-readable progress text
    
    var isDaily: Bool { goalType == "daily" }
    var isLongTerm: Bool { goalType == "longTerm" }
}

struct MascotState {
    let emotion: String
    let frameIndex: Int
}

struct GoalWidgetEntryView: View {
    var entry: GoalTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: GoalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let goal = entry.topGoal {
                HStack {
                    Text(goal.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    GoalTypeBadge(isDaily: goal.isDaily)
                }
                
                ProgressView(value: goal.progress)
                    .tint(urgencyColor(goal.urgency))
                
                HStack {
                    Text(goal.progressLabel ?? "\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    MascotView(emotion: entry.mascot.emotion, frameIndex: entry.mascot.frameIndex)
                }
                
                // Call to action
                HStack {
                    Spacer()
                    Text(ctaText(for: goal))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ctaColor(for: goal))
                        .cornerRadius(12)
                    Spacer()
                }
            } else {
                // Empty state CTA
                VStack(spacing: 12) {
                    MascotView(emotion: entry.mascot.emotion, frameIndex: entry.mascot.frameIndex)
                    
                    Text("Start your journey")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("+ Add Goal")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .widgetURL(URL(string: entry.topGoal != nil ? "goalwidget://log?goalId=\(entry.topGoal!.id)" : "goalwidget://add"))
    }
    
    func ctaText(for goal: TopGoal) -> String {
        if goal.progress >= 1.0 {
            return "✓ Complete!"
        } else if goal.isDaily {
            return "Tap to log"
        } else {
            return "Update progress"
        }
    }
    
    func ctaColor(for goal: TopGoal) -> Color {
        if goal.progress >= 1.0 {
            return .green
        } else if goal.urgency > 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
    
    func urgencyColor(_ urgency: Double) -> Color {
        if urgency < 0.2 { return .green }
        if urgency < 0.5 { return .blue }
        if urgency < 0.8 { return .orange }
        return .red
    }
}

struct MediumWidgetView: View {
    let entry: GoalEntry
    
    var body: some View {
        HStack(spacing: 16) {
            if let goal = entry.topGoal {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(goal.title)
                            .font(.headline)
                        GoalTypeBadge(isDaily: goal.isDaily)
                    }
                    
                    ProgressView(value: goal.progress)
                        .tint(urgencyColor(goal.urgency))
                    
                    Text(goal.progressLabel ?? "\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let dueEpoch = goal.nextDueEpoch, dueEpoch > 0 {
                        Text(timeUntilDue(dueEpoch, isDaily: goal.isDaily))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    MascotView(emotion: entry.mascot.emotion, frameIndex: entry.mascot.frameIndex)
                    
                    // Enhanced CTA button
                    Button(intent: LogGoalIntent(goalId: goal.id)) {
                        HStack(spacing: 4) {
                            Image(systemName: ctaIcon(for: goal))
                            Text(ctaButtonText(for: goal))
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ctaColor(for: goal))
                }
            } else {
                // Empty state with prominent CTA
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ready to achieve?")
                            .font(.headline)
                        
                        Text("Set your first goal and let's track it together!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        MascotView(emotion: entry.mascot.emotion, frameIndex: entry.mascot.frameIndex)
                        
                        Link(destination: URL(string: "goalwidget://add")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Goal")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    func ctaIcon(for goal: TopGoal) -> String {
        if goal.progress >= 1.0 {
            return "checkmark.seal.fill"
        } else if goal.isDaily {
            return "plus.circle"
        } else {
            return "arrow.up.circle"
        }
    }
    
    func ctaButtonText(for goal: TopGoal) -> String {
        if goal.progress >= 1.0 {
            return "Done!"
        } else if goal.isDaily {
            return "Log"
        } else {
            return "Update"
        }
    }
    
    func ctaColor(for goal: TopGoal) -> Color {
        if goal.progress >= 1.0 {
            return .green
        } else if goal.urgency > 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
    
    func urgencyColor(_ urgency: Double) -> Color {
        if urgency < 0.2 { return .green }
        if urgency < 0.5 { return .blue }
        if urgency < 0.8 { return .orange }
        return .red
    }
    
    func timeUntilDue(_ epoch: Int, isDaily: Bool) -> String {
        let dueDate = Date(timeIntervalSince1970: TimeInterval(epoch))
        let now = Date()
        let diff = dueDate.timeIntervalSince(now)
        
        if diff < 0 {
            return "Overdue"
        }
        
        if isDaily {
            let hours = Int(diff / 3600)
            let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        } else {
            let days = Int(diff / 86400)
            if days == 0 {
                return "Due today"
            } else if days == 1 {
                return "1 day left"
            } else {
                return "\(days) days left"
            }
        }
    }
}

struct GoalTypeBadge: View {
    let isDaily: Bool
    
    var body: some View {
        Text(isDaily ? "Daily" : "Goal")
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isDaily ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
            .foregroundColor(isDaily ? .blue : .orange)
            .cornerRadius(8)
    }
}

struct MascotView: View {
    let emotion: String
    let frameIndex: Int
    
    var body: some View {
        // Placeholder for cat mascot image
        // In production, load: "cat_\(emotion)_\(frameIndex)"
        Image(systemName: mascotIcon)
            .font(.system(size: 32))
            .foregroundColor(mascotColor)
    }
    
    var mascotIcon: String {
        switch emotion {
        case "happy": return "face.smiling"
        case "neutral": return "face.smiling"
        case "worried": return "face.dashed"
        case "sad": return "face.smiling.fill"
        case "celebrate": return "party.popper"
        default: return "face.smiling"
        }
    }
    
    var mascotColor: Color {
        switch emotion {
        case "happy": return .green
        case "neutral": return .blue
        case "worried": return .orange
        case "sad": return .red
        case "celebrate": return .yellow
        default: return .blue
        }
    }
}

#Preview(as: .systemSmall) {
    GoalWidget()
} timeline: {
    GoalEntry(
        date: Date(),
        topGoal: TopGoal(
            id: "1",
            title: "Learn Spanish",
            progress: 0.65,
            goalType: "longTerm",
            progressType: "percentage",
            nextDueEpoch: Int(Date().timeIntervalSince1970) + 86400 * 14,
            urgency: 0.4,
            progressLabel: "65%"
        ),
        mascot: MascotState(emotion: "neutral", frameIndex: 0)
    )
}

#Preview(as: .systemMedium) {
    GoalWidget()
} timeline: {
    GoalEntry(
        date: Date(),
        topGoal: TopGoal(
            id: "2",
            title: "Drink water",
            progress: 0.625,
            goalType: "daily",
            progressType: "numeric",
            nextDueEpoch: Int(Date().timeIntervalSince1970) + 3600,
            urgency: 0.3,
            progressLabel: "5/8 glasses"
        ),
        mascot: MascotState(emotion: "happy", frameIndex: 0)
    )
}

#Preview("Empty State - Small", as: .systemSmall) {
    GoalWidget()
} timeline: {
    GoalEntry(
        date: Date(),
        topGoal: nil,
        mascot: MascotState(emotion: "neutral", frameIndex: 0)
    )
}

#Preview("Empty State - Medium", as: .systemMedium) {
    GoalWidget()
} timeline: {
    GoalEntry(
        date: Date(),
        topGoal: nil,
        mascot: MascotState(emotion: "neutral", frameIndex: 0)
    )
}

#Preview("Urgent Goal", as: .systemSmall) {
    GoalWidget()
} timeline: {
    GoalEntry(
        date: Date(),
        topGoal: TopGoal(
            id: "3",
            title: "Exercise",
            progress: 0.25,
            goalType: "daily",
            progressType: "completion",
            nextDueEpoch: Int(Date().timeIntervalSince1970) + 1800,
            urgency: 0.85,
            progressLabel: "25%"
        ),
        mascot: MascotState(emotion: "worried", frameIndex: 0)
    )
}
