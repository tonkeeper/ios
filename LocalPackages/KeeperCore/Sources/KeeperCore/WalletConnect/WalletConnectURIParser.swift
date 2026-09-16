import Foundation
import ReownWalletKit

enum WalletConnectURIParser {
    static func normalized(_ uriString: String) -> String {
        let trimmedURIString = uriString.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedPairingURI = normalizedPairingURI(trimmedURIString) {
            return normalizedPairingURI
        }

        guard let wrappedURI = wrappedURI(from: trimmedURIString) else {
            return trimmedURIString
        }
        return normalized(wrappedURI)
    }

    static func pairingTopic(from uriString: String) -> String? {
        let normalizedURI = normalized(uriString)
        guard isRawPairingURI(normalizedURI),
              let components = rawURIComponents(from: normalizedURI),
              components.query != nil
        else {
            return nil
        }
        return components.topic
    }

    static func wakeUpTopic(from uriString: String) -> String? {
        let normalizedURI = normalized(uriString)
        guard let components = rawURIComponents(from: normalizedURI),
              components.query == nil
        else {
            return nil
        }
        return components.topic
    }

    static func requiredPairingTopic(from uriString: String) throws(WalletConnectPairingError) -> String {
        guard let topic = pairingTopic(from: uriString) else {
            throw .invalidURI(uriString)
        }
        return topic
    }

    static func pairingExpirationDate(from uriString: String) -> Date? {
        let normalizedURI = normalized(uriString)
        guard let uri = try? WalletConnectURI(uriString: normalizedURI) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(uri.expiryTimestamp))
    }

    static func wrappedURI(from uriString: String) -> String? {
        if let components = URLComponents(string: uriString),
           let value = components.queryItems?.first(where: { $0.name == "uri" })?.value
        {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if isRawPairingURI(trimmedValue) {
                return trimmedValue
            }
        }

        guard let value = rawQueryValue(named: "uri", in: uriString) else {
            return nil
        }
        let decoded = value.removingPercentEncoding ?? value
        let trimmedValue = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func isRawPairingURI(_ uriString: String) -> Bool {
        guard let components = rawURIComponents(from: uriString),
              let query = components.query,
              !query.isEmpty
        else {
            return false
        }

        return query
            .split(separator: "&")
            .contains { item in
                let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2,
                      let name = pair.first,
                      let value = pair.last
                else {
                    return false
                }
                return name.lowercased() == "symkey" && !value.isEmpty
            }
    }

    private static func normalizedPairingURI(_ uriString: String) -> String? {
        let trimmedURIString = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURIString.lowercased().hasPrefix("wc:") else {
            return nil
        }

        let payloadStart = trimmedURIString.index(trimmedURIString.startIndex, offsetBy: 3)
        return "wc:\(trimmedURIString[payloadStart...])"
    }

    private static func rawURIComponents(from uriString: String) -> (topic: String, query: String?)? {
        guard let normalizedURI = normalizedPairingURI(uriString) else {
            return nil
        }

        let payload = normalizedURI.dropFirst(3)
        let components = payload.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard let topicAndVersion = components.first else {
            return nil
        }

        let topicVersionComponents = topicAndVersion.split(
            separator: "@",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard topicVersionComponents.count == 2,
              let topic = topicVersionComponents.first,
              let version = topicVersionComponents.last,
              !topic.isEmpty,
              version == "2"
        else {
            return nil
        }

        let query = components.count == 2 ? components.last.map(String.init) : nil
        return (String(topic), query)
    }

    private static func rawQueryValue(named name: String, in uriString: String) -> String? {
        guard let queryStart = uriString.firstIndex(of: "?") else {
            return nil
        }

        var query = uriString[uriString.index(after: queryStart)...]
        if let fragmentStart = query.firstIndex(of: "#") {
            query = query[..<fragmentStart]
        }

        let prefixedName = "\(name)="
        let valueStart: String.Index
        if query.hasPrefix(prefixedName) {
            valueStart = query.index(query.startIndex, offsetBy: prefixedName.count)
        } else if let range = query.range(of: "&\(prefixedName)") {
            valueStart = range.upperBound
        } else {
            return nil
        }

        let value = String(query[valueStart...])
        if let valueEnd = query[valueStart...].firstIndex(of: "&") {
            let truncatedValue = String(query[valueStart ..< valueEnd])
            let decodedTruncatedValue = truncatedValue.removingPercentEncoding ?? truncatedValue
            if isRawPairingURI(decodedTruncatedValue) || wakeUpTopic(from: decodedTruncatedValue) != nil {
                return truncatedValue
            }
        }
        return value.isEmpty ? nil : value
    }
}
