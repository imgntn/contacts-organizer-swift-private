//
//  DashboardView.swift
//  Contacts Organizer
//
//  Main dashboard after successful permission grant
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DashboardTab = .overview
    @State private var navigationHistory: [DashboardTab] = []
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var dataQualityIssues: [DataQualityIssue] = []
    @State private var isAnalyzing = false
    @AppStorage("autoRefresh") private var autoRefresh = true
    @AppStorage("sidebarOrder") private var sidebarOrderStorageRaw: String = ""

    private func getSidebarOrder() -> [String] {
        guard let data = sidebarOrderStorageRaw.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    @MainActor
    private func setSidebarOrder(_ newValue: [String]) {
        if let data = try? JSONEncoder().encode(newValue),
           let string = String(data: data, encoding: .utf8) {
            sidebarOrderStorageRaw = string
        } else {
            sidebarOrderStorageRaw = ""
        }
    }

    @State private var sidebarItems: [DashboardTab] = DashboardTab.allCases
    @State private var isReordering: Bool = false

    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case duplicates = "Duplicates"
        case healthReport = "Health Report"
        case groups = "Groups"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .duplicates: return "arrow.triangle.merge"
            case .healthReport: return "wrench.and.screwdriver.fill"
            case .groups: return "folder.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            ZStack(alignment: .top) {
                List(selection: $selectedTab) {
                    ForEach(sidebarItems, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                    .onMove { indices, newOffset in
                        sidebarItems.move(fromOffsets: indices, toOffset: newOffset)
                        // Persist new order
                        setSidebarOrder(sidebarItems.map { $0.rawValue })
                    }
                }
                .moveDisabled(!isReordering)

                if isReordering {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                        Text("Drag to reorder sidebar items")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Contacts Organizer")
            .frame(minWidth: 200)
        } detail: {
            // Main content
            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(
                        duplicateGroups: duplicateGroups,
                        dataQualityIssues: dataQualityIssues,
                        selectedTab: $selectedTab
                    )

                case .duplicates:
                    DuplicatesView(duplicateGroups: duplicateGroups)

                case .healthReport:
                    HealthReportView(issues: dataQualityIssues)

                case .groups:
                    GroupsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if contactsManager.isLoading || isAnalyzing {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        // Loading indicator card
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(width: 40, height: 40)

                            Text(loadingMessage)
                                .font(.headline)

                            if isAnalyzing {
                                Text("This may take a moment for large contact lists")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                    }
                }
            }
        }
        .onAppear {
            // Restore sidebar order if previously saved
            if !getSidebarOrder().isEmpty {
                let mapped = getSidebarOrder().compactMap { DashboardTab(rawValue: $0) }
                // Ensure we include any new tabs that may have been added in updates
                let missing = DashboardTab.allCases.filter { !mapped.contains($0) }
                sidebarItems = mapped + missing
            }

            // Load data in background on first appearance or if auto-refresh is enabled
            if autoRefresh || (contactsManager.contacts.isEmpty && !contactsManager.isLoading) {
                Task {
                    await loadData()
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Push previous tab into history if it exists and isn't the same as new
            if oldValue != newValue {
                navigationHistory.append(oldValue)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    if let last = navigationHistory.popLast() {
                        selectedTab = last
                    } else {
                        // If no history, try to dismiss any presented view
                        dismiss()
                    }
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(navigationHistory.isEmpty && selectedTab == .overview)
                .help("Go back")
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isReordering.toggle()
                    if !isReordering {
                        setSidebarOrder(sidebarItems.map { $0.rawValue })
                    }
                }) {
                    Label(isReordering ? "Done" : "Reorder", systemImage: isReordering ? "checkmark" : "arrow.up.arrow.down")
                }
                .help(isReordering ? "Finish reordering" : "Reorder sidebar items")
                .animation(.default, value: isReordering)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await loadData() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(contactsManager.isLoading || isAnalyzing)
            }
        }
    }

    private var loadingMessage: String {
        if contactsManager.isLoading {
            return "Loading contacts..."
        } else if isAnalyzing {
            return "Analyzing duplicates and data quality..."
        } else {
            return "Loading..."
        }
    }

    private func loadData() async {
        // Phase 1: Fetch contacts (fast, ~1 second)
        await contactsManager.fetchAllContacts()

        // Phase 2: Analyze in background WITHOUT blocking UI
        await MainActor.run {
            isAnalyzing = true
        }

        // Get contacts snapshot on the main actor
        let contacts = await MainActor.run { contactsManager.contacts }

        // Capture singletons on the main actor to respect actor isolation in Swift 6
        let duplicateDetector = await MainActor.run { DuplicateDetector.shared }
        let qualityAnalyzer = await MainActor.run { DataQualityAnalyzer.shared }

        // Perform analysis off the main actor
        let result = await Task.detached { @Sendable in
            // Use captured instances to avoid touching main-actor isolated singletons here
            let duplicates = duplicateDetector.findDuplicates(in: contacts)
            let issues = qualityAnalyzer.analyzeDataQuality(contacts: contacts)
            return (duplicates, issues)
        }.value

        // Update UI and statistics on the main actor
        await MainActor.run {
            duplicateGroups = result.0
            dataQualityIssues = result.1
            isAnalyzing = false
            contactsManager.updateStatisticsWithIssues(result.1)
        }

        // Return immediately - UI can render while analysis happens in background
    }
}

