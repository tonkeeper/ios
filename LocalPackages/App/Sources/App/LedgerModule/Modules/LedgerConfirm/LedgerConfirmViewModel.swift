import Foundation
import TKUIKit
import TKLocalize

protocol LedgerConfirmModuleOutput: AnyObject {
  var didCancel: (() -> Void)? { get set }
  var didSign: ((String) -> Void)? { get set }
}

protocol LedgerConfirmViewModel: AnyObject {
  var didUpdateModel: ((LedgerConfirmView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class LedgerConfirmViewModelImplementation: LedgerConfirmViewModel, LedgerConfirmModuleOutput {
  enum State {
    case idle
    case bluetoothConnected
    case tonAppOpened
    case confirmed
  }
  
  // MARK: - LedgerConnectModuleOutput
  
  var didCancel: (() -> Void)?
  var didSign: ((String) -> Void)?
  
  // MARK: - LedgerConnectViewModel
  
  var didUpdateModel: ((LedgerConfirmView.Model) -> Void)?
  
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
      self.setTonAppOpened()
    }
  }
  
  func setTonAppOpened() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .tonAppOpened
      self.setConfirmed()
    }
  }
  
  func setConfirmed() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self.state = .confirmed
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

private extension LedgerConfirmViewModelImplementation {
  func updateModel() {
    let model = LedgerConfirmView.Model(
      contentViewModel: LedgerContentView.Model(
        bluetoothViewModel: createBluetoothModel(),
        stepModels: [
          createConnectStepModel(),
          createTonAppStepModel(),
          createConfirmStepModel()
        ]
      ),
      cancelButton: createCancelButtonModel()
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
    case .tonAppOpened:
      bluetoothState = .ready
    case .confirmed:
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
  
  func createConnectStepModel() -> LedgerStepView.Model {
    let stepState: LedgerStepView.State
    switch state {
    case .idle:
      stepState = .inProgress
    case .bluetoothConnected:
      stepState = .done
    case .tonAppOpened:
      stepState = .done
    case .confirmed:
      stepState = .done
    }
    return LedgerStepView.Model(
      content: TKLocales.LedgerConfirm.Steps.BluetoothConnect.description,
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
    case .tonAppOpened:
      stepState = .done
    case .confirmed:
      stepState = .done
    }
    return LedgerStepView.Model(
      content: TKLocales.LedgerConfirm.Steps.TonApp.description,
      linkButton: nil,
      state: stepState
    )
  }
  
  func createConfirmStepModel() -> LedgerStepView.Model {
    let stepState: LedgerStepView.State
    switch state {
    case .idle:
      stepState = .idle
    case .bluetoothConnected:
      stepState = .idle
    case .tonAppOpened:
      stepState = .inProgress
    case .confirmed:
      stepState = .done
    }
    return LedgerStepView.Model(
      content: TKLocales.LedgerConfirm.Steps.Confirm.description,
      linkButton: nil,
      state: stepState
    )
  }
}
