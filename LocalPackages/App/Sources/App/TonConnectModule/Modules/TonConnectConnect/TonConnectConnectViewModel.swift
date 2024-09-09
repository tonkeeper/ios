import Foundation
import AVFoundation
import KeeperCore
import TKCore
import UIKit
import TKUIKit

typealias ConnectionCompleteClosure = ((Bool) async -> Void)
struct TonConnectConnectParameters {
  let parameters: TonConnectParameters
  let manifest: TonConnectManifest
  let wallet: Wallet
}

protocol TonConnectConnectViewModuleOutput: AnyObject {
  var didConnect: (() -> Void)? { get set }
  var didTapWalletPicker: ((Wallet) -> Void)? { get set }
  var connect: ((TonConnectConnectParameters) async -> Bool)? { get set }
}

protocol TonConnectConnectModuleInput: AnyObject {
  func setWallet(_ wallet: Wallet)
}

protocol TonConnectConnectViewModel: AnyObject {
  var headerView: ((String?, URL?) -> UIView)? { get set }
  var walletPickerView: ((TonConnectConnectWalletButton.Model) -> UIControl)? { get set }
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TonConnectConnectViewModelImplementation: NSObject, TonConnectConnectViewModel, TonConnectConnectViewModuleOutput, TonConnectConnectModuleInput {
  
  // MARK: - TonConnectConnectViewModuleOutput
  
  var didConnect: (() -> Void)?
  var didTapWalletPicker: ((Wallet) -> Void)?
  var connect: ((TonConnectConnectParameters) async -> Bool)?
  
  // MARK: - TonConnectConnectModuleInput
  
  func setWallet(_ wallet: Wallet) {
    selectedWallet = wallet
    prepareContent()
  }
  
  // MARK: - TonConnectConnectViewModel
  
  var headerView: ((String?, URL?) -> UIView)?
  var walletPickerView: ((TonConnectConnectWalletButton.Model) -> UIControl)?
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
 
  func viewDidLoad() {
    prepareContent()
  }
  
  // MARK: - State
  
  private var selectedWallet: Wallet?
  
  // MARK: - Dependencies
  
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let walletsStore: WalletsStore
  private let showWalletPicker: Bool
    
  // MARK: - Init
  
  init(parameters: TonConnectParameters,
       manifest: TonConnectManifest,
       walletsStore: WalletsStore,
       showWalletPicker: Bool) {
    self.parameters = parameters
    self.manifest = manifest
    self.walletsStore = walletsStore
    self.showWalletPicker = showWalletPicker
    
    self.selectedWallet = try? walletsStore.getActiveWallet()
  }
}

private extension TonConnectConnectViewModelImplementation {
  func prepareContent() {
    guard let selectedWallet else { return }
    let configuration = TonConnectConnectMapper.modalCardConfiguration(
      wallet: selectedWallet,
      manifest: manifest,
      showWalletPicker: !walletsStore.wallets.isEmpty && showWalletPicker,
      headerView: {
        headerView?($0, $1)
      },
      walletPickerView: { [showWalletPicker] in
        guard showWalletPicker else { return nil }
        return walletPickerView?($0)
      },
      walletPickerAction: { [weak self] in
        guard let self,
        let selectedWallet = self.selectedWallet else { return }
        self.didTapWalletPicker?(selectedWallet)
      },
      connectAction: { [weak self] in
        guard let self, let connect else { return false }
        return await connect(
          TonConnectConnectParameters(
            parameters: parameters,
            manifest: manifest,
            wallet: selectedWallet
          )
        )
      },
      completionAction: { [weak self] in
        self?.didConnect?()
      }
    )
    didUpdateConfiguration?(configuration)
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
