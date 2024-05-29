//
//  StonFIApiModels.swift
//
//
//  Created by Marina on 27.05.2024.
//

import Foundation

struct StonFIAsset: Codable {
    let blacklisted: Bool
    let community: Bool
    let contractAddress: String
    let decimals: Int
    let defaultSymbol: Bool
    let deprecated: Bool
    let dexPriceUsd: String?
    let dexUsdPrice: String?
    let displayName: String
    let imageUrl: String?
    let kind: String
    let symbol: String
    let thirdPartyPriceUsd: String?
    let thirdPartyUsdPrice: String?

    enum CodingKeys: String, CodingKey {
        case blacklisted
        case community
        case contractAddress = "contract_address"
        case decimals
        case defaultSymbol = "default_symbol"
        case deprecated
        case dexPriceUsd = "dex_price_usd"
        case dexUsdPrice = "dex_usd_price"
        case displayName = "display_name"
        case imageUrl = "image_url"
        case kind
        case symbol
        case thirdPartyPriceUsd = "third_party_price_usd"
        case thirdPartyUsdPrice = "third_party_usd_price"
    }
}

struct StonFIAssetListResponse: Codable {
    let assetList: [StonFIAsset]

    enum CodingKeys: String, CodingKey {
        case assetList = "asset_list"
    }
}

struct StonFISwapRequest: Codable {
    let offerAddress: String
    let askAddress: String
    let units: String
    let slippageTolerance: String

    enum CodingKeys: String, CodingKey {
        case offerAddress = "offer_address"
        case askAddress = "ask_address"
        case units
        case slippageTolerance = "slippage_tolerance"
    }
}

struct StonFISwapSimulation: Codable {
    let offerAddress: String?
    let askAddress: String?
    let routerAddress: String?
    let poolAddress: String?
    let offerUnits: String?
    let askUnits: String?
    let slippageTolerance: String?
    let minAskUnits: String?
    let swapRate: String?
    let priceImpact: String?
    let feeAddress: String?
    let feeUnits: String?
    let feePercent: String?

    enum CodingKeys: String, CodingKey {
        case offerAddress = "offer_address"
        case askAddress = "ask_address"
        case routerAddress = "router_address"
        case poolAddress = "pool_address"
        case offerUnits = "offer_units"
        case askUnits = "ask_units"
        case slippageTolerance = "slippage_tolerance"
        case minAskUnits = "min_ask_units"
        case swapRate = "swap_rate"
        case priceImpact = "price_impact"
        case feeAddress = "fee_address"
        case feeUnits = "fee_units"
        case feePercent = "fee_percent"
    }
}
