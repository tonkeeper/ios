import KeeperCore
import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

@MainActor
final class P2PExpressCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didTapOpen: ((_ url: URL, _ expirationDate: Date) -> Void)?
    var didFailToCreateSession: ((Error) -> Void)?

    private let params: P2PExpressParams
    private let onRampService: OnRampService
    private let doNotShowAgainStore: P2PExpressDoNotShowAgainStore

    init(
        params: P2PExpressParams,
        router: ViewControllerRouter,
        onRampService: OnRampService,
        doNotShowAgainStore: P2PExpressDoNotShowAgainStore
    ) {
        self.params = params
        self.onRampService = onRampService
        self.doNotShowAgainStore = doNotShowAgainStore
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
                let merchants = try? await onRampService.getMerchants(walletId: params.walletId)
                let merchant = merchants?.first(where: { $0.isP2P })
                guard
                    let url = URL(string: p2pSession.deeplinkUrl),
                    let expirationDate = parseExpirationDate(p2pSession.dateExpire)
                else {
                    throw P2PExpressCoordinatorError.incorrectSessionData
                }
                openP2PExpressPopup(url: url, expirationDate: expirationDate, merchant: merchant)
            } catch {
                didFailToCreateSession?(error)
                didFinish?(self)
            }
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

    private func openP2PExpressPopup(url: URL, expirationDate: Date, merchant: OnRampMerchantInfo?) {
        guard !doNotShowAgainStore.doNotShowAgain else {
            didTapOpen?(url, expirationDate)
            return
        }

        var isDoNotShowAgain = doNotShowAgainStore.doNotShowAgain

        let popupViewController = TKPopUp.ViewController()
        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: popupViewController
        )

        popupViewController.configuration = makeConfiguration(
            isDoNotShowAgain: isDoNotShowAgain,
            merchant: merchant,
            didTapOpen: { [weak self, weak bottomSheetViewController] in
                guard let self else { return }

                self.doNotShowAgainStore.doNotShowAgain = isDoNotShowAgain
                self.didTapOpen?(url, expirationDate)
                bottomSheetViewController?.dismiss { [weak self] in
                    guard let self else { return }
                    self.didFinish?(self)
                }
            },
            didUpdateDoNotShowAgain: { newValue in
                isDoNotShowAgain = newValue
            }
        )
        popupViewController.headerConfiguration = .popup

        bottomSheetViewController.didClose = { [weak self] _ in
            guard let self else { return }
            self.didFinish?(self)
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    private func parseExpirationDate(_ value: String) -> Date? {
        if let date = Self.iso8601DateFormatterWithFractions.date(from: value) {
            return date
        }
        if let date = Self.iso8601DateFormatter.date(from: value) {
            return date
        }
        return nil
    }

    private func makeConfiguration(
        isDoNotShowAgain: Bool,
        merchant: OnRampMerchantInfo?,
        didTapOpen: @escaping () -> Void,
        didUpdateDoNotShowAgain: @escaping (Bool) -> Void
    ) -> TKPopUp.Configuration {
        var openButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        openButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Actions.open)
        )
        openButtonConfiguration.action = didTapOpen

        let imageItem: TKPopUp.Item = if
            let merchant,
            let iconURL = URL(string: merchant.image)
        {
            ExternalAppHeaderIconItem(bottomSpace: 20, imageURL: iconURL)
        } else {
            ExternalAppHeaderIconItem(bottomSpace: 20, image: .TKUIKit.Icons.Size72.serviceWallet)
        }

        return TKPopUp.Configuration(
            items: [
                imageItem,
                TKPopUp.Component.TitleCaption(
                    title: merchant?.title ?? TKLocales.P2pExpressPopup.title,
                    caption: merchant?.description ?? TKLocales.P2pExpressPopup.caption,
                    bottomSpace: 16
                ),
                TKPopUp.Component.GroupComponent(
                    padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
                    items: [
                        OpenDappWarningBannerItem(
                            configuration: OpenDappWarningBannerView.Model(
                                text: TKLocales.BuyListPopup.youAreOpeningExternalApp
                            ),
                            bottomSpace: 0
                        ),
                    ],
                    bottomSpace: 0
                ),
                TKPopUp.Component.ButtonGroupComponent(
                    buttons: [
                        TKPopUp.Component.ButtonComponent(buttonConfiguration: openButtonConfiguration),
                    ],
                    bottomSpace: 10
                ),
                TKPopUp.Component.TickItem(
                    model: TKDetailsTickView.Model(
                        text: TKLocales.Tick.doNotShowAgain,
                        tick: TKDetailsTickView.Model.Tick(
                            isSelected: isDoNotShowAgain,
                            closure: { didUpdateDoNotShowAgain($0) }
                        )
                    ),
                    bottomSpace: 13
                ),
            ]
        )
    }
}
