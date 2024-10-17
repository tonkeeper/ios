import Foundation

// MARK: -  First

public extension Sequence {

    /// Returns first element in the sequence that has value at certain key path equal to value at key path of passed element.
    /// - Parameters:
    ///   - keyPath: Key path to compare, must be Equatable.
    ///   - element: The element which value at key path must be equal to value at similar key path of element in sequence.
    /// - Returns: The first element of the sequence that satisfies condition, or `nil` if there is no such element.
    func first<T: Equatable>(by keyPath: KeyPath<Element, T>, of element: Element) -> Element? {
        first { entry -> Bool in
            entry[keyPath: keyPath] == element[keyPath: keyPath]
        }
    }

    /// Returns first element in the sequence which value at certain key path contained in passed collection.
    /// - Parameters:
    ///   - keyPath: Key path to compare, must be Equatable.
    ///   - elements: A collection of acceptable values.
    /// - Returns: The first element of the sequence that satisfies condition, or `nil` if there is no such element.
    func first<T: Equatable>(by keyPath: KeyPath<Element, T>, containedIn elements: [T]) -> Element? {
        first { entry -> Bool in
            elements.contains(entry[keyPath: keyPath])
        }
    }

    /// Returns first element in the sequence that has specific value at certain key path.
    /// - Parameters:
    ///   - value: The value that an element must have to be returned.
    ///   - keyPath: Key path to compare, must be Equatable.
    func first<T: Equatable>(with value: T, at keyPath: KeyPath<Element, T>) -> Element? {
        first { entry -> Bool in
            entry[keyPath: keyPath] == value
        }
    }

    /// Returns first element in the sequence that has different value at certain key path.
    /// - Parameters:
    ///   - value: The value that an element must differ in.
    ///   - keyPath: Key path to compare, must be Equatable.
    func first<T: Equatable>(without value: T, at keyPath: KeyPath<Element, T>) -> Element? {
        first { entry -> Bool in
            entry[keyPath: keyPath] != value
        }
    }
}

// MARK: -  Filter

public extension Sequence {

    /// Returns collection of elements that are having value at certain key path equal to value at key path of passed element.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to compare, must be Equatable.
    ///   - element: The element which value at key path must be compared with value at similar key path of elements in sequence.
    /// - Returns: Filtered collection based on key path.
    func filter<T: Equatable>(by keyPath: KeyPath<Element, T>, of element: Element) -> [Element] {
        filter { entry -> Bool in
            entry[keyPath: keyPath] == element[keyPath: keyPath]
        }
    }

    /// Returns collection of elements that are having specific value at certain key path.
    ///
    /// - Parameters:
    ///   - value: The value, that an element must have to be included in the returned collection.
    ///   - keyPath: Key path to compare, must be Equatable.
    /// - Returns: Filtered collection based on key path.
    func filter<T: Equatable>(by value: T, at keyPath: KeyPath<Element, T>) -> [Element] {
        filter { entry -> Bool in
            entry[keyPath: keyPath] == value
        }
    }

    /// Returns collection of elements that has value at certain key path that satisfies the given predicate.
    ///
    /// - Parameters:
    ///   - keyPath: Key path to compare, must be Equatable.
    ///   - isIncluded: A closure that takes a value at key path of an element of the sequence as its argument
    ///                 and returns a `Boolean` value indicating whether the element should be included in the returned collection.
    /// - Returns: A collection of the elements for which key paths `isIncluded` allowed.
    func filter<T: Equatable>(by keyPath: KeyPath<Element, T>, isIncluded: (T) -> Bool) -> [Element] {
        filter { entry -> Bool in
            isIncluded(entry[keyPath: keyPath])
        }
    }
}

// MARK: -  Contains

public extension Sequence {

    /// Returns a `Boolean` value indicating whether the sequence contains an element that has value
    /// at certain key path equal to value at similar key path of passed element.
    /// - Parameters:
    ///   - keyPath: Key path to compare, must be Equatable.
    ///   - element: The element which value at key path must be equal to value at similar key path of element in sequence.
    /// - Returns: `true` if the sequence contains an element that satisfies condition; otherwise - `false`.
    func contains<T: Equatable>(by keyPath: KeyPath<Element, T>, of element: Element) -> Bool {
        contains { entry -> Bool in
            entry[keyPath: keyPath] == element[keyPath: keyPath]
        }
    }

    /// Returns a `Boolean` value indicating whether the sequence contains an element that has specific value at certain key path.
    /// - Parameters:
    ///   - value: The value that an element must have to satisfy the condition.
    ///   - keyPath: Key path to compare, must be Equatable.
    /// - Returns: `true` if the sequence contains an element that satisfies condition; otherwise, `false`.
    func contains<T: Equatable>(with value: T, at keyPath: KeyPath<Element, T>) -> Bool {
        contains { entry -> Bool in
            entry[keyPath: keyPath] == value
        }
    }
}
