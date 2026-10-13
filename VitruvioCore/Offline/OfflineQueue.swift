import Foundation

/// Offline mutation queue seam. Concrete persistence lands with training changes.
public protocol OfflineQueue: AnyObject, Sendable {
    var pendingCount: Int { get }
}

/// No-op offline queue for Core wiring until training sync is implemented.
public final class StubOfflineQueue: OfflineQueue, @unchecked Sendable {
    public private(set) var pendingCount = 0

    public init() {}
}
