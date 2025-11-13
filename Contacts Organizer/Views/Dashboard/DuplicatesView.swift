//
//  DuplicatesView.swift
//  Contacts Organizer
//
//  View for managing duplicate contacts
//

import SwiftUI

struct DuplicatesView: View {
    let duplicateGroups: [DuplicateGroup]
    @State private var selectedGroup: DuplicateGroup?

    var body: some View {
        Group {
            if duplicateGroups.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "No Duplicates Found",
                    message: "Your contacts look clean! No duplicate entries were detected.",
                    color: .green
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duplicate Contacts")
                                    .responsiveFont(42, weight: .bold)

                                Text("\(duplicateGroups.count) groups found")
                                    .responsiveFont(20)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        // Duplicate groups list
                        ForEach(duplicateGroups) { group in
                            DuplicateGroupCard(group: group)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

// MARK: - Duplicate Group Card

struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @State private var isExpanded = false
    @State private var showMergeSheet = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.primaryContact.fullName)
                        .responsiveFont(14, weight: .semibold)

                    HStack(spacing: 12) {
                        Label("\(group.contacts.count) contacts", systemImage: "person.2.fill")
                            .platformCaptionFont()
                            .foregroundColor(.secondary)

                        Label(matchTypeLabel, systemImage: matchTypeIcon)
                            .platformCaptionFont()
                            .foregroundColor(confidenceColor)

                        Text(String(format: "%.0f%% match", group.confidence * 100))
                            .platformCaptionFont()
                            .foregroundColor(confidenceColor)
                    }
                }

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            // Expanded content
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(group.contacts) { contact in
                        ContactRowView(contact: contact, isPrimary: contact.id == group.primaryContact.id)
                    }
                }

                Divider()

                HStack {
                    Button("Review & Merge") {
                        showMergeSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Not Duplicates - Edit in Contacts") {
                        openContactsInContactsApp(group.contacts)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                RoundedRectangle(cornerRadius: 12)
                    .stroke((isHovered || isFocused) ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: (isHovered || isFocused) ? 2 : 0)
            }
        )
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .focusable(true)
        .focused($isFocused)
        .scaleEffect((isHovered || isFocused) ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered || isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
#if !os(macOS)
        .hoverEffect(.lift)
#endif
        .sheet(isPresented: $showMergeSheet) {
            MergeContactsSheet(group: group)
        }
    }

    private func openContactsInContactsApp(_ contacts: [ContactSummary]) {
        // Open each contact using the addressbook:// URL scheme
        for contact in contacts {
            if let url = URL(string: "addressbook://\(contact.id)") {
                NSWorkspace.shared.open(url)
                print("📖 Opening contact in Contacts.app: \(contact.fullName) (\(contact.id))")
            }
        }
    }

    private var matchTypeLabel: String {
        switch group.matchType {
        case .exactName: return "Exact name"
        case .similarName: return "Similar name"
        case .samePhone: return "Same phone"
        case .sameEmail: return "Same email"
        case .multipleMatches: return "Multiple matches"
        }
    }

    private var matchTypeIcon: String {
        switch group.matchType {
        case .exactName: return "textformat"
        case .similarName: return "textformat.abc"
        case .samePhone: return "phone.fill"
        case .sameEmail: return "envelope.fill"
        case .multipleMatches: return "arrow.triangle.merge"
        }
    }

    private var confidenceColor: Color {
        if group.confidence > 0.9 {
            return .green
        } else if group.confidence > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: ContactSummary
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .responsiveFont(20)
                .foregroundColor(isPrimary ? .blue : .gray)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.fullName)
                        .platformBodyFont(weight: .semibold)

