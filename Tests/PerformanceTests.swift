import SceneKit
import simd
import XCTest
import ZIPFoundation

/// Performance regression suite. Builds large synthetic STL/3MF/G-code fixtures once and
/// measures parser throughput. Numbers are recorded by XCTest as baselines; CI can compare
/// against them.
///
/// Default fixture size is small (50K triangles / G-code moves) so the suite stays fast on
/// PRs. Set the env var `THREEMF_PERF_LARGE=1` to scale STL up to 500K triangles for nightly
/// runs. 3MF and G-code stay at the PR-scale counts so ZIP/XML generation does not dominate.
final class PerformanceTests: XCTestCase {
    private var smallSTL: URL!
    private var largeSTL: URL!
    private var small3MF: URL!
    private var large3MF: URL!
    private var smallGCode: URL!
    private var largeGCode: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let triangleCount = ProcessInfo.processInfo.environment["THREEMF_PERF_LARGE"] == "1"
            ? 500_000
            : 50000
        smallSTL = try writeBinarySTL(triangles: 5000)
        largeSTL = try writeBinarySTL(triangles: triangleCount)
        small3MF = try writeSynthetic3MF(triangles: 5000)
        large3MF = try writeSynthetic3MF(triangles: 50000)
        smallGCode = try writeSyntheticGCode(moves: 5000)
        largeGCode = try writeSyntheticGCode(moves: 50000)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: smallSTL)
        try? FileManager.default.removeItem(at: largeSTL)
        try? FileManager.default.removeItem(at: small3MF)
        try? FileManager.default.removeItem(at: large3MF)
        try? FileManager.default.removeItem(at: smallGCode)
        try? FileManager.default.removeItem(at: largeGCode)
        try super.tearDownWithError()
    }

    /// Hard wall-clock budgets are stricter than XCTest baselines (no Xcode-only setup
    /// required, no per-machine plist), and they fail loudly on regression. Numbers are
    /// the 95th percentile observed on M2 / M3 with ~5× safety margin.
    private static let smallBudgetSeconds: Double = 0.250
    private static let largeBudgetSeconds: Double = 1.500
    // SceneKit's first Metal snapshot includes cold shader/cache setup on fresh CI runners.
    // Keep mesh rendering tolerant of that one-time cost while retaining a tighter toolpath cap.
    private static let meshThumbnailBudgetSeconds: Double = 3.000
    private static let toolpathThumbnailBudgetSeconds: Double = 1.500

    func testParseBinarySTL_smallBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try STLParser.parseMesh(from: smallSTL)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.smallBudgetSeconds,
            "Small STL parse exceeded \(Self.smallBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testParseBinarySTL_largeBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try STLParser.parseMesh(from: largeSTL)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.largeBudgetSeconds,
            "Large STL parse exceeded \(Self.largeBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testParse3MF_smallBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try ThreeMFMeshParser.parseMesh(from: small3MF)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.smallBudgetSeconds,
            "Small 3MF parse exceeded \(Self.smallBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testParse3MF_largeBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try ThreeMFMeshParser.parseMesh(from: large3MF)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.largeBudgetSeconds,
            "Large 3MF parse exceeded \(Self.largeBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testParseGCode_smallBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try GCodeParser.parse(from: smallGCode)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.smallBudgetSeconds,
            "Small G-code parse exceeded \(Self.smallBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testParseGCode_largeBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try GCodeParser.parse(from: largeGCode)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(
            elapsed, Self.largeBudgetSeconds,
            "Large G-code parse exceeded \(Self.largeBudgetSeconds * 1000) ms budget (\(elapsed * 1000) ms)"
        )
    }

    func testRender3MFThumbnailBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        let mesh = try ThreeMFMeshParser.parseMesh(from: large3MF, limits: .quickLook)
        let image = renderThumbnail(scene: SceneBuilder.buildScene(from: mesh))
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertLessThan(
            elapsed, Self.meshThumbnailBudgetSeconds,
            "3MF thumbnail render exceeded \(Self.meshThumbnailBudgetSeconds * 1000) ms budget "
                + "(\(elapsed * 1000) ms)"
        )
    }

    func testRenderGCodeThumbnailBudget() throws {
        let start = CFAbsoluteTimeGetCurrent()
        let toolpath = try GCodeParser.parse(
            from: largeGCode,
            limits: .quickLook,
            outputSegmentBudget: GCodeParser.thumbnailSegmentBudget,
            computesStatistics: false
        )
        let image = renderThumbnail(scene: ToolpathSceneBuilder.buildTopDownScene(from: toolpath))
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertLessThan(
            elapsed, Self.toolpathThumbnailBudgetSeconds,
            "G-code thumbnail render exceeded \(Self.toolpathThumbnailBudgetSeconds * 1000) ms budget "
                + "(\(elapsed * 1000) ms)"
        )
    }

    // MARK: - Fixture generation

    /// Writes a synthetic well-formed binary STL with `count` triangles to a temp file.
    /// Vertices are generated in a simple 3D grid so dedup ratio is realistic (~3:1).
    private func writeBinarySTL(triangles count: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-\(count)-\(UUID().uuidString)")
            .appendingPathExtension("stl")

        var data = Data(count: 80) // header
        var triCount = UInt32(count)
        data.append(Data(bytes: &triCount, count: 4))

        // Generate triangles by walking a grid lattice. Each triangle reuses 3 vertices
        // from neighboring grid points so the dedup map gets exercised.
        let side = max(2, Int(Double(count).squareRoot()) + 1)
        var emitted = 0
        outer: for i in 0 ..< side {
            for j in 0 ..< side {
                let x = Float(i % 8)
                let y = Float(j % 8)
                let z = Float((i + j) % 4)
                var values: [Float] = [
                    0, 0, 1,
                    x, y, z,
                    x + 1, y, z,
                    x, y + 1, z,
                ]
                data.append(Data(bytes: &values, count: 48))
                var attr: UInt16 = 0
                data.append(Data(bytes: &attr, count: 2))
                emitted += 1
                if emitted >= count {
                    break outer
                }
            }
        }
        try data.write(to: url)
        return url
    }

    /// Compact inline-mesh 3MF: a triangle fan so vertex count stays `triangles + 2`.
    private func writeSynthetic3MF(triangles count: Int) throws -> URL {
        var xml = ""
        xml.reserveCapacity(count * 64 + 512)
        xml.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">
          <resources>
            <object id="1" type="model">
              <mesh>
                <vertices>
        """)
        let vertexCount = count + 2
        for i in 0 ..< vertexCount {
            let x = i % 32
            let y = (i / 32) % 32
            let z = i % 8
            xml.append("\n<vertex x=\"\(x)\" y=\"\(y)\" z=\"\(z)\" />")
        }
        xml.append("\n</vertices>\n<triangles>\n")
        for i in 0 ..< count {
            xml.append("<triangle v1=\"0\" v2=\"\(i + 1)\" v3=\"\(i + 2)\" />\n")
        }
        xml.append("""
                </triangles>
              </mesh>
            </object>
          </resources>
          <build>
            <item objectid="1" />
          </build>
        </model>
        """)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-\(count)-\(UUID().uuidString)")
            .appendingPathExtension("3mf")
        let archive = try Archive(url: url, accessMode: .create, pathEncoding: nil)
        let data = Data(xml.utf8)
        try archive.addEntry(
            with: "3D/3dmodel.model",
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                let start = Int(position)
                return data.subdata(in: start ..< start + size)
            }
        )
        return url
    }

    private func writeSyntheticGCode(moves count: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("perf-\(count)-\(UUID().uuidString)")
            .appendingPathExtension("gcode")
        var body = "G0 X0 Y0 Z0.2 F600\n"
        body.reserveCapacity(count * 24)
        for i in 1 ... count {
            body.append("G1 X\(i) Y0 E\(i)\n")
        }
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func renderThumbnail(scene: SCNScene) -> NSImage {
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: true)
        return renderer.snapshot(
            atTime: 0,
            with: CGSize(width: 256, height: 256),
            antialiasingMode: .multisampling2X
        )
    }
}
