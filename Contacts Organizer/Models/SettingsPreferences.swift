//
//  SettingsPreferences.swift
//  Contacts Organizer
//
//  Shared constants for user-facing Settings behavior.
//

import Foundation

enum SettingsTab: String {
    case general
    case permissions
    case developer
    case about
}

enum SettingsPreferences {
    static let selectedTabKey = "settingsSelectedTab"
    static let developerToggleKey = "showDeveloperSettings"
}
