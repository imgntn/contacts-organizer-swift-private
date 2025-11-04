//
//  PermissionRequestView.swift
//  Contacts Organizer
//
//  Requests and handles Contacts access permission
//

import SwiftUI
import Contacts

struct PermissionRequestView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var isRequesting = false
    @State private var showDeniedAlert = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)

            // Title and description
            VStack(spacing: 16) {
                Text("Contacts Access Required")
                    .font(.system(size: 32, weight: .bold))

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
                    // Show alert about limited functionality
                    showDeniedAlert = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(40)
        .background(Color(.windowBackgroundColor))
        .alert("Access Required", isPresented: $showDeniedAlert) {
            Button("Request Access", role: .none) {
                requestPermission()
            }
            Button("Quit", role: .cancel) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("Contacts Organizer requires access to your contacts to function. Without this permission, the app cannot perform any operations.")
        }
    }

    private func requestPermission() {
        isRequesting = true

        Task {
            let granted = await contactsManager.requestAccess()

            await MainActor.run {
                isRequesting = false

                if granted {
                    appState.updateAuthorizationStatus(.authorized)
                } else {
                    showDeniedAlert = true
                }
            }
        }
    }
}

// MARK: - Feature Row

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
