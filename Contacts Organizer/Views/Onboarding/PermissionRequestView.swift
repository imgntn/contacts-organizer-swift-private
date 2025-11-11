//
//  PermissionRequestView.swift
//  Contacts Organizer
//
//  Requests and handles Contacts access permission
//

import SwiftUI
import Contacts
import AppKit

struct PermissionRequestView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var isRequesting = false
    @State private var showPermissionAlert = false
    @State private var showFirstBackupSheet = false
    @State private var alertMode: PermissionAlertMode = .info

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle.badge.questionmark")
                .responsiveFont(80)
                .foregroundStyle(.blue.gradient)

            // Title and description
            VStack(spacing: 16) {
                Text("Contacts Access Required")
                    .responsiveFont(32, weight: .bold)

                Text("Contacts Organizer needs access to your contacts to help you find duplicates, organize groups, and improve data quality.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                PermissionFeatureRow(
                    icon: "checkmark.shield.fill",
                    text: "All processing happens locally on your Mac",
                    color: .green
                )
                PermissionFeatureRow(
                    icon: "eye.slash.fill",
                    text: "Your data never leaves your device",
                    color: .blue
                )
                PermissionFeatureRow(
                    icon: "lock.fill",
                    text: "No tracking, analytics, or cloud sync",
                    color: .purple
                )
            }
            .padding(.horizontal, 80)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: requestPermission) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isRequesting ? "Requesting..." : "Grant Access")
                    }
                    .frame(maxWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting)

                Button("Maybe Later") {
                    alertMode = .info
                    showPermissionAlert = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(40)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showFirstBackupSheet) {
            FirstBackupSheet()
                .environmentObject(contactsManager)
                .onDisappear {
                    // Update app state to show dashboard after sheet is dismissed
                    appState.updateAuthorizationStatus(.authorized)
                }
        }
        .alert(alertTitle, isPresented: $showPermissionAlert) {
            if alertMode == .settingsRequired {
                Button("Open System Settings") {
                    openContactsSettingsPane()
                }
                Button("Check Again") {
                    requestPermission()
                }
            } else {
                Button("Request Access", role: .none) {
                    requestPermission()
                }
            }
            Button("Quit", role: .cancel) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func requestPermission() {
        let status = contactsManager.authorizationStatus

        if status == .authorized {
            appState.updateAuthorizationStatus(.authorized)
            return
        }

        if status == .denied || status == .restricted {
            print("⚠️ Contacts access previously denied. Directing user to System Settings.")
            alertMode = .settingsRequired
            showPermissionAlert = true
            openContactsSettingsPane()
            return
        }

        print("🔐 Permission request initiated")
        isRequesting = true

        Task {
            let granted = await contactsManager.requestAccess()
            print("🔐 Permission result: \(granted)")

            await MainActor.run {
                isRequesting = false

                if granted {
                    print("✅ Permission granted, updating app state")

                    // Check if user has created first backup
                    let hasCreatedFirstBackup = UserDefaults.standard.bool(forKey: "hasCreatedFirstBackup")

                    if !hasCreatedFirstBackup {
                        // Show first backup sheet
                        showFirstBackupSheet = true
                    } else {
                        // Go directly to dashboard
                        appState.updateAuthorizationStatus(.authorized)
                    }
                } else {
                    print("❌ Permission denied, showing alert")
                    let needsSettings = contactsManager.authorizationStatus == .denied || contactsManager.authorizationStatus == .restricted
                    alertMode = needsSettings ? .settingsRequired : .info
                    showPermissionAlert = true

                    if needsSettings {
                        openContactsSettingsPane()
                    }
                }
            }
        }
    }

    private func openContactsSettingsPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        }
    }

    private var alertTitle: String {
        alertMode == .settingsRequired ? "Enable Contacts Access" : "Access Required"
    }

    private var alertMessage: String {
        if alertMode == .settingsRequired {
            return "Contacts Organizer has been denied access. Please enable Contacts access for this app in System Settings › Privacy & Security › Contacts, then return to continue."
        } else {
            return "Contacts Organizer requires access to your contacts to function. Without this permission, the app cannot perform any operations."
        }
    }
}

// MARK: - Feature Row

private enum PermissionAlertMode {
    case info
    case settingsRequired
}

struct PermissionFeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PermissionRequestView()
        .environmentObject(AppState())
        .environmentObject(ContactsManager.shared)
        .frame(width: 900, height: 600)
}
