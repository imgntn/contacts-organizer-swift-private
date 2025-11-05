# Changelog

All notable changes to Contacts Organizer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Interactive Dashboard Cards**: Click any statistic or issue card on the Overview page to navigate to detailed views
  - Data Quality card → Cleanup tab
  - Organization/Photos cards → Groups tab
  - Duplicate Groups card → Duplicates tab
  - Issue cards → Cleanup tab
- **Comprehensive Health Score Tests**: Added 4 new test cases validating severity-weighted scoring algorithm
  - Test for severity weighting (high: -10, medium: -3, low: -0.5)
  - Test for low priority cap at 5% maximum impact
  - Test for mixed severity calculations
  - Test for accurate score decreases

### Changed
- **Improved Health Score Algorithm**: Severity-weighted scoring system with fairness improvements
  - High priority issues (no name, no contact info): -10 points each
  - Medium priority issues (missing phone): -3 points each
  - Low priority issues (missing email, incomplete data): -0.5 points each, **capped at 5% total impact**
  - Prevents low-priority issues from unfairly tanking health score to 0%
- **Unified Health Scoring**: Both Dashboard and Cleanup page now use identical algorithm
  - Fixed inconsistency between `ContactStatistics.dataQualityScore` and `DataQualityAnalyzer.healthScore`
  - Added severity count fields to `ContactStatistics` model
  - Dashboard now updates statistics with issue severities after analysis
- **Modern Settings Window Opening**: Replaced deprecated window-search hack with official `@Environment(\.openSettings)` API
  - Uses Apple's recommended approach for macOS 14+
  - Eliminates 24 lines of fragile selector-based code
  - Works reliably across macOS versions

### Fixed
- Health score showing 0% despite only having low-priority issues
- Cleanup page and Dashboard showing different health scores for same data
- "Open Settings" button not working reliably

## [1.0.0] - 2025-01-04

### Added
- Smart Groups feature with organization-based grouping and custom criteria
- Test Data Generator for creating realistic test contacts (10-1000 contacts)
- Import/Export functionality for JSON backup and restore
- Developer Settings tab with test data tools
- Comprehensive test suite with 40+ unit tests
- Swift 6 concurrency compliance throughout codebase
- Privacy policy and support pages ready for hosting
- Severity-based issue detection (High/Medium/Low)

### Changed
- Optimized duplicate detection from O(n²) to O(n) using hash-based lookups
- Improved performance with background processing for heavy analysis
- Enhanced UI with loading indicators and progress feedback

### Fixed
- Duplicate detector multipleMatches detection accuracy
- Smart groups accepting test contacts
- Name matching using proper word boundaries
- All Swift 6 concurrency warnings resolved
- IssueType Equatable conformance with nonisolated extension

## Technical Details

### Health Score Calculation Formula

```swift
// ContactStatistics.dataQualityScore
guard totalContacts > 0 else { return 100.0 }

let highPenalty = Double(highPriorityIssues) * 10.0
let mediumPenalty = Double(mediumPriorityIssues) * 3.0
let lowPenalty = min(Double(lowPriorityIssues) * 0.5, 5.0) // Capped at 5%

let totalPenalty = highPenalty + mediumPenalty + lowPenalty

return max(0, 100.0 - totalPenalty)
```

### Interactive Navigation Mappings

| Card | Destination | Description |
|------|-------------|-------------|
| Data Quality | Cleanup | View all data quality issues |
| With Organization | Groups | View organization-based groups |
| With Photos | Groups | View contacts with photos |
| Duplicate Groups | Duplicates | View all duplicate groups |
| High Priority Issues | Cleanup | View high-severity issues |
| Total Issues | Cleanup | View all issues |

### Test Coverage

- **43 total tests** (as of latest run)
- **40+ passing tests**
- Covers: Duplicate detection, Data quality analysis, Smart groups, Health scoring
- Performance tests with 1000+ contact datasets

## [0.9.0] - 2025-01-03

### Added
- Initial project structure
- CNContactStore integration
- Basic duplicate detection algorithm
- Data quality analyzer
- Onboarding flow
- Permission request handling
- Dashboard with statistics
- Settings view

---

[Unreleased]: https://github.com/yourusername/contacts-organizer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/contacts-organizer/releases/tag/v1.0.0
[0.9.0]: https://github.com/yourusername/contacts-organizer/releases/tag/v0.9.0
