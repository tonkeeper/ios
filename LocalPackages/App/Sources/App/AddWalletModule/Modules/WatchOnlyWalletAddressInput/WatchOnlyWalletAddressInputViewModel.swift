import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol WatchOnlyWalletAddressInputModuleOutput: AnyObject {
  var didInputWallet: ((ResolvableAddress) -> Void)? { get set }
}

protocol WatchOnlyWalletAddressInputViewModel: AnyObject {
  var didUpdateModel: ((WatchOnlyWalletAddressInputView.Model) -> Void)? { get set }
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
  var didUpdateIsValid: ((Bool) -> Void)? { get set }
  
  var text: String { get set }
  
  func viewDidLoad()
}

final class WatchOnlyWalletAddressInputViewModelImplementation: WatchOnlyWalletAddressInputViewModel, WatchOnlyWalletAddressInputModuleOutput {
  
  // MARK: - WatchOnlyWalletAddressInputModuleOutput
  
  var didInputWallet: ((ResolvableAddress) -> Void)?
  
  // MARK: - WatchOnlyWalletAddressInputViewModel
  
  var didUpdateModel: ((WatchOnlyWalletAddressInputView.Model) -> Void)?
  var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
  var didUpdateIsValid: ((Bool) -> Void)?
  
  var text: String = "" {
    didSet {
      Task {
        await controller.resolveAddress(input: text)
      }
    }
  }
  
  func viewDidLoad() {
    Task {
      await controller.start(didUpdateState: { [weak self] state in
        guard let self else { return }
        Task { @MainActor in
          self.didUpdateResolvingState(state)
        }
      })
    }
    didUpdateModel?(createModel())
    didUpdateContinueButton?(continueButtonConfiguration)
  }
  
  // MARK: - State
  
  private var continueButtonConfiguration: TKButton.Configuration {
    didSet {
      didUpdateContinueButton?(continueButtonConfiguration)
    }
  }
  
  private var isValid: Bool = true {
    didSet {
      didUpdateIsValid?(isValid)
    }
  }
  
  // MARK: - Dependencies
  
  private let controller: WatchOnlyWalletAddressInputController
  
  // MARK: - Init
  
  init(controller: WatchOnlyWalletAddressInputController) {
    self.controller = controller
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    continueButtonConfiguration.content.title = .plainString("Continue")
    self.continueButtonConfiguration = continueButtonConfiguration
  }
}

private extension WatchOnlyWalletAddressInputViewModelImplementation {
  func createModel() -> WatchOnlyWalletAddressInputView.Model {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: "Watch Account",
      bottomDescription: "Monitor wallet activity without recovery phrase. You will be notified of any transactions from this wallet."
    )
    
    let placeholder = "Address or name"
    
    return WatchOnlyWalletAddressInputView.Model(
      titleDescriptionModel: titleDescriptionModel,
      placeholder: placeholder
    )
  }
  
  func didUpdateResolvingState(_ state: WatchOnlyWalletAddressInputController.State) {
    switch state {
    case .none:
      self.continueButtonConfiguration.isEnabled = false
      self.continueButtonConfiguration.showsLoader = false
      self.continueButtonConfiguration.action = nil
      self.isValid = true
    case .resolving:
      self.continueButtonConfiguration.isEnabled = false
      self.continueButtonConfiguration.showsLoader = true
      self.continueButtonConfiguration.action = nil
      self.isValid = true
    case .resolved(let resolvableAddress):
      self.continueButtonConfiguration.isEnabled = true
      self.continueButtonConfiguration.showsLoader = false
      self.continueButtonConfiguration.action = { [weak self] in
        self?.didInputWallet?(resolvableAddress)
      }
      self.isValid = true
    case .failed:
      self.continueButtonConfiguration.isEnabled = false
      self.continueButtonConfiguration.showsLoader = false
      self.continueButtonConfiguration.action = nil
      self.isValid = false
    }
  }
}
