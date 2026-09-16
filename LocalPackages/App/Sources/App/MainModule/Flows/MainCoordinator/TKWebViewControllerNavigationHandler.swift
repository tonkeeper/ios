import Foundation
import KeeperCore
import TKScreenKit

struct TKWebViewControllerNavigationHandler: TKScreenKit.TKWebViewControllerNavigationHandler {
    private let deeplinkParser: DeeplinkParser
    private let openDeeplinkHandler: (Deeplink) -> Void

    init(
        deeplinkParser: DeeplinkParser,
        openDeeplinkHandler: @escaping (Deeplink) -> Void
    ) {
        self.deeplinkParser = deeplinkParser
        self.openDeeplinkHandler = openDeeplinkHandler
    }

    func handlerURLOpen(_ url: URL) -> TKScreenKit.TKWebViewControllerNavigationHandlerResult {
        do {
            let deeplink = try deeplinkParser.parse(
                string: url.absoluteString,
                source: .browser
            )
            openDeeplinkHandler(deeplink)
            return .notOpen
        } catch let error where error.isSilent {
            return .notOpen
        } catch {
            return .open
        }
    }
}
