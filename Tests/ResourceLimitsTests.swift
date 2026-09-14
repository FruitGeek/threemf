import XCTest

final class ResourceLimitsTests: XCTestCase {
    func testQuickLookCapsAreTighterThanCLI() {
        XCTAssertLessThan(ResourceLimits.quickLook.maxVertices, ResourceLimits.cli.maxVertices)
        XCTAssertLessThan(ResourceLimits.quickLook.maxGCodeSegments, ResourceLimits.cli.maxGCodeSegments)
        XCTAssertLessThan(ResourceLimits.quickLook.maxMetadataSidecarBytes, ResourceLimits.cli.maxMetadataSidecarBytes)
    }
}
