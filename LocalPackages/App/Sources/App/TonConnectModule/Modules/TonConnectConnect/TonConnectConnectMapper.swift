import UIKit
import TKUIKit
import KeeperCore
import TKLocalize

struct TonConnectConnectMapper {
  static func modalCardConfiguration(
    wallet: Wallet,
    manifest: TonConnectManifest,
    showWalletPicker: Bool,
    headerView: (String?, URL?) -> UIView?,
    walletPickerView: (TonConnectConnectWalletButton.Model) -> UIControl?,
    walletPickerAction: (() -> Void)?,
    connectAction: @escaping () async -> Bool,
    completionAction: @escaping () -> Void
  ) -> TKModalCardViewController.Configuration {
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
    if !showWalletPicker, let address = try? wallet.friendlyAddress.toShort() {
      let walletAddress = address.withTextStyle(.body1, color: .Text.tertiary)
      description.append(walletAddress)
    }
    
    let address = try? wallet.friendlyAddress.toShort()
    
    var headerItems = [TKModalCardViewController.Configuration.Item]()
    if let address,
       let headerView = headerView(address, manifest.iconUrl) {
      headerItems.append(.customView(headerView, bottomSpacing: 20))
    }
    headerItems.append(
      .text(
        TKModalCardViewController.Configuration.Text(
          text: title,
          numberOfLines: 0
        ),
        bottomSpacing: 4
      )
    )
    headerItems.append(
      .text(
        TKModalCardViewController.Configuration.Text(
          text: description,
          numberOfLines: 0
        ),
        bottomSpacing: 16
      )
    )
    
    if showWalletPicker {
      let model = TonConnectConnectWalletButton.Model.configuration(wallet: wallet,
                                                                    subtitle: address)
      if let walletPickerView = walletPickerView(model) {
        walletPickerView.addAction(UIAction(handler: { _ in
          walletPickerAction?()
        }), for: .touchUpInside)
        headerItems.append(.customView(walletPickerView, bottomSpacing: 16))
      }
    }
    
    let actionBarItems: [TKModalCardViewController.Configuration.Item] = [
      .button(
        TKModalCardViewController.Configuration.Button(
          title: .connectButtonTitle,
          size: .large,
          category: .primary,
          isEnabled: true,
          isActivity: false,
          tapAction: { isActivityClosure, isSuccessClosure in
            isActivityClosure(true)
            Task {
              let isConnected = await connectAction()
              await MainActor.run {
                isSuccessClosure(isConnected)
              }
            }
          },
          completionAction: { isSuccess in
            guard isSuccess else { return }
            completionAction()
          }
        ),
        bottomSpacing: 16
      ),
      .text(
        TKModalCardViewController.Configuration.Text(
          text: .footerText,
          numberOfLines: 0
        ),
        bottomSpacing: 0
      )
    ]
    
    let configuration = TKModalCardViewController.Configuration(
      header: TKModalCardViewController.Configuration.Header(
        items: headerItems
      ),
      actionBar: TKModalCardViewController.Configuration.ActionBar(
        items: actionBarItems
      )
    )
    return configuration
  }
}

private extension String {
  static let connectButtonTitle = TKLocales.TonConnect.connectWallet
}

private extension NSAttributedString {
  static var footerText: NSAttributedString {
    TKLocales.TonConnect.sureCheckServiceAddress
      .withTextStyle(
        .body2,
        color: .Text.tertiary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
  }
}
