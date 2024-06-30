import Foundation
import TonSwift
import BigInt

public struct Balance: Codable, Equatable {
  public let tonBalance: TonBalance
  public let jettonsBalance: [JettonBalance]
  
  public init(tonBalance: TonBalance,
              jettonsBalance: [JettonBalance]) {
    self.tonBalance = tonBalance
    self.jettonsBalance = jettonsBalance
  }
}

public extension Balance {
  var isEmpty: Bool {
    tonBalance.amount == 0 && jettonsBalance.isEmpty
  }
}

public struct TonBalance: Codable, Equatable {
  public let amount: Int64
  
  public init(amount: Int64) {
    self.amount = amount
  }
}

public struct JettonBalance: Codable, Equatable {
  public let item: JettonItem
  public let quantity: BigUInt
  public let rates: [Currency: Rates.Rate]
  
  public init(item: JettonItem, 
              quantity: BigUInt,
              rates: [Currency : Rates.Rate]) {
    self.item = item
    self.quantity = quantity
    self.rates = rates
  }
}

public struct JettonItem: Codable, Equatable, Hashable {
  public let jettonInfo: JettonInfo
  public let walletAddress: Address
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
}

public extension JettonInfo {
  var isTonUSDT: Bool {
    do {
      return try self.address == Address.parse("0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe")
    } catch {
      return false
    }
  }
}
