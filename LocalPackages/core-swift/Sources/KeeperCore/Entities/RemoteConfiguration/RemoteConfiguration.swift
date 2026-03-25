import Foundation

public struct RemoteConfigurations: Codable {
    @usableFromInline
    let mainnet: RemoteConfiguration
    @usableFromInline
    let testnet: RemoteConfiguration
    @usableFromInline
    let tetra: RemoteConfiguration
}

public struct RemoteConfiguration: Codable, Equatable {
    public let tonapiV2Endpoint: String
    public let tonapiTestnetHost: String
    public let tonAPISSEEndpoint: String
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
    public let multichainHelpUrl: URL?

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
        public let walletKitDisabled: Bool
    }
}

extension RemoteConfiguration {
    static var empty: RemoteConfiguration {
        RemoteConfiguration(
            tonapiV2Endpoint: "",
            tonapiTestnetHost: "",
            tonAPISSEEndpoint: "",
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
            multichainHelpUrl: URL(string: "https://tonkeeper.helpscoutdocs.com/article/137-multichain#Transfer-fees-for-USDT-TRC20-tHzDd")
        )
    }
}

extension RemoteConfiguration.Flags {
    static var `default`: RemoteConfiguration.Flags {
        RemoteConfiguration.Flags(
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
            nativeSwapDisabled: true,
            walletKitDisabled: false
        )
    }
}
