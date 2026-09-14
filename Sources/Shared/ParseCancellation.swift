import Foundation
import os

/// Cooperative cancellation for the mesh and toolpath parsers.
///
/// Parsers poll this at loop boundaries and abort with `CancellationError`. Quick Look
/// cancels the token on dismissal so a multi-million-triangle parse stops instead of
/// running to completion for a preview nobody will see.
public final class ParseCancellation: Sendable {
    /// Work items between polls. Large enough that the lock acquisition is noise against
    /// the per-item parse cost, small enough to abort within a few milliseconds.
    public static let checkStride = 1 << 16

    private let flag = OSAllocatedUnfairLock(initialState: false)

    public init() {}

    public func cancel() {
        flag.withLock { $0 = true }
    }

    public var isCancelled: Bool {
        flag.withLock { $0 }
    }

    public func check() throws {
        if isCancelled {
            throw CancellationError()
        }
    }
}

/// Amortizes cancellation polling across a hot loop: decrements a local counter and only
/// touches the shared flag once per ``ParseCancellation/checkStride`` items.
struct CancellationPoller {
    private let cancellation: ParseCancellation?
    private var remaining: Int

    init(_ cancellation: ParseCancellation?) {
        self.cancellation = cancellation
        // Poll on the first tick so a token cancelled before the parse started aborts at
        // once instead of after a full stride of work.
        remaining = 1
    }

    @inline(__always)
    mutating func tick() throws {
        remaining -= 1
        guard remaining <= 0 else { return }
        remaining = ParseCancellation.checkStride
        try cancellation?.check()
    }

    /// Variant for `DispatchQueue.concurrentPerform` bodies, which cannot throw. Callers
    /// return early from the chunk and re-check the token after the barrier.
    @inline(__always)
    mutating func tickIsCancelled() -> Bool {
        remaining -= 1
        guard remaining <= 0 else { return false }
        remaining = ParseCancellation.checkStride
        return cancellation?.isCancelled ?? false
    }
}
