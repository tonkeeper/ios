import Foundation

public struct RemoteConfigurations: Codable {
  let mainnet: RemoteConfiguration
  let testnet: RemoteConfiguration
}

public struct RemoteConfiguration: Equatable {
  
  public var batteryMeanFeesDecimaNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: batteryMeanFees)
  }
  
  public var batteryReservedAmountDecimalNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: batteryReservedAmount)
  }
  
  public var batteryMeanFeesPriceSwapDecimaNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: batteryMeanPriceSwap)
  }
  
  public var batteryMeanFeesPriceJettonDecimaNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: batteryMeanPriceJetton)
  }
  
  public var batteryMeanFeesPriceNFTDecimaNumber: NSDecimalNumber? {
    NSDecimalNumber.number(stringValue: batteryMeanPriceNFT)
  }
  
  public var batteryMaxInputAmountDecimaNumber: NSDecimalNumber {
    NSDecimalNumber.number(stringValue: batteryMaxInputAmount) ?? 3
  }

  public let tonapiV2Endpoint: String
  public let tonapiTestnetHost: String
  public let tonAPISSEEndpoint: String
  public let batteryHost: String
  public let tonApiV2Key: String
  public let mercuryoSecret: String?
  public let supportLink: URL?
  public let directSupportUrl: URL?
  public let tonkeeperNewsUrl: URL?
  public let stonfiUrl: URL?
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
  public let batteryMaxInputAmount: String?
  public let batteryRefundEndpoint: URL?
  public let disableBattery: Bool
  public let disableBatterySend: Bool
  public let flags: Flags
  
  enum CodingKeys: String, CodingKey {
    case tonapiV2Endpoint
    case tonapiTestnetHost
    case tonAPISSEEndpoint = "tonapi_sse_endpoint"
    case batteryHost
    case tonApiV2Key
    case mercuryoSecret
    case supportLink
    case directSupportUrl
    case tonkeeperNewsUrl
    case stonfiUrl
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
    case batteryMaxInputAmount
    case batteryRefundEndpoint
    case disableBattery = "disable_battery"
    case disableBatterySend = "disable_battery_send"
  }
}

public extension RemoteConfiguration {
  struct Flags: Codable, Equatable {
    public let isSwapDisable: Bool
    public let isExchangeMethodsDisable: Bool
    public let isDappsDisable: Bool
    
    static var `default`: Flags {
      Flags(
        isSwapDisable: true,
        isExchangeMethodsDisable: true,
        isDappsDisable: true
      )
    }
    
    enum CodingKeys: String, CodingKey {
      case isSwapDisable = "disable_swap"
      case isExchangeMethodsDisable = "disable_exchange_methods"
      case isDappsDisable = "disable_dapps"
    }
  }
}

extension RemoteConfiguration: Codable {}

extension RemoteConfiguration {
  static var empty: RemoteConfiguration {
    RemoteConfiguration(
      tonapiV2Endpoint: "",
      tonapiTestnetHost: "",
      tonAPISSEEndpoint: "",
      batteryHost: "",
      tonApiV2Key: "",
      mercuryoSecret: nil,
      supportLink: nil,
      directSupportUrl: nil,
      tonkeeperNewsUrl: nil,
      stonfiUrl: nil,
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
      batteryMaxInputAmount: nil,
      batteryRefundEndpoint: nil,
      disableBattery: false,
      disableBatterySend: false,
      flags: .default
    )
  }
}

public extension NSDecimalNumber {
  static func number(stringValue: String?) -> NSDecimalNumber? {
    let number = NSDecimalNumber(string: stringValue)
    guard number != NSDecimalNumber.notANumber else {
      return nil
    }
    return number
  }
}
