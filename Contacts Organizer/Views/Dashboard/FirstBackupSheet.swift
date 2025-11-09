//
//  FirstBackupSheet.swift
//  Contacts Organizer
//
//  First launch backup reminder with save location picker
//

import SwiftUI

struct FirstBackupSheet: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @Environment(\.dismiss) var dismiss
    @State private var isCreatingBackup = false
    @State private var backupComplete = false
    @State private var userBackupURL: URL?
    @State private var appBackupURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .responsiveFont(60)
                .foregroundStyle(.blue.gradient)

            // Title
            Text("Create Your First Backup")
                .responsiveFont(28, weight: .bold)

            // Description
            VStack(spacing: 12) {
                Text("Before using Contacts Organizer, we strongly recommend creating a backup of all your contacts.")
                    .font(.body)
                    .multilineTextAlignment(.center)

                Text("We'll save TWO copies for maximum safety:")
                    .font(.body.bold())
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 500)

            // Features
            VStack(alignment: .leading, spacing: 12) {
                BackupFeatureRow(
                    number: "1",
                    text: "Your chosen location (you pick where)",
                    color: .blue
                )
                BackupFeatureRow(
                    number: "2",
                    text: "App's safety folder (automatic failsafe)",
                    color: .green
                )
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            if backupComplete {
                // Success state
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Backup Created Successfully!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }

                    if let url = userBackupURL {
                        Text("Your backup: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let url = appBackupURL {
                        Text("Safety backup: \(url.path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Show My Backup in Finder") {
                        if let url = userBackupURL {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                if !backupComplete {
                    Button("Skip (Not Recommended)") {
                        UserDefaults.standard.set(true, forKey: "hasCreatedFirstBackup")
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)

                    Button(action: createBackup) {
                        HStack {
                            if isCreatingBackup {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                                Text("Creating Backup...")
                            } else {
                                Image(systemName: "externaldrive.fill")
                                Text("Create Backup Now")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isCreatingBackup)
                } else {
                    Button("Continue to App") {
                        UserDefaults.standard.set(true, forKey: "hasCreatedFirstBackup")
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(40)
        .frame(width: 600, height: 550)
    }

    private func createBackup() {
        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Save Contacts Backup"
        savePanel.message = "Choose where to save your contacts backup file"
        savePanel.nameFieldLabel = "Backup File:"
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.allowedContentTypes = [.vCard]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "Contacts_Backup_\(timestamp).vcf"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else {
                return
            }

            isCreatingBackup = true

            Task {
                let (userURL, appURL) = await contactsManager.createBackup(saveToURL: url)

                await MainActor.run {
                    isCreatingBackup = false
                    if userURL != nil {
                        userBackupURL = userURL
                        appBackupURL = appURL
                        backupComplete = true
                    }
                }
            }
        }
    }
}

struct BackupFeatureRow: View {
    let number: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)

                Text(number)
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    FirstBackupSheet()
        .environmentObject(ContactsManager.shared)
}
