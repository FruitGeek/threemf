import CoreFoundation
import Foundation

/// Spotlight calls our C entrypoint, which calls this. Returns true on success.
/// Populates `attributes` with both standard `kMDItem*` keys and custom
/// `com_andreymaltsev_threemf_*` keys declared in Schema.xml.
@_cdecl("ThreeMFExtractMetadata")
public func ThreeMFExtractMetadata(
    attributes: CFMutableDictionary,
    contentTypeUTI _: CFString,
    pathToFile: CFString
) -> DarwinBoolean {
    // Spotlight (mdworker) calls this once per indexed file across the user's filesystem.
    // Without an autorelease pool, every Foundation/AppKit object created during parse
    // accumulates until the process exits — for a full reindex of a 3D-print library,
    // that's enough to OOM mdworker. Wrap the body explicitly.
    autoreleasepool {
        let path = pathToFile as String
        let url = URL(fileURLWithPath: path)
        let attrs = attributes as NSMutableDictionary
        let ok = SpotlightMetadataExtractor.populate(attributes: attrs, fileURL: url)
        return DarwinBoolean(ok)
    }
}
