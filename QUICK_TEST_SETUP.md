# Quick Test Setup - 5 Minutes

Follow these steps to add the 36 tests to your Xcode project and run them.

## Step 1: Create Test Target (2 minutes)

1. Open Xcode
2. Open `Contacts Organizer.xcodeproj`
3. Go to **File → New → Target...**
4. Select **macOS** → **Unit Testing Bundle**
5. Click "Next"
6. Product Name: `Contacts OrganizerTests`
7. Click "Finish"

## Step 2: Add Test Files (2 minutes)

1. In Xcode's Project Navigator (left sidebar), find the **"Contacts OrganizerTests"** folder
2. Open Finder and navigate to:
   ```
   /Volumes/CORSAIR/swift_contacts_organizer/Contacts Organizer/Tests/
   ```
3. Drag these 3 files into the "Contacts OrganizerTests" folder in Xcode:
   - `DuplicateDetectorTests.swift`
   - `DataQualityAnalyzerTests.swift`
   - `SmartGroupTests.swift`

4. In the dialog that appears:
   - ✅ Check "Copy items if needed"
   - ✅ Select "Contacts OrganizerTests" target
   - Click "Finish"

## Step 3: Run Tests (1 minute)

Press **⌘U** (Command + U)

OR

Click **Product → Test** from the menu

## Expected Results

```
✅ Test Suite 'DuplicateDetectorTests' passed
   ✓ 11 tests passed

✅ Test Suite 'DataQualityAnalyzerTests' passed
   ✓ 12 tests passed

✅ Test Suite 'SmartGroupTests' passed
   ✓ 13 tests passed

════════════════════════════════
✅ All 36 tests passed!
════════════════════════════════
```

## Troubleshooting

### If you get "Cannot find type 'ContactSummary'"

The test files have a helper extension at the bottom. Make sure the entire file was added, not truncated.

### If tests don't appear

1. Clean Build Folder: **⌘⇧K**
2. Build: **⌘B**
3. Try running tests again: **⌘U**

## View Test Results

After running:
1. Open Test Navigator: **⌘6**
2. See all tests with pass/fail status
3. Click any test to see details

## Code Coverage (Optional)

To see code coverage:
1. Edit Scheme: **⌘<** (Command + Less Than)
2. Select "Test" on left
3. Enable "Gather coverage for all targets"
4. Run tests: **⌘U**
5. View coverage in Report Navigator: **⌘9**

---

**That's it!** You now have 36 tests verifying your app's core functionality. 🎉
