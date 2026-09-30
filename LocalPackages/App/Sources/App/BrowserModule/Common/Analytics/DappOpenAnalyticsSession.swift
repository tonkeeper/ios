import TKCore

enum DappOpenAnalyticsSessionState {
    case initial
    case loaded
}

final class DappOpenAnalyticsSession {
    let context: DappOpenAnalyticsContext

    private let analyticsProvider: AnalyticsProvider
    private var state: DappOpenAnalyticsSessionState

    init(
        context: DappOpenAnalyticsContext,
        analyticsProvider: AnalyticsProvider
    ) {
        self.context = context
        self.analyticsProvider = analyticsProvider
        self.state = .initial
    }
}

extension DappOpenAnalyticsSession {
    func logClick() {
        analyticsProvider.log(
            DappAppClick(
                from: context.from,
                url: context.urlDomain,
                assetChain: context.assetChain,
                appId: context.appId,
                bannerId: context.bannerId,
                location: context.location
            ),
            utm: context.utm
        )
    }

    func logLoaded() {
        guard case .initial = state else {
            return
        }
        analyticsProvider.log(
            DappAppLoaded(
                from: context.from,
                url: context.urlDomain,
                assetChain: context.assetChain,
                appId: context.appId,
                bannerId: context.bannerId,
                location: context.location
            ),
            utm: context.utm
        )
        state = .loaded
    }

    func logSharingCopy(from: DappSharingCopy.From) {
        analyticsProvider.log(
            DappSharingCopy(
                url: context.urlDomain,
                assetChain: context.assetChain,
                from: from,
                location: context.location
            ),
            utm: context.utm
        )
    }
}
