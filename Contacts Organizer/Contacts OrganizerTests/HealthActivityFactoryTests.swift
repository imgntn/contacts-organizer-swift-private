import XCTest
@testable import Contacts_Organizer

final class HealthActivityFactoryTests: XCTestCase {
    func testFactoryBuildsActivityWithCorrectFields() {
        let issue = DataQualityIssue(
            contactId: "1",
            contactName: "Sam Example",
            issueType: .missingEmail,
            description: "",
            severity: .medium
        )
        let action = HealthIssueAction(
            title: "Add Email",
            icon: "envelope",
            type: .addEmail,
            inputPrompt: nil,
            inputPlaceholder: nil
        )

        let activity = HealthActivityFactory.makeActivity(action: action, issue: issue)

        XCTAssertEqual(activity.kind, .healthAction)
        XCTAssertEqual(activity.title, "Add Email")
        XCTAssertEqual(activity.detail, "Sam Example")
        XCTAssertEqual(activity.icon, "envelope")
    }
}