// MARK: - Overview View

struct OverviewView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @Environment(\.openSettings) private var openSettings
    let duplicateGroups: [DuplicateGroup]
    let dataQualityIssues: [DataQualityIssue]
    @Binding var selectedTab: DashboardView.DashboardTab
    @State private var showBackupReminder = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .responsiveFont(36, weight: .bold)

                    if let stats = contactsManager.statistics {
                        Text("\(stats.totalContacts) contacts")
                            .responsiveFont(20)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Safety reminder
                if showBackupReminder && (duplicateGroups.count > 0 || dataQualityIssues.count > 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title2)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create a Backup First!")
                                .responsiveFont(14, weight: .semibold)
                                .foregroundColor(.orange)

                            Text("Before making any changes, go to Settings → General → Backup All Contacts to protect your data.")
                                .responsiveFont(11)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            // Open Settings window using official API
                            openSettings()
                        }) {
                            HStack(spacing: 4) {
                                Text("Open Settings")
                                Text("(⌘,)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("Open Settings or press ⌘,")

                        Button(action: {
                            showBackupReminder = false
                        }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }

                // Statistics Grid
                if let stats = contactsManager.statistics {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Contacts with Phone",
                            value: "\(stats.contactsWithPhone)",
                            icon: "phone.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "Contacts with Email",
                            value: "\(stats.contactsWithEmail)",
                            icon: "envelope.fill",
                            color: .green
                        )
                        StatCard(
                            title: "Complete Contacts",
                            value: "\(stats.contactsWithBoth)",
                            icon: "checkmark.circle.fill",
                            color: .purple
                        )
                        StatCard(
                            title: "With Organization",
                            value: "\(stats.contactsWithOrganization)",
                            icon: "building.2.fill",
                            color: .orange,
                            action: { selectedTab = .groups }
                        )
                        StatCard(
                            title: "With Photos",
                            value: "\(stats.contactsWithPhoto)",
                            icon: "photo.fill",
                            color: .pink,
                            action: { selectedTab = .groups }
                        )
                        StatCard(
                            title: "Data Quality",
                            value: String(format: "%.0f%%", stats.dataQualityScore),
                            icon: "chart.bar.fill",
                            color: .cyan,
                            action: { selectedTab = .healthReport }
                        )
                    }
                }

                // Issues Summary
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Issues Found")
                            .responsiveFont(20, weight: .bold)
                        Spacer()
                    }

                    HStack(spacing: 16) {
                        IssueCard(
                            count: duplicateGroups.count,
                            title: "Duplicate Groups",
                            color: .red,
                            action: { selectedTab = .duplicates }
                        )
                        IssueCard(
                            count: dataQualityIssues.filter { $0.severity == .high }.count,
                            title: "High Priority Issues",
                            color: .orange,
                            action: { selectedTab = .healthReport }
                        )
                        IssueCard(
                            count: dataQualityIssues.count,
                            title: "Total Issues",
                            color: .yellow,
                            action: { selectedTab = .healthReport }
                        )
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
                .help("Tap to view details")
                .focusable(true)
                .focused($isFocused)
                .accessibilityAddTraits(.isButton)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        let gradient = LinearGradient(colors: [color.opacity(0.25), color.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.subheadline)
                }
                Spacer()
            }

            Text(value)
                .responsiveFont(32, weight: .bold)

            Text(title)
                .responsiveFont(13)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                if action != nil {
                    gradient
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.06))
                }
                RoundedRectangle(cornerRadius: 12)
                    .stroke((isHovered || isFocused) ? color.opacity(0.6) : (action != nil ? color.opacity(0.25) : Color.clear), lineWidth: (isHovered || isFocused) ? 2 : 1)
            }
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect((isHovered || isFocused) ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered || isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
#if !os(macOS)
        .hoverEffect(.lift)
#endif
    }
}

struct IssueCard: View {
    let count: Int
    let title: String
    let color: Color
    var action: (() -> Void)? = nil

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
                .help("Tap to view \(title.lowercased())")
                .focusable(true)
                .focused($isFocused)
                .accessibilityAddTraits(.isButton)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        let gradient = LinearGradient(colors: [color.opacity(0.25), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)

        return VStack(spacing: 8) {
            Text("\(count)")
                .responsiveFont(24, weight: .bold)

            Text(title)
                .responsiveFont(13)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            ZStack {
                if action != nil {
                    gradient
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                }
                RoundedRectangle(cornerRadius: 10)
                    .stroke((isHovered || isFocused) ? color.opacity(0.7) : (action != nil ? color.opacity(0.35) : color.opacity(0.25)), lineWidth: (isHovered || isFocused) ? 2 : 1)
            }
        )
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect((isHovered || isFocused) ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered || isFocused)
#if os(macOS)
        .onHover { isHovered = $0 }
#endif
#if !os(macOS)
        .hoverEffect(.lift)
#endif
    }
}

#Preview {
    DashboardView()
        .environmentObject(ContactsManager.shared)
        .frame(width: 1200, height: 800)
}

