import XCTest
@testable import Contacts_Organizer

@MainActor
final class SettingsPreferenceStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var undoManager: ContactsUndoManager!
    private var store: SettingsPreferenceStore!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "SettingsPreferenceStoreTests")!
        defaults.removePersistentDomain(forName: "SettingsPreferenceStoreTests")
        undoManager = ContactsUndoManager()
        store = SettingsPreferenceStore(defaults: defaults)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: "SettingsPreferenceStoreTests")
        defaults = nil
        store = nil
    }

    func testUpdateTextScalePersistsAndIsUndoable() async {
        defaults.set("normal", forKey: "textScalePreference")

        store.updateTextScale(to: "large", undoManager: undoManager)
        XCTAssertEqual(defaults.string(forKey: "textScalePreference"), "large")

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(defaults.string(forKey: "textScalePreference"), "normal")

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(defaults.string(forKey: "textScalePreference"), "large")
    }

    func testUpdateAutoRefreshPersistsAndIsUndoable() async {
        defaults.set(false, forKey: "autoRefresh")

        store.updateAutoRefresh(to: true, undoManager: undoManager)
        XCTAssertEqual(defaults.bool(forKey: "autoRefresh"), true)

        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertEqual(defaults.bool(forKey: "autoRefresh"), false)

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertEqual(defaults.bool(forKey: "autoRefresh"), true)
    }

    func testUpdateSelectedTabPersistsKey() async {
        store.updateSelectedTab(to: .permissions)
        XCTAssertEqual(defaults.string(forKey: SettingsPreferences.selectedTabKey), SettingsTab.permissions.rawValue)
    }

    func testUpdateDeveloperSettingsPersistsKey() async {
        store.updateDeveloperSettings(enabled: true)
        XCTAssertTrue(defaults.bool(forKey: SettingsPreferences.developerToggleKey))
    }
}
