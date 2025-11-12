import XCTest
@testable import Contacts_Organizer

final class HealthIssueActionExecutorTests: XCTestCase {

    func testExecuteAddPhoneCallsPerformer() async throws {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingPhone, description: "", severity: .medium)
        let action = HealthIssueAction(title: "Add Phone", icon: "", type: .addPhone, inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: " 555-0000 ")

        XCTAssertTrue(result.success)
        if case .addedPhone(let contactId, let value)? = result.effect {
            XCTAssertEqual(contactId, "1")
            XCTAssertEqual(value, "555-0000")
        } else {
            XCTFail("Expected addedPhone effect")
        }
        XCTAssertEqual(mock.addPhoneCalls.count, 1)
        XCTAssertEqual(mock.addPhoneCalls.first?.phone, "555-0000")
        XCTAssertEqual(mock.addPhoneCalls.first?.contactId, "1")
    }

    func testExecuteAddEmailCallsPerformer() async {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingEmail, description: "", severity: .low)
        let action = HealthIssueAction(title: "Add Email", icon: "", type: .addEmail, inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: " user@example.com ")

        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.addEmailCalls.count, 1)
        XCTAssertEqual(mock.addEmailCalls.first?.email, "user@example.com")
    }

    func testExecuteAddToGroup() async {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "42", contactName: "Test", issueType: .missingPhone, description: "", severity: .medium)
        let action = HealthIssueAction(title: "Follow Up", icon: "", type: .addToGroup(name: "Needs Contact Cleanup"), inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: nil)

        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.addToGroupCalls.count, 1)
        XCTAssertEqual(mock.addToGroupCalls.first?.groupName, "Needs Contact Cleanup")
        XCTAssertEqual(mock.addToGroupCalls.first?.contactId, "42")
    }

    func testExecuteArchive() async {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "99", contactName: "Archived", issueType: .noContactInfo, description: "", severity: .high)
        let action = HealthIssueAction(title: "Archive", icon: "", type: .archive, inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: nil)

        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.archiveCalls, ["99"])
    }

    func testExecuteFailsForEmptyInput() async {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingPhone, description: "", severity: .medium)
        let action = HealthIssueAction(title: "Add Phone", icon: "", type: .addPhone, inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: "   ")

        XCTAssertFalse(result.success)
        XCTAssertTrue(mock.addPhoneCalls.isEmpty)
    }

    func testExecuteUpdateName() async {
        let mock = MockPerformer()
        mock.nameLookup = (given: "Old", family: "Name")
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "3", contactName: "Test", issueType: .missingName, description: "", severity: .high)
        let action = HealthIssueAction(title: "Update Name", icon: "", type: .updateName, inputPrompt: nil, inputPlaceholder: nil)

        let result = await executor.execute(action, for: issue, inputValue: "New Name")

        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.updatedNames.first?.contactId, "3")
        XCTAssertEqual(mock.updatedNames.first?.value, "New Name")
        if case .updatedName(let contactId, let previousGiven, let previousFamily, let newValue)? = result.effect {
            XCTAssertEqual(contactId, "3")
            XCTAssertEqual(previousGiven, "Old")
            XCTAssertEqual(previousFamily, "Name")
            XCTAssertEqual(newValue, "New Name")
        } else {
            XCTFail("Expected updatedName effect")
        }
    }

    func testMarkReviewedAddsToReviewedGroup() async {
        let mock = MockPerformer()
        let executor = HealthIssueActionExecutor(performer: mock)
        let issue = DataQualityIssue(contactId: "5", contactName: "Reviewed", issueType: .suggestion, description: "", severity: .suggestion)
        let markAction = HealthIssueActionCatalog.actions(for: issue).last!

        let result = await executor.execute(markAction, for: issue, inputValue: nil)

        XCTAssertTrue(result.success)
        XCTAssertEqual(mock.addToGroupCalls.last?.groupName, HealthIssueActionCatalog.reviewedGroupName)
        if case .addedToGroup(let contactId, let group)? = result.effect {
            XCTAssertEqual(contactId, "5")
            XCTAssertEqual(group, HealthIssueActionCatalog.reviewedGroupName)
        } else {
            XCTFail("Expected addedToGroup effect for reviewed action")
        }
    }
}

private final class MockPerformer: ContactActionPerforming {
    var addPhoneCalls: [(phone: String, contactId: String)] = []
    var addEmailCalls: [(email: String, contactId: String)] = []
    var addToGroupCalls: [(contactId: String, groupName: String)] = []
    var archiveCalls: [String] = []
    var updatedNames: [(contactId: String, value: String)] = []
    var nameLookup: (given: String, family: String)? = nil

    func addPhoneNumber(_ phoneNumber: String, label: String, to contactId: String) async -> Bool {
        addPhoneCalls.append((phoneNumber, contactId))
        return true
    }

    func addEmailAddress(_ emailAddress: String, label: String, to contactId: String) async -> Bool {
        addEmailCalls.append((emailAddress, contactId))
        return true
    }

    func addContact(_ contactId: String, toGroupNamed groupName: String) async -> Bool {
        addToGroupCalls.append((contactId, groupName))
        return true
    }

    func archiveContact(_ contactId: String) async -> Bool {
        archiveCalls.append(contactId)
        return true
    }

    func removePhoneNumber(_ phoneNumber: String, from contactId: String) async -> Bool { true }
    func removeEmailAddress(_ emailAddress: String, from contactId: String) async -> Bool { true }
    func removeContact(_ contactId: String, fromGroupNamed groupName: String) async -> Bool { true }
    func updateFullName(_ contactId: String, fullName: String) async -> Bool {
        updatedNames.append((contactId, fullName))
        return true
    }

    func fetchNameComponents(contactId: String) async -> (given: String, family: String)? {
        nameLookup
    }
}
