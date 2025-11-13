import Foundation

enum HealthActivityFactory {
    static func makeActivity(action: HealthIssueAction, issue: DataQualityIssue) -> RecentActivity {
        RecentActivity(
            kind: .healthAction,
            title: action.title,
            detail: issue.contactName,
            icon: action.icon
        )
    }
}
