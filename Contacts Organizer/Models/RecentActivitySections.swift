import Foundation

enum RecentActivitySections {
    static func groupedByDay(_ activities: [RecentActivity], calendar: Calendar = .current) -> [(Date, [RecentActivity])] {
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.timestamp)
        }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.0 > $1.0 }
    }
}
