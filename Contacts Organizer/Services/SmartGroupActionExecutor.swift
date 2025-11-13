import Foundation

protocol SmartGroupContactPerforming: AnyObject {
    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool) async -> Bool
    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool, replaceExisting: Bool) async -> Bool
    func deleteGroup(named name: String) async -> Bool
}

extension SmartGroupContactPerforming {
    func createGroup(name: String, contactIds: [String], allowDuplicateNames: Bool, replaceExisting: Bool) async -> Bool {
        await createGroup(name: name, contactIds: contactIds, allowDuplicateNames: allowDuplicateNames)
    }
}

protocol SmartGroupExportPerforming: AnyObject {
    func performExport(type: GroupExportService.ExportType, contacts: [ContactSummary], groupName: String) -> GroupExportService.ExportResult
}

@MainActor
final class GroupExportHistory {
    struct Record: Equatable {
        let groupName: String
        let type: GroupExportService.ExportType
        let message: String
    }

    private(set) var records: [Record] = []

    func append(_ record: Record) {
        records.append(record)
    }

    func remove(_ record: Record) {
        if let index = records.lastIndex(of: record) {
            records.remove(at: index)
        }
    }
}

@MainActor
final class SmartGroupActionExecutor {
    private let contactsGateway: SmartGroupContactPerforming
    private let exportGateway: SmartGroupExportPerforming
    private let undoManager: ContactsUndoManager
    private let exportHistory: GroupExportHistory

    init(
        contactsGateway: SmartGroupContactPerforming,
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
    func createGroup(from result: SmartGroupResult) async -> Bool {
        let contactIds = result.contacts.map(\.id)
        let success = await contactsGateway.createGroup(name: result.groupName, contactIds: contactIds, allowDuplicateNames: false, replaceExisting: true)
        guard success else { return false }
        registerCreateUndo(groupName: result.groupName, contactIds: contactIds)
        return true
    }

    @discardableResult
    func deleteGroup(named groupName: String, contacts: [ContactSummary]) async -> Bool {
        let contactIds = contacts.map(\.id)
        let success = await contactsGateway.deleteGroup(named: groupName)
        guard success else { return false }
        registerDeleteUndo(groupName: groupName, contactIds: contactIds)
        return true
    }

    @discardableResult
    func exportGroup(_ result: SmartGroupResult, as type: GroupExportService.ExportType) -> GroupExportService.ExportResult {
        let exportResult = exportGateway.performExport(type: type, contacts: result.contacts, groupName: result.groupName)
        let record = GroupExportHistory.Record(groupName: result.groupName, type: type, message: exportResult.message)
        exportHistory.append(record)

        undoManager.register(description: "Export \(result.groupName)") { [weak self] in
            guard let self = self else { return false }
            self.exportHistory.remove(record)
            return true
        } redo: { [weak self] in
            guard let self = self else { return false }
            self.exportHistory.append(record)
            return true
        }

        return exportResult
    }

    var exportHistoryRecords: [GroupExportHistory.Record] {
        exportHistory.records
    }

    private func registerCreateUndo(groupName: String, contactIds: [String]) {
        undoManager.register(description: "Create \(groupName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.deleteGroup(named: groupName)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.createGroup(name: groupName, contactIds: contactIds, allowDuplicateNames: false)
        }
    }

    private func registerDeleteUndo(groupName: String, contactIds: [String]) {
        undoManager.register(description: "Delete \(groupName)") { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.createGroup(name: groupName, contactIds: contactIds, allowDuplicateNames: false)
        } redo: { [weak self] in
            guard let self = self else { return false }
            return await self.contactsGateway.deleteGroup(named: groupName)
        }
    }
}

extension GroupExportService: SmartGroupExportPerforming {}
