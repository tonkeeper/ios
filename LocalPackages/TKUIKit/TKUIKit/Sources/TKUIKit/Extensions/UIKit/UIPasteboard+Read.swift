import UIKit

public extension UIPasteboard {
    /// A read waits for the paste permission alert and for the source app, so it must not block the main thread.
    @concurrent
    func readString() async -> String? {
        string
    }
}
