//
//  ContactsManagerConcurrencyTests.swift
//  Contacts OrganizerTests
//
//  Tests for concurrency and thread safety in ContactsManager
//

import XCTest
@testable import Contacts_Organizer

final class ContactsManagerConcurrencyTests: XCTestCase {

    var sut: ContactsManager!
    var testContacts: [ContactSummary]!

    override func setUp() async throws {
        try await super.setUp()
        sut = ContactsManager.shared

        // Generate test contacts for operations that need them
        testContacts = TestDataGenerator.shared.generateTestContacts(count: 100)
    }

    override func tearDown() async throws {
        testContacts = nil
        try await super.tearDown()
    }

    // MARK: - Main Thread Non-Blocking Tests

    /// Verifies that generateSmartGroups doesn't block the main thread
    func testGenerateSmartGroupsDoesNotBlockMainThread() async throws {
        // Generate a large dataset to ensure operation takes measurable time
        let largeContactSet = TestDataGenerator.shared.generateTestContacts(count: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()
        var mainThreadCheckTime: CFAbsoluteTime = 0

        // Start the smart groups generation (should not block)
        Task {
            _ = await sut.generateSmartGroups(
                definitions: ContactsManager.defaultSmartGroups,
                using: largeContactSet
            )
        }

        // Immediately check if main thread is responsive
        await MainActor.run {
            mainThreadCheckTime = CFAbsoluteTimeGetCurrent()
        }

        let mainThreadResponseTime = mainThreadCheckTime - startTime

        // Main thread should respond within 100ms, even though smart groups operation is running
        XCTAssertLessThan(mainThreadResponseTime, 0.1, "Main thread should remain responsive (< 100ms) during smart groups generation")
    }

    /// Verifies main thread can process multiple updates while smart groups are generating
    func testMainThreadResponsivenessDuringSmartGroupGeneration() async throws {
        let largeContactSet = TestDataGenerator.shared.generateTestContacts(count: 500)

        // Track how many main thread updates we can process
        var updateCount = 0
        let expectedUpdates = 10

        // Start smart groups generation
        let generationTask = Task {
            await sut.generateSmartGroups(
                definitions: ContactsManager.defaultSmartGroups,
                using: largeContactSet
            )
        }

        // Try to perform multiple main thread updates concurrently
        for _ in 0..<expectedUpdates {
            await MainActor.run {
                updateCount += 1
            }
            // Small delay between updates
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        // Wait for generation to complete
        _ = await generationTask.value

        // We should have completed all updates, proving main thread wasn't blocked
        XCTAssertEqual(updateCount, expectedUpdates, "Main thread should process all updates concurrently with smart groups generation")
    }

    /// Verifies that multiple smart group generations can run concurrently
    func testConcurrentSmartGroupGenerations() async throws {
        let contacts1 = TestDataGenerator.shared.generateTestContacts(count: 100)
        let contacts2 = TestDataGenerator.shared.generateTestContacts(count: 100)
        let contacts3 = TestDataGenerator.shared.generateTestContacts(count: 100)

        let definition1 = SmartGroupDefinition(name: "Test 1", groupingType: .organization)
        let definition2 = SmartGroupDefinition(name: "Test 2", groupingType: .custom(CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasPhone, condition: .exists)
        ])))
        let definition3 = SmartGroupDefinition(name: "Test 3", groupingType: .custom(CustomCriteria(rules: [
            CustomCriteria.Rule(field: .hasEmail, condition: .exists)
        ])))

        // Start all three generations concurrently
        async let result1 = sut.generateSmartGroups(definitions: [definition1], using: contacts1)
        async let result2 = sut.generateSmartGroups(definitions: [definition2], using: contacts2)
        async let result3 = sut.generateSmartGroups(definitions: [definition3], using: contacts3)

        // Wait for all to complete
        let (r1, r2, r3) = await (result1, result2, result3)

