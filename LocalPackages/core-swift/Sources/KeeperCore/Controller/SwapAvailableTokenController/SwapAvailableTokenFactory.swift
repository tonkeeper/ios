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
      ),
      try? .init(
        address: "0:2f956143c461769579baef2e32cc2d7bc18283f40d20bb03e432cd603ac33ffc",
        fractionDigits: 9,
        name: "Notcoin",
        symbol: "NOT",
        image: "https://cache.tonapi.io/imgproxy/4KCMNm34jZLXt0rqeFm4rH-BK4FoK76EVX9r0cCIGDg/rs:fill:200:200:1/g:no/aHR0cHM6Ly9jZG4uam9pbmNvbW11bml0eS54eXovY2xpY2tlci9ub3RfbG9nby5wbmc.webp"
      ),
      try? .init(
        address: "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
        fractionDigits: 6,
        name: "Tether USD",
        symbol: "USD₮",
        image: "https://cache.tonapi.io/imgproxy/T3PB4s7oprNVaJkwqbGg54nexKE0zzKhcrPv8jcWYzU/rs:fill:200:200:1/g:no/aHR0cHM6Ly90ZXRoZXIudG8vaW1hZ2VzL2xvZ29DaXJjbGUucG5n.webp"
      ),
      try? .init(
        address: "0:effb2af8d7f099daeae0da07de8157dae383c33e320af45f8c8a510328350886",
        fractionDigits: 9,
        name: "ANON",
        symbol: "ANON",
        image: "https://cache.tonapi.io/imgproxy/3nkA_bafJ5kaFjWLLfiCc2TZ5vVZYeqzu4dtNwdKkCs/rs:fill:200:200:1/g:no/aHR0cHM6Ly9pLmliYi5jby8wTVpnODd6L0lNRy04Mzk5LnBuZw.webp"
      ),
      try? .init(
        address: "0:9da73e90849b43b66dacf7e92b576ca0978e4fc25f8a249095d7e5eb3fe5eebb",
        fractionDigits: 9,
        name: "$PUNK",
        symbol: "PUNK",
        image: "https://cache.tonapi.io/imgproxy/mehFYlb1uDc1wa0RaKBQPCAKxBBiPcwIHHXd0-u4Ejo/rs:fill:200:200:1/g:no/aHR0cHM6Ly9wdW5rLW1ldGF2ZXJzZS5mcmExLmRpZ2l0YWxvY2VhbnNwYWNlcy5jb20vbG9nby9wdW5rLnBuZw.webp"
      ),
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
