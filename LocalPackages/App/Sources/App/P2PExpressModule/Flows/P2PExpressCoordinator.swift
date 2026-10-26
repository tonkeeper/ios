import KeeperCore
import TKCoordinator
import TKUIKit
import UIKit

@MainActor
final class P2PExpressCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didTapOpen: ((_ url: URL, _ expirationDate: Date) -> Void)?
    var didFailToCreateSession: ((Error) -> Void)?

    private let params: P2PExpressParams
    private let onRampService: OnRampService

    init(
        params: P2PExpressParams,
        router: ViewControllerRouter,
        onRampService: OnRampService
    ) {
        self.params = params
        self.onRampService = onRampService
        super.init(router: router)
    }

    override func start() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                ToastPresenter.hideAll()
            }

            ToastPresenter.hideAll()
            ToastPresenter.showToast(configuration: .loading)
            do {
                let p2pSession = try await onRampService.createP2PSession(
                    data: params.createP2PSession
                )
                guard
                    let url = URL(string: p2pSession.deeplinkUrl),
                    let expirationDate = parseExpirationDate(p2pSession.dateExpire)
                else {
                    throw P2PExpressCoordinatorError.incorrectSessionData
                }
                didTapOpen?(url, expirationDate)
            } catch {
                didFailToCreateSession?(error)
            }
            didFinish?(self)
        }
    }
}

private extension P2PExpressCoordinator {
    enum P2PExpressCoordinatorError: Error {
        case incorrectSessionData
    }

    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601DateFormatterWithFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func parseExpirationDate(_ value: String) -> Date? {
        if let date = Self.iso8601DateFormatterWithFractions.date(from: value) {
            return date
        }
        if let date = Self.iso8601DateFormatter.date(from: value) {
            return date
        }
        return nil
    }
}
