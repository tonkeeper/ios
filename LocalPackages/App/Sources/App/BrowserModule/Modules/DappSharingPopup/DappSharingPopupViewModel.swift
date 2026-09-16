import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

@MainActor
protocol DappSharingPopupModuleOutput: AnyObject {}

@MainActor
protocol DappSharingPopupViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
    var didTapShare: ((URL) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class DappSharingPopupViewModelImplementation: DappSharingPopupViewModel, DappSharingPopupModuleOutput {
    // MARK: - Dependencies

    private let dapp: Dapp
    private let url: URL
    private let analyticsSession: DappOpenAnalyticsSession?

    init(
        dapp: Dapp,
        url: URL,
        analyticsSession: DappOpenAnalyticsSession?
    ) {
        self.dapp = dapp
        self.url = url
        self.analyticsSession = analyticsSession
    }

    // MARK: - DappSharingPopupViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
    var didTapShare: ((URL) -> Void)?

    func viewDidLoad() {
        prepareContent()
    }

    private func prepareContent() {
        let copyAction = { [weak self, url] in
            Pasteboard.copy(value: url.absoluteString)
            self?.analyticsSession?.logSharingCopy(from: .copyLink)
        }

        var copyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        copyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Dapp.SharingPopup.Buttons.copy)
        )
        copyButtonConfiguration.action = copyAction

        var shareButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        shareButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Dapp.SharingPopup.Buttons.share)
        )
        shareButtonConfiguration.action = { [weak self, url] in
            self?.analyticsSession?.logSharingCopy(from: .share)
            self?.didTapShare?(url)
        }

        var imageViewModel: TKImageView.Model
        if let iconUrl = dapp.icon {
            imageViewModel = TKImageView.Model(
                image: .urlImage(iconUrl),
                size: .size(CGSize(width: 96, height: 96)),
                corners: .cornerRadius(cornerRadius: 16)
            )
        } else {
            imageViewModel = TKImageView.Model(
                image: .image(.TKUIKit.Icons.Size56.globe),
                tintColor: .Icon.secondary,
                size: .auto,
                corners: .cornerRadius(cornerRadius: 12)
            )
        }

        let configuration = TKPopUp.Configuration(
            items: [
                TransactionConfirmationHeaderImageItem(
                    configuration: TransactionConfirmationHeaderImageItemView.Configuration(
                        imageViewModel: imageViewModel,
                        backgroundColor: .Background.content,
                        badge: TransactionConfirmationHeaderImageItemView.Configuration.Badge(
                            image: .image(.TKUIKit.Icons.Size28.linkChainOutline),
                            backgroundColor: .Accent.blue,
                            size: .large
                        )
                    ),
                    bottomSpace: 20
                ),
                TKPopUp.Component.TitleCaption(
                    title: TKLocales.Dapp.SharingPopup.title(dapp.name),
                    caption: TKLocales.Dapp.SharingPopup.caption(dapp.name),
                    bottomSpace: 0
                ),
                TKPopUp.Component.GroupComponent(
                    padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
                    items: [
                        DappSharingURLButtonPopUpItem(
                            configuration: DappSharingURLButton.Configuration(
                                title: url.absoluteString
                            ),
                            action: {
                                copyAction()
                            },
                            bottomSpace: 0
                        ),
                    ],
                    bottomSpace: 0
                ),
                TKPopUp.Component.ButtonGroupComponent(
                    buttons: [
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: copyButtonConfiguration
                        ),
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: shareButtonConfiguration
                        ),
                    ]
                ),
            ]
        )

        didUpdateConfiguration?(configuration)
    }
}
