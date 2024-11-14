import Foundation

final class ScamAPIAssembly {
  
  private let configurationAssembly: ConfigurationAssembly
  
  init(configurationAssembly: ConfigurationAssembly) {
    self.configurationAssembly = configurationAssembly
  }
  
  var api: ScamAPI {
    ScamAPIImplementation(
      urlSession: .shared,
      configuration: configurationAssembly.configuration
    )
  }
}

