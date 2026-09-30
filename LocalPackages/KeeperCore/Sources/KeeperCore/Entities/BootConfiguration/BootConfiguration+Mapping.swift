import Foundation
import TKFeatureFlags

extension BootConfiguration {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let empty = BootConfiguration.empty

        tonapiV2Endpoint = (try? container.decode(String.self, forKey: .tonapiV2Endpoint)) ?? empty.tonapiV2Endpoint
        tonapiTestnetHost = (try? container.decode(String.self, forKey: .tonapiTestnetHost)) ?? empty.tonapiTestnetHost
        tonAPISSEEndpointV2 = try? container.decodeIfPresent(String.self, forKey: .tonAPISSEEndpointV2)
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
        aptabaseEndpoint = try? container.decodeIfPresent(String.self, forKey: .aptabaseEndpoint)
        multichainHelpUrl = try? container.decodeIfPresent(URL.self, forKey: .multichainHelpUrl) ?? empty.multichainHelpUrl
        multichain = (try? container.decode(Endpoint.self, forKey: .multichain)) ?? empty.multichain
        trading = (try? container.decode(Endpoint.self, forKey: .trading)) ?? empty.trading
        explorers = (try? container.decode([ChainExplorer].self, forKey: .explorers)) ?? empty.explorers
    }

    enum CodingKeys: String, CodingKey {
        case tonapiV2Endpoint
        case tonapiTestnetHost
        case tonAPISSEEndpointV2 = "tonapi_sse_endpoint_v2"
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
        case aptabaseEndpoint = "aptabase_endpoint"
        case multichainHelpUrl = "multichain_help_url"
        case multichain
        case trading
        case explorers
    }
}

extension BootConfiguration.Flags {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = BootConfiguration.Flags.default
        let overrides = StaticFlagOverrides.shared?.bootConfigurationFlags ?? [:]

        func value(_ key: CodingKeys, default fallback: Bool) -> Bool {
            if let override = overrides[key.rawValue] {
                return override
            }
            return (try? container.decode(Bool.self, forKey: key)) ?? fallback
        }

        isSwapDisable = value(.isSwapDisable, default: defaults.isSwapDisable)
        stakingDisabled = value(.stakingDisabled, default: defaults.stakingDisabled)
        tronDisabled = value(.tronDisabled, default: defaults.tronDisabled)
        batteryDisabled = value(.batteryDisabled, default: defaults.batteryDisabled)
        gaslessDisabled = value(.gaslessDisabled, default: defaults.gaslessDisabled)
        usdeDisabled = value(.usdeDisabled, default: defaults.usdeDisabled)
        exchangeMethodsDisabled = value(.exchangeMethodsDisabled, default: defaults.exchangeMethodsDisabled)
        dappsDisabled = value(.dappsDisabled, default: defaults.dappsDisabled)
        storiesDisabled = value(.storiesDisabled, default: defaults.storiesDisabled)
        onboardingStoryDisabled = value(.onboardingStoryDisabled, default: defaults.onboardingStoryDisabled)
        nftsDisabled = value(.nftsDisabled, default: defaults.nftsDisabled)
        nativeSwapDisabled = value(.nativeSwapDisabled, default: defaults.nativeSwapDisabled)
        trxOnlyRegion = value(.trxOnlyRegion, default: defaults.trxOnlyRegion)
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
    }
}
