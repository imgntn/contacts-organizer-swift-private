import XCTest
@testable import Contacts_Organizer

final class RecentActivitySectionsTests: XCTestCase {
    func testGroupsActivitiesByDayInDescendingOrder() {
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = Date()
        let day1 = baseDate
        let day2 = calendar.date(byAdding: .day, value: -1, to: baseDate)!

        let activities = [
            RecentActivity(kind: .smartGroupCreated, title: "A", detail: "Detail", icon: "sparkles", timestamp: day1.addingTimeInterval(-100)),
            RecentActivity(kind: .smartGroupCreated, title: "B", detail: "Detail", icon: "sparkles", timestamp: day1),
            RecentActivity(kind: .manualGroupCreated, title: "C", detail: "Detail", icon: "folder", timestamp: day2)
        ]

        let sections = RecentActivitySections.groupedByDay(activities, calendar: calendar)

        XCTAssertEqual(sections.count, 2)
        XCTAssertTrue(sections.first!.0 > sections.last!.0)
        XCTAssertEqual(sections.first!.1.map(\.title), ["B", "A"], "Most recent entries should appear first within the day")
    }
}
