import Foundation

/// Reads a regular file into memory only after verifying its on-disk size is within a cap.
/// Uses mapped I/O when possible to avoid an extra copy for large-but-allowed files.
enum BoundedFileReader {
    enum ReadError: Error {
        case fileTooLarge
    }

    static func dataContents(of url: URL, maxByteCount: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        if values.isRegularFile == false {
            throw CocoaError(.fileReadUnknown)
        }
        if let fileSize = values.fileSize, fileSize > maxByteCount {
            throw ReadError.fileTooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= maxByteCount else {
            throw ReadError.fileTooLarge
        }
        return data
    }
}
