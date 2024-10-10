import UIKit
import TKUIKit
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize

final class DecryptCommentHandler {
  static func decryptComment<ParentRouterViewController: UIViewController>(wallet: Wallet,
                                                                           payload: EncryptedCommentPayload,
                                                                           eventId: String,
                                                                           parentCoordinator: Coordinator,
                                                                           parentRouter: ContainerViewControllerRouter<ParentRouterViewController>,
                                                                           keeperCoreAssembly: KeeperCore.MainAssembly,
                                                                           coreAssembly: TKCore.CoreAssembly) {
    
    let decryptController = keeperCoreAssembly.decryptCommentController()
    let decrypt: () async -> Void = {
      Task {
        guard let passcode = await PasscodeInputCoordinator.getPasscode(
          parentCoordinator: parentCoordinator,
          parentRouter: parentRouter,
          mnemonicsRepository: keeperCoreAssembly.repositoriesAssembly.mnemonicsRepository(),
          securityStore: keeperCoreAssembly.storesAssembly.securityStore
        ) else { return }
        
        do {
          try await decryptController.decryptComment(payload, wallet: wallet, eventId: eventId, passcode: passcode)
        } catch {
          await MainActor.run {
            ToastPresenter.showToast(configuration: .failed)
          }
        }
      }
    }
    
    let appSettings = coreAssembly.appSettings
    
    if appSettings.isDecryptCommentWarningDoNotShow {
      Task {
        await decrypt()
      }
    } else {
      let fromViewController: UIViewController = {
        if let presentedViewController = parentRouter.rootViewController.presentedViewController {
          return presentedViewController
        } else {
          return parentRouter.rootViewController
        }
      }()
      showDecryptCommentWarningPopup(fromViewController: fromViewController,
                                     coreAssembly: coreAssembly) {
        Task {
          await decrypt()
        }
      }
    }
  }
  
  static func showDecryptCommentWarningPopup(fromViewController: UIViewController, 
                                             coreAssembly: TKCore.CoreAssembly,
                                             onConfirm: @escaping () -> Void) {
    
    var isDoNotShowMarked = false
    
    weak var bottomSheetViewController: TKBottomSheetViewController?
    let decryptButtonItem = {
      var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
      configuration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.DecryptCommentPopup.button))
      configuration.action = {
        coreAssembly.appSettings.isDecryptCommentWarningDoNotShow = isDoNotShowMarked
        bottomSheetViewController?.dismiss(completion: onConfirm)
      }
      return TKPopUp.Component.ButtonComponent(buttonConfiguration: configuration)
    }()
    
    let configuration = TKPopUp.Configuration(
      items: [
        TKPopUp.Component.ImageComponent(
          image: TKImageView.Model(image: .image(.TKUIKit.Icons.Size128.lock), tintColor: .Accent.green, size: .auto, corners: .none),
          bottomSpace: 12
        ),
        TKPopUp.Component.GroupComponent(
          padding: UIEdgeInsets(top: 0, left: 32, bottom: 16, right: 32),
          items: [
            TKPopUp.Component.LabelComponent(
              text: TKLocales.DecryptCommentPopup.title
                .withTextStyle(.h2, color: .Text.primary, alignment: .center),
              numberOfLines: 0,
              bottomSpace: 4
            ),
            TKPopUp.Component.LabelComponent(
              text: TKLocales.DecryptCommentPopup.caption
                .withTextStyle(.body1, color: .Text.secondary, alignment: .center),
              numberOfLines: 0),
          ]),
        TKPopUp.Component.ButtonGroupComponent(buttons: [
          decryptButtonItem
        ]),
        TKPopUp.Component.TickItem(
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
      ]
    )
    
    let popupViewController = TKPopUp.ViewController(configuration: configuration)
    popupViewController.configuration = configuration
    let viewController = TKBottomSheetViewController(contentViewController: popupViewController)
    bottomSheetViewController = viewController
    
    viewController.present(fromViewController: fromViewController)
  }
}
