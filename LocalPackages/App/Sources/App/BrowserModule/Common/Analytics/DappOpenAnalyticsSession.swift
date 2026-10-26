import Foundation
import TKCore

enum DappOpenAnalyticsSessionState {
    case initial
    case loaded
    case failed
}

final class DappOpenAnalyticsSession {
    let context: DappOpenAnalyticsContext

    private let analyticsProvider: AnalyticsProvider
    private let now: () -> Date
    private var state: DappOpenAnalyticsSessionState
    private var clickDate: Date

    init(
        context: DappOpenAnalyticsContext,
        analyticsProvider: AnalyticsProvider,
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.analyticsProvider = analyticsProvider
        self.now = now
        self.state = .initial
        self.clickDate = now()
    }
}

extension DappOpenAnalyticsSession {
    func logClick() {
        clickDate = now()
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
                location: context.location,
                loadDurationMs: millisecondsSinceClick()
            ),
            utm: context.utm
        )
        state = .loaded
    }

    func logLoadFailed(errorCode: String, httpStatus: Int?) {
        guard case .initial = state else {
            return
        }
        analyticsProvider.log(
            DappAppLoadFailed(
                from: context.from,
                url: context.urlDomain,
                assetChain: context.assetChain,
                appId: context.appId,
                bannerId: context.bannerId,
                location: context.location,
                errorCode: errorCode,
                httpStatus: httpStatus,
                loadDurationMs: millisecondsSinceClick()
            ),
            utm: context.utm
        )
        state = .failed
    }

    func millisecondsSinceClick() -> Int64 {
        Int64((now().timeIntervalSince(clickDate) * 1000).rounded())
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
