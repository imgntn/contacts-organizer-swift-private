import XCTest
@testable import Contacts_Organizer

final class ContactsUndoManagerTests: XCTestCase {

    func testRegisterAndUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let undone = XCTestExpectation(description: "undo")
        let redone = XCTestExpectation(description: "redo")

        await MainActor.run {
            manager.register(description: "Add Phone") {
                undone.fulfill()
                return true
            } redo: {
                redone.fulfill()
                return true
            }
        }

        let canUndo = await MainActor.run { manager.canUndo }
        XCTAssertTrue(canUndo)
        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        await fulfillment(of: [undone], timeout: 1)
        let canRedo = await MainActor.run { manager.canRedo }
        XCTAssertTrue(canRedo)
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        await fulfillment(of: [redone], timeout: 1)
    }

    func testFailedUndoReturnsOperationToStack() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let attempt = XCTestExpectation(description: "undo attempted")
        await MainActor.run {
            manager.register(description: "Fail") {
                attempt.fulfill()
                return false
            } redo: {
                return true
            }
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        await fulfillment(of: [attempt], timeout: 1)
        let canUndo = await MainActor.run { manager.canUndo }
        XCTAssertTrue(canUndo)
    }

    func testAddedPhoneEffectUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .addedPhone(contactId: "1", value: "555"), actionTitle: "Add Phone", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removePhoneCalls.count, 1)
        XCTAssertEqual(mock.removePhoneCalls.first?.0, "555")
        XCTAssertEqual(mock.removePhoneCalls.first?.1, "1")
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.addPhoneCalls.count, 1)
        XCTAssertEqual(mock.addPhoneCalls.first?.0, "555")
        XCTAssertEqual(mock.addPhoneCalls.first?.1, "1")
    }

    func testAddedEmailEffectUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .addedEmail(contactId: "2", value: "test@example.com"), actionTitle: "Add Email", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removeEmailCalls.count, 1)
        XCTAssertEqual(mock.removeEmailCalls.first?.0, "test@example.com")
        XCTAssertEqual(mock.removeEmailCalls.first?.1, "2")
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.addEmailCalls.count, 1)
        XCTAssertEqual(mock.addEmailCalls.first?.0, "test@example.com")
        XCTAssertEqual(mock.addEmailCalls.first?.1, "2")
    }

    func testAddedToGroupEffectUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .addedToGroup(contactId: "3", groupName: HealthIssueActionCatalog.generalFollowUpGroupName), actionTitle: "Follow Up", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removeGroupCalls.count, 1)
        XCTAssertEqual(mock.removeGroupCalls.first?.0, "3")
        XCTAssertEqual(mock.removeGroupCalls.first?.1, HealthIssueActionCatalog.generalFollowUpGroupName)
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.addGroupCalls.count, 1)
        XCTAssertEqual(mock.addGroupCalls.first?.0, "3")
        XCTAssertEqual(mock.addGroupCalls.first?.1, HealthIssueActionCatalog.generalFollowUpGroupName)
    }

    func testArchivedContactEffectUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .archivedContact(contactId: "4"), actionTitle: "Archive", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removeGroupCalls.last?.0, "4")
        XCTAssertEqual(mock.removeGroupCalls.last?.1, HealthIssueActionCatalog.archiveGroupName)
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.archiveCalls, ["4"])
    }

    func testUpdatedNameEffectUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .updatedName(contactId: "5", previousGiven: "Old", previousFamily: "Name", newValue: "New Name"), actionTitle: "Update Name", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.updatedNames.count, 1)
        XCTAssertEqual(mock.updatedNames.first?.0, "5")
        XCTAssertEqual(mock.updatedNames.first?.1, "Old Name")
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.updatedNamesRedo.count, 1)
        XCTAssertEqual(mock.updatedNamesRedo.first?.0, "5")
        XCTAssertEqual(mock.updatedNamesRedo.first?.1, "New Name")
    }

    func testMultiplePhoneAdditionsUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .addedPhone(contactId: "1", value: "111"), actionTitle: "Add Phone", contactsManager: mock)
            manager.register(effect: .addedPhone(contactId: "2", value: "222"), actionTitle: "Add Phone", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removePhoneCalls.map(\.0), ["222", "111"])
        XCTAssertEqual(mock.removePhoneCalls.map(\.1), ["2", "1"])

        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.addPhoneCalls.map(\.0), ["111", "222"])
        XCTAssertEqual(mock.addPhoneCalls.map(\.1), ["1", "2"])
    }

    func testMultipleEmailAdditionsUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .addedEmail(contactId: "10", value: "first@example.com"), actionTitle: "Add Email", contactsManager: mock)
            manager.register(effect: .addedEmail(contactId: "20", value: "second@example.com"), actionTitle: "Add Email", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.removeEmailCalls.map(\.0), ["second@example.com", "first@example.com"])
        XCTAssertEqual(mock.removeEmailCalls.map(\.1), ["20", "10"])

        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.addEmailCalls.map(\.0), ["first@example.com", "second@example.com"])
        XCTAssertEqual(mock.addEmailCalls.map(\.1), ["10", "20"])
    }

    func testMultipleArchiveActionsUndoRedo() async {
        let manager = await MainActor.run { ContactsUndoManager() }
        let mock = MockUndoPerformer()
        await MainActor.run {
            manager.register(effect: .archivedContact(contactId: "alpha"), actionTitle: "Archive", contactsManager: mock)
            manager.register(effect: .archivedContact(contactId: "beta"), actionTitle: "Archive", contactsManager: mock)
        }

        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        await MainActor.run { manager.undo() }
        await manager.waitForIdle()
        let removed = mock.removeGroupCalls.suffix(2)
        XCTAssertEqual(removed.map(\.0), ["beta", "alpha"])
        XCTAssertEqual(removed.map(\.1), Array(repeating: HealthIssueActionCatalog.archiveGroupName, count: 2))

        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        await MainActor.run { manager.redo() }
        await manager.waitForIdle()
        XCTAssertEqual(mock.archiveCalls.suffix(2), ["alpha", "beta"])
    }
}

