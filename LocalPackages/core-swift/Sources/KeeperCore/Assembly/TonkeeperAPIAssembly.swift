import Foundation

final class TonkeeperAPIAssembly {
  
  var api: TonkeeperAPI {
    TonkeeperAPIImplementation(
      urlSession: .shared,
      host: apiV1URL
    )
  }
  
  var apiV1URL: URL {
    URL(string: "https://api.tonkeeper.com")!
  }
}

