//
//  GroupsView.swift
//  Contacts Organizer
//
//  View for managing contact groups
//

import SwiftUI
import Contacts

struct GroupsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var showCreateGroupSheet = false
    @State private var showSmartGroupSheet = false
    @State private var smartGroupResults: [SmartGroupResult] = []
    @State private var selectedTab: GroupTab = .manual
    @State private var isCreatingGroups = false
    @State private var showResultsAlert = false
    @State private var creationResults: CreationResults?
    @State private var showConfirmCreate = false
    @State private var groupToCreate: SmartGroupResult?
    @State private var duplicateGroupCount = 0
    @State private var showConfirmCleanup = false
    @State private var isCleaningDuplicates = false
    @State private var showCleanupResults = false
    @State private var cleanupResults: CleanupResults?

    struct CreationResults {
        let successCount: Int
        let failureCount: Int
        let failedGroups: [String]
    }

    struct CleanupResults {
        let deletedCount: Int
        let errorCount: Int
    }

    enum GroupTab: String, CaseIterable {
        case manual = "Manual Groups"
        case smart = "Smart Groups"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Groups")
                        .font(.system(size: 36, weight: .bold))

                    Text(headerSubtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tab selector
                Picker("Group Type", selection: $selectedTab) {
                    ForEach(GroupTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                if selectedTab == .manual {
                    if duplicateGroupCount > 0 {
                        Button(action: { showConfirmCleanup = true }) {
                            HStack {
                                if isCleaningDuplicates {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                }
                                Label(isCleaningDuplicates ? "Cleaning..." : "Clean Up \(duplicateGroupCount) Duplicates", systemImage: "trash")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isCleaningDuplicates)
                    }

                    Button(action: { showCreateGroupSheet = true }) {
                        Label("Create Group", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: { showSmartGroupSheet = true }) {
                        HStack {
                            if isCreatingGroups {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            }
                            Label(isCreatingGroups ? "Creating Groups..." : "Generate Smart Groups", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreatingGroups)
                }
            }
            .padding(24)

            Divider()

            // Content based on selected tab
            Group {
                if selectedTab == .manual {
                    manualGroupsContent
                } else {
                    smartGroupsContent
                }
            }
        }
        .task {
            await contactsManager.fetchAllGroups()

            // Auto-generate smart groups for display (synthetic/in-memory only)
            // They won't be created in Contacts.app unless user explicitly clicks "Create in Contacts"
            await generateSmartGroupsAsync()

            // Check for duplicate groups
            let duplicates = await contactsManager.findDuplicateGroups()
            duplicateGroupCount = duplicates.values.reduce(0) { $0 + $1.count - 1 }
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateGroupSheet()
        }
        .sheet(isPresented: $showSmartGroupSheet) {
            SmartGroupConfigSheet(onGenerate: { definitions in
                // Use async version to avoid blocking UI
                Task {
                    await generateSmartGroupsAsync(definitions: definitions)
                }
            })
        }
        .alert("Create Smart Group in Contacts?", isPresented: $showConfirmCreate, presenting: groupToCreate) { result in
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                Task {
                    await confirmAndCreateGroup()
                }
            }
        } message: { result in
            Text("This will create a new group '\(result.groupName)' with \(result.contacts.count) contact\(result.contacts.count == 1 ? "" : "s") in your Contacts app.")
        }
        .alert("Clean Up Duplicate Groups?", isPresented: $showConfirmCleanup) {
            Button("Cancel", role: .cancel) { }
            Button("Clean Up", role: .destructive) {
                Task {
                    await cleanUpDuplicates()
                }
            }
        } message: {
            Text("This will delete \(duplicateGroupCount) duplicate group\(duplicateGroupCount == 1 ? "" : "s") from your Contacts app, keeping the first occurrence of each.")
        }
        .alert("Duplicate Cleanup Complete", isPresented: $showCleanupResults, presenting: cleanupResults) { results in
            Button("OK") { }
        } message: { results in
            if results.errorCount == 0 {
                Text("Successfully deleted \(results.deletedCount) duplicate group\(results.deletedCount == 1 ? "" : "s") from Contacts.app!")
            } else {
                Text("Deleted \(results.deletedCount) group\(results.deletedCount == 1 ? "" : "s"), but \(results.errorCount) failed. Please check Contacts app permissions.")
            }
        }
        .alert("Smart Groups Created", isPresented: $showResultsAlert, presenting: creationResults) { results in
            Button("OK") { }
        } message: { results in
            if results.failureCount == 0 {
                Text("Successfully created \(results.successCount) smart group\(results.successCount == 1 ? "" : "s") in Contacts.app!")
            } else if results.successCount == 0 {
                Text("Failed to create \(results.failureCount) group\(results.failureCount == 1 ? "" : "s"). Please check Contacts app permissions.")
            } else {
                Text("Created \(results.successCount) group\(results.successCount == 1 ? "" : "s") successfully. Failed to create \(results.failureCount) group\(results.failureCount == 1 ? "" : "s"): \(results.failedGroups.joined(separator: ", "))")
            }
        }
    }

    private var headerSubtitle: String {
        if selectedTab == .manual {
            return "\(contactsManager.groups.count) manual groups"
        } else {
            return "\(smartGroupResults.count) smart groups"
        }
    }

    @ViewBuilder
    private var manualGroupsContent: some View {
        if contactsManager.groups.isEmpty {
            EmptyStateView(
                icon: "folder.fill.badge.plus",
                title: "No Manual Groups",
                message: "Create groups to organize your contacts manually.",
                color: .blue
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(contactsManager.groups, id: \.identifier) { group in
                        GroupRowView(group: group)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var smartGroupsContent: some View {
        if smartGroupResults.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple.gradient)

                VStack(spacing: 8) {
                    Text("Smart Groups")
                        .font(.title.bold())

                    Text("Automatically organize contacts by organization, criteria, or custom rules.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "building.2.fill", text: "Organization-based groups", color: .green)
                    FeatureRow(icon: "star.fill", text: "Custom smart groups", color: .orange)
                    FeatureRow(icon: "checkmark.circle.fill", text: "Dynamic criteria", color: .blue)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                Button(action: {
                    Task {
                        await generateSmartGroupsAsync()
                    }
                }) {
                    HStack {
                        if isCreatingGroups {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Label(isCreatingGroups ? "Creating Groups..." : "Generate Default Smart Groups", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingGroups)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(smartGroupResults) { result in
                        SmartGroupResultCard(result: result) {
                            Task {
                                await createSingleSmartGroup(result)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    @MainActor
    private func generateSmartGroupsAsync(definitions: [SmartGroupDefinition]? = nil) async {
        let defs = definitions ?? ContactsManager.defaultSmartGroups
        let results = await contactsManager.generateSmartGroups(definitions: defs)

        if definitions == nil {
            // Initial load - replace with defaults
            smartGroupResults = results
        } else {
            // User-triggered generation - merge without duplicates
            for newGroup in results {
                // Only add if a group with this name doesn't already exist
                if let index = smartGroupResults.firstIndex(where: { $0.groupName == newGroup.groupName }) {
                    // Update existing group with fresh data
                    smartGroupResults[index] = newGroup
                } else {
                    // Add new group
                    smartGroupResults.append(newGroup)
                }
            }
        }
        // Smart groups are now synthetic (in-memory only)
        // User must explicitly click "Create in Contacts" button to add them
    }

    @MainActor
    private func createSingleSmartGroup(_ result: SmartGroupResult) async {
        groupToCreate = result
        showConfirmCreate = true
    }

    @MainActor
    private func confirmAndCreateGroup() async {
        guard let result = groupToCreate else { return }

        isCreatingGroups = true

        let contactIds = result.contacts.map { $0.id }
        let success = await contactsManager.createGroup(
            name: result.groupName,
            contactIds: contactIds
        )

        isCreatingGroups = false

        // Show result
        if success {
            creationResults = CreationResults(
                successCount: 1,
                failureCount: 0,
                failedGroups: []
            )
        } else {
            creationResults = CreationResults(
                successCount: 0,
                failureCount: 1,
                failedGroups: [result.groupName]
            )
        }
        showResultsAlert = true

        // Refresh groups list
        await contactsManager.fetchAllGroups()
    }

    @MainActor
    private func cleanUpDuplicates() async {
        isCleaningDuplicates = true

        let (deleted, errors) = await contactsManager.deleteDuplicateGroups(keepFirst: true)

        isCleaningDuplicates = false

        // Show cleanup result (separate from creation results)
        cleanupResults = CleanupResults(
            deletedCount: deleted,
            errorCount: errors
        )
        showCleanupResults = true

        // Refresh duplicate count
        let duplicates = await contactsManager.findDuplicateGroups()
        duplicateGroupCount = duplicates.values.reduce(0) { $0 + $1.count - 1 }
    }

    @MainActor
    private func createSmartGroupsInContactsApp() async {
        var successCount = 0
        var failedGroups: [String] = []

        // Create actual groups in Contacts.app for each smart group result
        for result in smartGroupResults {
            let contactIds = result.contacts.map { $0.id }
            let success = await contactsManager.createGroup(
                name: result.groupName,
                contactIds: contactIds
            )

            if success {
                successCount += 1
                print("✅ Created group: \(result.groupName) with \(contactIds.count) contacts")
            } else {
                failedGroups.append(result.groupName)
                print("❌ Failed to create group: \(result.groupName)")
            }
        }

        // Refresh the manual groups list to show newly created groups
        await contactsManager.fetchAllGroups()

        // Show results to user
        creationResults = CreationResults(
            successCount: successCount,
            failureCount: failedGroups.count,
            failedGroups: failedGroups
        )
        showResultsAlert = true
    }
}

struct GroupRowView: View {
    let group: CNGroup

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)

                Text("Group ID: \(group.identifier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                openGroupInContacts(groupName: group.name)
            }) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private func openGroupInContacts(groupName: String) {
        let bundleIdentifier = "com.apple.AddressBook"

        // Check if Contacts is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let contactsApp = runningApps.first { $0.bundleIdentifier == bundleIdentifier }

        if let app = contactsApp {
            // App is running - activate it (this actually works from sandboxed apps!)
            app.activate()
        } else {
            // App not running - launch it using modern API
            let appURL = URL(fileURLWithPath: "/System/Applications/Contacts.app")
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error = error {
                    print("❌ Failed to launch Contacts: \(error)")
                }
            }
        }

        // Wait for app to be ready, then select group
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let escapedName = groupName.replacingOccurrences(of: "\"", with: "\\\"")

            // NOTE: Removed "activate" from AppleScript - NSWorkspace handles that
            let script = """
            tell application "Contacts"
                if group "\(escapedName)" exists then
                    set selected of group "\(escapedName)" to true
                end if
            end tell
            """

            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Failed to select group: \(error)")
                } else {
                    print("✅ Opened group in Contacts: \(groupName)")
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Smart Group Result Card

struct SmartGroupResultCard: View {
    let result: SmartGroupResult
    let onCreateInContacts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: groupIcon)
                    .font(.title2)
                    .foregroundColor(groupColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.groupName)
                        .font(.headline)

                    Text("\(result.contacts.count) contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onCreateInContacts) {
                    Label("Create in Contacts", systemImage: "plus.app")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    openContactsForGroup()
                }) {
                    Label("View All", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Show preview of contacts
            if result.contacts.count > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.contacts.prefix(3)) { contact in
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(contact.fullName)
                                .font(.caption)

                            Spacer()
                        }
                    }

                    if result.contacts.count > 3 {
                        Text("+ \(result.contacts.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var groupIcon: String {
        switch result.criteria {
        case .organization:
            return "building.2.fill"
        case .geographic:
            return "mappin.circle.fill"
        case .custom:
            return "star.fill"
        }
    }

    private var groupColor: Color {
        switch result.criteria {
        case .organization:
            return .green
        case .geographic:
            return .blue
        case .custom:
            return .orange
        }
    }

    private func openContactsForGroup() {
        for contact in result.contacts {
            if let url = URL(string: "addressbook://\(contact.id)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Smart Group Config Sheet

struct SmartGroupConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactsManager: ContactsManager
    let onGenerate: ([SmartGroupDefinition]) -> Void

    @State private var definitions: [SmartGroupDefinition] = ContactsManager.defaultSmartGroups
    @State private var showAddCustom = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("Configure Smart Groups")
                    .font(.title.bold())
            }

            Divider()

            // Preset smart groups
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Smart Groups to Generate")
                    .font(.headline)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(definitions.indices, id: \.self) { index in
                            SmartGroupDefinitionRow(
                                definition: $definitions[index]
                            )
                        }
                    }
                }
                .frame(height: 300)
            }

            // Info
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Smart groups are generated based on your current contacts and their information.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Generate Groups") {
                    let enabledDefinitions = definitions.filter { $0.isEnabled }
                    onGenerate(enabledDefinitions)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(definitions.filter { $0.isEnabled }.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 600, height: 600)
    }
}

struct SmartGroupDefinitionRow: View {
    @Binding var definition: SmartGroupDefinition

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $definition.isEnabled)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.subheadline.bold())

                Text(criteriaDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: criteriaIcon)
                .foregroundColor(definition.isEnabled ? criteriaColor : .secondary)
        }
        .padding()
        .background(definition.isEnabled ? criteriaColor.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var criteriaDescription: String {
        switch definition.groupingType {
        case .organization:
            return "Groups contacts by their organization/company"
        case .geographic(let criteria):
            return "Groups contacts \(criteria.displayName)"
        case .custom(let criteria):
            let ruleCount = criteria.rules.count
            return "Groups with \(ruleCount) custom rule\(ruleCount == 1 ? "" : "s")"
        }
    }

    private var criteriaIcon: String {
        switch definition.groupingType {
        case .organization:
            return "building.2.fill"
        case .geographic:
            return "mappin.circle.fill"
        case .custom:
            return "star.fill"
        }
    }

    private var criteriaColor: Color {
        switch definition.groupingType {
        case .organization:
            return .green
        case .geographic:
            return .blue
        case .custom:
            return .orange
        }
    }
}

struct CreateGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var groupName = ""
    @State private var selectedContactIds: Set<String> = []
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var filteredContacts: [ContactSummary] {
        if searchText.isEmpty {
            return contactsManager.contacts
        } else {
            return contactsManager.contacts.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Create Contact Group")
                .font(.title.bold())

            // Group name input
            TextField("Group Name", text: $groupName)
                .textFieldStyle(.roundedBorder)

            Divider()

            // Contact selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select Contacts")
                        .font(.headline)
                    Spacer()
                    Text("\(selectedContactIds.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Search
                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                // Contact list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredContacts) { contact in
                            ContactSelectionRow(
                                contact: contact,
                                isSelected: selectedContactIds.contains(contact.id)
                            ) {
                                toggleContactSelection(contact.id)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .border(Color.secondary.opacity(0.2))
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(action: createGroup) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(isCreating ? "Creating..." : "Create Group")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty || selectedContactIds.isEmpty || isCreating)
            }
        }
        .padding(32)
        .frame(width: 600, height: 600)
    }

    private func toggleContactSelection(_ contactId: String) {
        if selectedContactIds.contains(contactId) {
            selectedContactIds.remove(contactId)
        } else {
            selectedContactIds.insert(contactId)
        }
    }

    private func createGroup() {
        isCreating = true
        errorMessage = nil

        Task {
            let success = await contactsManager.createGroup(
                name: groupName,
                contactIds: Array(selectedContactIds)
            )

            await MainActor.run {
                isCreating = false
                if success {
                    dismiss()
                } else {
                    errorMessage = contactsManager.errorMessage ?? "Failed to create group"
                }
            }
        }
    }
}

struct ContactSelectionRow: View {
    let contact: ContactSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    if let org = contact.organization {
                        Text(org)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GroupsView()
        .environmentObject(ContactsManager.shared)
}
