import Foundation
import KeeperCore
import TKScreenKit

struct TKWebViewControllerNavigationHandler: TKScreenKit.TKWebViewControllerNavigationHandler {
    private let deeplinkParser: DeeplinkParser
    private let openDeeplinkHandler: (_ deeplink: Deeplink, _ utm: UtmParameters) -> Void

    init(
        deeplinkParser: DeeplinkParser,
        openDeeplinkHandler: @escaping (_ deeplink: Deeplink, _ utm: UtmParameters) -> Void
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
            openDeeplinkHandler(deeplink, UtmParameters(link: url.absoluteString))
            return .notOpen
        } catch let error where error.isSilent {
            return .notOpen
        } catch {
            return .open
        }
    }
}
