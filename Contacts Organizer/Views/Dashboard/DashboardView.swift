//
//  DashboardView.swift
//  Contacts Organizer
//
//  Main dashboard after successful permission grant
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var contactsManager: ContactsManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var undoManager: ContactsUndoManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DashboardTab? = .overview
    @State private var navigationHistory: [DashboardTab] = []
    @State private var duplicateGroups: [DuplicateGroup] = []
    @State private var dataQualityIssues: [DataQualityIssue] = []
    @State private var isAnalyzing = false
    @State private var targetSmartGroupName: String?
    @State private var refreshMachine = RefreshStateMachine()
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

    enum DashboardTab: String, CaseIterable, Hashable {
        case overview = "Overview"
        case smartGroups = "Smart Groups"
        case manualGroups = "Manual Groups"
        case duplicates = "Duplicates"
        case healthReport = "Health Report"

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .duplicates: return "arrow.triangle.merge"
            case .healthReport: return "wrench.and.screwdriver.fill"
            case .smartGroups: return "sparkles"
            case .manualGroups: return "folder.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button(action: toggleReordering) {
                            Label(isReordering ? "Finish Reordering" : "Rearrange Sidebar", systemImage: "arrow.up.arrow.down.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(isReordering ? "Finish reordering" : "Reorder sidebar items")
                        Spacer()
                    }

                    if isReordering {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.left.fill")
                            Text("Drag to reorder sidebar items")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 12)

                List(selection: $selectedTab) {
                    ForEach(sidebarItems, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                            .padding(.vertical, 4)
                    }
                    .onMove { indices, newOffset in
                        sidebarItems.move(fromOffsets: indices, toOffset: newOffset)
                        // Persist new order
                        setSidebarOrder(sidebarItems.map { $0.rawValue })
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .moveDisabled(!isReordering)
            }
            .navigationTitle("Contacts Organizer")
            .frame(minWidth: 200)
        } detail: {
            // Main content
            Group {
                switch selectedTab ?? .overview {
                case .overview:
                    OverviewView(
                        duplicateGroups: duplicateGroups,
                        dataQualityIssues: dataQualityIssues,
                        selectedTab: $selectedTab,
                        targetSmartGroupName: $targetSmartGroupName,
                        contactsManager: contactsManager,
                        appState: appState,
                        undoManager: undoManager
                    )

                case .duplicates:
                    DuplicatesView(duplicateGroups: duplicateGroups)

                case .healthReport:
                    HealthReportView(issues: dataQualityIssues)

                case .smartGroups:
                    GroupsView(initialTab: .smart, targetSmartGroupName: $targetSmartGroupName)

                case .manualGroups:
                    GroupsView(initialTab: .manual, targetSmartGroupName: $targetSmartGroupName)
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
                var mapped: [DashboardTab] = []
                for str in getSidebarOrder() {
                    if str == "Groups" {
                        // Migrate old single Groups item into two new entries in-place
                        mapped.append(.smartGroups)
                        mapped.append(.manualGroups)
                    } else if let tab = DashboardTab(rawValue: str) {
                        mapped.append(tab)
                    }
                }
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
            if let oldValue, let newValue, oldValue != newValue {
                navigationHistory.append(oldValue)
            }
        }
        .onChange(of: contactsManager.refreshTrigger) { _, trigger in
            handleRefreshTrigger(trigger)
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
                .disabled(navigationHistory.isEmpty && (selectedTab ?? .overview) == .overview)
                .help("Go back")
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

    private func handleRefreshTrigger(_ trigger: ContactsManager.RefreshTrigger) {
        guard autoRefresh else { return }
        if refreshMachine.handleTrigger(autoRefreshEnabled: autoRefresh, isLoading: contactsManager.isLoading, isAnalyzing: isAnalyzing) {
            Task {
                await loadData(triggerReason: trigger.reason)
            }
        }
    }

    private func loadData(triggerReason: ContactsManager.RefreshReason? = nil) async {
        guard refreshMachine.prepareForLoad(isLoading: contactsManager.isLoading, isAnalyzing: isAnalyzing) else { return }

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

        if refreshMachine.consumePendingRefresh() {
            Task {
                await loadData(triggerReason: triggerReason)
            }
        }
    }

    private func toggleReordering() {
        withAnimation(.default) {
            isReordering.toggle()
        }
        if !isReordering {
            setSidebarOrder(sidebarItems.map { $0.rawValue })
        }
    }
}

// MARK: - Overview View

struct OverviewView: View {
    @Environment(\.openSettings) private var openSettings
    var duplicateGroups: [DuplicateGroup]
    var dataQualityIssues: [DataQualityIssue]
    @Binding var selectedTab: DashboardView.DashboardTab?
    @Binding var targetSmartGroupName: String?
    @StateObject private var viewModel: OverviewDashboardModel

    init(
        duplicateGroups: [DuplicateGroup],
        dataQualityIssues: [DataQualityIssue],
        selectedTab: Binding<DashboardView.DashboardTab?>,
        targetSmartGroupName: Binding<String?>,
        contactsManager: OverviewContactsProviding,
        appState: OverviewAppStateProviding,
        undoManager: ContactsUndoManager
    ) {
        self.duplicateGroups = duplicateGroups
        self.dataQualityIssues = dataQualityIssues
        _selectedTab = selectedTab
        _targetSmartGroupName = targetSmartGroupName
        let navigator = OverviewNavigator(selectedTab: selectedTab, targetSmartGroupName: targetSmartGroupName)
        _viewModel = StateObject(wrappedValue: OverviewDashboardModel(
            contactsProvider: contactsManager,
            appState: appState,
            navigator: navigator,
            undoManager: undoManager
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .responsiveFont(36, weight: .bold)

                    Text("\(viewModel.totalContacts) contacts")
                        .responsiveFont(20)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Safety reminder (required)
                if viewModel.showBackupReminder {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Create a Backup First!", systemImage: "exclamationmark.shield.fill")
                                .responsiveFont(16, weight: .semibold)
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Required")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Text("Before making any changes, go to Settings → General → Backup All Contacts to protect your data.")
                            .platformBodyFont()
                            .foregroundColor(.secondary)

                        Button(action: openGeneralSettings) {
                            Label("Open App Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .help("Open Settings or press ⌘,")

                        Button("Dismiss Reminder") {
                            viewModel.dismissBackupReminder()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                if !viewModel.recentActivities.isEmpty {
                    recentActivitySection
                }

                LazyVGrid(columns: overviewColumns, spacing: 16) {
                    featureCard(
                        title: "Smart Groups",
                        icon: "sparkles",
                        color: .purple,
                        description: "Auto-generated collections surface contacts missing info or matching useful recipes.",
                        status: "\(ContactsManager.defaultSmartGroups.count)+ recipes available",
                        highlights: [
                            ("sparkles", "Dive into curated segments instantly"),
                            ("plus.app", "Create a group in Contacts with one tap")
                        ],
                        primaryButtonTitle: "Browse Smart Groups",
                        primaryButtonIcon: "sparkles",
                        primaryAction: {
                            viewModel.browseSmartGroups()
                        },
                        secondary: (
                            title: "Review Missing Info",
                            icon: "exclamationmark.circle",
                            action: {
                                viewModel.reviewSmartGroup(named: "Missing Email")
                            }
                        )
                    )

                    featureCard(
                        title: "Manual Groups",
                        icon: "folder.fill.badge.plus",
                        color: .blue,
                        description: "Build your own folders for projects, events, or VIP lists with full control.",
                        status: "\(viewModel.manualGroupCount) groups in Contacts",
                        highlights: [
                            ("plus.circle", "Spin up a fresh manual group"),
                            ("trash", "Clean up duplicate folders safely")
                        ],
                        primaryButtonTitle: "Open Manual Groups",
                        primaryButtonIcon: "folder.fill",
                        primaryAction: {
                            viewModel.browseManualGroups()
                        },
                        secondary: (
                            title: "Create New Group",
                            icon: "plus.circle",
                            action: {
                                viewModel.browseManualGroups()
                            }
                        )
                    )

                    featureCard(
                        title: "Duplicates",
                        icon: "arrow.triangle.merge",
                        color: .green,
                        description: "Review contacts that look identical so you can merge, link, or ignore them.",
                        status: "\(viewModel.duplicateCount) groups detected",
                        highlights: [
                            ("eye", "Compare conflicting values side-by-side"),
                            ("arrow.down", "Apply quick merges with confidence")
                        ],
                        primaryButtonTitle: "Review Duplicates",
                        primaryButtonIcon: "arrow.triangle.merge",
                        primaryAction: {
                            viewModel.reviewDuplicates()
                        }
                    )

                    featureCard(
                        title: "Health Report",
                        icon: "heart.text.square",
                        color: .pink,
                        description: "Spot missing phone numbers, emails, birthdays, and other gaps in your address book.",
                        status: "\(viewModel.issuesCount) issues flagged",
                        highlights: [
                            ("stethoscope", "Prioritize high-severity fixes first"),
                            ("bolt", "Jump straight into auto-fix suggestions")
                        ],
                        primaryButtonTitle: "Open Health Report",
                        primaryButtonIcon: "heart.text.square",
                        primaryAction: {
                            viewModel.reviewHealthReport()
                        }
                    )
                }
            }
            .padding(24)
        }
        .onAppear {
            viewModel.updateDuplicates(duplicateGroups)
            viewModel.updateIssues(dataQualityIssues)
        }
        .onChange(of: duplicateGroups.map(\.id)) { _, _ in
            viewModel.updateDuplicates(duplicateGroups)
        }
        .onChange(of: dataQualityIssues.map(\.id)) { _, _ in
            viewModel.updateIssues(dataQualityIssues)
        }
    }

    private var overviewColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                    .responsiveFont(16, weight: .semibold)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recentActivities) { activity in
                        Button(action: { handleActivityTap(activity) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: activity.icon)
                                        .foregroundColor(.accentColor)
                                    Text(activity.title)
                                        .responsiveFont(13, weight: .semibold)
                                }
                                Text(activity.detail)
                                    .platformBodyFont()
                                Text(relativeTimeDescription(for: activity.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .frame(minWidth: 180, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    private func relativeTimeDescription(for date: Date) -> String {
        OverviewView.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func handleActivityTap(_ activity: RecentActivity) {
        switch activity.kind {
        case .smartGroupCreated:
            targetSmartGroupName = activity.detail
            selectedTab = .smartGroups
        case .manualGroupCreated:
            selectedTab = .manualGroups
        case .duplicatesCleaned:
            selectedTab = .duplicates
        }
    }

    private func openGeneralSettings() {
        UserDefaults.standard.set("general", forKey: SettingsPreferences.selectedTabKey)
        openSettings()
    }

    @ViewBuilder
    private func featureCard(
        title: String,
        icon: String,
        color: Color,
        description: String,
        status: String? = nil,
        highlights: [(String, String)] = [],
        primaryButtonTitle: String,
        primaryButtonIcon: String,
        primaryAction: @escaping () -> Void,
        secondary: (title: String, icon: String, action: () -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(title)
                    .responsiveFont(20, weight: .semibold)
                Spacer()
            }

            Text(description)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status {
                Label(status, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(highlights.enumerated()), id: \.offset) { highlight in
                        Label(highlight.element.1, systemImage: highlight.element.0)
                    }
                }
            }

            HStack {
                Button(action: primaryAction) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                }
                .buttonStyle(.borderedProminent)

                if let secondary {
                    Button(action: secondary.action) {
                        Label(secondary.title, systemImage: secondary.icon)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct RefreshStateMachine {
    private(set) var pendingAutoRefresh = false

    mutating func handleTrigger(autoRefreshEnabled: Bool, isLoading: Bool, isAnalyzing: Bool) -> Bool {
        guard autoRefreshEnabled else { return false }
        if isLoading || isAnalyzing {
            pendingAutoRefresh = true
            return false
        }
        return true
    }

    mutating func prepareForLoad(isLoading: Bool, isAnalyzing: Bool) -> Bool {
        if isLoading || isAnalyzing {
            pendingAutoRefresh = true
            return false
        }
        return true
    }

    mutating func consumePendingRefresh() -> Bool {
        if pendingAutoRefresh {
            pendingAutoRefresh = false
            return true
        }
        return false
    }
}


#if !DISABLE_PREVIEWS
#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(ContactsManager.shared)
        .environmentObject(ContactsUndoManager())
        .frame(width: 1200, height: 800)
}
#endif
