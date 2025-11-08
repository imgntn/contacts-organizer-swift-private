//
//  SettingsView.swift
//  Contacts Organizer
//
//  Application settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
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
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("showCompletedActions") private var showCompletedActions = false

    var body: some View {
        Form {
            Section {
                Toggle("Automatically refresh contacts", isOn: $autoRefresh)

                Toggle("Show completed actions", isOn: $showCompletedActions)
            } header: {
                Text("Preferences")
            }

            Section {
                Button("Reset Onboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
                .foregroundColor(.red)
            } header: {
                Text("Advanced")
            }
        }
        .padding(20)
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
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Support", destination: URL(string: "https://example.com/support")!)
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
