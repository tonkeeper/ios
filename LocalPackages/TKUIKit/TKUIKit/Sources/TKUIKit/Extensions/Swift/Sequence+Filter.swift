import Foundation

// MARK: -  First

public extension Sequence {
    // Returns first element in the sequence that has value at certain key path equal to value at key path of passed element.
    // - Parameters:
    //   - keyPath: Key path to compare, must be Equatable.
    //   - element: The element which value at key path must be equal to value at similar key path of element in sequence.
    // - Returns: The first element of the sequence that satisfies condition, or `nil` if there is no such element.

    // Returns first element in the sequence which value at certain key path contained in passed collection.
    // - Parameters:
    //   - keyPath: Key path to compare, must be Equatable.
    //   - elements: A collection of acceptable values.
    // - Returns: The first element of the sequence that satisfies condition, or `nil` if there is no such element.

    /// Returns first element in the sequence that has specific value at certain key path.
    /// - Parameters:
    ///   - value: The value that an element must have to be returned.
    ///   - keyPath: Key path to compare, must be Equatable.
    func first<T: Equatable>(with value: T, at keyPath: KeyPath<Element, T>) -> Element? {
        first { entry -> Bool in
            entry[keyPath: keyPath] == value
        }
    }

    // Returns first element in the sequence that has different value at certain key path.
    // - Parameters:
    //   - value: The value that an element must differ in.
    //   - keyPath: Key path to compare, must be Equatable.
}

// MARK: -  Contains

public extension Sequence {
    // Returns a `Boolean` value indicating whether the sequence contains an element that has value
    // at certain key path equal to value at similar key path of passed element.
    // - Parameters:
    //   - keyPath: Key path to compare, must be Equatable.
    //   - element: The element which value at key path must be equal to value at similar key path of element in sequence.
    // - Returns: `true` if the sequence contains an element that satisfies condition; otherwise - `false`.

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
