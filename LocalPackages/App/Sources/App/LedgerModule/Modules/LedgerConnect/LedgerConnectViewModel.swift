import Foundation
import TKUIKit
import TKLocalize

protocol LedgerConnectModuleOutput: AnyObject {
  var didCancel: (() -> Void)? { get set }
}

protocol LedgerConnectViewModel: AnyObject {
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class LedgerConnectViewModelImplementation: LedgerConnectViewModel, LedgerConnectModuleOutput {
  enum State {
    case idle
    case bluetoothConnected
    case appConnected
  }
  
  // MARK: - LedgerConnectModuleOutput
  
  var didCancel: (() -> Void)?
  
  // MARK: - LedgerConnectViewModel
  
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)?
  
  func viewDidLoad() {
    updateModel()
    didUpdateState()
    
    setDisconnected()
  }
  
  // TODO: Remove, For Debug
  
  func setDisconnected() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .idle
      self.setConnected()
    }
  }
  
  func setConnected() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .bluetoothConnected
      self.setReady()
    }
  }
  
  func setReady() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .appConnected
      self.setDisconnected()
    }
  }
  
  // MARK: - State
  
  private var state: State = .idle {
    didSet {
      didUpdateState()
    }
  }
  
  // MARK: - Dependencies
  
  // MARK: - Init
}

private extension LedgerConnectViewModelImplementation {
  func updateModel() {
    let model = LedgerConnectView.Model(
      contentViewModel: LedgerContentView.Model(
        bluetoothViewModel: createBluetoothModel(),
        stepModels: [
          createConnectStepModel(),
          createTonAppStepModel()
        ]
      ),
      cancelButton: createCancelButtonModel(),
      continuteButton: createContinueButtonModel()
    )
    didUpdateModel?(model)
  }
  
  func didUpdateState() {
    updateModel()
  }
  
  func createBluetoothModel() -> LedgerBluetoothView.Model {
    let bluetoothState: LedgerBluetoothViewState
    switch state {
    case .idle:
      bluetoothState = .disconnected
    case .bluetoothConnected:
      bluetoothState = .ready
    case .appConnected:
      bluetoothState = .ready
    }
    return LedgerBluetoothView.Model(state: bluetoothState)
  }
  
  func createCancelButtonModel() -> TKButton.Configuration {
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    configuration.content.title = .plainString(TKLocales.Actions.cancel)
    configuration.action = { [weak self] in
      self?.didCancel?()
    }
    return configuration
  }
  
  func createContinueButtonModel() -> TKButton.Configuration {
    let isEnabled: Bool
    switch state {
    case .idle:
      isEnabled = false
    case .bluetoothConnected:
      isEnabled = false
    case .appConnected:
      isEnabled = true
    }
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    configuration.content.title = .plainString(TKLocales.Actions.continue_action)
    configuration.isEnabled = isEnabled
    configuration.action = {
      print("Continue")
    }
    return configuration
  }
  
  func createConnectStepModel() -> LedgerStepView.Model {
    let stepState: LedgerStepView.State
    switch state {
    case .idle:
      stepState = .inProgress
    case .bluetoothConnected:
      stepState = .done
    case .appConnected:
      stepState = .done
    }
    return LedgerStepView.Model(
      content: TKLocales.LedgerConnect.Steps.BluetoothConnect.description,
      linkButton: nil,
      state: stepState
    )
  }
  
  func createTonAppStepModel() -> LedgerStepView.Model {
    let stepState: LedgerStepView.State
    switch state {
    case .idle:
      stepState = .idle
    case .bluetoothConnected:
      stepState = .inProgress
    case .appConnected:
      stepState = .done
    }
    return LedgerStepView.Model(
      content: TKLocales.LedgerConnect.Steps.TonApp.description,
      linkButton: LedgerStepView.LinkButton.Model(
        title: TKLocales.LedgerConnect.Steps.TonApp.link,
        tapClosure: {
          print("Install TON App")
        }
      ),
      state: stepState
    )
  }
}
