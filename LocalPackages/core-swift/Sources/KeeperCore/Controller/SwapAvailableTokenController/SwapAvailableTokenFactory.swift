import Foundation
import TonSwift

enum SwapAvailableTokenFactory {

  static func make() -> [Token?] {
    return [
      try? .init(
        address: "0:729c13b6df2c07cbf0a06ab63d34af454f3d320ec1bcd8fb5c6d24d0806a17c2",
        fractionDigits: 6,
        name: "jUSDT",
        symbol: "jUSDT",
        image: "https://cache.tonapi.io/imgproxy/CwB_AmfxXaRx6D2SB22UgGJJu-P49hbxhjTnxv5Ruek/rs:fill:200:200:1/g:no/aHR0cHM6Ly9icmlkZ2UudG9uLm9yZy90b2tlbi8xLzB4ZGFjMTdmOTU4ZDJlZTUyM2EyMjA2MjA2OTk0NTk3YzEzZDgzMWVjNy5wbmc.webp"
      )
    ]
  }
}

private extension Token {
  init(address: String, fractionDigits: Int, name: String, symbol: String?, image: String?) throws {
    let address = try Address.parse(raw: address)
    self = .jetton(
      .init(
        jettonInfo:
            .init(
              address: address,
              fractionDigits: fractionDigits,
              name: name,
              symbol: symbol,
              verification: .whitelist,
              imageURL: image != nil ? URL(string: image!) : nil),
        walletAddress: address
      )
    )
  }
}
