import Foundation

@MainActor
protocol SettingsContactsHandling: AnyObject {
    func requestAccess() async -> Bool
    func createBackup(saveToURL url: URL?) async -> (userBackup: URL?, appBackup: URL?)
}

extension ContactsManager: SettingsContactsHandling {}

@MainActor
final class SettingsActionController {
    private static var sharedInstance: SettingsActionController?

    nonisolated static func sharedActor() async -> SettingsActionController {
        await MainActor.run {
            if let existing = sharedInstance { return existing }
            let controller = SettingsActionController(contactsHandler: ContactsManager.shared)
            sharedInstance = controller
            return controller
        }
    }

    private let contactsHandler: SettingsContactsHandling

    init(contactsHandler: SettingsContactsHandling) {
        self.contactsHandler = contactsHandler
    }

    func requestContactsAccess() async -> Bool {
        await contactsHandler.requestAccess()
    }

    func createBackup(saveTo url: URL?) async -> (URL?, URL?) {
        let result = await contactsHandler.createBackup(saveToURL: url)
        return (result.userBackup, result.appBackup)
    }
}
