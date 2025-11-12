@testable import Contacts_Organizer

final class RecordingContactActionPerformer: ContactActionPerforming {
    var addPhoneCalls: [(value: String, contactId: String)] = []
    var removePhoneCalls: [(value: String, contactId: String)] = []
    var addEmailCalls: [(value: String, contactId: String)] = []
    var removeEmailCalls: [(value: String, contactId: String)] = []
    var addGroupCalls: [(contactId: String, groupName: String)] = []
    var removeGroupCalls: [(contactId: String, groupName: String)] = []
    var archiveCalls: [String] = []
    var updatedNames: [(contactId: String, value: String)] = []
    var nameLookup: [String: (given: String, family: String)] = [:]

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
        updatedNames.append((contactId, fullName))
        return true
    }

    func fetchNameComponents(contactId: String) async -> (given: String, family: String)? {
        nameLookup[contactId]
    }
}