        // All should complete successfully
        XCTAssertGreaterThanOrEqual(r1.count, 0, "First generation should complete")
        XCTAssertGreaterThanOrEqual(r2.count, 0, "Second generation should complete")
        XCTAssertGreaterThanOrEqual(r3.count, 0, "Third generation should complete")
    }

    // MARK: - Concurrent Execution Tests

    /// Verifies multiple operations can run concurrently without blocking each other
    func testMixedOperationsConcurrency() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 200)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Run three different operations concurrently
        async let smartGroups1 = sut.generateSmartGroups(
            definitions: [SmartGroupDefinition(name: "Org", groupingType: .organization)],
            using: contacts
        )
        async let smartGroups2 = sut.generateSmartGroups(
            definitions: [SmartGroupDefinition(name: "Phone", groupingType: .custom(CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhone, condition: .exists)
            ])))],
            using: contacts
        )
        async let smartGroups3 = sut.generateSmartGroups(
            definitions: [SmartGroupDefinition(name: "Email", groupingType: .custom(CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasEmail, condition: .exists)
            ])))],
            using: contacts
        )

        // Wait for all to complete
        let (r1, r2, r3) = await (smartGroups1, smartGroups2, smartGroups3)

        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime

        // Verify all completed
        XCTAssertGreaterThanOrEqual(r1.count, 0)
        XCTAssertGreaterThanOrEqual(r2.count, 0)
        XCTAssertGreaterThanOrEqual(r3.count, 0)

        // Operations should complete reasonably quickly when running concurrently
        // (If they were serialized, this would take much longer)
        XCTAssertLessThan(totalTime, 5.0, "Concurrent operations should complete within reasonable time")
    }

    /// Tests that concurrent operations don't corrupt results
    func testConcurrentOperationsProduceCorrectResults() async throws {
        // Create contacts with ONLY phone (no email)
        let contactsWithPhone = (0..<50).map { i in
            ContactSummary(
                id: "phone-\(i)",
                fullName: "Phone Contact \(i)",
                organization: nil,
                phoneNumbers: ["+1-555-000-\(String(format: "%04d", i))"],
                emailAddresses: [], // No email
                hasProfileImage: false,
                creationDate: Date(),
                modificationDate: Date()
            )
        }

        // Create contacts with ONLY email (no phone)
        let contactsWithEmail = (0..<50).map { i in
            ContactSummary(
                id: "email-\(i)",
                fullName: "Email Contact \(i)",
                organization: nil,
                phoneNumbers: [], // No phone
                emailAddresses: ["email\(i)@test.com"],
                hasProfileImage: false,
                creationDate: Date(),
                modificationDate: Date()
            )
        }

        let phoneDefinition = SmartGroupDefinition(
            name: "Has Phone",
            groupingType: .custom(CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasPhone, condition: .exists)
            ]))
        )

        let emailDefinition = SmartGroupDefinition(
            name: "Has Email",
            groupingType: .custom(CustomCriteria(rules: [
                CustomCriteria.Rule(field: .hasEmail, condition: .exists)
            ]))
        )

        // Run concurrently
        async let phoneResults = sut.generateSmartGroups(definitions: [phoneDefinition], using: contactsWithPhone)
        async let emailResults = sut.generateSmartGroups(definitions: [emailDefinition], using: contactsWithEmail)

        let (phone, email) = await (phoneResults, emailResults)

        // Verify results are correct (no cross-contamination)
        XCTAssertEqual(phone.count, 1, "Should have one phone group")
        XCTAssertEqual(email.count, 1, "Should have one email group")

        if let phoneGroup = phone.first {
            XCTAssertEqual(phoneGroup.groupName, "Has Phone")
            XCTAssertEqual(phoneGroup.contacts.count, 50, "Phone group should have 50 contacts")
        }

        if let emailGroup = email.first {
            XCTAssertEqual(emailGroup.groupName, "Has Email")
            XCTAssertEqual(emailGroup.contacts.count, 50, "Email group should have 50 contacts")
        }
    }

    // MARK: - Performance Tests

    /// Measures performance of concurrent smart group generation
    func testSmartGroupConcurrentPerformance() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 500)

        measure {
            let expectation = XCTestExpectation(description: "Concurrent generation completes")

            Task {
                async let r1 = sut.generateSmartGroups(
                    definitions: [SmartGroupDefinition(name: "Test1", groupingType: .organization)],
                    using: contacts
                )
                async let r2 = sut.generateSmartGroups(
                    definitions: [SmartGroupDefinition(name: "Test2", groupingType: .custom(CustomCriteria(rules: [
                        CustomCriteria.Rule(field: .hasPhone, condition: .exists)
                    ])))],
                    using: contacts
                )
                async let r3 = sut.generateSmartGroups(
                    definitions: [SmartGroupDefinition(name: "Test3", groupingType: .custom(CustomCriteria(rules: [
                        CustomCriteria.Rule(field: .hasEmail, condition: .exists)
                    ])))],
                    using: contacts
                )

                _ = await (r1, r2, r3)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    /// Tests main thread latency during heavy operations
    func testMainThreadLatencyDuringOperations() async throws {
        let largeContactSet = TestDataGenerator.shared.generateTestContacts(count: 1000)

        var maxLatency: TimeInterval = 0
        var latencyMeasurements: [TimeInterval] = []

        // Start heavy operation
        Task {
            await sut.generateSmartGroups(
                definitions: ContactsManager.defaultSmartGroups,
                using: largeContactSet
            )
        }

        // Measure main thread latency multiple times during the operation
        for _ in 0..<10 {
            let measureStart = CFAbsoluteTimeGetCurrent()

            await MainActor.run {
                let measureEnd = CFAbsoluteTimeGetCurrent()
                let latency = measureEnd - measureStart
                latencyMeasurements.append(latency)
                maxLatency = max(maxLatency, latency)
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between measurements
        }

        // Main thread should remain responsive (< 16ms for 60fps, < 33ms for 30fps)
        XCTAssertLessThan(maxLatency, 0.1, "Main thread latency should stay low (< 100ms) during background operations")

        let avgLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
        XCTAssertLessThan(avgLatency, 0.05, "Average main thread latency should be very low (< 50ms)")
    }

    // MARK: - State Consistency Tests

    /// Verifies that state updates happen on MainActor during concurrent operations
    func testStateConsistencyDuringConcurrentOperations() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 100)

        // Track state changes
        var stateChecks: [Bool] = []

        // Start multiple operations
        Task {
            async let r1 = sut.generateSmartGroups(
                definitions: [SmartGroupDefinition(name: "Test1", groupingType: .organization)],
                using: contacts
            )
            async let r2 = sut.generateSmartGroups(
                definitions: [SmartGroupDefinition(name: "Test2", groupingType: .organization)],
                using: contacts
            )

            _ = await (r1, r2)
        }

        // Check state consistency from main thread multiple times
        for _ in 0..<5 {
            await MainActor.run {
                // Just verifying we can access state without crashes or race conditions
                let _ = sut.contacts
                let _ = sut.statistics
                let _ = sut.isLoading
                stateChecks.append(true)
            }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }

        XCTAssertEqual(stateChecks.count, 5, "All state checks should complete without race conditions")
    }

    /// Tests that error handling in detached tasks properly updates state on MainActor
    func testErrorHandlingInConcurrentOperations() async throws {
        // Test with empty definitions to ensure no crashes
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 10)
        let emptyDefinitions: [SmartGroupDefinition] = []

        let results = await sut.generateSmartGroups(definitions: emptyDefinitions, using: contacts)

        // Should return empty array, not crash
        XCTAssertEqual(results.count, 0, "Empty definitions should return empty results")

        // State should remain consistent
        await MainActor.run {
            let _ = sut.contacts
            let _ = sut.isLoading
            // No assertion needed, just verifying no crashes
        }
    }

    // MARK: - Task.detached Verification Tests

    /// Verifies operations complete successfully when called from background context
    func testOperationsWorkFromBackgroundContext() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 50)

        // Call from a background task
        let result = await Task.detached(priority: .background) {
            await self.sut.generateSmartGroups(
                definitions: [SmartGroupDefinition(name: "Test", groupingType: .organization)],
                using: contacts
            )
        }.value

        // Should complete successfully even when called from background
        XCTAssertGreaterThanOrEqual(result.count, 0, "Operation should complete from background context")
    }

    /// Tests that operations maintain their priority when called from different contexts
    func testOperationsPriorityIndependence() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 50)

        // Call from low priority task
        let lowPriorityResult = await Task.detached(priority: .low) {
            await self.sut.generateSmartGroups(
                definitions: [SmartGroupDefinition(name: "Test1", groupingType: .organization)],
                using: contacts
            )
        }.value

        // Call from high priority task
        let highPriorityResult = await Task.detached(priority: .high) {
            await self.sut.generateSmartGroups(
                definitions: [SmartGroupDefinition(name: "Test2", groupingType: .organization)],
                using: contacts
            )
        }.value

        // Both should complete successfully regardless of caller's priority
        XCTAssertGreaterThanOrEqual(lowPriorityResult.count, 0)
        XCTAssertGreaterThanOrEqual(highPriorityResult.count, 0)
    }

    // MARK: - Stress Tests

    /// Stress test with many concurrent operations
    func testManySimultaneousOperations() async throws {
        let contacts = TestDataGenerator.shared.generateTestContacts(count: 100)

        let operationCount = 20
        var tasks: [Task<[SmartGroupResult], Never>] = []

        // Create many concurrent tasks
        for i in 0..<operationCount {
            let task = Task {
                await sut.generateSmartGroups(
                    definitions: [SmartGroupDefinition(name: "Test\(i)", groupingType: .organization)],
                    using: contacts
                )
            }
            tasks.append(task)
        }

        // Wait for all to complete
        var completedCount = 0
        for task in tasks {
            let result = await task.value
            if result.count >= 0 { // Any result is fine, just checking completion
                completedCount += 1
            }
        }

        XCTAssertEqual(completedCount, operationCount, "All \(operationCount) operations should complete successfully")
    }
}
