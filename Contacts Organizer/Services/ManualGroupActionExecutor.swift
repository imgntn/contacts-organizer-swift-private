import Foundation

struct ManualGroupSnapshot: Equatable {
    let name: String
    let contactIds: [String]
}

protocol ManualGroupContactPerforming: AnyObject {
    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool) async -> Bool
    func renameGroup(named currentName: String, to newName: String) async -> Bool
    func addContacts(_ contactIds: [String], toGroupNamed groupName: String) async -> Bool
    func removeContacts(_ contactIds: [String], fromGroupNamed groupName: String) async -> Bool
    func deleteGroup(named groupName: String) async -> Bool
    func fetchContacts(forGroupNamed groupName: String) async -> [ContactSummary]
    func duplicateGroupSnapshots(keepFirst: Bool) async -> [ManualGroupSnapshot]
}

@MainActor
final class ManualGroupActionExecutor {
    struct CleanupResult {
        let deletedCount: Int
        let errorCount: Int
    }

    private let contactsGateway: ManualGroupContactPerforming
    private let exportGateway: SmartGroupExportPerforming
    private let undoManager: ContactsUndoManager
    private let exportHistory: GroupExportHistory

    init(
        contactsGateway: ManualGroupContactPerforming,
        exportGateway: SmartGroupExportPerforming,
        undoManager: ContactsUndoManager,
        exportHistory: GroupExportHistory? = nil
    ) {
        self.contactsGateway = contactsGateway
        self.exportGateway = exportGateway
        self.undoManager = undoManager
        self.exportHistory = exportHistory ?? GroupExportHistory()
    }

    @discardableResult
    func createGroup(name: String, contactIds: [String]) async -> Bool {
        let success = await contactsGateway.createGroup(name: name, contactIds: contactIds, allowDuplicateNames: false)
        guard success else { return false }
        registerDeleteUndo(groupName: name, contactIds: contactIds)
        return true
    }

    @discardableResult
    func renameGroup(currentName: String, newName: String) async -> Bool {
        guard currentName != newName else { return false }
        let success = await contactsGateway.renameGroup(named: currentName, to: newName)
        guard success else { return false }
        undoManager.register(description: "Rename \(currentName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.renameGroup(named: newName, to: currentName)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.renameGroup(named: currentName, to: newName)
        }
        return true
    }

    @discardableResult
    func addContacts(_ contactIds: [String], to groupName: String) async -> Bool {
        guard !contactIds.isEmpty else { return false }
        let success = await contactsGateway.addContacts(contactIds, toGroupNamed: groupName)
        guard success else { return false }
        undoManager.register(description: "Add to \(groupName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.removeContacts(contactIds, fromGroupNamed: groupName)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.addContacts(contactIds, toGroupNamed: groupName)
        }
        return true
    }

    @discardableResult
    func removeContacts(_ contactIds: [String], from groupName: String) async -> Bool {
        guard !contactIds.isEmpty else { return false }
        let success = await contactsGateway.removeContacts(contactIds, fromGroupNamed: groupName)
        guard success else { return false }
        undoManager.register(description: "Remove from \(groupName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.addContacts(contactIds, toGroupNamed: groupName)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.removeContacts(contactIds, fromGroupNamed: groupName)
        }
        return true
    }

    @discardableResult
    func exportGroup(groupName: String, contacts: [ContactSummary], type: GroupExportService.ExportType) -> GroupExportService.ExportResult {
        let result = exportGateway.performExport(type: type, contacts: contacts, groupName: groupName)
        let record = GroupExportHistory.Record(groupName: groupName, type: type, message: result.message)
        exportHistory.append(record)
        undoManager.register(description: "Export \(groupName)") { [weak self] in
            guard let self = self else { return false }
            self.exportHistory.remove(record)
            return true
        } redo: { [weak self] in
            guard let self = self else { return false }
            self.exportHistory.append(record)
            return true
        }
        return result
    }

    @discardableResult
    func cleanupDuplicateGroups(keepFirst: Bool = true) async -> CleanupResult {
        let snapshots = await contactsGateway.duplicateGroupSnapshots(keepFirst: keepFirst)
        guard !snapshots.isEmpty else {
            return CleanupResult(deletedCount: 0, errorCount: 0)
        }

        var deletedCount = 0
        var errorCount = 0

        for snapshot in snapshots {
            let success = await contactsGateway.deleteGroup(named: snapshot.name)
            success ? (deletedCount += 1) : (errorCount += 1)
        }

        guard deletedCount > 0 else {
            return CleanupResult(deletedCount: deletedCount, errorCount: errorCount)
        }

        registerDuplicateUndo(snapshots: snapshots)
        return CleanupResult(deletedCount: deletedCount, errorCount: errorCount)
    }

    var exportHistoryRecords: [GroupExportHistory.Record] {
        exportHistory.records
    }

    private func registerDeleteUndo(groupName: String, contactIds: [String]) {
        undoManager.register(description: "Create \(groupName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.deleteGroup(named: groupName)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.createGroup(name: groupName, contactIds: contactIds, allowDuplicateNames: false)
        }
    }

    private func registerDuplicateUndo(snapshots: [ManualGroupSnapshot]) {
        undoManager.register(description: "Cleanup Duplicates") { [weak self] in
            guard let self = self else { return false }
            for snapshot in snapshots {
                let success = await self.contactsGateway.createGroup(name: snapshot.name, contactIds: snapshot.contactIds, allowDuplicateNames: true)
                if !success { return false }
            }
            return true
        } redo: { [weak self] in
            guard let self = self else { return false }
            for snapshot in snapshots {
                let success = await self.contactsGateway.deleteGroup(named: snapshot.name)
                if !success { return false }
            }
            return true
        }
    }
}
