//
//  SettingsView.swift
//  Contacts Organizer
//
//  Application settings and preferences
//

import SwiftUI
import Contacts

struct SettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .environmentObject(contactsManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("showCompletedActions") private var showCompletedActions = false
    @State private var isCreatingBackup = false
    @State private var backupSuccess = false
    @State private var userBackupURL: URL?
    @State private var appBackupURL: URL?

    var body: some View {
        Form {
            Section {
                Toggle("Automatically refresh contacts", isOn: $autoRefresh)

                Toggle("Show completed actions", isOn: $showCompletedActions)
            } header: {
                Text("Preferences")
            }

            Section {
                Button(action: createBackup) {
                    HStack {
                        if isCreatingBackup {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Creating backup...")
                        } else {
                            Image(systemName: "externaldrive.fill.badge.checkmark")
                            Text("Backup All Contacts")
                        }
                    }
                }
                .disabled(isCreatingBackup)

                if let url = userBackupURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last backup: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let safetyURL = appBackupURL {
                            Text("Safety copy: \(safetyURL.path)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text("Creates TWO backups: one in your chosen location and a safety copy in the app's folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Safety")
            }

            Section {
                Button("Reset Onboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    appState.hasCompletedOnboarding = false
                    appState.updateCurrentView()
                }
                .foregroundColor(.red)

                Text("Restart onboarding flow (for testing)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Debug")
            }
        }
        .padding(20)
        .alert("Backup Created", isPresented: $backupSuccess) {
            Button("Show in Finder") {
                if let url = userBackupURL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            if let userURL = userBackupURL, let appURL = appBackupURL {
                Text("TWO backups created:\n\n1. Your backup: \(userURL.lastPathComponent)\n2. Safety backup: \(appURL.path)")
            } else if let userURL = userBackupURL {
                Text("Backup saved to:\n\(userURL.lastPathComponent)")
            }
        }
    }

    private func createBackup() {
        isCreatingBackup = true

        Task {
            let (userURL, appURL) = await contactsManager.createBackup()

            await MainActor.run {
                isCreatingBackup = false
                if userURL != nil {
                    userBackupURL = userURL
                    appBackupURL = appURL
                    backupSuccess = true
                }
            }
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Contacts Access")
                    Spacer()
                    StatusBadge(isGranted: contactsManager.authorizationStatus == .authorized)
                }

                if contactsManager.authorizationStatus != .authorized {
                    Button("Request Access") {
                        Task {
                            await contactsManager.requestAccess()
                        }
                    }
                }
            } header: {
                Text("Permissions")
            }

            Section {
                Text("All data processing happens locally on your Mac. Your contact information never leaves your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("We do not collect, store, or transmit any of your personal information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Privacy Policy")
            }
        }
        .padding(20)
    }
}

struct StatusBadge: View {
    let isGranted: Bool

    var body: some View {
        Text(isGranted ? "Granted" : "Denied")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isGranted ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(isGranted ? .green : .red)
            .cornerRadius(6)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 8) {
                Text("Contacts Organizer")
                    .font(.title.bold())

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                Text("Keep your contacts clean and organized")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Text("Built with privacy in mind")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                // IMPORTANT: Update these URLs after hosting privacy-policy.html and support.html
                // See HOSTING_INSTRUCTIONS.md for setup guide
                // Example: https://[YOUR_USERNAME].github.io/contacts-organizer-web/privacy-policy.html
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Support", destination: URL(string: "https://example.com/support")!)

                Text("Note: Update URLs in SettingsView.swift after hosting")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding(40)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ContactsManager.shared)
        .environmentObject(AppState())
}
