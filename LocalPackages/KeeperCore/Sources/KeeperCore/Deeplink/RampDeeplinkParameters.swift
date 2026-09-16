import Foundation

public struct RampDeeplinkParameters: Equatable, Sendable {
    public let fromToken: String?
    public let toToken: String?
    public let toNetwork: String?
    public let fromNetwork: String?
    public let cashMethod: String?
    public let itemType: OnRampLayoutItemType?

    public init(
        fromToken: String?,
        toToken: String?,
        toNetwork: String?,
        fromNetwork: String?,
        cashMethod: String?,
        itemType: OnRampLayoutItemType? = nil
    ) {
        self.fromToken = fromToken
        self.toToken = toToken
        self.toNetwork = toNetwork
        self.fromNetwork = fromNetwork
        self.cashMethod = cashMethod
        self.itemType = itemType
    }
}

public enum RampDeeplinkMatching {
    public static func normalizedNetwork(_ value: String) -> String {
        let lower = value.lowercased()
        if lower == "trc-20" { return "trc20" }
        return lower
    }

    public static func matchLayoutAsset(
        in assets: [OnRampLayoutToken],
        fromToken ft: String?,
        fromNetwork fn: String?
    ) -> OnRampLayoutToken? {
        let trimmedFt = ft?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedFt.isEmpty else { return nil }

        let ftUpper = trimmedFt.uppercased()
        let candidates = assets.filter { $0.symbol.uppercased() == ftUpper }
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates.first }

        let fnTrimmed = fn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !fnTrimmed.isEmpty else {
            return candidates.first
        }

        let fnNorm = normalizedNetwork(fnTrimmed)
        if let match = candidates.first(where: { normalizedNetwork($0.network) == fnNorm }) {
            return match
        }
        let fnLower = fnTrimmed.lowercased()
        return candidates.first { $0.networkName.lowercased() == fnLower }
            ?? candidates.first { $0.network.lowercased() == fnLower }
    }

    public static func matchCryptoMethod(
        in methods: [OnRampLayoutCryptoMethod],
        toToken tt: String?,
        toNetwork tn: String?
    ) -> OnRampLayoutCryptoMethod? {
        let trimmedTt = tt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTt.isEmpty else { return nil }

        let ttUpper = trimmedTt.uppercased()
        let candidates = methods.filter { $0.symbol.uppercased() == ttUpper }
        guard !candidates.isEmpty else { return nil }

        let tnTrimmed = tn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !tnTrimmed.isEmpty {
            let tnNorm = normalizedNetwork(tnTrimmed)
            let filtered = candidates.filter { normalizedNetwork($0.network) == tnNorm }
            if let one = filtered.first { return one }
            let tnLower = tnTrimmed.lowercased()
            if let byName = candidates.first(where: { $0.networkName.lowercased() == tnLower }) {
                return byName
            }
        }

        return candidates.first
    }

    public static func matchCashMethod(
        in methods: [OnRampLayoutCashMethod],
        cashMethod cm: String?
    ) -> OnRampLayoutCashMethod? {
        let trimmed = cm?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        let cmLower = trimmed.lowercased()
        if let exact = methods.first(where: { $0.type.lowercased() == cmLower }) {
            return exact
        }
        return methods.first { $0.name.lowercased() == cmLower }
    }
}
