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
                            .responsiveFont(11)
                            .foregroundColor(.secondary)

                        Label(matchTypeLabel, systemImage: matchTypeIcon)
                            .responsiveFont(11)
                            .foregroundColor(confidenceColor)

                        Text(String(format: "%.0f%% match", group.confidence * 100))
                            .responsiveFont(11)
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
                        .responsiveFont(12, weight: .semibold)

                    if isPrimary {
                        Text("Primary")
                            .responsiveFont(10)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let org = contact.organization {
                    Text(org)
                        .responsiveFont(11)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    if !contact.phoneNumbers.isEmpty {
                        Label(contact.phoneNumbers[0], systemImage: "phone.fill")
                            .responsiveFont(11)
                            .foregroundColor(.secondary)
                    }

                    if !contact.emailAddresses.isEmpty {
                        Label(contact.emailAddresses[0], systemImage: "envelope.fill")
                            .responsiveFont(11)
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
    @State private var isMerging = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(group: DuplicateGroup) {
        self.group = group
        // Default to the primary contact from the group
        _selectedPrimaryId = State(initialValue: group.primaryContact.id)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text("Merge Duplicate Contacts")
                        .font(.title.bold())
                }

                Text("Select which contact to keep as the primary. All data will be merged into this contact, and duplicates will be deleted.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            Divider()

            // Contact selection
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
                .frame(height: 300)
            }

            // Info box
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("What happens during merge:")
                        .font(.subheadline.bold())

                    Text("• All phone numbers, emails, and addresses will be combined\n• Organization info and notes will be preserved\n• The other \(group.contacts.count - 1) contact(s) will be deleted\n• This action cannot be undone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Buttons
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
                        Text(isMerging ? "Merging..." : "Merge Contacts")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isMerging)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 700, height: 650)
    }

    private func performMerge() {
        isMerging = true
        showError = false

        // Get source IDs (all contacts except the selected primary)
        let sourceIds = group.contacts
            .filter { $0.id != selectedPrimaryId }
            .map { $0.id }

        Task {
            let success = await contactsManager.mergeContacts(
                sourceIds: sourceIds,
                destinationId: selectedPrimaryId
            )

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

#Preview {
    DuplicatesView(duplicateGroups: [])
}
