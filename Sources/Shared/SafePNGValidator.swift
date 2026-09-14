import AppKit
import Foundation
import ImageIO

/// Guards against PNG pixel bombs: small compressed files that expand to huge bitmaps.
enum SafePNGValidator {
    static let maxPixelDimension = 8192
    static let maxPixelCount = 16_777_216 // 16 MP

    enum ValidationError: Error {
        case invalidImage
        case dimensionsTooLarge
    }

    static func validatePNGData(_ data: Data) throws {
        guard !data.isEmpty else {
            throw ValidationError.invalidImage
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            throw ValidationError.invalidImage
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any] else {
            throw ValidationError.invalidImage
        }
        let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard isAllowedPixelSize(width: width, height: height) else {
            throw ValidationError.dimensionsTooLarge
        }
    }

    /// Overflow-safe dimension check. `width * height` on a crafted IHDR can trap.
    static func isAllowedPixelSize(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0,
              width <= maxPixelDimension, height <= maxPixelDimension
        else { return false }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        return !overflow && pixelCount <= maxPixelCount
    }

    /// Validates PNG header dimensions before allocating a decoded bitmap.
    static func nsImage(fromPNG data: Data) -> NSImage? {
        guard (try? validatePNGData(data)) != nil else { return nil }
        return NSImage(data: data)
    }
}
