//
//  HealthReportView.swift
//  Contacts Organizer
//
//  View for managing data quality issues
//

import SwiftUI
import Contacts

struct HealthReportView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    let issues: [DataQualityIssue]
    @State private var workingIssues: [DataQualityIssue]
    @State private var selectedSeverity: DataQualityIssue.Severity?
    @State private var selectedIssueType: DataQualityIssue.IssueType?
    @State private var excludeMissingEmail = false
    @State private var isSelectionMode = false
    @State private var selectedIssueIDs: Set<UUID> = []
    @State private var pendingQuickAction: PendingQuickAction?
    @State private var quickActionInput: String = ""
    @State private var statusMessage: StatusMessage?
    @State private var isPerformingBulkAction = false
    @EnvironmentObject var undoManager: ContactsUndoManager

    init(issues: [DataQualityIssue]) {
        self.issues = issues
        _workingIssues = State(initialValue: issues)
    }

    private var filteredIssues: [DataQualityIssue] {
        workingIssues.filter { issue in
            let severityMatch = selectedSeverity == nil || issue.severity == selectedSeverity
            let typeMatch = selectedIssueType == nil || issue.issueType == selectedIssueType
            let emailExclude = !excludeMissingEmail || issue.issueType != .missingEmail
            return severityMatch && typeMatch && emailExclude
        }
    }

    private var summary: DataQualitySummary {
        DataQualityAnalyzer.shared.generateSummary(issues: workingIssues)
    }

    var body: some View {
        Group {
            if workingIssues.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "Excellent Data Quality",
                    message: "All your contacts have complete information. No health issues found!",
                    color: .green
                )
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Data Quality")
                                    .responsiveFont(42, weight: .bold)

                                Text("\(workingIssues.count) issues found")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            // Health score
                            VStack(spacing: 4) {
                                Text(String(format: "%.0f%%", summary.healthScore))
                                    .responsiveFont(32, weight: .bold)
                                    .foregroundColor(healthScoreColor)

                                Text("Health Score")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Summary cards
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            SeverityCard(
                                severity: .high,
                                count: summary.highSeverityCount,
                                isSelected: selectedSeverity == .high
                            ) {
                                toggleSeverityFilter(.high)
                            }

                            SeverityCard(
                                severity: .medium,
                                count: summary.mediumSeverityCount,
                                isSelected: selectedSeverity == .medium
                            ) {
                                toggleSeverityFilter(.medium)
                            }

                            SeverityCard(
                                severity: .low,
                                count: summary.lowSeverityCount,
                                isSelected: selectedSeverity == .low
                            ) {
                                toggleSeverityFilter(.low)
                            }

                            SeverityCard(
                                severity: .suggestion,
                                count: summary.suggestionsCount,
                                isSelected: selectedSeverity == .suggestion
                            ) {
                                toggleSeverityFilter(.suggestion)
                            }
                        }

                        selectionControls

                        // Issue type filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                FilterChip(
                                    title: "All Issues",
                                    count: workingIssues.count,
                                    isSelected: selectedIssueType == nil
                                ) {
                                    selectedIssueType = nil
                                }

                                if summary.missingNameCount > 0 {
                                    FilterChip(
                                        title: "Missing Name",
                                        count: summary.missingNameCount,
                                        isSelected: selectedIssueType == .missingName
                                    ) {
                                        toggleIssueTypeFilter(.missingName)
                                    }
                                }

                                if summary.noContactInfoCount > 0 {
                                    FilterChip(
                                        title: "No Contact Info",
                                        count: summary.noContactInfoCount,
                                        isSelected: selectedIssueType == .noContactInfo
                                    ) {
                                        toggleIssueTypeFilter(.noContactInfo)
                                    }
                                }

                                if summary.missingPhoneCount > 0 {
                                    FilterChip(
                                        title: "Missing Phone",
                                        count: summary.missingPhoneCount,
                                        isSelected: selectedIssueType == .missingPhone
                                    ) {
                                        toggleIssueTypeFilter(.missingPhone)
                                    }
                                }

                                if summary.missingEmailCount > 0 {
                                    FilterChip(
                                        title: "Missing Email",
                                        count: summary.missingEmailCount,
                                        isSelected: selectedIssueType == .missingEmail
                                    ) {
                                        toggleIssueTypeFilter(.missingEmail)
                                    }
                                }

                                // Exclude filter
                                FilterChip(
                                    title: excludeMissingEmail ? "Show Missing Email" : "Hide Missing Email",
                                    count: summary.missingEmailCount,
                                    isSelected: excludeMissingEmail
                                ) {
                                    excludeMissingEmail.toggle()
                                    // Clear specific email filter if we're excluding
                                    if excludeMissingEmail && selectedIssueType == .missingEmail {
                                        selectedIssueType = nil
                                    }
                                }
                            }
                        }

                        // Issues list
                        LazyVStack(spacing: 12) {
                            ForEach(filteredIssues) { issue in
                                IssueRowView(
                                    issue: issue,
                                    actions: HealthIssueActionCatalog.actions(for: issue),
                                    selectionMode: isSelectionMode,
                                    isSelected: selectedIssueIDs.contains(issue.id),
                                    toggleSelection: { toggleSelection(for: issue) },
                                    onAction: { handleQuickAction($0, for: issue) }
                                )
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(item: $pendingQuickAction) { pending in
            QuickActionInputSheet(
                action: pending.action,
                issue: pending.issue,
                inputText: $quickActionInput,
                onSubmit: { value in
                    Task {
                        await executeQuickAction(pending.action, for: pending.issue, inputValue: value)
                    }
                },
                onCancel: {
                    pendingQuickAction = nil
                    quickActionInput = ""
                }
            )
        }
        .alert(item: $statusMessage) { status in
            Alert(
                title: Text(status.isError ? "Action Failed" : "Action Complete"),
                message: Text(status.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: issues) { _, newIssues in
            workingIssues = newIssues
            selectedIssueIDs.removeAll()
        }
    }

    private var healthScoreColor: Color {
        if summary.healthScore >= 80 {
            return .green
        } else if summary.healthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    private func toggleSeverityFilter(_ severity: DataQualityIssue.Severity) {
        if selectedSeverity == severity {
            selectedSeverity = nil
        } else {
            selectedSeverity = severity
        }
    }

    private func toggleIssueTypeFilter(_ type: DataQualityIssue.IssueType) {
        if selectedIssueType == type {
            selectedIssueType = nil
        } else {
            selectedIssueType = type
        }
    }

    private var selectionControls: some View {
        HStack(spacing: 12) {
            Button(isSelectionMode ? "Done Selecting" : "Select Issues") {
                withAnimation {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedIssueIDs.removeAll()
                    }
                }
            }
            .buttonStyle(.bordered)

            if isSelectionMode {
                Menu {
                    Button("Add to Follow-Up Group") {
                        performBulkAction(.followUp)
                    }
                    Button("Archive Contacts") {
                        performBulkAction(.archive)
                    }
                    Button("Mark Resolved") {
                        performBulkAction(.markResolved)
                    }
                } label: {
                    Label("Bulk Actions", systemImage: "tray.full.fill")
                }
                .disabled(selectedIssueIDs.isEmpty || isPerformingBulkAction)

                if isPerformingBulkAction {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Spacer()
        }
    }

    private func toggleSelection(for issue: DataQualityIssue) {
        if selectedIssueIDs.contains(issue.id) {
            selectedIssueIDs.remove(issue.id)
        } else {
            selectedIssueIDs.insert(issue.id)
        }
    }

    private func handleQuickAction(_ action: HealthIssueAction, for issue: DataQualityIssue) {
        if action.requiresInput {
            quickActionInput = ""
            pendingQuickAction = PendingQuickAction(issue: issue, action: action)
        } else {
            Task {
                await executeQuickAction(action, for: issue, inputValue: nil)
            }
        }
    }

    private func executeQuickAction(
        _ action: HealthIssueAction,
        for issue: DataQualityIssue,
        inputValue: String?
    ) async {
        let trimmedInput = inputValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var success = false

        if action.requiresInput && trimmedInput.isEmpty {
            statusMessage = StatusMessage(isError: true, message: "Value cannot be empty")
            return
        }

        let executor = HealthIssueActionExecutor(performer: contactsManager)
        let result = await executor.execute(action, for: issue, inputValue: trimmedInput)
        success = result.success

        await MainActor.run {
            pendingQuickAction = nil
            quickActionInput = ""
            if success {
                removeIssue(issue)
                logHealthAction(action, for: issue)
                if let effect = result.effect {
                    undoManager.register(effect: effect, actionTitle: action.title, contactsManager: contactsManager)
                }
                statusMessage = StatusMessage(isError: false, message: "Updated \(issue.contactName)")
            } else {
                statusMessage = StatusMessage(isError: true, message: "Couldn't update \(issue.contactName)")
            }
        }
    }

    private func performBulkAction(_ action: BulkAction) {
        let targets = workingIssues.filter { selectedIssueIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        isPerformingBulkAction = true
        Task {
            let executor = HealthIssueActionExecutor(performer: contactsManager)
            var successCount = 0
            var effects: [UndoEffect] = []
            for issue in targets {
                let actionDefinition: HealthIssueAction
                switch action {
                case .followUp:
                    actionDefinition = HealthIssueAction(
                        title: "Add to Follow-Up",
                        icon: "folder.badge.plus",
                        type: .addToGroup(name: HealthIssueActionCatalog.generalFollowUpGroupName),
                        inputPrompt: nil,
                        inputPlaceholder: nil
                    )
                case .archive:
                    actionDefinition = HealthIssueAction(
                        title: "Archive",
                        icon: "archivebox",
                        type: .archive,
                        inputPrompt: nil,
                        inputPlaceholder: nil
                    )
                case .markResolved:
                    actionDefinition = HealthIssueActionCatalog.markReviewedAction
                }

                let result = await executor.execute(actionDefinition, for: issue, inputValue: nil)
                if result.success {
                    successCount += 1
                    if let effect = result.effect {
                        effects.append(effect)
                    }
                    await MainActor.run {
                        removeIssue(issue)
                        logHealthAction(actionDefinition, for: issue)
                    }
                }
            }

            await MainActor.run {
                isPerformingBulkAction = false
                if successCount > 0 {
                    effects.forEach { undoManager.register(effect: $0, actionTitle: action.bulkTitle, contactsManager: contactsManager) }
                    let message: String
                    switch action {
                    case .archive:
                        message = "Archived \(successCount) contacts"
                    case .markResolved:
                        message = "Marked \(successCount) issues as reviewed"
                    case .followUp:
                        message = "Updated \(successCount) contacts"
                    }
                    statusMessage = StatusMessage(
                        isError: false,
                        message: message
                    )
                } else {
                    statusMessage = StatusMessage(isError: true, message: "Bulk action failed")
                }
            }
        }
    }

    private func removeIssue(_ issue: DataQualityIssue) {
        workingIssues.removeAll { $0.id == issue.id }
        selectedIssueIDs.remove(issue.id)
    }

    @MainActor
    private func logHealthAction(_ action: HealthIssueAction, for issue: DataQualityIssue) {
        let activity = HealthActivityFactory.makeActivity(action: action, issue: issue)
        contactsManager.logActivity(activity)
    }

    private struct PendingQuickAction: Identifiable {
        let issue: DataQualityIssue
        let action: HealthIssueAction
        var id: UUID { issue.id }
    }

    private struct StatusMessage: Identifiable {
        let id = UUID()
        let isError: Bool
        let message: String
    }

    private enum BulkAction {
        case followUp
        case archive
        case markResolved

        var bulkTitle: String {
            switch self {
            case .followUp: return "Add to Follow-Up"
            case .archive: return "Archive"
            case .markResolved: return "Mark Reviewed"
            }
        }
    }
}

// MARK: - Supporting Views

struct SeverityCard: View {
    let severity: DataQualityIssue.Severity
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: severityIcon)
                    .font(.title)
                    .foregroundColor(severityColor)

                Text("\(count)")
                    .responsiveFont(32, weight: .bold)

                Text("\(severity.description) Priority")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                ZStack {
                    (isSelected ? severityColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((isHovered || isFocused) ? severityColor.opacity(0.7) : (isSelected ? severityColor : Color.clear), lineWidth: (isHovered || isFocused) ? 2 : (isSelected ? 2 : 0))
                }
            )
            .cornerRadius(12)
            .scaleEffect((isHovered || isFocused) ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered || isFocused)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
#if !os(macOS)
        .hoverEffect(.lift)
#endif
    }

    private var severityIcon: String {
        switch severity {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }

    private var severityColor: Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .suggestion: return .blue
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("(\(count))")
                    .foregroundColor(.secondary)
            }
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct IssueRowView: View {
    let issue: DataQualityIssue
    let actions: [HealthIssueAction]
    let selectionMode: Bool
    let isSelected: Bool
    let toggleSelection: () -> Void
    let onAction: (HealthIssueAction) -> Void

    var body: some View {
        HStack(spacing: 16) {
            if selectionMode {
                Button(action: toggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(issue.contactName)
                    .font(.headline)
                    .bold()

                Text(issue.description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Menu {
                ForEach(actions) { action in
                    Button(action.title) {
                        onAction(action)
                    }
                    .labelStyle(.titleOnly)
                }

                Divider()

                Button("View in Contacts") {
                    openContactInContactsApp(contactId: issue.contactId)
                }
            } label: {
                Label("Quick Actions", systemImage: "bolt.fill")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var severityIcon: String {
        switch issue.severity {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .suggestion: return "lightbulb.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        case .suggestion: return .blue
        }
    }

    private func openContactInContactsApp(contactId: String) {
        if let url = URL(string: "addressbook://\(contactId)") {
            NSWorkspace.shared.open(url)
            print("📖 Opening contact in Contacts.app: \(issue.contactName) (\(contactId))")
        }
    }
}

struct QuickActionInputSheet: View {
    let action: HealthIssueAction
    let issue: DataQualityIssue
    @Binding var inputText: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(action.title)
                .font(.title3.bold())
            Text("for \(issue.contactName)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(action.inputPrompt ?? "Provide the missing information to update this contact from the dashboard.")
                .font(.body)
                .multilineTextAlignment(.center)

            TextField(action.inputPlaceholder ?? "Value", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    onSubmit(inputText)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(32)
        .frame(width: 420)
    }
}

// MARK: - Quick Action Executor

protocol ContactActionPerforming: AnyObject {
    func addPhoneNumber(_ phoneNumber: String, label: String, to contactId: String) async -> Bool
    func addEmailAddress(_ emailAddress: String, label: String, to contactId: String) async -> Bool
    func addContact(_ contactId: String, toGroupNamed groupName: String) async -> Bool
    func archiveContact(_ contactId: String) async -> Bool
    func removePhoneNumber(_ phoneNumber: String, from contactId: String) async -> Bool
    func removeEmailAddress(_ emailAddress: String, from contactId: String) async -> Bool
    func removeContact(_ contactId: String, fromGroupNamed groupName: String) async -> Bool
    func updateFullName(_ contactId: String, fullName: String) async -> Bool
    func fetchNameComponents(contactId: String) async -> (given: String, family: String)?
}

extension ContactsManager: ContactActionPerforming {}

struct HealthIssueActionExecutor {
    let performer: ContactActionPerforming

    func execute(_ action: HealthIssueAction, for issue: DataQualityIssue, inputValue: String?) async -> HealthActionResult {
        switch action.type {
        case .addPhone:
            guard let value = sanitizedInput(inputValue) else { return HealthActionResult(success: false, effect: nil) }
            let success = await performer.addPhoneNumber(value, label: CNLabelPhoneNumberMobile, to: issue.contactId)
            return HealthActionResult(success: success, effect: success ? .addedPhone(contactId: issue.contactId, value: value) : nil)

        case .addEmail:
            guard let value = sanitizedInput(inputValue) else { return HealthActionResult(success: false, effect: nil) }
            let success = await performer.addEmailAddress(value, label: CNLabelWork, to: issue.contactId)
            return HealthActionResult(success: success, effect: success ? .addedEmail(contactId: issue.contactId, value: value) : nil)

        case .addToGroup(let name):
            let success = await performer.addContact(issue.contactId, toGroupNamed: name)
            return HealthActionResult(success: success, effect: success ? .addedToGroup(contactId: issue.contactId, groupName: name) : nil)

        case .archive:
            let success = await performer.archiveContact(issue.contactId)
            return HealthActionResult(success: success, effect: success ? .archivedContact(contactId: issue.contactId) : nil)

        case .updateName:
            guard let value = sanitizedInput(inputValue), let previous = await performer.fetchNameComponents(contactId: issue.contactId) else {
                return HealthActionResult(success: false, effect: nil)
            }
            let success = await performer.updateFullName(issue.contactId, fullName: value)
            return HealthActionResult(success: success, effect: success ? .updatedName(contactId: issue.contactId, previousGiven: previous.given, previousFamily: previous.family, newValue: value) : nil)

        }
    }

    private func sanitizedInput(_ input: String?) -> String? {
        guard let trimmed = input?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

struct HealthActionResult {
    let success: Bool
    let effect: UndoEffect?
}

extension DataQualityIssue.Severity: CustomStringConvertible {
    var description: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .suggestion: return "Suggestion"
        }
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    HealthReportView(issues: [])
        .environmentObject(ContactsManager.shared)
        .environmentObject(ContactsUndoManager())
}
#endif
