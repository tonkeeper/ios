import Foundation

public enum SomeOf<First, Second> {
    case firstOption(First)
    case secondOption(Second)

    public static func certain(_ option: First) -> Self {
        .firstOption(option)
    }

    public static func certain(_ option: Second) -> Self {
        .secondOption(option)
    }
}

extension SomeOf: Error where First: Error, Second: Error {
    public var localizedDescription: String {
        switch self {
        case let .firstOption(first):
            first.localizedDescription
        case let .secondOption(second):
            second.localizedDescription
        }
    }
}
