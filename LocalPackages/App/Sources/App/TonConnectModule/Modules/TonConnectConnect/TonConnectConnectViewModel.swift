import Foundation
import AVFoundation
import KeeperCore
import TKCore
import UIKit
import TKUIKit
import TKLocalize

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
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  
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
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
 
  func viewDidLoad() {
    prepareContent()
  }
  
  // MARK: - State
  
  private var selectedWallet: Wallet?
  private var isNotificationsOn: Bool = true
  private var connectingState: TKProcessContainerView.State = .idle {
    didSet {
      prepareContent()
    }
  }
  
  // MARK: - Dependencies
  
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let walletsStore: WalletsStore
  private let walletNotificationStore: WalletNotificationStore
  private let showWalletPicker: Bool
    
  // MARK: - Init
  
  init(parameters: TonConnectParameters,
       manifest: TonConnectManifest,
       walletsStore: WalletsStore,
       walletNotificationStore: WalletNotificationStore,
       showWalletPicker: Bool) {
    self.parameters = parameters
    self.manifest = manifest
    self.walletsStore = walletsStore
    self.walletNotificationStore = walletNotificationStore
    self.showWalletPicker = showWalletPicker
    
    self.selectedWallet = try? walletsStore.activeWallet
  }
}

private extension TonConnectConnectViewModelImplementation {
  func prepareContent() {
    guard let selectedWallet else { return }
    let configuration = TonConnectConnectMapper.modalCardConfiguration(
      wallet: selectedWallet,
      manifest: manifest,
      showWalletPicker: !walletsStore.wallets.isEmpty && showWalletPicker,
      isNotificationOn: isNotificationsOn,
      connectingState: connectingState,
      tickAction: { [weak self] isOn in
        self?.isNotificationsOn = isOn
      },
      walletPickerAction: { [weak self] in
        self?.didTapWalletPicker?(selectedWallet)
      },
      connectAction: { [weak self, walletNotificationStore, manifest] in
        guard let self, let connect else { return }
        connectingState = .process
        Task {
          let isSuccess = await connect(
            TonConnectConnectParameters(
              parameters: self.parameters,
              manifest: self.manifest,
              wallet: selectedWallet
            )
          )
          if isSuccess && self.isNotificationsOn {
            await walletNotificationStore.setNotificationsIsOn(true, wallet: selectedWallet, dappHost: manifest.host)
          }
          
          await MainActor.run {
            if isSuccess {
              self.connectingState = .success
            } else {
              self.connectingState = .failed
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
              self.connectingState = .idle
              guard isSuccess else {
                return
              }
              self.didConnect?()
            }
          }
        }
      }
    )
    didUpdateConfiguration?(configuration)
  }
}

private extension String {
  static let buttonTitle = TKLocales.TonConnect.connectWallet
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
