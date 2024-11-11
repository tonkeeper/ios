import Foundation
import TKUIKit
import TKLocalize
import TonTransport
import BleTransport
import KeeperCore

enum LedgerProofError: Error {
  case versionTooLow(version: String, requiredVersion: String)
}

protocol LedgerProofModuleOutput: AnyObject {
  var didCancel: (() -> Void)? { get set }
  var didSign: ((Data) -> Void)? { get set }
  var didError: ((_ error: LedgerProofError) -> Void)? { get set }
}

protocol LedgerProofViewModel: AnyObject {
  var didUpdateModel: ((LedgerProofView.Model) -> Void)? { get set }
  var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
  var didShowTurnOnBluetoothAlert: (() -> Void)? { get set }
  var didShowBluetoothAuthorisationAlert: (() -> Void)? { get set }
  
  func viewDidLoad()
  func stopTasks()
}

final class LedgerProofViewModelImplementation: LedgerProofViewModel, LedgerProofModuleOutput {
  enum Error: Swift.Error {
    case invalidDeviceId
  }
  
  enum State {
    case idle
    case bluetoothConnected
    case tonAppOpened
    case confirmed
  }
  
  // MARK: - LedgerConnectModuleOutput
  
  var didCancel: (() -> Void)?
  var didSign: ((Data) -> Void)?
  var didError: ((_ error: LedgerProofError) -> Void)?
  
  // MARK: - LedgerConnectViewModel
  
  var didUpdateModel: ((LedgerProofView.Model) -> Void)?
  var showToast: ((ToastPresenter.Configuration) -> Void)?
  var didShowTurnOnBluetoothAlert: (() -> Void)?
  var didShowBluetoothAuthorisationAlert: (() -> Void)?
  
  private var pollTonAppTask: Task<Void, Swift.Error>? = nil
  private var disconnectTask: Task<Void, Never>? = nil
  
  private var isClosed: Bool = false
  
  func viewDidLoad() {
    updateModel()
    didUpdateState()
    
    listenBluetoothState()
  }
  
  func stopTasks() {
    isClosed = true
    
    pollTonAppTask?.cancel()
    disconnectTask?.cancel()
    
    bleTransport.disconnect(completion: nil)
  }
  
  // MARK: - State
  
  private var state: State = .idle {
    didSet {
      didUpdateState()
    }
  }
  
  // MARK: - Dependencies
  
  private let proofParameters: LedgerProofParameters
  private let ledgerDevice: Wallet.LedgerDevice
  private let wallet: Wallet
  private let bleTransport: BleTransportProtocol
  
  // MARK: - Init
  
  init(proofParameters: LedgerProofParameters, 
       wallet: Wallet,
       ledgerDevice: Wallet.LedgerDevice,
       bleTransport: BleTransportProtocol) {
    self.proofParameters = proofParameters
    self.wallet = wallet
    self.ledgerDevice = ledgerDevice
    self.bleTransport = bleTransport
  }
}

private extension LedgerProofViewModelImplementation {
  func listenBluetoothState() {
    bleTransport.bluetoothStateCallback { state in
      switch state {
      case .poweredOn:
        self.connect()
      case .poweredOff:
        self.didShowTurnOnBluetoothAlert?()
      case .unauthorized:
        self.didShowBluetoothAuthorisationAlert?()
      default:
        break
      }
    }
  }
  
  func connect() {
    do {
      guard let uuid = UUID(uuidString: ledgerDevice.deviceId) else {
        throw Error.invalidDeviceId
      }
      let peripheral = PeripheralIdentifier(uuid: uuid, name: ledgerDevice.deviceModel)
      
      print("Connecting to \(peripheral.name)...")
      bleTransport.disconnect() { [weak self] _ in
        guard let self else { return }
        self.bleTransport.connect(toPeripheralID: peripheral, disconnectedCallback: {
          print("Log: Ledger disconnected, isClosed: \(self.isClosed)")
          if self.isClosed { return }
          
          self.pollTonAppTask?.cancel()
          self.connect()
          
          self.disconnectTask = Task {
            do {
              try await Task.sleep(nanoseconds: 3_000_000_000)
              try Task.checkCancellation()
              await MainActor.run {
                self.setDisconnected()
              }
            } catch {}
          }
        }, success: { result in
          print("Connected to \(result.name), udid: \(result.uuid)")
          self.disconnectTask?.cancel()
          self.setConnected()
          self.waitForAppOpen()
        }, failure: { error in
          if self.isClosed { return }
          self.connect()
          self.setDisconnected()
        })
      }
    } catch {
      didCancel?()
    }
  }
  
  func checkVersion(version: String) -> Result<Void, LedgerProofError> {
    guard TonTransport.isVersion(version, greaterThanOrEqualTo: "2.1.0") else {
      return .failure(LedgerProofError.versionTooLow(version: version, requiredVersion: "2.1.0"))
    }
    return .success(())
  }
  
  func waitForAppOpen() {
    let tonTransport = TonTransport(transport: bleTransport)
    
    @Sendable func startPollTask() {
      let task = Task {
        let (isAppOpened, version) = try await tonTransport.isAppOpen()
        try Task.checkCancellation()
        guard isAppOpened else {
          try await Task.sleep(nanoseconds: 1_000_000_000)
          try Task.checkCancellation()
          await MainActor.run {
            startPollTask()
          }
          return
        }
        
        switch checkVersion(version: version) {
        case .success:
          await MainActor.run {
            self.setTonAppOpened()
            self.signProof(tonTransport: tonTransport)
          }
        case .failure(let error):
          await MainActor.run {
            self.didError?(error)
          }
        }
      }
      self.pollTonAppTask = task
    }
    startPollTask()
  }
  
  func signProof(tonTransport: TonTransport) {
    let accountPath = AccountPath(index: ledgerDevice.accountIndex)
    
    Task {
      do {
        let signature = try await tonTransport.signAddressProof(
          path: accountPath,
          domain: proofParameters.domain,
          timestamp: proofParameters.timestamp,
          payload: proofParameters.payload
        )
        
        await MainActor.run {
          self.setConfirmed()
          self.didSign?(signature)
        }
      } catch {
        await MainActor.run {
          if let transportError = error as? TransportStatusError, case .deniedByUser = transportError {
            // nothing
          } else {
            self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.unknown))
          }
          
          self.didCancel?()
        }
      }
    }
  }
  
  func setDisconnected() {
    self.state = .idle
  }
  
  func setConnected() {
    self.state = .bluetoothConnected
  }
  
  func setTonAppOpened() {
    self.state = .tonAppOpened
  }
  
  func setConfirmed() {
    self.state = .confirmed
  }
  
  func updateModel() {
    let model = LedgerProofView.Model(
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
      content: TKLocales.LedgerConfirm.Steps.ConfirmProof.description,
      linkButton: nil,
      state: stepState
    )
  }
}
