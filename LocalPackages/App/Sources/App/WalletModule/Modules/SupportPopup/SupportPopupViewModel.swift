import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

@MainActor
public protocol SupportPopupModuleOutput: AnyObject {
    var didOpenURL: ((URL) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
}

@MainActor
protocol SupportPopupViewModel: AnyObject {
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class SupportPopupViewModelImplementation: SupportPopupViewModel, SupportPopupModuleOutput {
    // MARK: - SupportPopupViewModel

    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
    var didOpenURL: ((URL) -> Void)?
    var didClose: (() -> Void)?

    // MARK: - Dependencies

    private let directSupportURL: URL?

    init(directSupportURL: URL?) {
        self.directSupportURL = directSupportURL
    }

    func viewDidLoad() {
        prepareContent()
    }

    private func prepareContent() {
        let askAction = { [weak self] in
            guard let self, let directSupportURL else { return }

            didOpenURL?(directSupportURL)
        }

        var askButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .primary,
            size: .large
        )
        askButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Support.SupportPopup.Buttons.ask)
        )
        askButtonConfiguration.action = askAction

        var closeButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
            category: .secondary,
            size: .large
        )
        closeButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(TKLocales.Support.SupportPopup.Buttons.close)
        )
        closeButtonConfiguration.action = { [weak self] in
            self?.didClose?()
        }

        let configuration = TKPopUp.Configuration(
            items: [
                SupportPopupImagePopUpItem(
                    configuration: SupportPopupImageView.Configuration(
                        image: getSupportImage()
                    ),
                    bottomSpace: 20
                ),
                TKPopUp.Component.TitleCaption(
                    title: TKLocales.Support.SupportPopup.title,
                    caption: TKLocales.Support.SupportPopup.caption,
                    bottomSpace: 0
                ),
                TKPopUp.Component.ButtonGroupComponent(
                    buttons: [
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: askButtonConfiguration
                        ),
                        TKPopUp.Component.ButtonComponent(
                            buttonConfiguration: closeButtonConfiguration
                        ),
                    ]
                ),
            ]
        )

        didUpdateConfiguration?(configuration)
    }

    private func getSupportImage() -> UIImage {
        switch TKThemeManager.shared.theme {
        case .deepBlue: SupportIcon.deepBlue.image
        case .dark: SupportIcon.dark.image
        case .light: SupportIcon.light.image
        case .system:
            switch UIScreen.main.traitCollection.userInterfaceStyle {
            case .dark: SupportIcon.dark.image
            case .light: SupportIcon.light.image
            case .unspecified: SupportIcon.deepBlue.image
            @unknown default: SupportIcon.deepBlue.image
            }
        }
    }

    enum SupportIcon {
        case deepBlue
        case dark
        case light

        var image: UIImage {
            switch self {
            case .deepBlue: .App.Images.Size72.supportBlue
            case .dark: .App.Images.Size72.supportDark
            case .light: .App.Images.Size72.supportLight
            }
        }
    }
}
