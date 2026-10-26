import ChainKit

extension ChainError {
    var logValue: String {
        let described = "type=\(String(reflecting: type(of: self)))"
        let causes = causeChain
        guard !causes.isEmpty else {
            return described
        }
        return "\(described), causes=[\(causes.joined(separator: " <- "))]"
    }
}

private extension KotlinThrowable {
    /// A cause that ChainKit does not export reaches Swift as a generated `ChainKit_kobjcc*`
    /// class, so its Swift type name identifies nothing. `description()` is the Kotlin
    /// `toString()`, which still carries the real qualified class name.
    var causeChain: [String] {
        var links = [String]()
        var current = cause
        while let link = current, links.count < 4 {
            links.append(link.description())
            current = link.cause
        }
        return links
    }
}

extension NodeError {
    var logValue: String {
        let described = "type=\(String(reflecting: type(of: self)))"
        switch self {
        case let wrapped as NodeError.NetworkWrap: return "\(described), error=\(wrapped.value.description())"
        case let rejected as NodeError.Rejected: return "\(described), code=\(rejected.code), message=\(rejected.message)"
        case let unknown as NodeError.Unknown: return "\(described), error=\(unknown.error?.description() ?? "unknown")"
        default: return described
        }
    }
}

extension SignError {
    var logValue: String {
        "type=\(String(reflecting: type(of: self)))"
    }
}
