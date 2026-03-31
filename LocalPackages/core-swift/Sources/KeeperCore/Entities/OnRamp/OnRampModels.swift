import Foundation

// MARK: - Merchants (v2/onramp/merchants)

public struct OnRampMerchantInfoButton: Codable, Equatable {
    public let title: String
    public let url: String
}

public struct OnRampMerchantInfo: Codable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let image: String
    public let fee: Double
    public let isP2P: Bool
    public let buttons: [OnRampMerchantInfoButton]
}

public struct OnRampLimits: Codable, Equatable, Hashable {
    public let min: Double
    public let max: Double?
}

// MARK: - Calculate (v2/onramp/calculate)

public enum OnRampPurchaseType: String {
    case buy
    case sell
    case swap
}

public struct OnRampCalculateResult: Equatable {
    public let quotes: [OnRampQuoteResult]
    public let suggestedQuotes: [OnRampQuoteResult]
}

public struct OnRampQuoteResult: Equatable {
    public let merchantId: String
    public let widgetUrl: String?
    public let amount: Double
    public let fromAmount: Double?
    public let minAmount: Double?
    public let maxAmount: Double?
}

// MARK: - Layout (v2/onramp/layout)

public struct OnRampLayout: Codable, Equatable {
    public let assets: [OnRampLayoutToken]
}

public struct OnRampLayoutToken: Codable, Equatable, Hashable {
    public let symbol: String
    public let assetId: String?
    public let address: String?
    public let network: String
    public let networkName: String
    public let networkImage: String
    public let image: String
    public let decimals: Int
    public let stablecoin: Bool
    public let cashMethods: [OnRampLayoutCashMethod]
    public let cryptoMethods: [OnRampLayoutCryptoMethod]

    public var isTronNetwork: Bool {
        isTron(network: network)
    }
}

public struct OnRampLayoutCashMethod: Codable, Equatable, Hashable {
    public let type: String
    public let name: String
    public let image: String
    public let providers: [OnRampLayoutProvider]
    public let isP2P: Bool
}

public struct OnRampLayoutCryptoMethod: Codable, Equatable, Hashable {
    public let symbol: String
    public let assetId: String?
    public let network: String
    public let networkName: String
    public let networkImage: String
    public let image: String
    public let decimals: Int
    public let stablecoin: Bool
    public let fee: Double?
    public let minAmount: Double?
    public let providers: [OnRampLayoutProvider]

    public var cryptoPickerIdentifier: String {
        "\(symbol)_\(network)"
    }

    public var isTronNetwork: Bool {
        isTron(network: network)
    }
}

public struct OnRampLayoutProvider: Codable, Equatable, Hashable {
    public let slug: String
    public let limits: OnRampLimits?
}

// MARK: - Create exchange result (v2/onramp/exchange)

public struct OnRampExchangeResult: Equatable {
    public let id: String
    public let payinAddress: String
    public let amountExpectedFrom: Double
    public let amountExpectedTo: Double
    public let status: String
    public let minDeposit: Double
    public let maxDeposit: Double
    public let rate: Double
    public let estimatedDuration: Int
}

private func isTron(network: String) -> Bool {
    ["trc20", "trc-20"].contains(network.lowercased())
}
