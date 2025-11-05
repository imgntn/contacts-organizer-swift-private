# Contacts Organizer for macOS

A native macOS application built with Swift and SwiftUI for cleaning, organizing, and managing your contacts. Designed for the Mac App Store with privacy-first architecture.

## Features

### Core Features (Implemented ✅)
- **Duplicate Detection & Merging**: Intelligent O(n) algorithm using name similarity, phone, and email matching
- **Data Quality Analysis**: Identify incomplete contacts with severity-weighted health scoring
  - High priority issues (no name, no contact info): -10 points each
  - Medium priority issues (missing phone): -3 points each
  - Low priority issues (missing email): -0.5 points each, capped at 5% total impact
- **Smart Groups**: Automatic organization by company, custom criteria, and more
- **Interactive Dashboard**: Click any statistic card to navigate to detailed views
- **Smart Statistics**: Comprehensive analytics about your contact database
- **Test Data Generator**: Generate realistic test contacts for development and screenshots
- **Import/Export**: Backup and restore contacts as JSON
- **Privacy-First**: All processing happens locally, no data ever leaves your device

### Coming Soon
- **Contact Merging UI**: Interactive merge workflow with preview
- **Batch Operations**: Bulk contact cleanup and organization
- **Export Reports**: Generate detailed reports (PDF/CSV) about your contacts

## Project Structure

```
swift_contacts_organizer/
├── ContactsOrganizer/
│   ├── App/
│   │   └── ContactsOrganizerApp.swift          # Main app entry point
│   ├── Models/
│   │   ├── AppState.swift                       # Application state management
│   │   └── ContactModels.swift                  # Contact data models
│   ├── Services/
│   │   ├── ContactsManager.swift                # CNContactStore integration
│   │   ├── DuplicateDetector.swift              # Duplicate detection algorithm (O(n))
│   │   ├── DataQualityAnalyzer.swift            # Data quality analysis with health scoring
│   │   ├── TestDataGenerator.swift              # Generate realistic test contacts
│   │   └── ImportExportService.swift            # JSON import/export for backups
│   ├── Views/
│   │   ├── ContentView.swift                    # Main view router
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift             # Welcome flow
│   │   │   └── PermissionRequestView.swift      # Contacts permission request
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift              # Main dashboard
│   │   │   ├── DuplicatesView.swift             # Duplicate management
│   │   │   ├── CleanupView.swift                # Data quality issues
│   │   │   └── GroupsView.swift                 # Group management
│   │   └── SettingsView.swift                   # App settings
│   ├── Resources/
│   └── SupportingFiles/
│       ├── Info.plist                           # App metadata & permissions
│       └── ContactsOrganizer.entitlements       # Sandbox & entitlements
└── README.md
```

## Architecture

### MVVM + Service Layer Pattern

**Models**: Data structures for contacts, duplicates, quality issues
**Views**: SwiftUI views for UI presentation
**Services**: Business logic for contact operations, duplicate detection, analysis
**State Management**: Centralized app state with `@StateObject` and `@EnvironmentObject`

### Key Components

#### 1. ContactsManager (Service)
- Manages CNContactStore access and authorization
- Fetches and caches contacts
- Performs contact operations (merge, create groups)
- Calculates statistics

#### 2. DuplicateDetector (Service)
- Implements Levenshtein distance algorithm for name similarity
- Matches contacts by exact/similar names, phone, email
- Ranks duplicate groups by confidence level
- Returns analysis summary

#### 3. DataQualityAnalyzer (Service)
- Identifies missing or incomplete contact information
- Categorizes issues by severity (high/medium/low)
- Generates health score and summary statistics

#### 4. AppState (State Management)
- Manages navigation between onboarding, permissions, dashboard
- Tracks authorization status
- Persists user preferences

## Mac App Store Requirements

### ✅ Implemented Requirements

- [x] App Sandbox enabled
- [x] Contacts entitlement (`com.apple.security.personal-information.addressbook`)
- [x] `NSContactsUsageDescription` in Info.plist
- [x] Permission request flow with clear explanation
- [x] Privacy-first architecture (local processing only)
- [x] Modern SwiftUI interface following macOS Human Interface Guidelines
- [x] Graceful permission denial handling

### 📋 Required Before Submission

1. **Developer Setup**
   - [ ] Enroll in Apple Developer Program ($99/year)
   - [ ] Create App Store Connect account
   - [ ] Configure banking/tax information

2. **App Assets**
   - [ ] 1024x1024 app icon (PNG, Display P3)
   - [ ] 3-10 screenshots (2880x1800 recommended)
   - [ ] App description and keywords
   - [ ] Privacy policy URL (required)

3. **Code Signing**
   - [ ] Mac App Distribution certificate
   - [ ] Configure bundle ID (must be unique)
   - [ ] Sign app in Xcode

4. **Testing**
   - [ ] Test on multiple macOS versions
   - [ ] Test with large contact databases (1K+ contacts)
   - [ ] Test permission denial scenarios
   - [ ] Beta test with TestFlight

5. **App Store Connect**
   - [ ] Complete App Privacy Details
   - [ ] Complete age rating questionnaire (likely 4+)
   - [ ] Select category (Productivity recommended)
   - [ ] Upload screenshots and app icon

## Development Setup

### Prerequisites

- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Building the Project

1. **Open in Xcode**
   ```bash
   cd /Volumes/CORSAIR/swift_contacts_organizer
   open -a Xcode ContactsOrganizer/
   ```

2. **Create Xcode Project**
   - Launch Xcode
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: "Contacts Organizer"
   - Bundle ID: `com.yourname.ContactsOrganizer` (must be unique)
   - Team: Select your Apple Developer team
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: macOS 12.0

