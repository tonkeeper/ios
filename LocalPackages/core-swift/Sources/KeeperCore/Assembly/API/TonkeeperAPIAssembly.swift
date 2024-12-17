import Foundation

public final class TonkeeperAPIAssembly {
  
  private let appInfoProvider: AppInfoProvider
  
  init(appInfoProvider: AppInfoProvider) {
    self.appInfoProvider = appInfoProvider
  }
  
  public var api: TonkeeperAPI {
    TonkeeperAPIImplementation(
      urlSession: .shared,
      host: apiV1URL,
      appInfoProvider: appInfoProvider
    )
  }
  
  var apiV1URL: URL {
    URL(string: "https://api.tonkeeper.com")!
  }
}

