//
//  SettingsView.swift
//  Contacts Organizer
//
//  Application settings and preferences
//

import SwiftUI
import Contacts
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var privacyMonitor: PrivacyMonitorService

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .environmentObject(contactsManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            PrivacyDashboardView()
                .environmentObject(privacyMonitor)
                .tabItem {
                    Label("Privacy Dashboard", systemImage: "lock.shield.fill")
                }

            PrivacySettingsView()
                .environmentObject(contactsManager)
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            DeveloperSettingsView()
                .environmentObject(contactsManager)
                .tabItem {
                    Label("Developer", systemImage: "hammer.fill")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 700)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("showCompletedActions") private var showCompletedActions = false
    @AppStorage("textScalePreference") private var textScalePreference = "large"
    @State private var isCreatingBackup = false
    @State private var backupSuccess = false
    @State private var userBackupURL: URL?
    @State private var appBackupURL: URL?
    @State private var showSavePanel = false

    var body: some View {
        Form {
            Section {
                Toggle("Automatically refresh contacts", isOn: $autoRefresh)

                Toggle("Show completed actions", isOn: $showCompletedActions)
            } header: {
                Text("Preferences")
            }

            Section {
                Picker("Text Size", selection: $textScalePreference) {
                    Text("Normal").tag("normal")
                    Text("Large").tag("large")
                    Text("Extra Large").tag("xlarge")
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Contacts look clearer with larger text")
                        .font(.headline)
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Button(action: { showSavePanel = true }) {
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
        .fileExporter(
            isPresented: $showSavePanel,
            document: BackupDocument(),
            contentType: .vCard,
            defaultFilename: generateBackupFilename()
        ) { result in
            handleBackupSave(result)
        }
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

    private func generateBackupFilename() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        return "Contacts_Backup_\(timestamp).vcf"
    }

    private func handleBackupSave(_ result: Result<URL, Error>) {
        isCreatingBackup = true

        Task {
            do {
                let saveURL = try result.get()
                let (userURL, appURL) = await contactsManager.createBackup(saveToURL: saveURL)

                await MainActor.run {
                    isCreatingBackup = false
                    if userURL != nil {
                        userBackupURL = userURL
                        appBackupURL = appURL
                        backupSuccess = true
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingBackup = false
                    contactsManager.errorMessage = "Failed to save backup: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Developer Settings

struct DeveloperSettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var isLoadingTest = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var testContactCount = 100
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Test Contacts:")
                        Stepper("\(testContactCount)", value: $testContactCount, in: 10...1000, step: 10)
                            .frame(width: 120)
                    }

                    Button(action: loadTestData) {
                        HStack {
                            if isLoadingTest {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                                Text("Loading...")
                            } else {
                                Image(systemName: "doc.on.doc.fill")
                                Text("Load Test Database")
                            }
                        }
                    }
                    .disabled(isLoadingTest)

                    Text("Generates realistic test contacts with duplicates and incomplete data for testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Test Data")
            }

            Section {
                Button(action: { showImportPicker = true }) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Importing...")
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Contacts")
                        }
                    }
                }
                .disabled(isImporting)

                Button(action: { showExportPicker = true }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                            Text("Exporting...")
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Contacts")
                        }
                    }
                }
                .disabled(isExporting || contactsManager.contacts.isEmpty)

                Text("Import/export contacts as JSON. Current contacts: \(contactsManager.contacts.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Import/Export")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Load test database to populate with sample contacts")
                    Text("• Test duplicate detection and data quality features")
                    Text("• Export current contacts to backup or share")
                    Text("• Import previously exported contacts")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("Usage")
            }
        }
        .padding(20)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: ContactsDocument(contacts: contactsManager.contacts),
            contentType: .json,
            defaultFilename: "contacts_export.json"
        ) { result in
            handleExport(result)
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
    }

    private func loadTestData() {
        isLoadingTest = true

        Task {
            await contactsManager.loadTestContacts(count: testContactCount)

            await MainActor.run {
                isLoadingTest = false
                successMessage = "Loaded \(testContactCount) test contacts successfully!"
                showSuccessAlert = true
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        isImporting = true

        Task {
            do {
                let url = try result.get().first!
                await contactsManager.importContacts(from: url)

                await MainActor.run {
                    isImporting = false
                    successMessage = "Imported \(contactsManager.contacts.count) contacts successfully!"
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    contactsManager.errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        isExporting = true

        Task {
            do {
                let url = try result.get()
                let success = await contactsManager.exportContacts(to: url)

                await MainActor.run {
                    isExporting = false
                    if success {
                        successMessage = "Exported \(contactsManager.contacts.count) contacts to \(url.lastPathComponent)"
                        showSuccessAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    contactsManager.errorMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Documents (for FileExporter)

// Empty document for backup file exporter (actual backup is created by ContactsManager)
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.vCard]

    init() {}

    init(configuration: ReadConfiguration) throws {
        // Not used for backup export
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Return empty wrapper - actual backup is created by ContactsManager
        return FileWrapper(regularFileWithContents: Data())
    }
}

struct ContactsDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]

    var contacts: [ContactSummary]

    init(contacts: [ContactSummary]) {
        self.contacts = contacts
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        contacts = try ImportExportService.shared.importContactsFromData(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try ImportExportService.shared.exportContactsToJSON(contacts)
        return FileWrapper(regularFileWithContents: data)
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
        .environmentObject(PrivacyMonitorService.shared)
}
