import Foundation

/// P2P deeplink session parameters
public struct CreateP2PSession: Codable {
    /// Withdrawal wallet address
    public let wallet: String
    /// Blockchain chain identifier
    public let network: String
    /// Crypto currency code
    public let cryptoCurrency: String
    /// Fiat currency code
    public let fiatCurrency: String
    /// Optional exchange amount
    public let amount: Int64?

    public init(
        wallet: String,
        network: String,
        cryptoCurrency: String,
        fiatCurrency: String,
        amount: Int64?
    ) {
        self.wallet = wallet
        self.network = network
        self.cryptoCurrency = cryptoCurrency
        self.fiatCurrency = fiatCurrency
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case wallet
        case network
        case cryptoCurrency = "crypto_currency"
        case fiatCurrency = "fiat_currency"
        case amount
    }
}