                    if isPrimary {
                        Text("Primary")
                            .platformMiniCaptionFont(weight: .semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let org = contact.organization {
                    Text(org)
                        .platformCaptionFont()
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    if !contact.phoneNumbers.isEmpty {
                        Label(contact.phoneNumbers[0], systemImage: "phone.fill")
                            .platformCaptionFont()
                            .foregroundColor(.secondary)
                    }

                    if !contact.emailAddresses.isEmpty {
                        Label(contact.emailAddresses[0], systemImage: "envelope.fill")
                            .platformCaptionFont()
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Merge Contacts Sheet

struct MergeContactsSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var contactsManager: ContactsManager
    let group: DuplicateGroup

    @State private var selectedPrimaryId: String
    @State private var mergePlan: MergePlan
    @State private var isMerging = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shouldCreateSnapshot = true

    init(group: DuplicateGroup) {
        self.group = group
        _selectedPrimaryId = State(initialValue: group.primaryContact.id)
        _mergePlan = State(initialValue: MergePlan.initial(for: group))
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            Divider()
            primarySelectionSection
            conflictResolutionSection
            valueSelectionSection(
                title: "Phone Numbers",
                icon: "phone.fill",
                options: phoneOptions,
                keyPath: \.selectedPhoneNumbers,
                emptyStateDescription: "No phone numbers found across this group"
            )
            valueSelectionSection(
                title: "Email Addresses",
                icon: "envelope.fill",
                options: emailOptions,
                keyPath: \.selectedEmailAddresses,
                emptyStateDescription: "No email addresses available to merge"
            )
            snapshotSection

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            actionButtons
        }
        .padding(32)
        .frame(width: 780, height: 760)
        .onChange(of: selectedPrimaryId) { oldValue, newValue in
            updatePlanForPrimaryChange(from: oldValue, to: newValue)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Merge Duplicate Contacts")
                    .font(.title.bold())
            }

            Text("Choose what stays, what gets archived, and how conflicting fields should be resolved before completing the merge.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
    }

    private var primarySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Primary Contact")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(group.contacts) { contact in
                        MergeContactSelectionRow(
                            contact: contact,
                            isSelected: selectedPrimaryId == contact.id,
                            onSelect: { selectedPrimaryId = contact.id }
                        )
                    }
                }
            }
            .frame(height: 240)
        }
    }

    private var conflictResolutionSection: some View {
        GroupBox("Resolve Conflicts") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Display Name", selection: $mergePlan.preferredNameContactId) {
                    ForEach(group.contacts, id: \.id) { contact in
                        Text(contact.fullName)
                            .tag(contact.id)
                    }
                }

                Picker("Company & Title", selection: bindingForOrganization()) {
                    ForEach(group.contacts, id: \.id) { contact in
                        Text(contact.organization ?? "Use \(contact.fullName)'s info")
                            .tag(contact.id)
                    }
                }

                let photoCapableContacts = group.contacts.filter { $0.hasProfileImage }
                if !photoCapableContacts.isEmpty {
                    Picker("Profile Photo", selection: bindingForPhoto()) {
                        Text("Keep current photo")
                            .tag(String?.none)
                        ForEach(photoCapableContacts, id: \.id) { contact in
                            Text(contact.fullName)
                                .tag(String?.some(contact.id))
                        }
                    }
                }
            }
        }
    }

    private func valueSelectionSection(
        title: String,
        icon: String,
        options: [MergeValueOption],
        keyPath: WritableKeyPath<MergePlan, Set<String>>,
        emptyStateDescription: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            if options.isEmpty {
                Text(emptyStateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ForEach(options) { option in
                    Toggle(isOn: binding(for: option.value, keyPath: keyPath)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.displayValue)
                                .font(.body)
                            Text(option.ownersDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $shouldCreateSnapshot) {
                Label("Create safety snapshot before merging", systemImage: "externaldrive.fill.badge.timemachine")
            }
            .toggleStyle(.switch)

            Text("Snapshots are stored inside the app's Library folder so you can roll back a merge if needed.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button(action: performMerge) {
                HStack {
                    if isMerging {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                    Text(isMerging ? "Working..." : "Merge Contacts")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isMerging)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var phoneOptions: [MergeValueOption] {
        MergePlanBuilder.uniqueValues(for: group.contacts, keyPath: \.phoneNumbers)
    }

    private var emailOptions: [MergeValueOption] {
        MergePlanBuilder.uniqueValues(for: group.contacts, keyPath: \.emailAddresses)
    }

    private func binding(for value: String, keyPath: WritableKeyPath<MergePlan, Set<String>>) -> Binding<Bool> {
        Binding(
            get: { mergePlan[keyPath: keyPath].contains(value) },
            set: { include in
                if include {
                    mergePlan[keyPath: keyPath].insert(value)
                } else {
                    mergePlan[keyPath: keyPath].remove(value)
                }
            }
        )
    }

    private func bindingForOrganization() -> Binding<String> {
        Binding(
            get: { mergePlan.preferredOrganizationContactId ?? selectedPrimaryId },
            set: { mergePlan.preferredOrganizationContactId = $0 }
        )
    }

    private func bindingForPhoto() -> Binding<String?> {
        Binding(
            get: { mergePlan.preferredPhotoContactId },
            set: { mergePlan.preferredPhotoContactId = $0 }
        )
    }

    private func updatePlanForPrimaryChange(from oldValue: String?, to newValue: String) {
        if mergePlan.preferredNameContactId == oldValue {
            mergePlan.preferredNameContactId = newValue
        }
        if mergePlan.preferredOrganizationContactId == oldValue {
            mergePlan.preferredOrganizationContactId = newValue
        }
        if mergePlan.preferredPhotoContactId == oldValue {
            mergePlan.preferredPhotoContactId = newValue
        }
    }

    private func performMerge() {
        isMerging = true
        showError = false

        let configuration = mergePlan.configuration(primaryContactId: selectedPrimaryId, group: group)

        Task {
            if shouldCreateSnapshot {
                _ = await contactsManager.createSafetySnapshot(tag: "merge_\(group.primaryContact.fullName)")
            }

            let success = await contactsManager.mergeContacts(using: configuration)

            await MainActor.run {
                isMerging = false
                if success {
                    dismiss()
                } else {
                    showError = true
                    errorMessage = contactsManager.errorMessage ?? "Failed to merge contacts"
                }
            }
        }
    }
}

struct MergeContactSelectionRow: View {
    let contact: ContactSummary
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)

                // Contact details
                VStack(alignment: .leading, spacing: 6) {
                    Text(contact.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let org = contact.organization {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                                .font(.caption)
                            Text(org)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        if !contact.phoneNumbers.isEmpty {
                            Label(contact.phoneNumbers[0], systemImage: "phone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !contact.emailAddresses.isEmpty {
                            Label(contact.emailAddresses[0], systemImage: "envelope")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Data completeness indicator
                    HStack(spacing: 8) {
                        if !contact.phoneNumbers.isEmpty {
                            Text("\(contact.phoneNumbers.count) phone")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }

                        if !contact.emailAddresses.isEmpty {
                            Text("\(contact.emailAddresses.count) email")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }

                        if contact.hasProfileImage {
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let color: Color

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .responsiveFont(60)
                .foregroundStyle(color.gradient)

            VStack(spacing: 8) {
                Text(title)
                    .responsiveFont(24, weight: .bold)

                Text(message)
                    .responsiveFont(14)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    DuplicatesView(duplicateGroups: [])
}
#endif
