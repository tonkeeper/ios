import Foundation

public final class SignerScanController {
  
  private let deeplinkGenerator: DeeplinkGenerator
  
  init(deeplinkGenerator: DeeplinkGenerator) {
    self.deeplinkGenerator = deeplinkGenerator
  }
  
  public func createOpenSignerUrl() -> URL? {
    URL(string: deeplinkGenerator.generateTonSignOpenDeeplink().string)
  }
}
