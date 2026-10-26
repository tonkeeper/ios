import Foundation

/// Holds provider-resolved links until the scene can route them, and drops a link the
/// Tonkeeper pipeline has already received during this launch. Universal links and custom
/// schemes that open the same screen count as one link.
public struct ResolvedDeeplinkBuffer: Equatable {
    private var seen: Set<String> = []
    private var pending: [String] = []
    private var isRouterReady = false
    private var isCoalescing = false

    public init() {}

    public mutating func markDelivered(_ link: String?) {
        guard let link = Self.normalized(link) else { return }
        seen.insert(Self.identity(link))
        pending.removeAll { Self.identity($0) == Self.identity(link) }
    }

    /// A link to route immediately, or nothing when it is a duplicate or still waiting
    /// for the router / the end of the current URL callback.
    public mutating func receive(_ link: String?) -> [String] {
        guard let link = Self.normalized(link), seen.insert(Self.identity(link)).inserted else { return [] }
        if isRouterReady, !isCoalescing {
            return [link]
        }
        pending.append(link)
        return []
    }

    public mutating func beginCoalescing() {
        isCoalescing = true
    }

    public mutating func endCoalescing() -> [String] {
        isCoalescing = false
        guard isRouterReady else { return [] }
        return drainPending()
    }

    public mutating func attachRouter() -> [String] {
        isRouterReady = true
        guard !isCoalescing else { return [] }
        return drainPending()
    }

    private mutating func drainPending() -> [String] {
        let links = pending
        pending.removeAll()
        return links
    }

    private static func normalized(_ link: String?) -> String? {
        guard let link = link?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else {
            return nil
        }
        return link
    }

    private static func identity(_ link: String) -> String {
        guard let components = URLComponents(string: link),
              let scheme = components.scheme?.lowercased()
        else {
            return link
        }
        let host = components.host?.lowercased()
        let query = canonicalQuery(components)
        let fragment = components.fragment.map { "#\($0)" } ?? ""
        if scheme == "https" || scheme == "http",
           host == "app.tonkeeper.com" || host == "app.tonkeeper.org" || host == "app.keeperwallet.com"
        {
            return "tonkeeper://\(pathAndQuery(Self.trimPath(components.path), query: query))\(fragment)"
        }
        if scheme == "tonkeeper" || scheme == "keeper" || scheme == "tonkeeper-mob" || scheme == "ton" {
            let path = [host ?? "", Self.trimPath(components.path)]
                .filter { !$0.isEmpty }
                .joined(separator: "/")
            return "tonkeeper://\(pathAndQuery(path, query: query))\(fragment)"
        }
        return "\(scheme)://\(host ?? "")\(components.path)\(query.isEmpty ? "" : "?\(query)")\(fragment)"
    }

    private static func trimPath(_ path: String) -> String {
        var path = path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        if path.hasPrefix("/") {
            path.removeFirst()
        }
        return path
    }

    private static func pathAndQuery(_ path: String, query: String) -> String {
        guard !query.isEmpty else { return path }
        return "\(path)?\(query)"
    }

    private static func canonicalQuery(_ components: URLComponents) -> String {
        guard let items = components.queryItems, !items.isEmpty else { return "" }
        let sorted = items.sorted { lhs, rhs in
            if lhs.name != rhs.name {
                return lhs.name < rhs.name
            }
            return (lhs.value ?? "") < (rhs.value ?? "")
        }
        var rebuilt = URLComponents()
        rebuilt.queryItems = sorted
        return rebuilt.percentEncodedQuery ?? ""
    }
}
