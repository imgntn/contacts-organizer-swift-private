//
//  FirstBackupSheet.swift
//  Contacts Organizer
//
//  Guides the user to create an initial backup before proceeding
//

import SwiftUI

struct FirstBackupSheet: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingBackup = false
    @State private var userBackupURL: URL?
    @State private var appBackupURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Create Your First Backup")
                    .font(.title.bold())
            }

            Text("Before you start organizing and cleaning up your contacts, we strongly recommend creating a backup. We'll save TWO backups: one to your chosen location (default: Downloads) and a safety copy in the app's folder.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // Backup details / result
            if let userURL = userBackupURL {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your backup: \(userURL.lastPathComponent)", systemImage: "externaldrive.fill.badge.checkmark")
                        .font(.subheadline)
                    if let safetyURL = appBackupURL {
                        Label("Safety copy: \(safetyURL.path)", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                }
                .font(.caption)
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Not Now") {
                    // Allow skipping, but user remains responsible
                    UserDefaults.standard.set(true, forKey: "hasCreatedFirstBackup")
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(action: createBackup) {
                    HStack {
                        if isCreatingBackup {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                            Text("Creating backup…")
                        } else {
                            Image(systemName: "externaldrive.fill.badge.checkmark")
                            Text(userBackupURL == nil ? "Create Backup Now" : "Done")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingBackup)

                if userBackupURL != nil {
                    Button("Show in Finder") {
                        if let url = userBackupURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(32)
        .frame(width: 520)
    }

    private func createBackup() {
        guard !isCreatingBackup else { return }
        errorMessage = nil
        isCreatingBackup = true

        Task {
            let (userURL, safetyURL) = await contactsManager.createBackup()

            await MainActor.run {
                isCreatingBackup = false
                if let userURL = userURL {
                    self.userBackupURL = userURL
                    self.appBackupURL = safetyURL
                    // Mark onboarding backup step complete
                    UserDefaults.standard.set(true, forKey: "hasCreatedFirstBackup")
                    // Dismiss sheet; PermissionRequestView.onDisappear will advance app state
                    dismiss()
                } else {
                    errorMessage = contactsManager.errorMessage ?? "Failed to create backup."
                }
            }
        }
    }
}

#Preview {
    FirstBackupSheet()
        .environmentObject(ContactsManager.shared)
}
