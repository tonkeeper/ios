import Foundation

public extension Sequence {
    func asyncNonThrowingForEach(_ handler: (Element) async -> Void) async {
        for element in self {
            await handler(element)
        }
    }
}
