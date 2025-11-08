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
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duplicate Contacts")
                                    .font(.system(size: 36, weight: .bold))

                                Text("\(duplicateGroups.count) groups found")
                                    .font(.title3)
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

    var body: some View {
        VStack(alignment: leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.primaryContact.fullName)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(group.contacts.count) contacts", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(matchTypeLabel, systemImage: matchTypeIcon)
                            .font(.caption)
                            .foregroundColor(confidenceColor)

                        Text(String(format: "%.0f%% match", group.confidence * 100))
                            .font(.caption)
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
                        // TODO: Show merge dialog
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Not Duplicates") {
                        // TODO: Mark as not duplicates
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
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
                .font(.title2)
                .foregroundColor(isPrimary ? .blue : .gray)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.fullName)
                        .font(.subheadline.bold())

                    if isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let org = contact.organization {
                    Text(org)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    if !contact.phoneNumbers.isEmpty {
                        Label(contact.phoneNumbers[0], systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !contact.emailAddresses.isEmpty {
                        Label(contact.emailAddresses[0], systemImage: "envelope.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
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
                .font(.system(size: 60))
                .foregroundStyle(color.gradient)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title.bold())

                Text(message)
                    .font(.body)
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
