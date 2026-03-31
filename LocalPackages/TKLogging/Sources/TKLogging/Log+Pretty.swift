import Foundation

public struct PrettyPrinter<Value> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

// MARK: - String

public extension PrettyPrinter where Value == String {
    var masked: String {
        guard value.count > 6 else {
            return value
        }
        let prefix = value.prefix(3)
        let suffix = value.suffix(3)
        return "\(prefix)...\(suffix)"
    }
}

public extension String {
    var pretty: PrettyPrinter<Self> {
        PrettyPrinter(self)
    }
}

// MARK: - Date

public extension PrettyPrinter where Value == Date {
    var msSinceNow: String {
        String(Int(Date().timeIntervalSince(value) * 1000))
    }
}

public extension Date {
    var pretty: PrettyPrinter<Self> {
        PrettyPrinter(self)
    }
}
