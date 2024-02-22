import Foundation
import AVFoundation
import KeeperCore
import TKCore
import UIKit
import TKUIKit

protocol TonConnectConnectViewModuleOutput: AnyObject {
  var didRequireConfirmation: (() async -> Bool)? { get set }
  var didConnect: (() -> Void)? { get set }
  var didTapWalletPicker: ((Wallet) -> Void)? { get set }
}

protocol TonConnectConnectModuleInput: AnyObject {
  func setWallet(_ wallet: Wallet)
}

protocol TonConnectConnectViewModel: AnyObject {
  var headerView: ((String?, URL?) -> UIView)? { get set }
  var walletPickerView: ((TonConnectConnectModel.Wallet) -> UIControl)? { get set }
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TonConnectConnectViewModelImplementation: NSObject, TonConnectConnectViewModel, TonConnectConnectViewModuleOutput, TonConnectConnectModuleInput {
  
  // MARK: - TonConnectConnectViewModuleOutput
  
  var didRequireConfirmation: (() async -> Bool)?
  var didConnect: (() -> Void)?
  var didTapWalletPicker: ((Wallet) -> Void)?
  
  // MARK: - TonConnectConnectModuleInput
  
  func setWallet(_ wallet: Wallet) {
    tonConnectConnectController.setWallet(wallet)
    prepareContent()
  }
  
  // MARK: - TonConnectConnectViewModel
  
  var headerView: ((String?, URL?) -> UIView)?
  var walletPickerView: ((TonConnectConnectModel.Wallet) -> UIControl)?
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
 
  func viewDidLoad() {
    prepareContent()
  }
  
  // MARK: - Dependencies
  
  private let tonConnectConnectController: TonConnectConnectController
  
  // MARK: - Init
  
  init(tonConnectConnectController: TonConnectConnectController) {
    self.tonConnectConnectController = tonConnectConnectController
  }
}

private extension TonConnectConnectViewModelImplementation {
  func prepareContent() {
    let model = tonConnectConnectController.getModel()
    
    let title = NSMutableAttributedString()
    let connect = "Connect to ".withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    let domain = model.host.withTextStyle(
      .h2,
      color: .Accent.blue,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    title.append(connect)
    title.append(domain)
    title.append("?".withTextStyle(
      .h2,
      color: .Text.primary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    ))
    
    let description = "\(model.name) is requesting access to your wallet address:"
      .withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    
    var headerItems = [TKModalCardViewController.Configuration.Item]()
    if let headerView = headerView?(model.address, model.appImageURL) {
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
    
    if tonConnectConnectController.needToShowWalletPicker(),
       let walletPickerView = walletPickerView?(model.wallet) {
      walletPickerView.addAction(UIAction(handler: { [weak self, tonConnectConnectController] _ in
        self?.didTapWalletPicker?(tonConnectConnectController.selectedWallet)
      }), for: .touchUpInside)
      headerItems.append(.customView(walletPickerView, bottomSpacing: 16))
    }
    
    let actionBarItems: [TKModalCardViewController.Configuration.Item] = [
      .button(
        TKModalCardViewController.Configuration.Button(
          title: .buttonTitle,
          size: .large,
          category: .primary,
          isEnabled: true,
          isActivity: false,
          tapAction: { [weak self] isActivityClosure, isSuccessClosure in
            guard let self else { return }
            isActivityClosure(true)
            Task {
              let isSuccess = await self.connect()
              await MainActor.run {
                isSuccessClosure(isSuccess)
              }
            }
          },
          completionAction: { [weak self] isSuccess in
            guard let self, isSuccess else { return }
            self.didConnect?()
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
    didUpdateConfiguration?(configuration)
  }
  
  func connect() async -> Bool {
    let isConfirmed = await didRequireConfirmation?() ?? false
    guard isConfirmed else { return false }
    do {
      try await tonConnectConnectController.connect()
      return true
    } catch {
      return false
    }
  }
}

private extension String {
  static let buttonTitle = "Connect wallet"
}

private extension NSAttributedString {
  static var footerText: NSAttributedString {
    "Be sure to check the service address before connecting the wallet."
      .withTextStyle(
        .body2,
        color: .Text.tertiary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
  }
}
