import Foundation
import KeeperCore
import TKScreenKit

struct TKWebViewControllerNavigationHandler: TKScreenKit.TKWebViewControllerNavigationHandler {
    private let openDeeplinkHandler: (Deeplink) -> Void

    init(openDeeplinkHandler: @escaping (Deeplink) -> Void) {
        self.openDeeplinkHandler = openDeeplinkHandler
    }

    func handlerURLOpen(_ url: URL) -> TKScreenKit.TKWebViewControllerNavigationHandlerResult {
        let deeplinkParser = DeeplinkParser()
        do {
            let deeplink = try deeplinkParser.parse(string: url.absoluteString)
            openDeeplinkHandler(deeplink)
            return .notOpen
        } catch {
            return .open
        }
    }
}
