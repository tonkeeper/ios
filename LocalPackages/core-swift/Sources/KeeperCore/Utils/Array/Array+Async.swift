import Foundation


extension Array {

    func asyncForEach(_ operation: @escaping (Element) async -> Void) async {
        for element in self {
            await operation(element)
        }
    }
}

