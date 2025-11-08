//
//  GroupsView.swift
//  Contacts Organizer
//
//  View for managing contact groups
//

import SwiftUI
import Contacts
import ApplicationServices

struct GroupsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var showCreateGroupSheet = false
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
    @State private var isLoadingSmartGroups = false

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
        rootAlerts(
            VStack(spacing: 0) {
                headerView
                    .padding(24)

                Divider()

                Group {
                    if selectedTab == .manual {
                        AnyView(manualGroupsContent)
                    } else {
                        AnyView(smartGroupsContent)
                    }
                }
            }
            .task {
                await contactsManager.fetchAllGroups()
                await generateSmartGroupsAsync()
                let duplicates = await contactsManager.findDuplicateGroups()
                duplicateGroupCount = duplicates.values.reduce(0) { $0 + $1.count - 1 }
            }
            .sheet(isPresented: $showCreateGroupSheet) {
                CreateGroupSheet()
            }
            .onChange(of: contactsManager.contacts, initial: false) { _,_  in
                Task { await generateSmartGroupsAsync() }
            }
        )
    }

    private func rootAlerts<V: View>(_ content: V) -> some View {
        content
            .alert("Create Smart Group in Contacts?", isPresented: $showConfirmCreate, presenting: groupToCreate) { _ in
                Button("Cancel", role: .cancel) { }
                Button("Create") { Task { await confirmAndCreateGroup() } }
            } message: { result in
                smartGroupCreateMessage(for: result)
            }
            .alert("Clean Up Duplicate Groups?", isPresented: $showConfirmCleanup) {
                Button("Cancel", role: .cancel) { }
                Button("Clean Up", role: .destructive) { Task { await cleanUpDuplicates() } }
            } message: {
                cleanupConfirmMessage(count: duplicateGroupCount)
            }
            .alert("Duplicate Cleanup Complete", isPresented: $showCleanupResults, presenting: cleanupResults) { _ in
                Button("OK") { }
            } message: { results in
                cleanupResultsMessage(results)
            }
            .alert("Smart Groups Created", isPresented: $showResultsAlert, presenting: creationResults) { _ in
                Button("OK") { }
            } message: { results in
                creationResultsMessage(results)
            }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Contact Groups").font(.system(size: 36, weight: .bold))
                Text(headerSubtitle).font(.title3).foregroundColor(.secondary)
            }
            Spacer()
            Picker("Group Type", selection: $selectedTab) {
                ForEach(GroupTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            headerActions
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if selectedTab == .manual {
            manualHeaderActions
        } else {
            smartHeaderActions
        }
    }

    @ViewBuilder
    private var manualHeaderActions: some View {
        HStack(spacing: 12) {
            if duplicateGroupCount > 0 {
                Button(action: { showConfirmCleanup = true }) {
                    HStack {
                        if isCleaningDuplicates {
                            ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                        }
                        Label(isCleaningDuplicates ? "Cleaning..." : "Clean Up \(duplicateGroupCount) Duplicates", systemImage: "trash")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCleaningDuplicates)
            }
            Button(action: { showCreateGroupSheet = true }) {
                Label("Create Group", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var smartHeaderActions: some View {
        if isLoadingSmartGroups {
            ProgressView().scaleEffect(0.9).padding(.trailing, 8)
        } else {
            Label("Smart groups update automatically", systemImage: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        if selectedTab == .manual { return "\(contactsManager.groups.count) manual groups" }
        if isLoadingSmartGroups { return "Loading smart groups…" }
        return "\(smartGroupResults.count) smart groups"
    }


    @ViewBuilder
    private var manualGroupsContent: some View {
        if contactsManager.groups.isEmpty {
            EmptyStateView(icon: "folder.fill.badge.plus", title: "No Manual Groups", message: "Create groups to organize your contacts manually.", color: .blue)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(contactsManager.groups, id: \.identifier) { group in
                        ManualGroupCard(group: group)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var smartGroupsContent: some View {
        if isLoadingSmartGroups {
            VStack(spacing: 20) {
                ProgressView().scaleEffect(1.1)
                VStack(spacing: 8) {
                    Text("Fetching Smart Groups").font(.title.bold())
                    Text("Hang tight—your smart groups refresh automatically whenever contacts change.")
                        .font(.body).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else if smartGroupResults.isEmpty {
            EmptyStateView(icon: "sparkles", title: "No Smart Groups Yet", message: "Smart groups appear automatically once your contacts match the built-in rules.", color: .purple)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(smartGroupResults) { result in
                        SmartGroupResultCard(result: result, isCreating: isCreatingGroups) {
                            Task { await createSingleSmartGroup(result) }
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    @MainActor
    private func generateSmartGroupsAsync() async {
        if isLoadingSmartGroups { return }
        isLoadingSmartGroups = true
        defer { isLoadingSmartGroups = false }
        let results = await contactsManager.generateSmartGroups(definitions: ContactsManager.defaultSmartGroups)
        smartGroupResults = results
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
        let success = await contactsManager.createGroup(name: result.groupName, contactIds: contactIds)
        isCreatingGroups = false
        if success {
            creationResults = CreationResults(successCount: 1, failureCount: 0, failedGroups: [])
        } else {
            creationResults = CreationResults(successCount: 0, failureCount: 1, failedGroups: [result.groupName])
        }
        showResultsAlert = true
        await contactsManager.fetchAllGroups()
    }

    @MainActor
    private func cleanUpDuplicates() async {
        isCleaningDuplicates = true
        let (deleted, errors) = await contactsManager.deleteDuplicateGroups(keepFirst: true)
        isCleaningDuplicates = false
        cleanupResults = CleanupResults(deletedCount: deleted, errorCount: errors)
        showCleanupResults = true
        let duplicates = await contactsManager.findDuplicateGroups()
        duplicateGroupCount = duplicates.values.reduce(0) { $0 + $1.count - 1 }
    }

    private func smartGroupCreateMessage(for result: SmartGroupResult) -> Text {
        let count = result.contacts.count
        let plural = count == 1 ? "" : "s"
        return Text("This will create a new group '\(result.groupName)' with \(count) contact\(plural) in your Contacts app.")
    }

    private func cleanupConfirmMessage(count: Int) -> Text {
        let plural = count == 1 ? "" : "s"
        return Text("This will delete \(count) duplicate group\(plural) from your Contacts app, keeping the first occurrence of each.")
    }

    private func cleanupResultsMessage(_ results: CleanupResults) -> Text {
        if results.errorCount == 0 {
            let c = results.deletedCount
            let plural = c == 1 ? "" : "s"
            return Text("Successfully deleted \(c) duplicate group\(plural) from Contacts.app!")
        } else {
            let c = results.deletedCount
            let cPlural = c == 1 ? "" : "s"
            let e = results.errorCount
            return Text("Deleted \(c) group\(cPlural), but \(e) failed. Please check Contacts app permissions.")
        }
    }

    private func creationResultsMessage(_ results: CreationResults) -> Text {
        if results.failureCount == 0 {
            let c = results.successCount
            let plural = c == 1 ? "" : "s"
            return Text("Successfully created \(c) smart group\(plural) in Contacts.app!")
        } else if results.successCount == 0 {
            let f = results.failureCount
            let plural = f == 1 ? "" : "s"
            return Text("Failed to create \(f) group\(plural). Please check Contacts app permissions.")
        } else {
            let s = results.successCount
            let sPlural = s == 1 ? "" : "s"
            let f = results.failureCount
            let fPlural = f == 1 ? "" : "s"
            let failed = results.failedGroups.joined(separator: ", ")
            return Text("Created \(s) group\(sPlural) successfully. Failed to create \(f) group\(fPlural): \(failed)")
        }
    }

}

// MARK: - Smart Group Result Card

struct SmartGroupResultCard: View {
    let result: SmartGroupResult
    let isCreating: Bool
    let onCreateInContacts: () -> Void
    @State private var showExportMenu = false
    @State private var exportResult: String?
    @State private var showExportAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: groupIcon).font(.title2).foregroundColor(groupColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.groupName).font(.headline)
                    Text("\(result.contacts.count) contacts").font(.caption).foregroundColor(.secondary)
                }
                Spacer()

                // Export Menu
                Menu {
                    ForEach(GroupExportService.ExportType.allCases, id: \.self) { exportType in
                        Button(action: { performExport(type: exportType) }) {
                            Label(exportType.rawValue, systemImage: exportType.icon)
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export group to various formats")

                Button(action: onCreateInContacts) {
                    if isCreating {
                        HStack(spacing: 6) { ProgressView().scaleEffect(0.75); Text("Creating…").font(.caption.bold()) }
                    } else {
                        Label("Create in Contacts", systemImage: "plus.app")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isCreating)

                Button(action: { openContactsForGroup() }) {
                    Label("View All", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .alert("Export Result", isPresented: $showExportAlert) {
                Button("OK") { }
            } message: {
                Text(exportResult ?? "")
            }

            if !result.contacts.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(result.contacts) { contact in
                            Button(action: { openContact(contact) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.circle.fill").font(.caption).foregroundColor(.secondary)
                                    Text(contact.fullName).font(.caption).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8).padding(.trailing, 16)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal)
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
        case .organization: return "building.2.fill"
        case .geographic: return "mappin.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private var groupColor: Color {
        switch result.criteria {
        case .organization: return .green
        case .geographic: return .blue
        case .custom: return .orange
        }
    }

    private func openContactsForGroup() {
        for contact in result.contacts {
            if let url = URL(string: "addressbook://\(contact.id)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func openContact(_ contact: ContactSummary) {
        guard let url = URL(string: "addressbook://\(contact.id)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func performExport(type: GroupExportService.ExportType) {
        let result = GroupExportService.shared.performExport(
            type: type,
            contacts: result.contacts,
            groupName: result.groupName
        )

        if let fileURL = result.fileURL {
            // Open file location in Finder for CSV exports
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
        }

        exportResult = result.message
        showExportAlert = true
    }
}

// MARK: - Manual Group Card

struct ManualGroupCard: View {
    let group: CNGroup
    @State private var contacts: [ContactSummary] = []
    @State private var isLoadingContacts = false
    @State private var exportResult: String?
    @State private var showExportAlert = false
    @EnvironmentObject var contactsManager: ContactsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill").font(.title2).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).font(.headline)
                    Text("\(contacts.count) contacts").font(.caption).foregroundColor(.secondary)
                }
                Spacer()

                // Export Menu
                if !contacts.isEmpty {
                    Menu {
                        ForEach(GroupExportService.ExportType.allCases, id: \.self) { exportType in
                            Button(action: { performExport(type: exportType) }) {
                                Label(exportType.rawValue, systemImage: exportType.icon)
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Export group to various formats")
                }
            }
            .alert("Export Result", isPresented: $showExportAlert) {
                Button("OK") { }
            } message: {
                Text(exportResult ?? "")
            }

            if isLoadingContacts {
                ProgressView().frame(maxWidth: .infinity)
            } else if !contacts.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(contacts) { contact in
                            Button(action: { openContact(contact) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.circle.fill").font(.caption).foregroundColor(.secondary)
                                    Text(contact.fullName).font(.caption).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8).padding(.trailing, 16)
                }
                .frame(maxHeight: 200)
                .padding(.horizontal)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .task {
            await loadContacts()
        }
    }

    private func loadContacts() async {
        isLoadingContacts = true
        contacts = await contactsManager.fetchContactsForGroup(group)
        isLoadingContacts = false
    }

    private func openContact(_ contact: ContactSummary) {
        guard let url = URL(string: "addressbook://\(contact.id)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func performExport(type: GroupExportService.ExportType) {
        let result = GroupExportService.shared.performExport(
            type: type,
            contacts: contacts,
            groupName: group.name
        )

        if let fileURL = result.fileURL {
            // Open file location in Finder for CSV exports
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
        }

        exportResult = result.message
        showExportAlert = true
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
            HStack {
                Image(systemName: "sparkles").font(.title2).foregroundColor(.purple)
                Text("Configure Smart Groups").font(.title.bold())
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Smart Groups to Generate").font(.headline)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(definitions.indices, id: \.self) { index in
                            SmartGroupDefinitionRow(definition: $definitions[index])
                        }
                    }
                }
                .frame(height: 300)
            }
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill").foregroundColor(.blue)
                Text("Smart groups are generated based on your current contacts and their information.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button("Generate Groups") {
                    let enabled = definitions.filter { $0.isEnabled }
                    onGenerate(enabled)
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
            Toggle("", isOn: $definition.isEnabled).labelsHidden()
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name).font(.subheadline.bold())
                Text(criteriaDescription).font(.caption).foregroundColor(.secondary)
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
        case .organization: return "building.2.fill"
        case .geographic: return "mappin.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private var criteriaColor: Color {
        switch definition.groupingType {
        case .organization: return .green
        case .geographic: return .blue
        case .custom: return .orange
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
        if searchText.isEmpty { return contactsManager.contacts }
        return contactsManager.contacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Contact Group").font(.title.bold())
            TextField("Group Name", text: $groupName).textFieldStyle(.roundedBorder)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select Contacts").font(.headline)
                    Spacer()
                    Text("\(selectedContactIds.count) selected").font(.caption).foregroundColor(.secondary)
                }
                TextField("Search contacts...", text: $searchText).textFieldStyle(.roundedBorder)
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredContacts) { contact in
                            ContactSelectionRow(contact: contact, isSelected: selectedContactIds.contains(contact.id)) {
                                toggleContactSelection(contact.id)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .border(Color.secondary.opacity(0.2))
            }
            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Button(action: createGroup) {
                    HStack {
                        if isCreating { ProgressView().scaleEffect(0.7).frame(width: 16, height: 16) }
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
        if selectedContactIds.contains(contactId) { selectedContactIds.remove(contactId) }
        else { selectedContactIds.insert(contactId) }
    }

    private func createGroup() {
        isCreating = true
        errorMessage = nil
        Task {
            let success = await contactsManager.createGroup(name: groupName, contactIds: Array(selectedContactIds))
            await MainActor.run {
                isCreating = false
                if success { dismiss() } else { errorMessage = contactsManager.errorMessage ?? "Failed to create group" }
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
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundColor(isSelected ? .blue : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.fullName).font(.subheadline).foregroundColor(.primary)
                    if let org = contact.organization {
                        Text(org).font(.caption2).foregroundColor(.secondary)
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
    GroupsView().environmentObject(ContactsManager.shared)
}

