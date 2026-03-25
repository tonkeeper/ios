import Foundation

extension RemoteConfiguration {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let empty = RemoteConfiguration.empty

        tonapiV2Endpoint = (try? container.decode(String.self, forKey: .tonapiV2Endpoint)) ?? empty.tonapiV2Endpoint
        tonapiTestnetHost = (try? container.decode(String.self, forKey: .tonapiTestnetHost)) ?? empty.tonapiTestnetHost
        tonAPISSEEndpoint = (try? container.decode(String.self, forKey: .tonAPISSEEndpoint)) ?? empty.tonAPISSEEndpoint
        batteryHost = (try? container.decode(String.self, forKey: .batteryHost)) ?? empty.batteryHost
        tonApiV2Key = (try? container.decode(String.self, forKey: .tonApiV2Key)) ?? empty.tonApiV2Key
        tonConnectBridge = (try? container.decode(String.self, forKey: .tonConnectBridge)) ?? empty.tonConnectBridge
        mercuryoSecret = try? container.decodeIfPresent(String.self, forKey: .mercuryoSecret)
        supportLink = try? container.decodeIfPresent(URL.self, forKey: .supportLink)
        directSupportUrl = try? container.decodeIfPresent(URL.self, forKey: .directSupportUrl)
        tonkeeperNewsUrl = try? container.decodeIfPresent(URL.self, forKey: .tonkeeperNewsUrl)
        stonfiUrl = try? container.decodeIfPresent(URL.self, forKey: .stonfiUrl)
        webSwapsUrl = try? container.decodeIfPresent(URL.self, forKey: .webSwapsUrl)
        faqUrl = try? container.decodeIfPresent(URL.self, forKey: .faqUrl)
        stakingInfoUrl = try? container.decodeIfPresent(URL.self, forKey: .stakingInfoUrl)
        isBatteryBeta = (try? container.decode(Bool.self, forKey: .isBatteryBeta)) ?? empty.isBatteryBeta
        accountExplorer = try? container.decodeIfPresent(String.self, forKey: .accountExplorer)
        transactionExplorer = try? container.decodeIfPresent(String.self, forKey: .transactionExplorer)
        nftOnExplorerUrl = try? container.decodeIfPresent(String.self, forKey: .nftOnExplorerUrl)
        batteryMeanFees = try? container.decodeIfPresent(String.self, forKey: .batteryMeanFees)
        batteryReservedAmount = try? container.decodeIfPresent(String.self, forKey: .batteryReservedAmount)
        batteryMeanPriceSwap = try? container.decodeIfPresent(String.self, forKey: .batteryMeanPriceSwap)
        batteryMeanPriceJetton = try? container.decodeIfPresent(String.self, forKey: .batteryMeanPriceJetton)
        batteryMeanPriceNFT = try? container.decodeIfPresent(String.self, forKey: .batteryMeanPriceNFT)
        batteryMeanPriceTRCMin = try? container.decodeIfPresent(String.self, forKey: .batteryMeanPriceTRCMin)
        batteryMeanPriceTRCMax = try? container.decodeIfPresent(String.self, forKey: .batteryMeanPriceTRCMax)
        batteryMaxInputAmount = try? container.decodeIfPresent(String.self, forKey: .batteryMaxInputAmount)
        batteryRefundEndpoint = try? container.decodeIfPresent(URL.self, forKey: .batteryRefundEndpoint)
        disableBattery = (try? container.decode(Bool.self, forKey: .disableBattery)) ?? empty.disableBattery
        disableBatterySend = (try? container.decode(Bool.self, forKey: .disableBatterySend)) ?? empty.disableBatterySend
        disableBatteryCryptoRechargeModule = (try? container.decode(Bool.self, forKey: .disableBatteryCryptoRechargeModule)) ?? empty.disableBatteryCryptoRechargeModule
        scamApiURL = try? container.decodeIfPresent(URL.self, forKey: .scamApiURL)
        flags = (try? container.decode(Flags.self, forKey: .flags)) ?? empty.flags
        stories = try? container.decodeIfPresent([String].self, forKey: .stories)
        reportAmount = try? container.decodeIfPresent(String.self, forKey: .reportAmount)
        stakingEnabledProviders = (try? container.decode(Set<String>.self, forKey: .stakingEnabledProviders)) ?? empty.stakingEnabledProviders
        qrScannerExtensions = try? container.decodeIfPresent([QRScannerExtension].self, forKey: .qrScannerExtensions)
        region = try? container.decodeIfPresent(String.self, forKey: .region)
        tronApiUrl = try? container.decodeIfPresent(String.self, forKey: .tronApiUrl)
        tronSwapUrl = (try? container.decode(String.self, forKey: .tronSwapUrl)) ?? empty.tronSwapUrl
        tronSwapTitle = (try? container.decode(String.self, forKey: .tronSwapTitle)) ?? empty.tronSwapTitle
        tonkeeperApiUrl = try? container.decodeIfPresent(String.self, forKey: .tonkeeperApiUrl)
        multichainHelpUrl = try? container.decodeIfPresent(URL.self, forKey: .multichainHelpUrl) ?? empty.multichainHelpUrl
    }

    enum CodingKeys: String, CodingKey {
        case tonapiV2Endpoint
        case tonapiTestnetHost
        case tonAPISSEEndpoint = "tonapi_sse_endpoint"
        case batteryHost
        case tonApiV2Key
        case tonConnectBridge = "ton_connect_bridge"
        case mercuryoSecret
        case supportLink
        case directSupportUrl
        case tonkeeperNewsUrl
        case stonfiUrl
        case webSwapsUrl = "web_swaps_url"
        case faqUrl = "faq_url"
        case stakingInfoUrl
        case isBatteryBeta = "battery_beta"
        case flags
        case accountExplorer
        case transactionExplorer
        case nftOnExplorerUrl = "NFTOnExplorerUrl"
        case batteryMeanFees
        case batteryReservedAmount
        case batteryMeanPriceSwap = "batteryMeanPrice_swap"
        case batteryMeanPriceJetton = "batteryMeanPrice_jetton"
        case batteryMeanPriceNFT = "batteryMeanPrice_nft"
        case batteryMeanPriceTRCMin = "batteryMeanPrice_trc20_min"
        case batteryMeanPriceTRCMax = "batteryMeanPrice_trc20_max"
        case batteryMaxInputAmount
        case batteryRefundEndpoint
        case disableBattery = "disable_battery"
        case disableBatterySend = "disable_battery_send"
        case disableBatteryCryptoRechargeModule = "disable_battery_crypto_recharge_module"
        case scamApiURL = "scam_api_url"
        case stories
        case reportAmount
        case stakingEnabledProviders = "enabled_staking"
        case qrScannerExtensions = "qr_scanner_extends"
        case region
        case tronApiUrl = "tron_api_url"
        case tronSwapUrl = "tron_swap_url"
        case tronSwapTitle = "tron_swap_title"
        case tonkeeperApiUrl = "tonkeeper_api_url"
        case multichainHelpUrl = "multichain_help_url"
    }
}

