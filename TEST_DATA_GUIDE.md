# Test Data & Import/Export Guide

This guide explains how to use the test database generator and import/export features.

## Quick Start

### 1. Add New Files to Xcode

The following new files need to be added to your Xcode project:

1. Open `Contacts Organizer.xcodeproj` in Xcode
2. Right-click on the "Services" folder in the project navigator
3. Select "Add Files to 'Contacts Organizer'..."
4. Add these files:
   - `Services/TestDataGenerator.swift`
   - `Services/ImportExportService.swift`
5. Make sure "Copy items if needed" is unchecked (files are already in the right location)
6. Make sure "Contacts Organizer" target is checked
7. Click "Add"

### 2. Load Test Data in the App

Once the files are added to Xcode:

1. Build and run the app
2. Go to **Settings** (⌘,)
3. Click the **Developer** tab
4. Adjust the contact count (10-1000) using the stepper
5. Click **"Load Test Database"**
6. The app will generate realistic test contacts with:
   - Varied names, phone numbers, emails, organizations
   - ~10% duplicates (exact names, similar names, same contact info)
   - ~5% incomplete contacts (missing data for quality analysis testing)

### 3. Import/Export Contacts

#### Export Current Contacts
1. Go to Settings > Developer
2. Click **"Export Contacts"**
3. Choose a location and filename
4. Contacts are saved as JSON

#### Import Contacts
1. Go to Settings > Developer
2. Click **"Import Contacts"**
3. Select a previously exported JSON file
4. Contacts will be loaded into the app

## Command-Line Test Database Generator

A standalone script is included for generating test data without running the app:

```bash
# Generate 100 contacts (default)
swift generate_test_database.swift

# Generate custom count
swift generate_test_database.swift 500

# Specify output file
swift generate_test_database.swift 200 my_test_contacts.json
```

The generated `test_contacts.json` file can then be imported using the app's import feature.

## Generated Test Data

Test contacts include:

### Realistic Variations
- **16 first names** × **15 last names** = diverse combinations
- **10 companies** including tech giants and generic names
- **4 email domains** (gmail.com, yahoo.com, outlook.com, company.com)
- **Phone numbers** in US format: (XXX) XXX-XXXX
- **Random dates** within the past year for creation/modification

### Intentional Duplicates (~10% of total)
1. **Exact name matches** - Same full name, different contact info
2. **Similar names** - Typo variations (e.g., "John Smith" vs "John Smithe")
3. **Same contact info** - Same phone or email with different name

### Data Quality Issues (~5% of total)
1. **Missing name** - "No Name" placeholder
2. **Missing phone** - Email only
3. **Missing email** - Phone only
4. **No contact info** - Name and organization only

This ensures you can test:
- Duplicate detection algorithms
- Data quality analysis
- Smart groups and filtering
- Performance with realistic data

## JSON Format

Exported contacts use this format:

```json
[
  {
    "id": "test-0",
    "fullName": "John Smith",
    "organization": "Apple Inc.",
    "phoneNumbers": ["(555) 123-4567"],
    "emailAddresses": ["john.smith@gmail.com"],
    "hasProfileImage": true,
    "creationDate": "2024-06-15T14:30:00Z",
    "modificationDate": "2024-11-03T10:15:00Z"
  }
]
```

## Use Cases

### Development & Testing
- Test duplicate detection with known duplicates
- Verify data quality analysis catches incomplete contacts
- Performance testing with large datasets (1000+ contacts)
- UI testing with realistic data

### Demos & Screenshots
- Generate clean test data for screenshots
- Show app features with professional-looking contacts
- Export/share consistent demo data

### Backup & Migration
- Export real contacts as backup before cleanup
- Import contacts on another device
- Share contact lists between team members

## Performance Notes

- **Generation**: ~100ms for 100 contacts
- **Import**: ~50ms for 100 contacts
- **Export**: ~30ms for 100 contacts

Large datasets (1000+ contacts) may take a few seconds but should remain responsive.

## Troubleshooting

**Build errors after adding files:**
- Ensure files are added to the "Contacts Organizer" target
- Clean build folder (Product > Clean Build Folder in Xcode)
- Rebuild the project

**Import fails:**
- Verify JSON file format matches the expected structure
- Check that dates are in ISO8601 format
- Ensure all required fields are present (id, fullName, phoneNumbers, emailAddresses, hasProfileImage)

**Test data doesn't show duplicates:**
- The app's duplicate detection runs automatically
- Navigate to the "Duplicates" tab to see detected groups
- Ensure you loaded enough contacts (100+ recommended)

## Next Steps

1. Add the files to Xcode (see step 1 above)
2. Build and run the app
3. Load test data and explore the features!
4. Test duplicate detection, data quality analysis, and smart groups
