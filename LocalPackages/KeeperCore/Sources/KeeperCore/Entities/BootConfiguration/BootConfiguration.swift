import Foundation

public struct BootConfigurations: Codable {
    @usableFromInline
    let mainnet: BootConfiguration
    @usableFromInline
    let testnet: BootConfiguration
}

public struct BootConfiguration: Codable, Equatable {
    public let tonapiV2Endpoint: String
    public let tonapiTestnetHost: String
    public let tonAPISSEEndpointV2: String?
    public let batteryHost: String
    public let tonApiV2Key: String
    public let tonConnectBridge: String
    public let mercuryoSecret: String?
    public let supportLink: URL?
    public let directSupportUrl: URL?
    public let tonkeeperNewsUrl: URL?
    public let stonfiUrl: URL?
    public let webSwapsUrl: URL?
    public let faqUrl: URL?
    public let stakingInfoUrl: URL?
    public let isBatteryBeta: Bool
    public let accountExplorer: String?
    public let transactionExplorer: String?
    public let nftOnExplorerUrl: String?
    public let batteryMeanFees: String?
    public let batteryReservedAmount: String?
    public let batteryMeanPriceSwap: String?
    public let batteryMeanPriceJetton: String?
    public let batteryMeanPriceNFT: String?
    public let batteryMeanPriceTRCMin: String?
    public let batteryMeanPriceTRCMax: String?
    public let batteryMaxInputAmount: String?
    public let batteryRefundEndpoint: URL?
    public let disableBattery: Bool
    public let disableBatterySend: Bool
    public let disableBatteryCryptoRechargeModule: Bool
    public let scamApiURL: URL?
    public let flags: Flags
    public let stories: [String]?
    public let reportAmount: String?
    public let stakingEnabledProviders: Set<String>
    public let qrScannerExtensions: [QRScannerExtension]?
    public let region: String?
    public let tronApiUrl: String?
    public let tronSwapUrl: String
    public let tronSwapTitle: String
    public let tonkeeperApiUrl: String?
    /// Analytics ingestion host. Scheme and host only — the path is appended by the sender.
    /// Absent means the endpoint compiled into the bundle stands.
    public let aptabaseEndpoint: String?
    public let multichainHelpUrl: URL?
    public let multichain: Endpoint
    public let trading: Endpoint
    public let explorers: [ChainExplorer]

    public struct Endpoint: Codable, Equatable {
        public let domain: URL
        public let realtime: URL?
    }

    public struct ChainExplorer: Codable, Equatable {
        public let chain: String
        public let name: String
        /// Transaction page template carrying a `{tx_hash}` placeholder.
        public let url: String
        /// Token page template carrying a `{token_address}` placeholder. Absent on chains without tokens.
        public let tokenURL: String?

        public init(
            chain: String,
            name: String,
            url: String,
            tokenURL: String?
        ) {
            self.chain = chain
            self.name = name
            self.url = url
            self.tokenURL = tokenURL
        }

        enum CodingKeys: String, CodingKey {
            case chain
            case name
            case url
            case tokenURL = "token_url"
        }
    }

    public struct Flags: Codable, Equatable {
        public let isSwapDisable: Bool
        public let stakingDisabled: Bool
        public let tronDisabled: Bool
        public let trxOnlyRegion: Bool
        public let batteryDisabled: Bool
        public let gaslessDisabled: Bool
        public let usdeDisabled: Bool
        public let exchangeMethodsDisabled: Bool
        public let dappsDisabled: Bool
        public let storiesDisabled: Bool
        public let onboardingStoryDisabled: Bool
        public let nftsDisabled: Bool
        public let nativeSwapDisabled: Bool
    }
}

extension BootConfiguration {
    /// Used until the boot configuration answers, and whenever it answers without a realtime host.
    static let defaultMultichainRealtimeURL = URL(string: "wss://rt.tonkeeper.com/connection/websocket")!

    static var empty: BootConfiguration {
        BootConfiguration(
            tonapiV2Endpoint: "",
            tonapiTestnetHost: "",
            tonAPISSEEndpointV2: nil,
            batteryHost: "",
            tonApiV2Key: "",
            tonConnectBridge: "",
            mercuryoSecret: nil,
            supportLink: nil,
            directSupportUrl: nil,
            tonkeeperNewsUrl: nil,
            stonfiUrl: nil,
            webSwapsUrl: nil,
            faqUrl: nil,
            stakingInfoUrl: nil,
            isBatteryBeta: true,
            accountExplorer: nil,
            transactionExplorer: nil,
            nftOnExplorerUrl: nil,
            batteryMeanFees: nil,
            batteryReservedAmount: nil,
            batteryMeanPriceSwap: nil,
            batteryMeanPriceJetton: nil,
            batteryMeanPriceNFT: nil,
            batteryMeanPriceTRCMin: nil,
            batteryMeanPriceTRCMax: nil,
            batteryMaxInputAmount: nil,
            batteryRefundEndpoint: nil,
            disableBattery: false,
            disableBatterySend: false,
            disableBatteryCryptoRechargeModule: true,
            scamApiURL: nil,
            flags: .default,
            stories: [],
            reportAmount: nil,
            stakingEnabledProviders: [],
            qrScannerExtensions: nil,
            region: nil,
            tronApiUrl: nil,
            tronSwapUrl: "https://widget.letsexchange.io/en?affiliate_id=ffzymmunvvyxyypo&coin_from=ton&coin_to=USDT-TRC20&is_iframe=true",
            tronSwapTitle: "LetsExchange",
            tonkeeperApiUrl: nil,
            aptabaseEndpoint: nil,
            multichainHelpUrl: URL(string: "https://tonkeeper.helpscoutdocs.com/article/137-multichain#Transfer-fees-for-USDT-TRC20-tHzDd"),
            multichain: Endpoint(
                domain: URL(string: "https://multi.tonkeeper.com")!,
                realtime: defaultMultichainRealtimeURL
            ),
            trading: Endpoint(domain: URL(string: "https://trading.tonkeeper.com")!, realtime: nil),
            explorers: []
        )
    }
}

extension BootConfiguration.Flags {
    static var `default`: BootConfiguration.Flags {
        BootConfiguration.Flags(
            isSwapDisable: true,
            stakingDisabled: true,
            tronDisabled: true,
            trxOnlyRegion: true,
            batteryDisabled: true,
            gaslessDisabled: true,
            usdeDisabled: true,
            exchangeMethodsDisabled: true,
            dappsDisabled: true,
            storiesDisabled: true,
            onboardingStoryDisabled: true,
            nftsDisabled: true,
            nativeSwapDisabled: true
        )
    }
}
