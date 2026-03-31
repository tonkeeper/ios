import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol RampMerchantPopUpModuleOutput: AnyObject {
    var didTapOpen: ((URL) -> Void)? { get set }
}

protocol RampMerchantPopUpViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

final class RampMerchantPopUpViewModelImplementation: RampMerchantPopUpViewModel, RampMerchantPopUpModuleOutput {
    var didTapOpen: ((URL) -> Void)?

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    func viewDidLoad() {
        configure()
    }

    private var doNotShowAgain = false

    private let merchantInfo: OnRampMerchantInfo
    private let actionURL: URL
    private let appSettings: AppSettings
    private let urlOpener: URLOpener

    init(
        merchantInfo: OnRampMerchantInfo,
        actionURL: URL,
        appSettings: AppSettings,
        urlOpener: URLOpener
    ) {
        self.merchantInfo = merchantInfo
        self.actionURL = actionURL
        self.appSettings = appSettings
        self.urlOpener = urlOpener
    }
}

private extension RampMerchantPopUpViewModelImplementation {
    func configure() {
        var isDoNotShowMarked = false

        let imageURL = URL(string: merchantInfo.image)
        let imageItem = TKPopUp.Component.ImageComponent(
            image: TKImageView.Model(
                image: imageURL.map { .urlImage($0) } ?? .image(nil),
                size: .size(CGSize(width: 72, height: 72)),
                corners: .cornerRadius(cornerRadius: 20)
            ),
            bottomSpace: 20
        )

        let titleCaption = TKPopUp.Component.TitleCaption(
            title: merchantInfo.title,
            caption: nil,
            bottomSpace: 4,
            addBottomPadding: false
        )

        let description: TKPopUp.Item = TKPopUp.Component.GroupComponent(
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
        )

        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        buttonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Actions.open)
        )
        buttonConfiguration.action = { [weak self] in
            guard let self else { return }
            appSettings.setIsBuySellItemMarkedDoNotShowWarning(
                merchantInfo.id,
                doNotShow: isDoNotShowMarked
            )
            self.didTapOpen?(actionURL)
        }

        let buttons = TKPopUp.Component.ButtonGroupComponent(buttons: [
            TKPopUp.Component.ButtonComponent(buttonConfiguration: buttonConfiguration),
        ], bottomSpace: 16)

        let doNotShowItem = TKPopUp.Component.TickItem(
            model: TKDetailsTickView.Model(
                text: TKLocales.Tick.doNotShowAgain,
                tick: TKDetailsTickView.Model.Tick(
                    isSelected: isDoNotShowMarked,
                    closure: {
                        isDoNotShowMarked = $0
                    }
                )
            ),
            bottomSpace: 16
        )

        var configurationItems: [TKPopUp.Item] = [
            imageItem,
            titleCaption,
        ]
        if !merchantInfo.buttons.isEmpty {
            configurationItems.append(RampMerchantPopUpButtonsItem(
                buttons: merchantInfo.buttons,
                urlOpener: urlOpener,
                bottomSpace: 32
            ))
        }
        configurationItems.append(contentsOf: [
            description,
            buttons,
            doNotShowItem,
        ])

        let configuration = TKPopUp.Configuration(items: configurationItems)

        didUpdateConfiguration?(configuration)
    }
}

private struct RampMerchantPopUpButtonsItem: TKPopUp.Item {
    let bottomSpace: CGFloat
    let buttons: [OnRampMerchantInfoButton]
    let urlOpener: URLOpener

    init(buttons: [OnRampMerchantInfoButton], urlOpener: URLOpener, bottomSpace: CGFloat) {
        self.buttons = buttons
        self.urlOpener = urlOpener
        self.bottomSpace = bottomSpace
    }

    func getView() -> UIView {
        let buttonsView = RampMerchantPopUpButtonsView()
        let buttonItems = buttons.map { button in
            RampMerchantPopUpButtonsView.ButtonItem(
                title: button.title,
                url: URL(string: button.url)
            )
        }
        buttonsView.configure(buttons: buttonItems, onLinkTap: { urlOpener.open(url: $0) })
        return buttonsView
    }
}