3. **Add Source Files**
   - Drag the `ContactsOrganizer/` directory into your Xcode project
   - Ensure "Copy items if needed" is checked
   - Select "Create groups" for folder structure

4. **Configure Entitlements**
   - Select your target → Signing & Capabilities
   - Click "+ Capability"
   - Add "App Sandbox"
   - Under "Personal Information", enable "Contacts"
   - Verify `ContactsOrganizer.entitlements` matches your settings

5. **Configure Info.plist**
   - Verify `NSContactsUsageDescription` is present
   - Update description if needed for your use case

6. **Build and Run**
   - Select "My Mac" as run destination
   - Press Cmd+R to build and run

### Development Mode

For development, the app runs in sandbox mode but has access to your actual Contacts database. **Always backup your contacts before testing!**

You can create a test contacts database:
1. Open Contacts.app
2. Create a new test group
3. Add sample contacts for testing

## Privacy & Security

### What Data is Accessed
- Contact names, phone numbers, email addresses
- Contact organization and group information
- Contact metadata (creation/modification dates)

### What Data is NOT Accessed
- ❌ Messages database (not possible in sandboxed apps)
- ❌ Call history (not accessible to sandboxed apps)
- ❌ Any data outside the Contacts framework

### Data Usage
- All processing happens locally on the user's Mac
- No data is sent to servers or third parties
- No analytics, tracking, or telemetry
- No cloud sync or backup

### User Control
- Users must explicitly grant Contacts access
- Users can revoke access at any time in System Settings
- All contact modifications require user confirmation
- Undo functionality provided where possible

## Distribution Options

### Option 1: Mac App Store (Recommended)
**Pros:**
- Best discoverability and credibility
- Automatic updates
- Sandboxing provides security guarantees
- Apple handles payment processing

**Cons:**
- 30% commission to Apple
- Cannot access Messages or Call History
- Review process (typically 1-3 days)
- Must follow strict guidelines

### Option 2: Direct Distribution
**Pros:**
- Keep 100% of revenue
- Can add features not allowed in App Store
- Faster iteration
- More flexibility

**Cons:**
- Need to handle code signing and notarization
- Less discoverability
- Users more hesitant to install
- Must handle updates yourself

## Pricing Recommendations

For general consumers on Mac App Store:

- **Paid Upfront**: $9.99 - $14.99 (recommended for v1.0)
- **Free + IAP**: Free download, unlock full features for $9.99
- **Subscription**: $1.99 - $4.99/month (requires ongoing feature development)

Start with paid upfront to validate market demand, then consider subscription model for v2.0 with additional features.

## Roadmap

### Version 1.0 (MVP) - Current Status
- [x] Duplicate detection algorithm (O(n) optimized)
- [x] Data quality analysis with severity weighting
- [x] Smart groups by organization and custom criteria
- [x] Interactive dashboard with clickable cards
- [x] Comprehensive test suite (40+ tests)
- [x] Test data generator for development
- [x] JSON import/export for backups
- [x] Onboarding flow
- [x] Permission handling
- [x] Swift 6 concurrency compliance
- [ ] App icon design
- [ ] Screenshot creation for App Store
- [ ] Mac App Store submission

### Version 1.1
- [ ] Interactive merge workflow UI
- [ ] Contact editing capabilities
- [ ] Export reports (PDF/CSV)
- [ ] Dark mode optimization
- [ ] Undo/redo functionality

### Version 2.0
- [ ] Batch operations
- [ ] Advanced filtering and search
- [ ] Contact deduplication wizard
- [ ] Automated cleanup scheduling

### Version 3.0 (Future)
- [ ] Contact history tracking
- [ ] Scheduled automatic cleanup
- [ ] Integration with other productivity apps
- [ ] AI-powered suggestions

## Known Limitations

1. **No Messages/Call History**: Mac App Store sandboxing prevents access to these databases
2. **Contact Merging**: Algorithm implemented, UI workflow needs completion
3. **Undo**: Not yet implemented for all operations
4. **Export Reports**: PDF/CSV export not yet implemented (JSON export available)

## Performance Optimizations ✅

- **Duplicate detection**: Optimized to O(n) using hash-based lookups instead of O(n²) comparison
- **Background processing**: Heavy analysis runs on background threads without blocking UI
- **Async/await**: Swift 6 concurrency-safe with proper actor isolation
- **Efficient health scoring**: Severity-weighted algorithm with minimal overhead
- **Tested with 1000+ contacts**: Maintains responsiveness on large databases

## Testing Checklist

- [ ] Test with 0 contacts
- [ ] Test with 100 contacts
- [ ] Test with 1,000 contacts
- [ ] Test with 10,000+ contacts
- [ ] Test permission denial
- [ ] Test permission revocation during use
- [ ] Test on macOS 12 (minimum deployment target)
- [ ] Test on macOS 13
- [ ] Test on latest macOS version
- [ ] Test with contacts containing special characters
- [ ] Test with contacts in multiple languages
- [ ] Test app launch time
- [ ] Test memory usage during analysis

## Contributing

This is currently a single-developer project. If you'd like to contribute:

1. Fork the repository
2. Create a feature branch
3. Follow Swift style guidelines
4. Add tests for new functionality
5. Submit a pull request

## License

Copyright © 2025. All rights reserved.

## Support

For questions or issues:
- Email: support@example.com
- Website: https://example.com/support

## Acknowledgments

- Built with SwiftUI and Contacts framework
- Duplicate detection uses Levenshtein distance algorithm
- Inspired by the need for better contact management on macOS
