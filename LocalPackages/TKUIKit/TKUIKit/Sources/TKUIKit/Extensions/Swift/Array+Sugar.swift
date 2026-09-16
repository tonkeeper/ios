import Foundation

public extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

public extension Array where Element: Equatable {
    var unique: [Element] {
        var uniqueElements: [Element] = []
        forEach { item in
            if !uniqueElements.contains(item) {
                uniqueElements += [item]
            }
        }
        return uniqueElements
    }

    mutating func remove(_ element: Element) {
        if let index = firstIndex(where: { evaluated in
            evaluated == element
        }) {
            remove(at: index)
        }
    }

    func removingDuplicatedElements() -> [Element] {
        var result = [Element]()
        forEach { item in
            if !result.contains(item) {
                result.append(item)
            }
        }
        return result
    }
}