extension RemoteConfiguration.Flags {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = RemoteConfiguration.Flags.default

        isSwapDisable = (try? container.decode(Bool.self, forKey: .isSwapDisable)) ?? defaults.isSwapDisable
        stakingDisabled = (try? container.decode(Bool.self, forKey: .stakingDisabled)) ?? defaults.stakingDisabled
        tronDisabled = (try? container.decode(Bool.self, forKey: .tronDisabled)) ?? defaults.tronDisabled
        batteryDisabled = (try? container.decode(Bool.self, forKey: .batteryDisabled)) ?? defaults.batteryDisabled
        gaslessDisabled = (try? container.decode(Bool.self, forKey: .gaslessDisabled)) ?? defaults.gaslessDisabled
        usdeDisabled = (try? container.decode(Bool.self, forKey: .usdeDisabled)) ?? defaults.usdeDisabled
        exchangeMethodsDisabled = (try? container.decode(Bool.self, forKey: .exchangeMethodsDisabled)) ?? defaults.exchangeMethodsDisabled
        dappsDisabled = (try? container.decode(Bool.self, forKey: .dappsDisabled)) ?? defaults.dappsDisabled
        storiesDisabled = (try? container.decode(Bool.self, forKey: .storiesDisabled)) ?? defaults.storiesDisabled
        onboardingStoryDisabled = (try? container.decode(Bool.self, forKey: .onboardingStoryDisabled)) ?? defaults.onboardingStoryDisabled
        nftsDisabled = (try? container.decode(Bool.self, forKey: .nftsDisabled)) ?? defaults.nftsDisabled
        nativeSwapDisabled = (try? container.decode(Bool.self, forKey: .nativeSwapDisabled)) ?? defaults.nativeSwapDisabled
        trxOnlyRegion = (try? container.decode(Bool.self, forKey: .trxOnlyRegion)) ?? defaults.trxOnlyRegion
        walletKitDisabled = (try? container.decode(Bool.self, forKey: .walletKitDisabled)) ?? defaults.walletKitDisabled
    }

    enum CodingKeys: String, CodingKey {
        case isSwapDisable = "disable_swap"
        case stakingDisabled = "disable_staking"
        case tronDisabled = "disable_tron"
        case trxOnlyRegion = "trx_only_region"
        case batteryDisabled = "disable_battery"
        case gaslessDisabled = "disable_gaseless"
        case usdeDisabled = "disable_usde"
        case exchangeMethodsDisabled = "disable_exchange_methods"
        case dappsDisabled = "disable_dapps"
        case storiesDisabled = "disable_stories"
        case onboardingStoryDisabled = "disable_onboarding_story"
        case nftsDisabled = "disable_nfts"
        case nativeSwapDisabled = "disable_native_swap"
        case walletKitDisabled = "disable_wallet_kit"
    }
}
