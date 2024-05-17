import Foundation

public final class MainController {
  private let deeplinkParser: DeeplinkParser
  
  init(deeplinkParser: DeeplinkParser) {
    self.deeplinkParser = deeplinkParser
  }
  
  public func parseDeeplink(deeplink: String?) throws -> Deeplink {
    try deeplinkParser.parse(string: deeplink)
  }
  
}
