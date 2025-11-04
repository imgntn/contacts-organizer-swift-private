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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contactsManager)
                .environmentObject(appState)
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
        }
    }
}
