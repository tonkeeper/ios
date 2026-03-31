import Foundation

public extension Sequence {
    func asyncForEach(_ handler: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await handler(element)
        }
    }
}
