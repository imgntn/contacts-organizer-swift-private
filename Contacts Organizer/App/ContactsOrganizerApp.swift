//
//  ContactsOrganizerApp.swift
//  Contacts Organizer
//
//  Created on 2025-01-01
//

import SwiftUI
import Combine

@main
struct ContactsOrganizerApp: App {
    @StateObject private var contactsManager = ContactsManager.shared
    @StateObject private var appState = AppState()
    @StateObject private var privacyMonitor = PrivacyMonitorService.shared

    @AppStorage("textScalePreference") private var textScalePreference = "large"

    private var mappedDynamicTypeSize: DynamicTypeSize {
        switch textScalePreference {
        case "normal": return .large
        case "xlarge": return .accessibility2
        default: return .accessibility1
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contactsManager)
                .environmentObject(appState)
                .environmentObject(privacyMonitor)
                .dynamicTypeSize(mappedDynamicTypeSize)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(contactsManager)
                .environmentObject(appState)
                .environmentObject(privacyMonitor)
                .dynamicTypeSize(mappedDynamicTypeSize)
        }
    }
}
