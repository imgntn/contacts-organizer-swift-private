import XCTest
@testable import Contacts_Organizer

@MainActor
final class SettingsActionControllerTests: XCTestCase {

    func testRequestAccessCallsContactsManager() async {
        let handler = MockSettingsContactsHandler()
        let controller = SettingsActionController(contactsHandler: handler)

        _ = await controller.requestContactsAccess()

        XCTAssertEqual(handler.requestAccessCallCount, 1)
    }

    func testCreateBackupPassesThroughToContactsManager() async {
        let handler = MockSettingsContactsHandler()
        handler.backupResult = (URL(fileURLWithPath: "/tmp/user.vcf"), URL(fileURLWithPath: "/tmp/app.vcf"))
        let controller = SettingsActionController(contactsHandler: handler)

        let result = await controller.createBackup(saveTo: URL(fileURLWithPath: "/tmp/output.vcf"))

        XCTAssertEqual(handler.createBackupCallCount, 1)
        XCTAssertEqual(result.0, handler.backupResult?.0)
        XCTAssertEqual(result.1, handler.backupResult?.1)
    }
}

@MainActor
private final class MockSettingsContactsHandler: SettingsContactsHandling {
    var requestAccessCallCount = 0
    var createBackupCallCount = 0
    var backupResult: (URL?, URL?)?

    func requestAccess() async -> Bool {
        requestAccessCallCount += 1
        return true
    }

    func createBackup(saveToURL url: URL?) async -> (userBackup: URL?, appBackup: URL?) {
        createBackupCallCount += 1
        return backupResult ?? (nil, nil)
    }
}
