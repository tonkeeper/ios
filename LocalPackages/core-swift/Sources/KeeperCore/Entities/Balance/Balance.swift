import Foundation
import TonSwift
import BigInt

public struct Balance: Codable {
  public let tonBalance: TonBalance
  public let jettonsBalance: [JettonBalance]
}

public extension Balance {
  var isEmpty: Bool {
    tonBalance.amount == 0 && jettonsBalance.isEmpty
  }
}

public struct TonBalance: Codable {
  public let amount: Int64
}

public struct JettonBalance: Codable {
  public let item: JettonItem
  public let quantity: BigUInt
  public let rates: [Currency: Rates.Rate]
}

public struct JettonItem: Codable, Equatable {
  public let jettonInfo: JettonInfo
  public let walletAddress: Address

  public init(jettonInfo: JettonInfo, walletAddress: Address) {
      self.jettonInfo = jettonInfo
      self.walletAddress = walletAddress
  }
}

public struct TonInfo {
  public static let name = "Toncoin"
  public static let symbol = "TON"
  public static let fractionDigits = 9
  private init() {}
}

public struct JettonInfo: Codable, Equatable, Hashable {
  public enum Verification: Codable {
    case none
    case whitelist
    case blacklist
  }
  
  public let address: Address
  public let fractionDigits: Int
  public let name: String
  public let symbol: String?
  public let verification: Verification
  public let imageURL: URL?
  
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.address == rhs.address
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(address)
  }

  public init(address: Address, fractionDigits: Int, name: String, symbol: String?, verification: Verification, imageURL: URL?) {
      self.address = address
      self.fractionDigits = fractionDigits
      self.name = name
      self.symbol = symbol
      self.verification = verification
      self.imageURL = imageURL
  }
}
