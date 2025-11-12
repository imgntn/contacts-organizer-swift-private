import XCTest
@testable import Contacts_Organizer

final class TypographyTests: XCTestCase {

    func testPlatformTypographyMatchesMacGuidelines() {
        #if os(macOS)
        XCTAssertEqual(PlatformTypography.body, 13, "macOS body text should default to 13 pt")
        XCTAssertEqual(PlatformTypography.callout, 12, "macOS callout text should default to 12 pt")
        XCTAssertEqual(PlatformTypography.caption, 11, "macOS caption text should default to 11 pt")
        XCTAssertEqual(PlatformTypography.miniCaption, 10, "macOS mini caption text should default to 10 pt")
        #else
        // When we add more platforms, ensure the helper returns non-zero values
        XCTAssertGreaterThan(PlatformTypography.body, 0)
        XCTAssertGreaterThan(PlatformTypography.callout, 0)
        XCTAssertGreaterThan(PlatformTypography.caption, 0)
        XCTAssertGreaterThan(PlatformTypography.miniCaption, 0)
        #endif
    }

    func testTextScaleMultipliers() {
        XCTAssertEqual(TextScale.normal.multiplier, 1.0)
        XCTAssertEqual(TextScale.large.multiplier, 1.15)
        XCTAssertEqual(TextScale.xlarge.multiplier, 1.3)
    }

    func testTypographySizesAreMonotonic() {
        XCTAssertGreaterThan(PlatformTypography.body, PlatformTypography.callout)
        XCTAssertGreaterThan(PlatformTypography.callout, PlatformTypography.caption)
        XCTAssertGreaterThan(PlatformTypography.caption, PlatformTypography.miniCaption)
    }
}
