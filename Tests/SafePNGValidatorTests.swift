import XCTest

final class SafePNGValidatorTests: XCTestCase {
    private let tinyPNG = TestPNG.tiny1x1

    func testValidate_acceptsTinyPNG() throws {
        try SafePNGValidator.validatePNGData(tinyPNG)
        XCTAssertNotNil(SafePNGValidator.nsImage(fromPNG: tinyPNG))
    }

    func testValidate_rejectsEmptyData() {
        XCTAssertThrowsError(try SafePNGValidator.validatePNGData(Data())) { error in
            XCTAssertEqual(error as? SafePNGValidator.ValidationError, .invalidImage)
        }
    }

    func testDimensions_rejectOverMaxEdge() {
        XCTAssertFalse(SafePNGValidator.isAllowedPixelSize(width: 8193, height: 1))
    }

    func testDimensions_rejectOverMaxPixels() {
        XCTAssertFalse(SafePNGValidator.isAllowedPixelSize(width: 8192, height: 8192))
    }

    func testDimensions_rejectOverflowWithoutTrapping() {
        XCTAssertFalse(SafePNGValidator.isAllowedPixelSize(width: Int.max, height: Int.max))
    }
}
