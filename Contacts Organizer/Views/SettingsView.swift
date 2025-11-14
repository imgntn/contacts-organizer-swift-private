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
    @EnvironmentObject var undoManager: ContactsUndoManager
    @AppStorage(SettingsPreferences.selectedTabKey) private var selectedTabRaw: String = SettingsTab.general.rawValue
    @AppStorage(SettingsPreferences.developerToggleKey) private var showDeveloperSettings: Bool = false
    private let preferenceStore = SettingsPreferenceStore.shared

    var body: some View {
        TabView(selection: $selectedTabRaw) {
            GeneralSettingsView(showDeveloperSettings: $showDeveloperSettings)
                .environmentObject(appState)
                .environmentObject(contactsManager)
                .environmentObject(undoManager)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general.rawValue)

            PrivacySettingsView()
                .environmentObject(contactsManager)
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }
                .tag(SettingsTab.permissions.rawValue)

            if showDeveloperSettings {
                DeveloperSettingsView()
                    .environmentObject(contactsManager)
                    .environmentObject(appState)
                    .tabItem {
                        Label("Developer", systemImage: "hammer.fill")
                    }
                    .tag(SettingsTab.developer.rawValue)
            }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about.rawValue)
        }
        .frame(width: 500, height: 700)
        .onAppear(perform: ensureValidSelection)
        .onChange(of: showDeveloperSettings) { _, newValue in
            preferenceStore.updateDeveloperSettings(enabled: newValue)
            ensureValidSelection()
        }
        .onChange(of: selectedTabRaw) { _, newValue in
            let tab = SettingsTab(rawValue: newValue) ?? .general
            preferenceStore.updateSelectedTab(to: tab)
        }
    }

    private var selectedTab: SettingsTab {
        SettingsTab(rawValue: selectedTabRaw) ?? .general
    }

    private func ensureValidSelection() {
        if !showDeveloperSettings && selectedTab == .developer {
            selectedTabRaw = SettingsTab.general.rawValue
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var undoManager: ContactsUndoManager
    @EnvironmentObject var diagnosticsCenter: DiagnosticsCenter
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("showCompletedActions") private var showCompletedActions = false
    @AppStorage("textScalePreference") private var textScalePreference = "normal"
    @Binding var showDeveloperSettings: Bool
    @State private var isCreatingBackup = false
    @State private var backupSuccess = false
    @State private var userBackupURL: URL?
    @State private var appBackupURL: URL?
    @State private var showSavePanel = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    private let preferenceStore = SettingsPreferenceStore.shared
    @State private var showingDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                GeneralSettingsHeader(
                    contactCount: contactsManager.contacts.count,
                    isAutoRefreshOn: autoRefresh,
                    lastBackupName: userBackupURL?.lastPathComponent
                )

                SettingsCard(
                    icon: "externaldrive.fill.badge.checkmark",
                    title: "Resilient Backups",
                    subtitle: "Create a primary and safety copy in one click",
                    accentColor: .blue
                ) {
                    VStack(spacing: 16) {
                        Button(action: { showSavePanel = true }) {
                            HStack(spacing: 12) {
                                if isCreatingBackup {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                        .tint(.white)
                                    Text("Creating backup...")
                                } else {
                                    Image(systemName: "shield.checkerboard")
                                        .imageScale(.medium)
                                    Text("Backup All Contacts")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isCreatingBackup)

                        if let url = userBackupURL {
                            InfoCallout(
                                icon: "clock.arrow.circlepath",
                                title: "Last backup",
                                detail: url.lastPathComponent,
                                footer: appBackupURL?.path
                            )
                        } else {
                            InfoCallout(
                                icon: "info.circle",
                                title: "Dual copies",
                                detail: "One goes wherever you choose, the other lives inside the app",
                                footer: nil
                            )
                        }
                    }
                }

                SettingsCard(
                    icon: "bolt.fill",
                    title: "Automation",
                    subtitle: "Decide how proactive the app should be",
                    accentColor: .orange
                ) {
                    VStack(spacing: 12) {
                        Toggle(isOn: $autoRefresh) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-refresh contacts")
                                Text("Stay up to date without manual syncs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: $showCompletedActions) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show completed actions")
                                Text("Keep a visual trail of what you’ve finished")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                SettingsCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Import & Export",
                    subtitle: "Bring data in or share a clean snapshot",
                    accentColor: .purple
                ) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            GeneralSettingsActionButton(
                                title: isImporting ? "Importing..." : "Import Contacts",
                                icon: "square.and.arrow.down",
                                isBusy: isImporting,
                                action: { showImportPicker = true }
                            )
                            .disabled(isImporting)

                            GeneralSettingsActionButton(
                                title: isExporting ? "Exporting..." : "Export Contacts",
                                icon: "square.and.arrow.up",
                                isBusy: isExporting,
                                action: { showExportPicker = true }
                            )
                            .disabled(isExporting || contactsManager.contacts.isEmpty)
                        }

                        InfoCallout(
                            icon: "doc.badge.ellipsis",
                            title: "JSON compatible",
                            detail: "Use exports as clean data snapshots or for migrations",
                            footer: "Current contacts: \(contactsManager.contacts.count)"
                        )
                    }
                }

                SettingsCard(
                    icon: "textformat.size",
                    title: "Appearance",
                    subtitle: "Match the interface to your reading comfort",
                    accentColor: .teal
                ) {
                    VStack(alignment: .leading, spacing: 16) {
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
                                .font(textScalePreference == "xlarge" ? .title3 : textScalePreference == "large" ? .headline : .subheadline)
                        }
                    }
                }

                SettingsCard(
                    icon: "terminal.fill",
                    title: "Advanced",
                    subtitle: "Expose developer-focused tooling when needed",
                    accentColor: .gray
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show developer options", isOn: $showDeveloperSettings)
                        Text("Enable this when you need access to the Developer tab for QA or support.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                SettingsCard(
                    icon: "stethoscope",
                    title: "Diagnostics & Logs",
                    subtitle: "Review recent warnings, errors, and performance notes",
                    accentColor: .gray.opacity(0.8)
                ) {
                    DiagnosticsPreviewCard(entry: diagnosticsCenter.entries.first) {
                        showingDiagnostics = true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileExporter(
            isPresented: $showSavePanel,
            document: BackupDocument(),
            contentType: .vCard,
            defaultFilename: generateBackupFilename()
        ) { result in
            handleBackupSave(result)
        }
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
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .onChange(of: textScalePreference) { _, newValue in
            preferenceStore.updateTextScale(to: newValue, undoManager: undoManager)
        }
        .onChange(of: autoRefresh) { _, newValue in
            preferenceStore.updateAutoRefresh(to: newValue, undoManager: undoManager)
        }
        .sheet(isPresented: $showingDiagnostics) {
            DiagnosticsView()
                .environmentObject(diagnosticsCenter)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                let controller = await SettingsActionController.sharedActor()
                let (userURL, appURL) = await controller.createBackup(saveTo: saveURL)

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

// MARK: - General Settings Helpers

private struct GeneralSettingsHeader: View {
    let contactCount: Int
    let isAutoRefreshOn: Bool
    let lastBackupName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stay in control")
                .font(.largeTitle.bold())

            Text("Backups, automation, and personalization in one tidy hub.")
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                StatPill(title: "Contacts synced", value: "\(contactCount)")
                StatPill(title: "Auto-refresh", value: isAutoRefreshOn ? "On" : "Off")
                StatPill(title: "Last backup", value: lastBackupName ?? "Not yet")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
        )
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        )
    }
}

private struct InfoCallout: View {
    let icon: String
    let title: String
    let detail: String
    let footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .imageScale(.medium)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            if let footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 26)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
    }
}

