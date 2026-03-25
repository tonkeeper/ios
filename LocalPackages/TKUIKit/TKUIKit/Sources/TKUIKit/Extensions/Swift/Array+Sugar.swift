import Foundation

public extension Array where Element: Equatable {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    var unique: [Element] {
        var uniqueElements: [Element] = []
        forEach { item in
            if !uniqueElements.contains(item) {
                uniqueElements += [item]
            }
        }
        return uniqueElements
    }

    func index(of element: Element) -> Int? {
        return firstIndex { item -> Bool in
            return item == element
        }
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
