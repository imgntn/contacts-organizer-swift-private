import XCTest
@testable import Contacts_Organizer

final class HealthReportActionUndoTests: XCTestCase {

    func testAddPhoneActionRegistersUndoRedo() async {
        await assertUndoFlow(
            action: HealthIssueAction(title: "Add Phone", icon: "", type: .addPhone, inputPrompt: nil, inputPlaceholder: nil),
            issueType: .missingPhone,
            input: "555-1111",
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.addPhoneCalls.count, 1)
                XCTAssertEqual(performer.addPhoneCalls.first?.value, "555-1111")
                XCTAssertEqual(performer.addPhoneCalls.first?.contactId, contactId)
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.removePhoneCalls.count, 1)
                XCTAssertEqual(performer.removePhoneCalls.first?.value, "555-1111")
                XCTAssertEqual(performer.removePhoneCalls.first?.contactId, contactId)
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.addPhoneCalls.count, 2)
                XCTAssertEqual(performer.addPhoneCalls.last?.contactId, contactId)
            }
        )
    }

    func testAddEmailActionRegistersUndoRedo() async {
        await assertUndoFlow(
            action: HealthIssueAction(title: "Add Email", icon: "", type: .addEmail, inputPrompt: nil, inputPlaceholder: nil),
            issueType: .missingEmail,
            input: "user@example.com",
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.addEmailCalls.count, 1)
                XCTAssertEqual(performer.addEmailCalls.first?.value, "user@example.com")
                XCTAssertEqual(performer.addEmailCalls.first?.contactId, contactId)
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.removeEmailCalls.count, 1)
                XCTAssertEqual(performer.removeEmailCalls.first?.value, "user@example.com")
                XCTAssertEqual(performer.removeEmailCalls.first?.contactId, contactId)
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.addEmailCalls.count, 2)
                XCTAssertEqual(performer.addEmailCalls.last?.contactId, contactId)
            }
        )
    }

    func testAddToGroupActionRegistersUndoRedo() async {
        await assertUndoFlow(
            action: HealthIssueAction(title: "Needs Email", icon: "", type: .addToGroup(name: HealthIssueActionCatalog.emailFollowUpGroupName), inputPrompt: nil, inputPlaceholder: nil),
            issueType: .missingEmail,
            input: nil,
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.addGroupCalls.count, 1)
                XCTAssertEqual(performer.addGroupCalls.first?.groupName, HealthIssueActionCatalog.emailFollowUpGroupName)
                XCTAssertEqual(performer.addGroupCalls.first?.contactId, contactId)
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.removeGroupCalls.count, 1)
                XCTAssertEqual(performer.removeGroupCalls.first?.groupName, HealthIssueActionCatalog.emailFollowUpGroupName)
                XCTAssertEqual(performer.removeGroupCalls.first?.contactId, contactId)
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.addGroupCalls.count, 2)
                XCTAssertEqual(performer.addGroupCalls.last?.contactId, contactId)
            }
        )
    }

    func testArchiveActionRegistersUndoRedo() async {
        await assertUndoFlow(
            action: HealthIssueAction(title: "Archive", icon: "", type: .archive, inputPrompt: nil, inputPlaceholder: nil),
            issueType: .noContactInfo,
            input: nil,
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.archiveCalls, [contactId])
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.removeGroupCalls.count, 1)
                XCTAssertEqual(performer.removeGroupCalls.first?.groupName, HealthIssueActionCatalog.archiveGroupName)
                XCTAssertEqual(performer.removeGroupCalls.first?.contactId, contactId)
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.archiveCalls.count, 2)
                XCTAssertEqual(performer.archiveCalls.last, contactId)
            }
        )
    }

    func testUpdateNameRegistersUndoRedo() async {
        let performer = RecordingContactActionPerformer()
        performer.nameLookup["contact-update"] = (given: "Old", family: "Name")
        await assertUndoFlow(
            action: HealthIssueAction(title: "Update Name", icon: "", type: .updateName, inputPrompt: nil, inputPlaceholder: nil),
            issueType: .missingName,
            input: "New Name",
            performer: performer,
            contactId: "contact-update",
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.updatedNames.count, 1)
                XCTAssertEqual(performer.updatedNames.first?.contactId, contactId)
                XCTAssertEqual(performer.updatedNames.first?.value, "New Name")
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.updatedNames.count, 2)
                XCTAssertEqual(performer.updatedNames.last?.value, "Old Name")
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.updatedNames.count, 3)
                XCTAssertEqual(performer.updatedNames.last?.value, "New Name")
            }
        )
    }

    func testMarkReviewedRegistersUndoRedo() async {
        let reviewedGroup = await MainActor.run { HealthIssueActionCatalog.reviewedGroupName }
        let markReviewedAction = await MainActor.run { HealthIssueActionCatalog.markReviewedAction }
        await assertUndoFlow(
            action: markReviewedAction,
            issueType: .suggestion,
            input: nil,
            verifyInitial: { performer, contactId in
                XCTAssertEqual(performer.addGroupCalls.last?.groupName, reviewedGroup)
                XCTAssertEqual(performer.addGroupCalls.last?.contactId, contactId)
            },
            verifyUndo: { performer, contactId in
                XCTAssertEqual(performer.removeGroupCalls.last?.groupName, reviewedGroup)
                XCTAssertEqual(performer.removeGroupCalls.last?.contactId, contactId)
            },
            verifyRedo: { performer, contactId in
                XCTAssertEqual(performer.addGroupCalls.last?.groupName, reviewedGroup)
                XCTAssertEqual(performer.addGroupCalls.last?.contactId, contactId)
                XCTAssertEqual(performer.addGroupCalls.count, 2)
            }
        )
    }

    // MARK: - Helpers

    private func assertUndoFlow(
        action: HealthIssueAction,
        issueType: DataQualityIssue.IssueType,
        input: String?,
        performer: RecordingContactActionPerformer = RecordingContactActionPerformer(),
        contactId: String = UUID().uuidString,
        verifyInitial: (RecordingContactActionPerformer, String) -> Void,
        verifyUndo: (RecordingContactActionPerformer, String) -> Void,
        verifyRedo: (RecordingContactActionPerformer, String) -> Void
    ) async {
        let executor = HealthIssueActionExecutor(performer: performer)
        let issue = DataQualityIssue(
            contactId: contactId,
            contactName: "Test",
            issueType: issueType,
            description: "",
            severity: .medium
        )
        let undoManager = await MainActor.run { ContactsUndoManager() }

        let result = await executor.execute(action, for: issue, inputValue: input)
        let wasSuccessful = await MainActor.run { result.success }
        XCTAssertTrue(wasSuccessful, "Health report action should succeed")
        guard let effect = await MainActor.run(resultType: UndoEffect?.self, body: { result.effect }) else {
            return XCTFail("Action did not report an undo effect")
        }

        await MainActor.run {
            undoManager.register(effect: effect, actionTitle: action.title, contactsManager: performer)
        }
        verifyInitial(performer, contactId)

        await MainActor.run { undoManager.undo() }
        await undoManager.waitForIdle()
        verifyUndo(performer, contactId)

        await MainActor.run { undoManager.redo() }
        await undoManager.waitForIdle()
        verifyRedo(performer, contactId)
    }
}
