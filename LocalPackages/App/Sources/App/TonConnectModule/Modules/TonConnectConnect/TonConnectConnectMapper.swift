import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

struct TonConnectConnectMapper {
  
  private static func titleCaptionItem(wallet: Wallet,
                                       manifest: TonConnectManifest,
                                       showWalletPicker: Bool) -> TKPopUp.Item {
    
    let walletAddress = try? wallet.friendlyAddress
    
    let connectTo = TKLocales.TonConnectMapper.connectTo.withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let domain = manifest.host.withTextStyle(
      .h2,
      color: .Accent.blue,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let questionMark = "?".withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let title = NSMutableAttributedString()
    title.append(connectTo)
    title.append(domain)
    title.append(questionMark)
    
    let description = NSMutableAttributedString()
    let caption = TKLocales.TonConnectMapper.requestingCapture(manifest.name, (showWalletPicker ? ":" : " "))
      .withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    description.append(caption)
    if !showWalletPicker, let shortAddress = walletAddress?.toShort() {
      description.append(shortAddress.withTextStyle(.body1, color: .Text.tertiary))
    }
    
    return TKPopUp.Component.TitleCaption(
      title: title,
      caption: description,
      bottomSpace: 0
    )
  }
  
  private static func headerItem(wallet: Wallet, manifest: TonConnectManifest) -> TKPopUp.Item? {
    guard let walletAddress = try? wallet.friendlyAddress else { return nil }
    return TonConnectConnectHeaderComponent(
      configuration: TonConnectConnectHeaderView.Model(
        walletAddress: walletAddress.toString(),
        appImage: manifest.iconUrl
      ),
      bottomSpace: 20
    )
  }
  
  private static func tickComponent(isOn: Bool, action: @escaping (Bool) -> Void) -> TKPopUp.Item {
    TonConnectConnectNotificationTickComponent(
      configuration: TonConnectConnectNotificationTickView.Configuration(
        text: TKLocales.TonConnectMapper.allowNotifications.withTextStyle(.label1, color: .Text.primary),
        isOn: isOn,
        action: action
      ),
      bottomSpace: 0
    )
  }
  
  static func modalCardConfiguration(
    wallet: Wallet,
    manifest: TonConnectManifest,
    showWalletPicker: Bool,
    isNotificationOn: Bool,
    connectingState: TKProcessContainerView.State,
    coordinatorFlow: TonConnectConnectCoordinator.Flow,
    tickAction: @escaping (Bool) -> Void,
    walletPickerAction: @escaping () -> Void,
    connectAction: @escaping () -> Void,
    openBrowserAndConnectAction: @escaping () -> Void
  ) -> TKPopUp.Configuration {
    
    var items = [TKPopUp.Item]()
    
    if let headerItem = headerItem(wallet: wallet, manifest: manifest) {
      items.append(headerItem)
    }
    
    items.append(
      titleCaptionItem(wallet: wallet, manifest: manifest, showWalletPicker: showWalletPicker)
    )
    
    if showWalletPicker {
      items.append(
        TKPopUp.Component.GroupComponent(
          padding: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16),
          items: [
            TonConnectConnectWalletButtonComponent(
              configuration: TonConnectConnectWalletButton.Model.configuration(
                wallet: wallet,
                subtitle: try? wallet.friendlyAddress.toShort()
              ),
              action: {
                walletPickerAction()
              },
              bottomSpace: 0
            )
          ]
        )
      )
    }
    
    items.append(tickComponent(isOn: isNotificationOn, action: tickAction))

    let buttonTitle: String = {
      switch coordinatorFlow {
      case .common:
        return TKLocales.TonConnect.connectWallet
      case .deeplink:
        return TKLocales.TonConnect.openBrowserAndConnect
      }
    }()

    var primaryButton = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    primaryButton.content = .init(title: .plainString(buttonTitle))
    primaryButton.action = {
      switch coordinatorFlow {
      case .common:
        connectAction()
      case .deeplink:
        openBrowserAndConnectAction()
      }
    }

    let footerText: NSAttributedString = {
      let text: String
      switch coordinatorFlow {
      case .common:
        text = TKLocales.TonConnect.sureCheckServiceAddress
      case .deeplink:
        text = TKLocales.TonConnect.sureCheckServiceAddressConnectWithoutChecking
      }
      return text.withTextStyle(
        .body2,
        color: .Text.tertiary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    }()

    let secondaryButton = TKButton.Configuration(
      content: .init(title: .attributedString(footerText)),
      padding: UIEdgeInsets(top: 0, left: 32, bottom: 16, right: 32),
      textNumberOfLines: 0,
      action: {
        switch coordinatorFlow {
        case .common:
          return
        case .deeplink:
          connectAction()
        }
      }
    )

    items.append(TKPopUp.Component.Process(items: [
      TKPopUp.Component.ButtonGroupComponent(buttons: [
        TKPopUp.Component.ButtonComponent(buttonConfiguration: primaryButton)
      ]),
      TKPopUp.Component.ButtonGroupComponent(buttons: [
        TKPopUp.Component.ButtonComponent(buttonConfiguration: secondaryButton)
      ])
    ], state: connectingState))
    
    return TKPopUp.Configuration(items: items)
  }
}