private final class MockUndoPerformer: ContactActionPerforming {
    var addPhoneCalls: [(String, String)] = []
    var removePhoneCalls: [(String, String)] = []
    var addEmailCalls: [(String, String)] = []
    var removeEmailCalls: [(String, String)] = []
    var addGroupCalls: [(String, String)] = []
    var removeGroupCalls: [(String, String)] = []
    var archiveCalls: [String] = []
    var updatedNames: [(String, String)] = []
    var updatedNamesRedo: [(String, String)] = []

    func addPhoneNumber(_ phoneNumber: String, label: String, to contactId: String) async -> Bool {
        addPhoneCalls.append((phoneNumber, contactId))
        return true
    }

    func removePhoneNumber(_ phoneNumber: String, from contactId: String) async -> Bool {
        removePhoneCalls.append((phoneNumber, contactId))
        return true
    }

    func addEmailAddress(_ emailAddress: String, label: String, to contactId: String) async -> Bool {
        addEmailCalls.append((emailAddress, contactId))
        return true
    }

    func removeEmailAddress(_ emailAddress: String, from contactId: String) async -> Bool {
        removeEmailCalls.append((emailAddress, contactId))
        return true
    }

    func addContact(_ contactId: String, toGroupNamed groupName: String) async -> Bool {
        addGroupCalls.append((contactId, groupName))
        return true
    }

    func removeContact(_ contactId: String, fromGroupNamed groupName: String) async -> Bool {
        removeGroupCalls.append((contactId, groupName))
        return true
    }

    func archiveContact(_ contactId: String) async -> Bool {
        archiveCalls.append(contactId)
        return true
    }

    func updateFullName(_ contactId: String, fullName: String) async -> Bool {
        if updatedNames.contains(where: { $0.0 == contactId }) {
            updatedNamesRedo.append((contactId, fullName))
        } else {
            updatedNames.append((contactId, fullName))
        }
        return true
    }

    func fetchNameComponents(contactId: String) async -> (given: String, family: String)? {
        nil
    }
}
