import Foundation

/// Limits for the bundled Spotlight importer (`mdworker`). Kept separate from CLI parse caps
/// so indexing stays bounded even when the headless CLI allows larger inputs.
enum SpotlightIndexing {
    /// Files larger than this skip full mesh / toolpath parsing during Spotlight indexing.
    static let largeFileFastPathByteCount = 50 * 1024 * 1024 // 50 MB
}
