import Foundation

@MainActor
final class SettingsPreferenceStore {
    static let shared = SettingsPreferenceStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func updateTextScale(to newValue: String, undoManager: ContactsUndoManager?) {
        let key = "textScalePreference"
        let previous = defaults.string(forKey: key) ?? "normal"
        guard previous != newValue else { return }
        defaults.set(newValue, forKey: key)
        undoManager?.register(description: "Text size") { [weak self] in
            self?.defaults.set(previous, forKey: key)
            return true
        } redo: { [weak self] in
            self?.defaults.set(newValue, forKey: key)
            return true
        }
    }

    func updateAutoRefresh(to newValue: Bool, undoManager: ContactsUndoManager?) {
        let key = "autoRefresh"
        let previous = defaults.object(forKey: key) as? Bool ?? true
        guard previous != newValue else { return }
        defaults.set(newValue, forKey: key)
        undoManager?.register(description: "Auto-refresh") { [weak self] in
            self?.defaults.set(previous, forKey: key)
            return true
        } redo: { [weak self] in
            self?.defaults.set(newValue, forKey: key)
            return true
        }
    }

    func updateSelectedTab(to tab: SettingsTab) {
        defaults.set(tab.rawValue, forKey: SettingsPreferences.selectedTabKey)
    }

    func updateDeveloperSettings(enabled: Bool) {
        defaults.set(enabled, forKey: SettingsPreferences.developerToggleKey)
    }
}
