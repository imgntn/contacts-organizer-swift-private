import XCTest
@testable import Contacts_Organizer

@MainActor
final class ManualGroupActionExecutorTests: XCTestCase {

    func testCreateGroupRegistersUndoRedo() async {
        let gateway = MockManualGroupGateway()
        let exporter = MockManualExportGateway()
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = ManualGroupActionExecutor(
            contactsGateway: gateway,
            exportGateway: exporter,
            undoManager: undoManager
        )

        let contacts = ["1", "2"]
        let success = await executor.createGroup(name: "Friends", contactIds: contacts)
        XCTAssertTrue(success)
        XCTAssertEqual(gateway.groups["Friends"], contacts)

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertNil(gateway.groups["Friends"])

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.groups["Friends"], contacts)
        XCTAssertEqual(gateway.createCalls.filter { $0.allowDuplicate }.count, 0)
    }

    func testRenameGroupRegistersUndoRedo() async {
        let gateway = MockManualGroupGateway()
        gateway.groups["Sales"] = []
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = ManualGroupActionExecutor(
            contactsGateway: gateway,
            exportGateway: MockManualExportGateway(),
            undoManager: undoManager
        )

        let success = await executor.renameGroup(currentName: "Sales", newName: "Sales EMEA")
        XCTAssertTrue(success)
        XCTAssertEqual(gateway.renameCalls.last?.from, "Sales")
        XCTAssertEqual(gateway.renameCalls.last?.to, "Sales EMEA")

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.renameCalls[1].from, "Sales EMEA")
        XCTAssertEqual(gateway.renameCalls[1].to, "Sales")

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.renameCalls.last?.from, "Sales")
        XCTAssertEqual(gateway.renameCalls.last?.to, "Sales EMEA")
    }

    func testAddAndRemoveContactsRegisterUndoRedo() async {
        let gateway = MockManualGroupGateway()
        gateway.groups["VIP"] = []
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = ManualGroupActionExecutor(
            contactsGateway: gateway,
            exportGateway: MockManualExportGateway(),
            undoManager: undoManager
        )

        let addSuccess = await executor.addContacts(["1", "2"], to: "VIP")
        XCTAssertTrue(addSuccess)
        XCTAssertEqual(gateway.addCalls.last?.ids, ["1", "2"])

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.removeCalls.last?.ids, ["1", "2"])

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.addCalls.last?.ids, ["1", "2"])

        let removeSuccess = await executor.removeContacts(["3"], from: "VIP")
        XCTAssertTrue(removeSuccess)
        XCTAssertEqual(gateway.removeCalls.last?.ids, ["3"])

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.addCalls.last?.ids, ["3"])
    }

    func testExportGroupRecordsHistoryAndSupportsUndo() async {
        let gateway = MockManualGroupGateway()
        let exportGateway = MockManualExportGateway()
        exportGateway.nextResult = GroupExportService.ExportResult(success: true, fileURL: nil, message: "Exported")
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = ManualGroupActionExecutor(
            contactsGateway: gateway,
            exportGateway: exportGateway,
            undoManager: undoManager
        )

        let result = executor.exportGroup(groupName: "VIP", contacts: [makeContact(id: "1")], type: .csv)
        XCTAssertTrue(result.success)
        XCTAssertEqual(executor.exportHistoryRecords.count, 1)
        XCTAssertEqual(exportGateway.calls.count, 1)
        XCTAssertEqual(exportGateway.calls.first?.groupName, "VIP")
        XCTAssertEqual(exportGateway.calls.first?.type, .csv)
        XCTAssertEqual(exportGateway.calls.first?.contacts.map(\.id), ["1"])

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertTrue(executor.exportHistoryRecords.isEmpty)

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(executor.exportHistoryRecords.count, 1)
    }

    func testCleanupDuplicatesDeletesAllSnapshotsAndRegistersUndo() async {
        let gateway = MockManualGroupGateway()
        gateway.duplicateSnapshotsToReturn = [
            ManualGroupSnapshot(name: "Marketing", contactIds: ["1", "2"]),
            ManualGroupSnapshot(name: "Marketing", contactIds: ["3"])
        ]
        let undoManager = await MainActor.run { ContactsUndoManager() }
        let executor = ManualGroupActionExecutor(
            contactsGateway: gateway,
            exportGateway: MockManualExportGateway(),
            undoManager: undoManager
        )

        let result = await executor.cleanupDuplicateGroups()
        XCTAssertEqual(result.deletedCount, 2)
        XCTAssertEqual(gateway.deleteCalls.filter { $0 == "Marketing" }.count, 2)

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.createCalls.filter { $0.allowDuplicate }.count, 2)
        XCTAssertEqual(gateway.createCalls.filter { $0.allowDuplicate }.first?.contactIds, ["1", "2"])

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(gateway.deleteCalls.filter { $0 == "Marketing" }.count, 4)
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
private final class MockManualGroupGateway: ManualGroupContactPerforming {
    struct CreateCall {
        let name: String
        let contactIds: [String]
        let allowDuplicate: Bool
    }

