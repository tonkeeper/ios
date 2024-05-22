import Foundation

final class TonkeeperAPIAssembly {
  
  var api: TonkeeperAPI {
    TonkeeperAPIImplementation(
      urlSession: .shared,
      host: apiV1URL,
      bootHost: bootApiURL
    )
  }
  
  var apiV1URL: URL {
    URL(string: "https://api.tonkeeper.com")!
  }
  
  var bootApiURL: URL {
    URL(string: "https://boot.tonkeeper.com")!
  }
}

