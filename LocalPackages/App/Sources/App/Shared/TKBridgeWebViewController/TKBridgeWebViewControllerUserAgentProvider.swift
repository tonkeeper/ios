import TKScreenKit
import TKCore

struct TonkeeperBridgeWebViewControllerUserAgentProvider: TKBridgeWebViewControllerUserAgentProvider {
  func getUserAgent() -> String {
    "Tonkeeper iOS /\(InfoProvider.appVersion()) (Build \(InfoProvider.buildVersion()))"
  }
}