    struct RenameCall {
        let from: String
        let to: String
    }

    struct MemberCall {
        let group: String
        let ids: [String]
    }

    var groups: [String: [String]] = [:]
    var createCalls: [CreateCall] = []
    var renameCalls: [RenameCall] = []
    var addCalls: [MemberCall] = []
    var removeCalls: [MemberCall] = []
    var deleteCalls: [String] = []
    var duplicateSnapshotsToReturn: [ManualGroupSnapshot] = []

    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool) async -> Bool {
        createCalls.append(.init(name: name, contactIds: contactIds, allowDuplicate: allowDuplicateNames))
        if !allowDuplicateNames, groups[name] != nil { return false }
        groups[name, default: []] = contactIds
        return true
    }

    func renameGroup(named currentName: String, to newName: String) async -> Bool {
        renameCalls.append(.init(from: currentName, to: newName))
        guard let contacts = groups.removeValue(forKey: currentName) else { return false }
        groups[newName] = contacts
        return true
    }

    func addContacts(_ contactIds: [String], toGroupNamed groupName: String) async -> Bool {
        addCalls.append(.init(group: groupName, ids: contactIds))
        groups[groupName, default: []].append(contentsOf: contactIds)
        return true
    }

    func removeContacts(_ contactIds: [String], fromGroupNamed groupName: String) async -> Bool {
        removeCalls.append(.init(group: groupName, ids: contactIds))
        guard var existing = groups[groupName] else { return false }
        existing.removeAll { contactIds.contains($0) }
        groups[groupName] = existing
        return true
    }

    func deleteGroup(named groupName: String) async -> Bool {
        deleteCalls.append(groupName)
        groups.removeValue(forKey: groupName)
        return true
    }

    func fetchContacts(forGroupNamed groupName: String) async -> [ContactSummary] {
        (groups[groupName] ?? []).map {
            ContactSummary(
                id: $0,
                fullName: "Contact \($0)",
                organization: nil,
                phoneNumbers: [],
                emailAddresses: [],
                hasProfileImage: false,
                creationDate: nil,
                modificationDate: nil
            )
        }
    }

    func duplicateGroupSnapshots(keepFirst: Bool) async -> [ManualGroupSnapshot] {
        duplicateSnapshotsToReturn
    }
}

@MainActor
private final class MockManualExportGateway: SmartGroupExportPerforming {
    struct ExportCall {
        let type: GroupExportService.ExportType
        let groupName: String
        let contacts: [ContactSummary]
    }

    var nextResult = GroupExportService.ExportResult(success: true, fileURL: nil, message: "ok")
    var calls: [ExportCall] = []

    func performExport(type: GroupExportService.ExportType, contacts: [ContactSummary], groupName: String) -> GroupExportService.ExportResult {
        calls.append(.init(type: type, groupName: groupName, contacts: contacts))
        return nextResult
    }
}
