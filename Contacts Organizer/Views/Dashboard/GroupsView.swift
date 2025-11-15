//
//  GroupsView.swift
//  Contacts Organizer
//
//  View for managing contact groups
//

import SwiftUI
import Contacts
import ApplicationServices
#if os(macOS)
import AppKit
#endif

struct GroupsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var undoManager: ContactsUndoManager
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
    @AppStorage("smartGroupSavedFilters") private var savedFiltersRaw: String = "[]"
    @State private var savedFilters: [String] = []
    @State private var smartGroupSearchIndex: [UUID: SmartGroupSearchMetadata] = [:]

    init(initialTab: GroupTab = .smart, targetSmartGroupName: Binding<String?>) {
        self._targetSmartGroupName = targetSmartGroupName
        self.groupTab = initialTab
        let rawValue = UserDefaults.standard.string(forKey: "smartGroupSavedFilters") ?? "[]"
        let decoded = GroupsView.decodeSavedFilters(from: rawValue)
        self._savedFilters = State(initialValue: decoded)
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

    private static func decodeSavedFilters(from raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
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
        let query = trimmedSearchText
        guard !query.isEmpty else {
            return smartGroupResults
        }
        let queryTokens = SmartGroupSearchIndexBuilder.queryTokens(from: query)
        guard !queryTokens.isEmpty else {
            return smartGroupResults
        }

        return smartGroupResults.filter { result in
            smartGroupNameMatches(result, tokens: queryTokens)
        }
    }

    var body: some View {
        rootAlerts(
            VStack(spacing: 0) {
                headerView
                    .padding(24)

                Divider()

                GroupsSearchBar(text: $searchText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                if groupTab == .smart {
                    savedFiltersBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

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
                SmartGroupDetailSheet(
                    result: result,
                    isCreating: isCreatingGroups,
                    onCreateInContacts: {
                        createSingleSmartGroup(result)
                    },
                    onExport: { exportType in
                        exportSmartGroup(result, as: exportType)
                    }
                )
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
            .onChange(of: savedFiltersRaw, initial: false) { _, newValue in
                savedFilters = GroupsView.decodeSavedFilters(from: newValue)
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
    private var savedFiltersBar: some View {
        if savedFilters.isEmpty && !canSaveCurrentFilter {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Saved Filters", systemImage: "bookmark")
                        .platformCalloutFont(weight: .semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    if canSaveCurrentFilter {
                        Button(action: saveCurrentFilter) {
                            Label("Save \"\(trimmedSearchText)\"", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .transition(.opacity.combined(with: .scale))
                    }
                }

                if !savedFilters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(savedFilters, id: \.self) { filter in
                                HStack(spacing: 6) {
                                    Button(action: { applySavedFilter(filter) }) {
                                        Text(filter)
                                            .platformBodyFont(weight: .medium)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.primary)

                                    Button(action: { removeSavedFilter(filter) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.05))
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

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveCurrentFilter: Bool {
        groupTab == .smart &&
        !trimmedSearchText.isEmpty &&
        !savedFilters.contains { $0.caseInsensitiveCompare(trimmedSearchText) == .orderedSame }
    }

    private func persistSavedFilters() {
        guard let data = try? JSONEncoder().encode(savedFilters),
              let string = String(data: data, encoding: .utf8) else { return }
        savedFiltersRaw = string
    }

    private func saveCurrentFilter() {
        guard canSaveCurrentFilter else { return }
        savedFilters.insert(trimmedSearchText, at: 0)
        if savedFilters.count > 8 { savedFilters.removeLast(savedFilters.count - 8) }
        persistSavedFilters()
    }

    private func removeSavedFilter(_ filter: String) {
        savedFilters.removeAll { $0 == filter }
        persistSavedFilters()
    }

    private func applySavedFilter(_ filter: String) {
        searchText = filter
    }

    private func rebuildSmartGroupIndex(with results: [SmartGroupResult]) {
        Task.detached(priority: .utility) {
            let index = SmartGroupSearchIndexBuilder.buildIndex(from: results)
            await MainActor.run {
                self.smartGroupSearchIndex = index
            }
        }
    }

    private func smartGroupNameMatches(_ result: SmartGroupResult, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        if let metadata = smartGroupSearchIndex[result.id] {
            return metadata.matches(queryTokens: tokens)
        }
        let lowercasedName = result.groupName.lowercased()
        return tokens.allSatisfy { lowercasedName.contains($0) }
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
                                    .platformBodyFont()
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
                                        .platformCaptionFont(weight: .medium)
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
    private func makeSmartGroupExecutor() -> SmartGroupActionExecutor {
        SmartGroupActionExecutor(
            contactsGateway: contactsManager,
            exportGateway: GroupExportService.shared,
            undoManager: undoManager
        )
    }

    @MainActor
    private func makeManualGroupExecutor() -> ManualGroupActionExecutor {
        ManualGroupActionExecutor(
            contactsGateway: contactsManager,
            exportGateway: GroupExportService.shared,
            undoManager: undoManager
        )
    }

    @MainActor
    private func exportSmartGroup(_ result: SmartGroupResult, as type: GroupExportService.ExportType) -> GroupExportService.ExportResult {
        let executor = makeSmartGroupExecutor()
        let exportResult = executor.exportGroup(result, as: type)
        logFileExportIfNeeded(
            groupName: result.groupName,
            contactCount: result.contacts.count,
            exportType: type,
            exportResult: exportResult
        )
        return exportResult
    }

    @MainActor
    private func logFileExportIfNeeded(
        groupName: String,
        contactCount: Int,
        exportType: GroupExportService.ExportType,
        exportResult: GroupExportService.ExportResult
    ) {
        guard exportResult.success,
              exportType == .csv || exportType == .vcardFile else { return }
        let formatLabel = exportType == .csv ? "CSV" : "vCard"
        contactsManager.logActivity(
            kind: .export,
            title: "Exported \(groupName)",
            detail: "\(contactCount) contacts to \(formatLabel)",
            icon: "square.and.arrow.down"
        )
    }

    @MainActor
    private func generateSmartGroupsAsync() async {
        if isLoadingSmartGroups { return }
        isLoadingSmartGroups = true
        defer { isLoadingSmartGroups = false }
        let results = await contactsManager.generateSmartGroups(definitions: ContactsManager.defaultSmartGroups)
        smartGroupResults = results
        rebuildSmartGroupIndex(with: results)
    }

    @MainActor
    private func createSingleSmartGroup(_ result: SmartGroupResult) {
        // Dismiss any open detail sheet so alerts/confirmations appear
        selectedGroupForModal = nil
        groupToCreate = result
        DispatchQueue.main.async {
            showConfirmCreate = true
        }
    }

    @MainActor
    private func confirmAndCreateGroup() async {
        guard let result = groupToCreate else { return }
        isCreatingGroups = true
        let executor = makeSmartGroupExecutor()
        let success = await executor.createGroup(from: result)
        isCreatingGroups = false
        if success {
            creationResults = CreationResults(successCount: 1, failureCount: 0, failedGroups: [])
            contactsManager.logActivity(
                kind: .smartGroupCreated,
                title: "Smart Group Created",
                detail: result.groupName,
                icon: "sparkles"
            )
        } else {
            creationResults = CreationResults(successCount: 0, failureCount: 1, failedGroups: [result.groupName])
        }
        showResultsAlert = true
        await contactsManager.fetchAllGroups()
    }

    @MainActor
    private func cleanUpDuplicates() async {
        isCleaningDuplicates = true
        let cleanupResult = await makeManualGroupExecutor().cleanupDuplicateGroups(keepFirst: true)
        isCleaningDuplicates = false
        cleanupResults = CleanupResults(deletedCount: cleanupResult.deletedCount, errorCount: cleanupResult.errorCount)
        showCleanupResults = true
        let duplicates = await contactsManager.findDuplicateGroups()
        duplicateGroupCount = duplicates.values.reduce(0) { $0 + $1.count - 1 }

        if cleanupResult.deletedCount > 0 {
            contactsManager.logActivity(
                kind: .duplicatesCleaned,
                title: "Cleaned Duplicate Groups",
                detail: "\(cleanupResult.deletedCount) removed",
                icon: "arrow.triangle.merge"
            )
        }
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

private struct GroupsSearchBar: View {
    @Binding var text: String

    var body: some View {
        #if os(macOS)
        NativeSearchFieldRepresentable(text: $text, prompt: "Search groups")
            .frame(minHeight: 34)
        #else
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search groups...", text: $text)
                .textFieldStyle(.roundedBorder)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08))
        )
        #endif
    }
}

#if os(macOS)
private struct NativeSearchFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var prompt: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.sendsWholeSearchString = false
        field.translatesAutoresizingMaskIntoConstraints = false
        field.controlSize = .large
        field.focusRingType = .default
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchFieldRepresentable

        init(_ parent: NativeSearchFieldRepresentable) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}
#endif

private struct SmartGroupSearchMetadata {
    let tokens: [String]

    func matches(queryTokens: [String]) -> Bool {
        guard !queryTokens.isEmpty else { return true }
        return queryTokens.allSatisfy { query in
            tokens.contains(where: { $0.contains(query) })
        }
    }
}

private enum SmartGroupSearchIndexBuilder {
    private static let splitCharacters = CharacterSet.alphanumerics.inverted

    static func buildIndex(from results: [SmartGroupResult], maxContactsPerGroup: Int = 40) -> [UUID: SmartGroupSearchMetadata] {
        var index: [UUID: SmartGroupSearchMetadata] = [:]
        for result in results {
            var tokens = tokenize(result.groupName)

            if !result.contacts.isEmpty {
                // Index only a subset of contact names per group to keep filtering cheap.
                for contact in result.contacts.prefix(maxContactsPerGroup) {
                    tokens.append(contentsOf: tokenize(contact.fullName))
                }
            }

            let uniqueTokens = Array(Set(tokens))
            index[result.id] = SmartGroupSearchMetadata(tokens: uniqueTokens)
        }
        return index
    }

    static func queryTokens(from searchText: String) -> [String] {
        tokenize(searchText)
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: splitCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
                            .platformMiniCaptionFont()
                        Text("\(result.contacts.count)")
                            .platformCaptionFont(weight: .medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(result.groupName)
                    .platformBodyFont(weight: .semibold)
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
    let onExport: (GroupExportService.ExportType) -> GroupExportService.ExportResult
    @State private var exportResult: GroupExportService.ExportResult?
    @State private var showExportAlert = false
    @State private var showOpenGroupAlert = false

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
                        Button {
                            exportResult = onExport(exportType)
                            showExportAlert = true
                        } label: {
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

                Button(action: handleOpenGroupTap) {
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
                                                .platformCalloutFont()
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.forward")
                                        .platformCaptionFont()
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
        .alert("Export Result", isPresented: $showExportAlert) {
            Button("OK") {
                exportResult = nil
            }
        } message: {
            Text(exportResult?.message ?? "Export complete")
        }
        .alert("Open \(result.contacts.count) contacts in Contacts?", isPresented: $showOpenGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open", role: .destructive) {
                openContactsForGroup()
            }
        } message: {
            Text("Opening this group will launch \(result.contacts.count) Contact cards at once.")
        }
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

    private func handleOpenGroupTap() {
        if result.contacts.count >= 10 {
            showOpenGroupAlert = true
        } else {
            openContactsForGroup()
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
    @State private var showOpenGroupAlert = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: groupIcon).responsiveFont(20).foregroundColor(groupColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.groupName).responsiveFont(14, weight: .semibold)
                        Text("\(result.contacts.count) contacts").platformCaptionFont().foregroundColor(.secondary)
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
                        HStack(spacing: 6) { ProgressView().scaleEffect(0.75); Text("Creating…").platformCaptionFont(weight: .bold) }
                    } else {
                        Label("Create in Contacts", systemImage: "plus.app")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isCreating)

                Button(action: handleOpenGroupTap) {
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
            .alert("Open \(result.contacts.count) contacts in Contacts?", isPresented: $showOpenGroupAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open", role: .destructive) {
                    openContactsForGroup()
                }
            } message: {
                Text("Opening this group will launch \(result.contacts.count) Contact cards.")
            }

            if !result.contacts.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(result.contacts) { contact in
                            Button(action: { openContact(contact) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.circle.fill").responsiveFont(11).foregroundColor(.secondary)
                                    Text(contact.fullName).platformBodyFont().foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").platformMiniCaptionFont().foregroundColor(.secondary)
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

    private func handleOpenGroupTap() {
        if result.contacts.count >= 10 {
            showOpenGroupAlert = true
        } else {
            openContactsForGroup()
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
    @State private var showRenameSheet = false
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var undoManager: ContactsUndoManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill").responsiveFont(20).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).responsiveFont(14, weight: .semibold)
                    Text("\(contacts.count) contacts").platformCaptionFont().foregroundColor(.secondary)
                }
                Spacer()

                Menu {
                    Button {
                        showRenameSheet = true
                    } label: {
                        Label("Rename Group", systemImage: "pencil")
                    }

                    ShareLink(item: shareSummary) {
                        Label("Share Summary", systemImage: "square.and.arrow.up")
                    }

                    if !contacts.isEmpty {
                        Divider()
                        ForEach(GroupExportService.ExportType.allCases, id: \.self) { exportType in
                            Button(action: { performExport(type: exportType) }) {
                                Label(exportType.rawValue, systemImage: exportType.icon)
                            }
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                                    Text(contact.fullName).platformBodyFont().foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward").platformMiniCaptionFont().foregroundColor(.secondary)
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
        .sheet(isPresented: $showRenameSheet) {
            RenameGroupSheet(currentName: group.name) { newName in
                await renameGroup(to: newName)
            }
        }
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
        let executor = ManualGroupActionExecutor(
            contactsGateway: contactsManager,
            exportGateway: GroupExportService.shared,
            undoManager: undoManager
        )
        let result = executor.exportGroup(groupName: group.name, contacts: contacts, type: type)

        if result.success, (type == .csv || type == .vcardFile) {
            let formatLabel = type == .csv ? "CSV" : "vCard"
            contactsManager.logActivity(
                kind: .export,
                title: "Exported \(group.name)",
                detail: "\(contacts.count) contacts to \(formatLabel)",
                icon: "square.and.arrow.down"
            )
        }

        if let fileURL = result.fileURL {
            // Open file location in Finder for CSV exports
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
        }

        exportResult = result.message
        showExportAlert = true
    }

    private func renameGroup(to newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != group.name else { return false }
        let executor = ManualGroupActionExecutor(
            contactsGateway: contactsManager,
            exportGateway: GroupExportService.shared,
            undoManager: undoManager
        )
        let success = await executor.renameGroup(currentName: group.name, newName: trimmed)
        if success {
            await contactsManager.fetchAllGroups()
        }
        return success
    }

    private var shareSummary: String {
        var lines = ["Group: \(group.name)", ""]
        if contacts.isEmpty {
            lines.append("No contacts yet.")
        } else {
            lines.append(contentsOf: contacts.prefix(20).map { "• \($0.fullName)" })
            if contacts.count > 20 {
                lines.append("…and \(contacts.count - 20) more")
            }
        }
        return lines.joined(separator: "\n")
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
    @EnvironmentObject var undoManager: ContactsUndoManager
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
            let executor = ManualGroupActionExecutor(
                contactsGateway: contactsManager,
                exportGateway: GroupExportService.shared,
                undoManager: undoManager
            )
            let success = await executor.createGroup(name: groupName, contactIds: Array(selectedContactIds))
            await MainActor.run {
                isCreating = false
                if success {
                    contactsManager.logActivity(
                        kind: .manualGroupCreated,
                        title: "Manual Group Created",
                        detail: groupName,
                        icon: "folder.fill"
                    )
                    Task {
                        await contactsManager.fetchAllGroups()
                    }
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

#if !DISABLE_PREVIEWS
#Preview {
    GroupsView(initialTab: .smart, targetSmartGroupName: .constant(nil))
        .environmentObject(ContactsManager.shared)
}
#endif

struct RenameGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentName: String
    let onRename: (String) async -> Bool

    @State private var proposedName: String
    @State private var isRenaming = false
    @State private var errorMessage: String?

    init(currentName: String, onRename: @escaping (String) async -> Bool) {
        self.currentName = currentName
        self.onRename = onRename
        _proposedName = State(initialValue: currentName)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Group")
                .font(.title2.weight(.bold))

            TextField("Group Name", text: $proposedName)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Spacer()

                Button(action: submit) {
                    if isRenaming {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("Save", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRenaming || proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func submit() {
        errorMessage = nil
        isRenaming = true
        let newName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let success = await onRename(newName)
            await MainActor.run {
                isRenaming = false
                if success {
                    dismiss()
                } else {
                    errorMessage = "Unable to rename group. Try another name."
                }
            }
        }
    }
}
