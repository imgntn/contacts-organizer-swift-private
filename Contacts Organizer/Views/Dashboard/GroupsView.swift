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
    @Binding var targetSmartGroupName: String?
    @State private var showCreateGroupSheet = false
    @State private var smartGroupResults: [SmartGroupResult] = []
    private let groupTab: GroupTab
    @State private var searchText = ""
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

    @State private var selectedGroupForModal: SmartGroupResult?

    init(initialTab: GroupTab = .smart, targetSmartGroupName: Binding<String?>) {
        self._targetSmartGroupName = targetSmartGroupName
        self.groupTab = initialTab
    }

    struct CreationResults {
        let successCount: Int
        let failureCount: Int
        let failedGroups: [String]
    }

    struct CleanupResults {
        let deletedCount: Int
        let errorCount: Int
    }

    enum GroupTab: String {
        case smart = "Smart Groups"
        case manual = "Manual Groups"
    }

    private enum SmartGroupCategory: String, CaseIterable, Identifiable {
        case fundamentals = "Contact Fundamentals"
        case stayingInTouch = "Stay in Touch"
        case digital = "Digital Presence"
        case work = "Work & Organization"
        case addresses = "Places & Addresses"
        case personal = "Personal Touches"
        case other = "Other Smart Groups"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .fundamentals: return "checkmark.seal"
            case .stayingInTouch: return "calendar.badge.clock"
            case .digital: return "network"
            case .work: return "briefcase.fill"
            case .addresses: return "mappin.and.ellipse"
            case .personal: return "person.crop.circle.badge.checkmark"
            case .other: return "sparkles"
            }
        }

        static func category(for name: String) -> SmartGroupCategory {
            if let mapped = nameToCategory[name] {
                return mapped
            }
            return .other
        }

        private static let nameToCategory: [String: SmartGroupCategory] = [
            "By Organization": .work,
            "Complete Contacts": .fundamentals,
            "Missing Email": .fundamentals,
            "Has Photo": .fundamentals,
            "Missing Critical Info": .fundamentals,
            "Phone Only (No Email)": .fundamentals,
            "Email Only (No Phone)": .fundamentals,
            "Multiple Phone Numbers": .fundamentals,
            "Multiple Email Addresses": .fundamentals,
            "Recently Added (Last 30 Days)": .stayingInTouch,
            "Recently Modified (Last 30 Days)": .stayingInTouch,
            "Stale Contacts (1+ Year)": .stayingInTouch,
            "Birthday This Month": .stayingInTouch,
            "Birthday This Week": .stayingInTouch,
            "Connected on LinkedIn": .digital,
            "Connected on Twitter/X": .digital,
            "Social Media Savvy": .digital,
            "Missing Social Media": .digital,
            "Has Instant Messaging": .digital,
            "Digitally Connected": .digital,
            "Has Address": .addresses,
            "Missing Address": .addresses,
            "Multiple Addresses": .addresses,
            "Has Job Title": .work,
            "Has Department": .work,
            "Professional Network": .work,
            "Career Network": .work,
            "Has Website": .digital,
            "Business Contacts": .work,
            "Has Nickname": .personal,
            "Highly Detailed Contacts": .fundamentals,
            "Basic Contacts Only": .fundamentals,
            "Personal Contacts": .personal,
            "By City": .addresses
        ]
    }

    private struct SmartGroupSection: Identifiable {
        let category: SmartGroupCategory
        let groups: [SmartGroupResult]
        var id: String { category.rawValue }
    }

    private var filteredManualGroups: [CNGroup] {
        if searchText.isEmpty {
            return contactsManager.groups
        }
        // Note: Manual groups only filter by group name (not contact names)
        // since contacts are loaded asynchronously per-group
        return contactsManager.groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSmartGroups: [SmartGroupResult] {
        if searchText.isEmpty {
            return smartGroupResults
        }
        return smartGroupResults.filter { result in
            // Match group name
            if result.groupName.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            // Match any contact name in the group
            return result.contacts.contains { contact in
                contact.fullName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        rootAlerts(
            VStack(spacing: 0) {
                headerView
                    .padding(24)

                Divider()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search groups...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.05))

                Divider()

                Group {
                    if groupTab == .manual {
                        manualGroupsContent
                    } else {
                        smartGroupsContent
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
            .sheet(item: $selectedGroupForModal) { result in
                SmartGroupDetailSheet(result: result, isCreating: isCreatingGroups) {
                    Task { await createSingleSmartGroup(result) }
                }
            }
            .onChange(of: contactsManager.contacts, initial: false) { _,_  in
                Task { await generateSmartGroupsAsync() }
            }
            .onChange(of: targetSmartGroupName, initial: false) { _, newGroupName in
                guard groupTab == .smart else { return }
                guard let groupName = newGroupName else { return }

                // Find matching smart group and open its modal
                if let matchingGroup = smartGroupResults.first(where: { $0.groupName == groupName }) {
                    // Open the modal for this group
                    selectedGroupForModal = matchingGroup
                    // Clear the target after a brief delay to allow modal to open
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        targetSmartGroupName = nil
                    }
                }
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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(groupTab == .smart ? "Smart Groups" : "Manual Groups")
                    .responsiveFont(36, weight: .bold)
                Text(headerSubtitle).responsiveFont(16).foregroundColor(.secondary)
            }
            Spacer()

            headerActions
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if groupTab == .manual {
            manualHeaderActions
        } else {
            smartHeaderActions
        }
    }

    @ViewBuilder
    private var manualHeaderActions: some View {
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
    }

    @ViewBuilder
    private var smartHeaderActions: some View {
        if isLoadingSmartGroups {
            ProgressView().scaleEffect(0.9).padding(.trailing, 8)
        } else {
            Label("Auto-updates", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        if groupTab == .manual { return "\(contactsManager.groups.count) manual groups" }
        if isLoadingSmartGroups { return "Loading smart groups…" }
        return "\(smartGroupResults.count) smart groups"
    }

    private var smartGroupSections: [SmartGroupSection] {
        var grouped: [SmartGroupCategory: [SmartGroupResult]] = [:]
        for result in filteredSmartGroups {
            let category = SmartGroupCategory.category(for: result.groupName)
            grouped[category, default: []].append(result)
        }

        return SmartGroupCategory.allCases.compactMap { category in
            guard let groups = grouped[category], !groups.isEmpty else { return nil }
            let sorted = groups.sorted { $0.groupName < $1.groupName }
            return SmartGroupSection(category: category, groups: sorted)
        }
    }

    private var smartGroupTileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 12)]
    }


    @ViewBuilder
    private var manualGroupsContent: some View {
        if contactsManager.groups.isEmpty {
            EmptyStateView(icon: "folder.fill.badge.plus", title: "No Manual Groups", message: "Create groups to organize your contacts manually.", color: .blue)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Create group button
                    Button(action: { showCreateGroupSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .responsiveFont(20)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create New Group")
                                    .responsiveFont(14, weight: .semibold)
                                Text("Manually organize your contacts")
                                    .responsiveFont(11)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if filteredManualGroups.isEmpty && !searchText.isEmpty {
                        // No search results
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .responsiveFont(48)
                                .foregroundColor(.secondary)
                            Text("No groups found")
                                .font(.title2.bold())
                            Text("No groups match \"\(searchText)\"")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(48)
                    } else {
                        ForEach(filteredManualGroups, id: \.identifier) { group in
                            ManualGroupCard(group: group)
                        }
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
                if filteredSmartGroups.isEmpty && !searchText.isEmpty {
                    // No search results
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .responsiveFont(48)
                            .foregroundColor(.secondary)
                        Text("No groups found")
                            .font(.title2.bold())
                        Text("No groups match \"\(searchText)\"")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(48)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(smartGroupSections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(section.category.rawValue, systemImage: section.category.icon)
                                        .responsiveFont(14, weight: .semibold)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(section.groups.count)")
                                        .responsiveFont(12, weight: .medium)
                                        .foregroundColor(.secondary)
                                }

                                LazyVGrid(columns: smartGroupTileColumns, spacing: 12) {
                                    ForEach(section.groups) { result in
                                        SmartGroupTile(result: result) {
                                            selectedGroupForModal = result
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.vertical, 12)
                }
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

// MARK: - Smart Group Tile (Compact View)

struct SmartGroupTile: View {
    let result: SmartGroupResult
    let onTap: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: groupIcon)
                        .responsiveFont(20)
                        .foregroundColor(groupColor)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .responsiveFont(10)
                        Text("\(result.contacts.count)")
                            .responsiveFont(11, weight: .medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(result.groupName)
                    .responsiveFont(12.5, weight: .semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 90)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((isHovered || isFocused) ? groupColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
                    )
            )
            .scaleEffect((isHovered || isFocused) ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered || isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
    }

    private var groupIcon: String {
        // Enhanced icon mapping based on group name
        let name = result.groupName.lowercased()

        // Social Media
        if name.contains("linkedin") { return "person.badge.shield.checkmark.fill" }
        if name.contains("twitter") || name.contains("x") { return "at.circle.fill" }
        if name.contains("social media savvy") { return "person.2.fill" }
        if name.contains("social") { return "person.2.fill" }

        // Digital & Web
        if name.contains("website") { return "link.circle.fill" }
        if name.contains("instant messaging") { return "bubble.left.and.bubble.right.fill" }
        if name.contains("digitally connected") { return "network" }

        // Professional
        if name.contains("job title") || name.contains("career") { return "briefcase.fill" }
        if name.contains("department") { return "building.2.crop.circle.fill" }
        if name.contains("professional") { return "person.badge.key.fill" }

        // Geographic
        if name.contains("address") { return "house.fill" }
        if name.contains("city") { return "mappin.circle.fill" }
        if name.contains("multiple addresses") { return "house.and.flag.fill" }

        // Time-based
        if name.contains("birthday") { return "calendar.circle.fill" }
        if name.contains("recent") { return "clock.arrow.circlepath" }
        if name.contains("stale") { return "hourglass" }

        // Detail & Quality
        if name.contains("highly detailed") { return "star.circle.fill" }
        if name.contains("basic") { return "person.crop.circle" }
        if name.contains("nickname") { return "person.text.rectangle" }
        if name.contains("business contact") { return "building.2.fill" }
        if name.contains("personal contact") { return "heart.circle.fill" }

        // Organization
        if name.contains("organization") { return "building.2.fill" }

        // Default by criteria type
        switch result.criteria {
        case .organization: return "building.2.fill"
        case .geographic: return "mappin.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private var groupColor: Color {
        let name = result.groupName.lowercased()

        // Social Media - Indigo/Teal
        if name.contains("linkedin") || name.contains("twitter") || name.contains("social") {
            return .indigo
        }

        // Professional - Purple
        if name.contains("job") || name.contains("career") || name.contains("department") || name.contains("professional") {
            return .purple
        }

        // Geographic - Red/Mint
        if name.contains("address") || name.contains("city") {
            return .red
        }

        // Digital/Web - Teal
        if name.contains("website") || name.contains("messaging") || name.contains("digitally") {
            return .teal
        }

        // Time-based - Orange
        if name.contains("birthday") || name.contains("recent") || name.contains("stale") {
            return .orange
        }

        // Detail - Yellow
        if name.contains("detailed") || name.contains("basic") {
            return .yellow
        }

        // Nickname - Orange
        if name.contains("nickname") {
            return .orange
        }

        // Business/Personal
        if name.contains("business") {
            return .brown
        }
        if name.contains("personal") {
            return .pink
        }

        // Default by criteria type
        switch result.criteria {
        case .organization: return .green
        case .geographic: return .blue
        case .custom: return .orange
        }
    }
}

// MARK: - Smart Group Detail Sheet (Modal)

struct SmartGroupDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let result: SmartGroupResult
    let isCreating: Bool
    let onCreateInContacts: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: groupIcon)
                    .responsiveFont(32)
                    .foregroundColor(groupColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.groupName)
                        .responsiveFont(24, weight: .bold)
                    Text("\(result.contacts.count) contacts")
                        .responsiveFont(14)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .responsiveFont(24)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                // Export Menu
                Menu {
                    ForEach(GroupExportService.ExportType.allCases, id: \.self) { exportType in
                        Button(action: { }) {
                            Label(exportType.rawValue, systemImage: exportType.icon)
                        }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: onCreateInContacts) {
                    if isCreating {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.85)
                            Text("Creating…").responsiveFont(14, weight: .semibold)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Create in Contacts", systemImage: "plus.app")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCreating)

                Button(action: { openContactsForGroup() }) {
                    Label("View All", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            // Contact List
            if !result.contacts.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(result.contacts) { contact in
                            Button(action: { openContact(contact) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .responsiveFont(16)
                                        .foregroundColor(.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.fullName)
                                            .responsiveFont(14, weight: .medium)
                                            .foregroundColor(.primary)

                                        if let org = contact.organization {
                                            Text(org)
                                                .responsiveFont(12)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.forward")
                                        .responsiveFont(12)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if contact.id != result.contacts.last?.id {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .responsiveFont(48)
                        .foregroundColor(.secondary)
                    Text("No contacts in this group")
                        .responsiveFont(16, weight: .medium)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(48)
            }
        }
        .frame(width: 650, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var groupIcon: String {
        let name = result.groupName.lowercased()

        // Social Media
        if name.contains("linkedin") { return "person.badge.shield.checkmark.fill" }
        if name.contains("twitter") || name.contains("x") { return "at.circle.fill" }
        if name.contains("social media savvy") { return "person.2.fill" }
        if name.contains("social") { return "person.2.fill" }

        // Digital & Web
        if name.contains("website") { return "link.circle.fill" }
        if name.contains("instant messaging") { return "bubble.left.and.bubble.right.fill" }
        if name.contains("digitally connected") { return "network" }

        // Professional
        if name.contains("job title") || name.contains("career") { return "briefcase.fill" }
        if name.contains("department") { return "building.2.crop.circle.fill" }
        if name.contains("professional") { return "person.badge.key.fill" }

        // Geographic
        if name.contains("address") { return "house.fill" }
        if name.contains("city") { return "mappin.circle.fill" }
        if name.contains("multiple addresses") { return "house.and.flag.fill" }

        // Time-based
        if name.contains("birthday") { return "calendar.circle.fill" }
        if name.contains("recent") { return "clock.arrow.circlepath" }
        if name.contains("stale") { return "hourglass" }

        // Detail & Quality
        if name.contains("highly detailed") { return "star.circle.fill" }
        if name.contains("basic") { return "person.crop.circle" }
        if name.contains("nickname") { return "person.text.rectangle" }
        if name.contains("business contact") { return "building.2.fill" }
        if name.contains("personal contact") { return "heart.circle.fill" }

        // Organization
        if name.contains("organization") { return "building.2.fill" }

        switch result.criteria {
        case .organization: return "building.2.fill"
        case .geographic: return "mappin.circle.fill"
        case .custom: return "star.fill"
        }
    }

    private var groupColor: Color {
        let name = result.groupName.lowercased()

        if name.contains("linkedin") || name.contains("twitter") || name.contains("social") { return .indigo }
        if name.contains("job") || name.contains("career") || name.contains("department") || name.contains("professional") { return .purple }
        if name.contains("address") || name.contains("city") { return .red }
        if name.contains("website") || name.contains("messaging") || name.contains("digitally") { return .teal }
        if name.contains("birthday") || name.contains("recent") || name.contains("stale") { return .orange }
        if name.contains("detailed") || name.contains("basic") { return .yellow }
        if name.contains("nickname") { return .orange }
        if name.contains("business") { return .brown }
        if name.contains("personal") { return .pink }

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
}

// MARK: - Smart Group Result Card

struct SmartGroupResultCard: View {
    let result: SmartGroupResult
    let isCreating: Bool
    let onTap: () -> Void
    let onCreateInContacts: () -> Void
    @State private var showExportMenu = false
    @State private var exportResult: String?
    @State private var showExportAlert = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: groupIcon).responsiveFont(20).foregroundColor(groupColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.groupName).responsiveFont(14, weight: .semibold)
                        Text("\(result.contacts.count) contacts").responsiveFont(11).foregroundColor(.secondary)
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
                        HStack(spacing: 6) { ProgressView().scaleEffect(0.75); Text("Creating…").responsiveFont(11, weight: .bold) }
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
                                    Image(systemName: "person.circle.fill").responsiveFont(11).foregroundColor(.secondary)
                                    Text(contact.fullName).responsiveFont(11).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").responsiveFont(10).foregroundColor(.secondary)
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
        .buttonStyle(.plain)
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
                Image(systemName: "folder.fill").responsiveFont(20).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).responsiveFont(14, weight: .semibold)
                    Text("\(contacts.count) contacts").responsiveFont(11).foregroundColor(.secondary)
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
                                    Image(systemName: "person.circle.fill").responsiveFont(11).foregroundColor(.secondary)
                                    Text(contact.fullName).responsiveFont(11).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").responsiveFont(10).foregroundColor(.secondary)
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
    GroupsView(initialTab: .smart, targetSmartGroupName: .constant(nil))
        .environmentObject(ContactsManager.shared)
}
