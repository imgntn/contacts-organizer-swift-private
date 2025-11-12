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
    @StateObject private var undoManager = ContactsUndoManager()

    @AppStorage("textScalePreference") private var textScalePreference = "normal"

    private var textScale: TextScale {
        TextScale(rawValue: textScalePreference) ?? .normal
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(contactsManager)
                .environmentObject(appState)
                .environmentObject(privacyMonitor)
                .environmentObject(undoManager)
                .environment(\.textScale, textScale)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) {
                Button(undoManager.undoDescription.map { "Undo \($0)" } ?? "Undo") {
                    undoManager.undo()
                }
                .disabled(!undoManager.canUndo)

                Button(undoManager.redoDescription.map { "Redo \($0)" } ?? "Redo") {
                    undoManager.redo()
                }
                .disabled(!undoManager.canRedo)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(contactsManager)
                .environmentObject(appState)
                .environmentObject(privacyMonitor)
                .environmentObject(undoManager)
                .environment(\.textScale, textScale)
        }
    }
}
