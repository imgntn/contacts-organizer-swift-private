# Test Setup Guide - Contacts Organizer

Comprehensive unit tests have been created for the core functionality of Contacts Organizer.

## Test Files Created

1. **DuplicateDetectorTests.swift** - Tests for duplicate detection logic
   - Exact name matching
   - Phone number matching
   - Email matching
   - Similar name matching (fuzzy)
   - Multiple match criteria
   - Primary contact selection
   - Performance testing

2. **DataQualityAnalyzerTests.swift** - Tests for data quality analysis
   - Missing name detection
   - Missing contact info detection
   - Missing phone detection
   - Missing email detection
   - Incomplete data detection
   - Issue sorting by severity
   - Health score calculation
   - Performance testing

3. **SmartGroupTests.swift** - Tests for smart group generation
   - Organization grouping
   - Custom criteria (has phone, has email, has photo)
   - Multiple rules (AND logic)
   - String matching (organization contains, name contains)
   - Multiple definitions
   - Disabled definitions handling

## Adding Tests to Xcode

### Option 1: Using Xcode (Recommended)

1. Open Xcode
2. Open your project: `Contacts Organizer.xcodeproj`
3. In the Project Navigator, locate "Contacts OrganizerTests" folder
4. Drag and drop the three test files from Finder:
   - `Tests/DuplicateDetectorTests.swift`
   - `Tests/DataQualityAnalyzerTests.swift`
   - `Tests/SmartGroupTests.swift`
5. In the dialog that appears:
   - ✅ Check "Copy items if needed"
   - ✅ Check "Contacts OrganizerTests" target
   - ✅ Make sure "Add to targets" includes the test target
   - Click "Finish"

### Option 2: Create Tests Group First

If you don't have a Tests target yet:

1. In Xcode, go to File → New → Target
2. Choose "macOS" → "Unit Testing Bundle"
3. Name it "Contacts OrganizerTests"
4. Make sure "Contacts Organizer" is selected as the target to be tested
5. Click "Finish"
6. Then follow Option 1 steps 3-5

## Running the Tests

### Run All Tests

- **Keyboard**: Press `⌘U` (Command + U)
- **Menu**: Product → Test
- **Toolbar**: Click and hold the Play button → Test

### Run Specific Test

1. Open any test file
2. Click the diamond icon next to a test function
3. Or click the diamond next to the class name to run all tests in that file

### Run from Test Navigator

1. Open Test Navigator (`⌘6`)
2. Click the play icon next to any test or test class

## Test Coverage

### Duplicate Detector (11 tests)
- ✅ Exact name matching
- ✅ Phone number matching
- ✅ Email address matching
- ✅ Similar name matching
- ✅ Multiple match criteria
- ✅ Primary contact selection (chooses contact with most data)
- ✅ Empty input handling
- ✅ Single contact handling
- ✅ Performance test with 1000+ contacts

### Data Quality Analyzer (12 tests)
- ✅ Missing name detection
- ✅ No contact info detection
- ✅ Missing phone detection
- ✅ Missing email detection
- ✅ Incomplete data detection
- ✅ Complete contact (no issues)
- ✅ Multiple issues on same contact
- ✅ Issue sorting by severity
- ✅ Summary generation
- ✅ Health score calculations
- ✅ Empty input handling
- ✅ Performance test with 1000+ contacts

### Smart Groups (13 tests)
- ✅ Organization grouping
- ✅ Minimum contact requirement (2+)
- ✅ Has phone criteria
- ✅ Missing email criteria
- ✅ Multiple rules (AND logic)
- ✅ Organization contains matching
- ✅ Name contains matching
- ✅ Has photo criteria
- ✅ Multiple definitions
- ✅ Disabled definitions
- ✅ Default smart groups
- ✅ Empty contact list

**Total: 36 comprehensive unit tests**

## Expected Results

All tests should pass! If any tests fail:

1. Check that you've updated `ContactSummary` init to match the test helper
2. Ensure all model properties match expectations
3. Review the specific failure message in Xcode

## Performance Benchmarks

The performance tests measure execution time for:
- Processing 1000+ contacts for duplicate detection
- Analyzing 1000+ contacts for data quality

These help ensure the app remains performant even with large contact lists.

## Continuous Integration (Optional)

To run tests from command line:

```bash
xcodebuild test \
  -project "Contacts Organizer.xcodeproj" \
  -scheme "Contacts Organizer" \
  -destination 'platform=macOS'
```

## Test-Driven Development

When adding new features:

1. Write tests first (TDD approach)
2. Run tests (they should fail)
3. Implement the feature
4. Run tests again (they should pass)
5. Refactor if needed

## Code Coverage

To view code coverage:

1. Edit Scheme (⌘<)
2. Select "Test" on left sidebar
3. Check "Gather coverage for all targets"
4. Run tests
5. View coverage in Report Navigator (`⌘9`)

## Troubleshooting

### "Target Membership" issues
- Select the test file
- Check File Inspector (⌘⌥1)
- Ensure "Contacts OrganizerTests" is checked under Target Membership

### Import errors
- Make sure your app target builds successfully first
- Check that `@testable import Contacts_Organizer` matches your module name

### Tests not showing up
- Clean Build Folder (⌘⇧K)
- Rebuild (⌘B)
- Try closing and reopening Xcode

## Next Steps

1. Add these tests to your Xcode project (see above)
2. Run all tests to verify they pass
3. Use tests to catch regressions during future development
4. Add more tests for edge cases you discover
5. Run tests before each commit

## Benefits of Testing

✅ **Catch bugs early** - Before users see them
✅ **Refactor safely** - Tests verify nothing breaks
✅ **Document behavior** - Tests show how code should work
✅ **Faster debugging** - Pinpoint exact issues quickly
✅ **Confidence** - Deploy with assurance

Happy testing! 🧪
