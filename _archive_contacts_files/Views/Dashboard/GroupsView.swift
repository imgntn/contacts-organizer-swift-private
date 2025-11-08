//
//  GroupsView.swift
//  Contacts Organizer
//
//  View for managing contact groups
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @State private var showCreateGroupSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Groups")
                        .font(.system(size: 36, weight: .bold))

                    Text("Organize your contacts into smart groups")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { showCreateGroupSheet = true }) {
                    Label("Create Group", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            // Coming soon placeholder
            VStack(spacing: 20) {
                Image(systemName: "folder.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)

                VStack(spacing: 8) {
                    Text("Smart Groups Coming Soon")
                        .font(.title.bold())

                    Text("Automatically organize contacts by location, company, and custom criteria.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "mappin.circle.fill", text: "Geographic grouping", color: .blue)
                    FeatureRow(icon: "building.2.fill", text: "Organization-based groups", color: .green)
                    FeatureRow(icon: "star.fill", text: "Custom smart groups", color: .orange)
                    FeatureRow(icon: "arrow.triangle.branch", text: "Bulk organization", color: .purple)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            CreateGroupSheet()
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

struct CreateGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var groupName = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Group")
                .font(.title.bold())

            TextField("Group Name", text: $groupName)
                .textFieldStyle(.roundedBorder)

            Text("Group creation functionality coming soon!")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    // TODO: Implement group creation
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

#Preview {
    GroupsView()
        .environmentObject(ContactsManager.shared)
}
