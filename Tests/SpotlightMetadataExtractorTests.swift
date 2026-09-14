import Darwin
import XCTest

final class SpotlightMetadataExtractorTests: XCTestCase {
    func testUnknownFileSize_failsClosed() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
            .appendingPathExtension("gcode")

        let attrs = NSMutableDictionary()
        XCTAssertFalse(SpotlightMetadataExtractor.populate(attributes: attrs, fileURL: url))
        XCTAssertEqual(attrs.count, 0)
    }

    func testLargeGCode_skipsSegmentCount() {
        let url = sparseFile(ext: "gcode", logicalSize: Int64(SpotlightIndexing.largeFileFastPathByteCount) + 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let attrs = NSMutableDictionary()
        XCTAssertTrue(SpotlightMetadataExtractor.populate(attributes: attrs, fileURL: url))
        XCTAssertNil(attrs["com_andreymaltsev_threemf_segmentCount"])
        let desc = attrs[kMDItemDescription as String] as? String
        XCTAssertEqual(desc, "Large G-code (\(SpotlightIndexing.largeFileFastPathByteCount + 1) bytes)")
    }

    func testLargeSTL_skipsTriangleCount() {
        let url = sparseFile(ext: "stl", logicalSize: Int64(SpotlightIndexing.largeFileFastPathByteCount) + 1)
        defer { try? FileManager.default.removeItem(at: url) }

        let attrs = NSMutableDictionary()
        XCTAssertTrue(SpotlightMetadataExtractor.populate(attributes: attrs, fileURL: url))
        XCTAssertNil(attrs["com_andreymaltsev_threemf_triangleCount"])
        let desc = attrs[kMDItemDescription as String] as? String
        XCTAssertEqual(desc, "Large STL (\(SpotlightIndexing.largeFileFastPathByteCount + 1) bytes)")
    }

    private func sparseFile(ext: String, logicalSize: Int64) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotlight-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        let fd = open(url.path, O_CREAT | O_RDWR, 0o600)
        precondition(fd >= 0)
        precondition(ftruncate(fd, logicalSize) == 0)
        close(fd)
        return url
    }
}
