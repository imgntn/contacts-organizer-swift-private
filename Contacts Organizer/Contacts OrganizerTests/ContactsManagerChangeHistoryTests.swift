import XCTest
import Contacts
@testable import Contacts_Organizer

final class ContactsManagerChangeHistoryTests: XCTestCase {

    func testRefreshRecencyInfoProcessesEvents() {
        let contact = makeContact(given: "Add")
        let addEvent = ChangeHistoryEvent(kind: .add(contact: contact))
        let updateEvent = ChangeHistoryEvent(kind: .update(contact: contact))
        let response = MockChangeHistoryFetcher.Response.success(
            events: [addEvent, updateEvent],
            token: Data("token-1".utf8)
        )
        let fetcher = MockChangeHistoryFetcher(responses: [response])
        let manager = ContactsManager(store: CNContactStore(), changeHistoryFetcher: fetcher)
        manager.authorizationStatus = .authorized

        manager.refreshRecencyInfoFromHistory()

        let recency = manager.testRecencyInfo(for: contact.identifier)
        XCTAssertNotNil(recency)
        XCTAssertEqual(fetcher.fetchCallCount, 1)
        XCTAssertEqual(manager.testCurrentHistoryAnchor(), Data("token-1".utf8))
    }

    func testRefreshRecencyRetriesAfterHistoryExpiration() {
        let staleInfo = ContactRecencyInfo(createdAt: Date().addingTimeInterval(-3600), modifiedAt: Date().addingTimeInterval(-3600))
        let newContact = makeContact(given: "Fresh")
        let expiredError = NSError(
            domain: CNErrorDomain,
            code: CNError.Code.changeHistoryExpired.rawValue,
            userInfo: nil
        )
        let responses: [MockChangeHistoryFetcher.Response] = [
            .failure(expiredError),
            .success(events: [ChangeHistoryEvent(kind: .add(contact: newContact))], token: Data("token-2".utf8))
        ]
        let fetcher = MockChangeHistoryFetcher(responses: responses)
        let manager = ContactsManager(store: CNContactStore(), changeHistoryFetcher: fetcher)
        manager.authorizationStatus = .authorized
        manager.testSetRecencyInfo(staleInfo, for: "stale-contact")
        manager.testSetChangeHistoryAnchor(Data("stale-token".utf8))

        manager.refreshRecencyInfoFromHistory()

        XCTAssertNil(manager.testRecencyInfo(for: "stale-contact"))
        XCTAssertNotNil(manager.testRecencyInfo(for: newContact.identifier))
        XCTAssertEqual(fetcher.fetchCallCount, 2)
        XCTAssertEqual(manager.testCurrentHistoryAnchor(), Data("token-2".utf8))
    }

    // MARK: - Helpers

    private func makeContact(given: String) -> CNContact {
        let mutable = CNMutableContact()
        mutable.givenName = given
        return mutable.copy() as! CNContact
    }
}

private final class MockChangeHistoryFetcher: ChangeHistoryFetching {
    enum Response {
        case success(events: [ChangeHistoryEvent], token: Data?)
        case failure(NSError)
    }

    private var queue: [Response]
    private(set) var fetchCallCount = 0

    init(responses: [Response]) {
        self.queue = responses
    }

    func fetchEvents(using request: CNChangeHistoryFetchRequest, currentToken: inout NSData?) throws -> [ChangeHistoryEvent] {
        fetchCallCount += 1
        let response = queue.isEmpty ? .success(events: [], token: nil) : queue.removeFirst()
        switch response {
        case .success(let events, let token):
            if let token = token {
                currentToken = NSData(data: token)
            } else {
                currentToken = nil
            }
            return events
        case .failure(let error):
            throw error
        }
    }
}