private struct DiagnosticsPreviewCard: View {
    let entry: DiagnosticsCenter.Entry?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let entry {
                HStack {
                    SeverityBadge(severity: entry.severity)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(entry.message)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                if let metadata = entry.metadata {
                    Text(metadata)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("All quiet for now.")
                        .font(.headline)
                    Text("We’ll surface warnings and slow operations here as they happen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                onOpen()
            } label: {
                Label("Open Diagnostics Console", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct GeneralSettingsActionButton: View {
    let title: String
    let icon: String
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .imageScale(.medium)
                }
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Developer Settings

struct DeveloperSettingsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState
    @State private var isLoadingTest = false
    @State private var testContactCount = 100
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                DeveloperSettingsHeader(
                    sampleSize: testContactCount,
                    isLoading: isLoadingTest
                )

                SettingsCard(
                    icon: "wrench.and.screwdriver",
                    title: "Test Data Lab",
                    subtitle: "Populate your workspace with realistic contacts",
                    accentColor: .indigo
                ) {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sample size")
                                    .font(.subheadline.bold())
                                Text("Choose how many demo contacts to generate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Stepper("\(testContactCount)", value: $testContactCount, in: 10...1000, step: 10)
                                .frame(width: 140)
                        }

                        GeneralSettingsActionButton(
                            title: isLoadingTest ? "Loading..." : "Load Test Database",
                            icon: "doc.on.doc.fill",
                            isBusy: isLoadingTest,
                            action: loadTestData
                        )
                        .disabled(isLoadingTest)

                        InfoCallout(
                            icon: "sparkles",
                            title: "What you get",
                            detail: "Contacts with duplicates, missing fields, and other real-world quirks.",
                            footer: nil
                        )
                    }
                }

                SettingsCard(
                    icon: "ladybug.fill",
                    title: "Debug Utilities",
                    subtitle: "Reset onboarding flows and prompts",
                    accentColor: .red
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Onboarding state")
                            .font(.subheadline.bold())
                        Text("Use this after UI or copy changes to replay the welcome experience.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button(action: resetOnboarding) {
                            Label("Reset Onboarding", systemImage: "arrow.counterclockwise.circle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }

                SettingsCard(
                    icon: "checklist",
                    title: "Testing Playbook",
                    subtitle: "Quick reminders before every release",
                    accentColor: .gray
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        DeveloperChecklistRow(text: "Load demo contacts and verify duplicate detection.")
                        DeveloperChecklistRow(text: "Confirm data quality warnings across all smart groups.")
                        DeveloperChecklistRow(text: "Run onboarding reset to validate the welcome flow.")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasSeenBackupReminder")
        appState.hasCompletedOnboarding = false
        appState.hasSeenBackupReminder = false
        appState.updateCurrentView()
    }
}

private struct DeveloperSettingsHeader: View {
    let sampleSize: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Build with confidence")
                .font(.largeTitle.bold())
            Text("Spin up data sets, reset flows, and follow the testing playbook before each release.")
                .foregroundColor(.secondary)
            DeveloperStatusPanel(sampleSize: sampleSize, isLoading: isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DeveloperStatusPanel: View {
    let sampleSize: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("READINESS SNAPSHOT")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                DeveloperStatusRow(
                    icon: "tray.full.fill",
                    iconColor: .indigo,
                    title: "\(sampleSize) contacts queued",
                    detail: "The generator will create this many demo contacts."
                )

                DeveloperStatusRow(
                    icon: isLoading ? "clock.fill" : "bolt.fill",
                    iconColor: isLoading ? .orange : .green,
                    title: isLoading ? "Generator is busy" : "Generator is idle",
                    detail: isLoading ? "Hang tight while we assemble the dataset." : "Ready for your next batch."
                )

                DeveloperStatusRow(
                    icon: "checklist.checked",
                    iconColor: .blue,
                    title: "3-item release playbook",
                    detail: "Test data lab, debug utilities, and onboarding reset."
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .controlBackgroundColor),
                            Color(nsColor: .controlBackgroundColor).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct DeveloperStatusRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct DeveloperChecklistRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(.accentColor)
                .imageScale(.small)
                .padding(.top, 2)
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
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

    private var isAuthorized: Bool {
        contactsManager.authorizationStatus == .authorized
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PrivacySettingsHeader(isAuthorized: isAuthorized)

                SettingsCard(
                    icon: "hand.raised.fill",
                    title: "Contacts Permission",
                    subtitle: "Control who can read your address book",
                    accentColor: .pink
                ) {
                    VStack(spacing: 16) {
                        HStack {
                            Text(isAuthorized ? "Access granted" : "Action required")
                                .font(.headline)
                            Spacer()
                            StatusBadge(isGranted: isAuthorized)
                        }

                        if !isAuthorized {
                            Button(action: requestAccess) {
                                Label("Request Access", systemImage: "checkmark.shield")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                        } else {
                            InfoCallout(
                                icon: "lock.shield",
                                title: "Ready to analyze",
                                detail: "All contact tools are enabled.",
                                footer: nil
                            )
                        }
                    }
                }

                SettingsCard(
                    icon: "key.fill",
                    title: "What access enables",
                    subtitle: "Grant contacts permission to unlock these tools",
                    accentColor: .green
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        PermissionBenefitRow(
                            icon: "wand.and.stars",
                            title: "Data cleanup",
                            detail: "Detect duplicates, incomplete entries, and inconsistent formatting."
                        )
                        PermissionBenefitRow(
                            icon: "square.and.arrow.up.on.square",
                            title: "Safe exports",
                            detail: "Generate JSON or vCard backups curated from your real contacts."
                        )
                        PermissionBenefitRow(
                            icon: "rectangle.stack.badge.plus",
                            title: "Bulk editing",
                            detail: "Merge, tag, or group contacts directly from the dashboard."
                        )
                    }
                }

                SettingsCard(
                    icon: "questionmark.circle",
                    title: "Permission troubleshooting",
                    subtitle: "Tips if macOS keeps the toggle off",
                    accentColor: .cyan
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        PermissionHelpRow(
                            title: "Enable manually",
                            detail: "System Settings → Privacy & Security → Contacts → turn on “Contacts Organizer”."
                        )
                        PermissionHelpRow(
                            title: "Already denied?",
                            detail: "Toggle the switch off/on or remove the app from the list, then relaunch."
                        )
                        PermissionHelpRow(
                            title: "Still stuck?",
                            detail: "Restart your Mac. Some sandbox resets require a log-out or reboot."
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func requestAccess() {
        Task {
            let controller = await SettingsActionController.sharedActor()
            _ = await controller.requestContactsAccess()
        }
    }
}

struct StatusBadge: View {
    let isGranted: Bool

    var body: some View {
        Text(isGranted ? "Granted" : "Denied")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isGranted ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
            .foregroundColor(isGranted ? .green : .red)
            .cornerRadius(8)
    }
}

private struct PrivacySettingsHeader: View {
    let isAuthorized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permission center")
                .font(.largeTitle.bold())
            Text("Grant contacts access and keep track of the current authorization state.")
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                PermissionStatusPill(
                    title: "Contacts permission",
                    value: isAuthorized ? "Granted" : "Needs access",
                    icon: isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                    iconColor: isAuthorized ? .green : .orange
                )
                PermissionStatusPill(
                    title: "Automation status",
                    value: isAuthorized ? "Enabled" : "Paused",
                    icon: "bolt.fill",
                    iconColor: isAuthorized ? .green : .gray
                )
                PermissionStatusPill(
                    title: "Next step",
                    value: isAuthorized ? "Good to go!" : "Request access",
                    icon: isAuthorized ? "hand.thumbsup.fill" : "hand.point.up.left.fill",
                    iconColor: isAuthorized ? .blue : .orange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionBenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.green.opacity(0.15))
                Image(systemName: icon)
                    .foregroundColor(.green)
                    .imageScale(.medium)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionHelpRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct PermissionStatusPill: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .imageScale(.small)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        )
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

#if !DISABLE_PREVIEWS
#Preview {
    SettingsView()
        .environmentObject(ContactsManager.shared)
        .environmentObject(AppState())
        .environmentObject(PrivacyMonitorService.shared)
        .environmentObject(ContactsUndoManager())
}
#endif
