import TKLocalize
import TKUIKit
import UIKit

@MainActor
enum PerpsRegionRestrictionSheet {
    static func make() -> TKBottomSheetViewController {
        var gotItButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        gotItButton.content = TKButton.Configuration.Content(title: .plainString(TKLocales.Actions.gotIt))

        let viewController = InfoPopupBottomSheetViewController()
        let bottomSheet = TKBottomSheetViewController(contentViewController: viewController)
        gotItButton.action = { [weak bottomSheet] in
            bottomSheet?.dismiss()
        }
        viewController.configuration = InfoPopupBottomSheetViewController.Configuration(
            image: .TKUIKit.Icons.Size84.globe,
            imageTintColor: .Icon.primary,
            title: TKLocales.Perps.RegionRestricted.title,
            caption: TKLocales.Perps.RegionRestricted.caption,
            bodyContent: nil,
            buttons: [gotItButton]
        )
        viewController.headerConfiguration = TKBottomSheetHeaderConfiguration(
            title: .empty,
            contentInsets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)
        )
        return bottomSheet
    }
}
