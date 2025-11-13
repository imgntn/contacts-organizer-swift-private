import XCTest
@testable import Contacts_Organizer

@MainActor
final class SmartGroupActionExecutorTests: XCTestCase {

    func testCreateGroupRegistersUndoRedoAndUpdatesStore() async {
        let contactsGateway = MockSmartGroupContactsGateway()
        let exporter = MockSmartGroupExportGateway()
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = SmartGroupActionExecutor(
            contactsGateway: contactsGateway,
            exportGateway: exporter,
            undoManager: undoManager
        )

        let contacts = [
            makeContact(id: "1"),
            makeContact(id: "2")
        ]
        let result = SmartGroupResult(groupName: "VIP", contacts: contacts, criteria: .organization)

        let success = await executor.createGroup(from: result)
        XCTAssertTrue(success)
        XCTAssertEqual(contactsGateway.groups["VIP"], contacts.map(\.id))
        XCTAssertEqual(contactsGateway.createCalls.count, 1)
        XCTAssertEqual(contactsGateway.createCalls.first?.contactIds, contacts.map(\.id))
        XCTAssertFalse(contactsGateway.createCalls.first?.allowDuplicate ?? true)

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertNil(contactsGateway.groups["VIP"])
        XCTAssertEqual(contactsGateway.deleteCalls.count, 1)
        XCTAssertEqual(contactsGateway.deleteCalls.first, "VIP")

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(contactsGateway.groups["VIP"], contacts.map(\.id))
        XCTAssertEqual(contactsGateway.createCalls.last?.contactIds, contacts.map(\.id))
    }

    func testDeleteGroupRegistersUndoRedo() async {
        let contactsGateway = MockSmartGroupContactsGateway()
        let exporter = MockSmartGroupExportGateway()
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = SmartGroupActionExecutor(
            contactsGateway: contactsGateway,
            exportGateway: exporter,
            undoManager: undoManager
        )

        let contacts = [makeContact(id: "10")]
        _ = await contactsGateway.createGroup(name: "Leads", contactIds: contacts.map(\.id), allowDuplicateNames: false)

        let success = await executor.deleteGroup(named: "Leads", contacts: contacts)
        XCTAssertTrue(success)
        XCTAssertNil(contactsGateway.groups["Leads"])
        XCTAssertEqual(contactsGateway.deleteCalls.count, 1)
        XCTAssertEqual(contactsGateway.deleteCalls.first, "Leads")

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(contactsGateway.groups["Leads"], contacts.map(\.id))
        XCTAssertEqual(contactsGateway.createCalls.last?.contactIds, contacts.map(\.id))

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertNil(contactsGateway.groups["Leads"])
        XCTAssertEqual(contactsGateway.deleteCalls.count, 2)
    }

    func testExportRecordsHistoryAndSupportsUndo() async {
        let contactsGateway = MockSmartGroupContactsGateway()
        let exporter = MockSmartGroupExportGateway()
        exporter.nextResult = GroupExportService.ExportResult(success: true, fileURL: nil, message: "Exported 1 contact")
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = SmartGroupActionExecutor(
            contactsGateway: contactsGateway,
            exportGateway: exporter,
            undoManager: undoManager
        )

        let result = SmartGroupResult(groupName: "Stale Contacts", contacts: [makeContact(id: "old")], criteria: .custom(CustomCriteria(rules: [])))

        let exportResult = executor.exportGroup(result, as: .csv)
        XCTAssertTrue(exportResult.success)
        XCTAssertEqual(executor.exportHistoryRecords.count, 1)
        XCTAssertEqual(exporter.calls.count, 1)
        XCTAssertEqual(exporter.calls.first?.groupName, "Stale Contacts")
        XCTAssertEqual(exporter.calls.first?.contacts.map(\.id), ["old"])
        XCTAssertEqual(exporter.calls.first?.type, .csv)

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertTrue(executor.exportHistoryRecords.isEmpty)

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(executor.exportHistoryRecords.count, 1)
        XCTAssertEqual(exporter.calls.count, 1, "Export should not rerun automatically on redo")
    }

    // MARK: - Helpers

    private func makeContact(id: String) -> ContactSummary {
        ContactSummary(
            id: id,
            fullName: "Contact \(id)",
            organization: nil,
            phoneNumbers: [],
            emailAddresses: [],
            hasProfileImage: false,
            creationDate: nil,
            modificationDate: nil
        )
    }
}

@MainActor
private final class MockSmartGroupContactsGateway: SmartGroupContactPerforming {
    struct CreateCall {
        let name: String
        let contactIds: [String]
        let allowDuplicate: Bool
    }

    var groups: [String: [String]] = [:]
    var createCalls: [CreateCall] = []
    var deleteCalls: [String] = []

    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool) async -> Bool {
        createCalls.append(.init(name: name, contactIds: contactIds, allowDuplicate: allowDuplicateNames))
        if !allowDuplicateNames, groups[name] != nil { return false }
        groups[name] = contactIds
        return true
    }

    func deleteGroup(named name: String) async -> Bool {
        deleteCalls.append(name)
        return groups.removeValue(forKey: name) != nil
    }
}

@MainActor
private final class MockSmartGroupExportGateway: SmartGroupExportPerforming {
    struct ExportCall {
        let type: GroupExportService.ExportType
        let groupName: String
        let contacts: [ContactSummary]
    }

    var calls: [ExportCall] = []
    var nextResult = GroupExportService.ExportResult(success: true, fileURL: nil, message: "done")

    func performExport(type: GroupExportService.ExportType, contacts: [ContactSummary], groupName: String) -> GroupExportService.ExportResult {
        calls.append(.init(type: type, groupName: groupName, contacts: contacts))
        return nextResult
    }
}
