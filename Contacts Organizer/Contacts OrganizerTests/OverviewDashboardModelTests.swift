import XCTest
import Combine
import Contacts
@testable import Contacts_Organizer

@MainActor
final class OverviewDashboardModelTests: XCTestCase {
    private var contactsPublisher = MockContactsProvider()
    private var appState = MockOverviewAppState()
    private var navigator = MockNavigator()
    private var undoManager: ContactsUndoManager!
    private var model: OverviewDashboardModel!

    override func setUp() async throws {
        undoManager = ContactsUndoManager()
        model = OverviewDashboardModel(
            contactsProvider: contactsPublisher,
            appState: appState,
            navigator: navigator,
            undoManager: undoManager
        )
    }

    func testMetricsUpdateWhenStatisticsChange() async {
        let stats = ContactStatistics(
            totalContacts: 42,
            contactsWithPhone: 0,
            contactsWithEmail: 0,
            contactsWithBoth: 0,
            contactsWithOrganization: 0,
            contactsWithPhoto: 0,
            duplicateGroups: 0,
            dataQualityIssues: 0,
            highPriorityIssues: 0,
            mediumPriorityIssues: 0,
            lowPriorityIssues: 0,
            suggestions: 0,
            contactsWithSocialMedia: 0,
            contactsWithAddress: 0,
            contactsWithJobTitle: 0,
            contactsWithWebsite: 0,
            contactsWithNickname: 0,
            contactsWithInstantMessaging: 0,
            highDetailContacts: 0
        )
        contactsPublisher.statisticsSubject.send(stats)
        await Task.yield()
        XCTAssertEqual(model.totalContacts, 42)
    }

    func testDuplicateAndIssueCountsTrackUpdates() async {
        let duplicates = [
            DuplicateGroup(
                contacts: [makeContact("1"), makeContact("2")],
                matchType: .exactName,
                confidence: 0.9
            )
        ]
        model.updateDuplicates(duplicates)
        XCTAssertEqual(model.duplicateCount, 1)

        let issues = [makeIssue(), makeIssue()]
        model.updateIssues(issues)
        XCTAssertEqual(model.issuesCount, 2)
    }

    func testRecentActivitiesPublish() async {
        let activity = RecentActivity(kind: .smartGroupCreated, title: "Created Smart Group", detail: "VIP", icon: "sparkles", timestamp: Date())
        contactsPublisher.activitiesSubject.send([activity])
        await Task.yield()
        XCTAssertEqual(model.recentActivities.first?.title, "Created Smart Group")
    }

    func testManualGroupCountUpdatesFromPublisher() async {
        let group = CNMutableGroup()
        group.name = "VIP"
        contactsPublisher.groupsSubject.send([group.copy() as! CNGroup])
        await Task.yield()
        XCTAssertEqual(model.manualGroupCount, 1)
    }

    func testNavigationActionsRouteToTabs() async {
        model.browseSmartGroups()
        XCTAssertEqual(navigator.lastSelection, .smartGroups)

        model.browseManualGroups()
        XCTAssertEqual(navigator.lastSelection, .manualGroups)

        model.reviewDuplicates()
        XCTAssertEqual(navigator.lastSelection, .duplicates)

        model.reviewHealthReport()
        XCTAssertEqual(navigator.lastSelection, .healthReport)

        model.reviewSmartGroup(named: "Missing Email")
        XCTAssertEqual(navigator.lastSmartGroupName, "Missing Email")
    }

    func testDismissBackupReminderRegistersUndo() async {
        XCTAssertTrue(model.showBackupReminder)
        model.dismissBackupReminder()
        XCTAssertFalse(model.showBackupReminder)
        await undoManager.undo()
        await undoManager.waitForIdle()
        XCTAssertTrue(model.showBackupReminder)

        await undoManager.redo()
        await undoManager.waitForIdle()
        XCTAssertFalse(model.showBackupReminder)
    }

    func testBackupReminderRespectsInitialAppState() async {
        let localNavigator = MockNavigator()
        let seenAppState = MockOverviewAppState(initiallySeen: true)
        let localModel = OverviewDashboardModel(
            contactsProvider: contactsPublisher,
            appState: seenAppState,
            navigator: localNavigator,
            undoManager: undoManager
        )

        XCTAssertFalse(localModel.showBackupReminder)
    }

    // MARK: - Helpers

    private func makeContact(_ id: String) -> ContactSummary {
        ContactSummary(id: id, fullName: "Test", organization: nil, phoneNumbers: [], emailAddresses: [], hasProfileImage: false, creationDate: nil, modificationDate: nil)
    }

    private func makeIssue() -> DataQualityIssue {
        DataQualityIssue(contactId: "1", contactName: "Test", issueType: .missingEmail, description: "", severity: .medium)
    }
}

private final class MockContactsProvider: OverviewContactsProviding {
    let statisticsSubject = PassthroughSubject<ContactStatistics?, Never>()
    let activitiesSubject = PassthroughSubject<[RecentActivity], Never>()
    let groupsSubject = PassthroughSubject<[CNGroup], Never>()

    var statisticsPublisher: AnyPublisher<ContactStatistics?, Never> { statisticsSubject.eraseToAnyPublisher() }
    var recentActivitiesPublisher: AnyPublisher<[RecentActivity], Never> { activitiesSubject.eraseToAnyPublisher() }
    var groupsPublisher: AnyPublisher<[CNGroup], Never> { groupsSubject.eraseToAnyPublisher() }
}

private final class MockOverviewAppState: OverviewAppStateProviding {
    var hasSeenBackupReminder: Bool
    private let reminderSubject: CurrentValueSubject<Bool, Never>

    init(initiallySeen: Bool = false) {
        self.hasSeenBackupReminder = initiallySeen
        self.reminderSubject = CurrentValueSubject(initiallySeen)
    }

    var hasSeenBackupReminderPublisher: AnyPublisher<Bool, Never> {
        reminderSubject.eraseToAnyPublisher()
    }

    func markBackupReminderSeen() {
        hasSeenBackupReminder = true
        reminderSubject.send(true)
    }

    func resetBackupReminder() {
        hasSeenBackupReminder = false
        reminderSubject.send(false)
    }
}

private final class MockNavigator: OverviewNavigating {
    var lastSelection: DashboardView.DashboardTab?
    var lastSmartGroupName: String?

    func select(_ tab: DashboardView.DashboardTab) {
        lastSelection = tab
    }

    func reviewSmartGroup(named name: String) {
        lastSmartGroupName = name
        lastSelection = .smartGroups
    }
}
