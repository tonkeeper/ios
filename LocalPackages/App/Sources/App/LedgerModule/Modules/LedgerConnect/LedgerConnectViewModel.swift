import Foundation
import UIKit
import TKUIKit
import TKLocalize
import TonSwift
import KeeperCore
import TonTransport
import BleTransport

protocol LedgerConnectModuleOutput: AnyObject {
  var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, @escaping (() -> Void)) -> Void)? { get set }
  var didCancel: (() -> Void)? { get set }
}

protocol LedgerConnectViewModel: AnyObject {
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)? { get set }
  var didShowTurnOnBluetoothAlert: (() -> Void)? { get set }
  var didShowBluetoothAuthorisationAlert: (() -> Void)? { get set }
  
  func viewDidLoad()
}

final class LedgerConnectViewModelImplementation: LedgerConnectViewModel, LedgerConnectModuleOutput {
  enum State {
    case idle
    case bluetoothConnected
    case appConnected
  }
  
  // MARK: - LedgerConnectModuleOutput
  
  var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, @escaping (() -> Void)) -> Void)?
  var didCancel: (() -> Void)?
  
  // MARK: - LedgerConnectViewModel
  
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)?
  var didShowTurnOnBluetoothAlert: (() -> Void)?
  var didShowBluetoothAuthorisationAlert: (() -> Void)?
  
  private var pollTonAppTask: Task<Void, Never>? = nil
  private var disconnectTask: Task<Void, Never>? = nil
  
  private var transport: BleTransportProtocol = BleTransport.shared
  private var tonTransport: TonTransport? = nil
  private var connectedDeviceId: String? = nil
  
  func viewDidLoad() {
    updateModel()
    didUpdateState()
    
    listenBluetoothState()
  }
  
  func listenBluetoothState() {
    BleTransport.shared.bluetoothStateCallback { state in
      switch state {
      case .poweredOn:
        self.startScan()
      case .poweredOff:
        self.didShowTurnOnBluetoothAlert?()
      case .unauthorized:
        self.didShowBluetoothAuthorisationAlert?()
      default:
        break
      }
    }
  }
  
  func startScan() {
    self.transport.create(scanDuration: TimeInterval.infinity, disconnectedCallback: {
      print("Log: Ledger disconnected")
      self.pollTonAppTask?.cancel()
      self.startScan()
      
      self.disconnectTask = Task {
        do {
          try await Task.sleep(nanoseconds: 2_000_000_000)
          await MainActor.run {
            self.setDisconnected()
          }
        } catch {}
      }
    }, success: { result in
      print("Connected to \(result.name)")
      self.disconnectTask?.cancel()
      self.setConnected(deviceId: result.uuid.uuidString)
      self.waitForAppOpen()
    }, failure: { error in
      print("Error connecting to device: \(error.localizedDescription)")
      self.setDisconnected()
    })
  }
  
  func waitForAppOpen() {
    let tonTransport = TonTransport(transport: BleTransport.shared)
    self.pollTonAppTask = Task {
      do {
        while true {
          try Task.checkCancellation()
          let isAppOpened = try await tonTransport.isAppOpen()
          if isAppOpened {
            await MainActor.run {
              self.setReady(tonTransport: tonTransport)
            }
            break
          }
          try await Task.sleep(nanoseconds: 1_000_000_000)
        }
      } catch {}
    }
  }
  
  func didTapContinueButton() {
    guard let tonTransport = tonTransport, let deviceId = connectedDeviceId else { return }
    self.isLoading = true
    Task {
      do {
        var accounts: [LedgerAccount] = []
        
        for index in 0..<10 {
          let account = try await tonTransport.getAccount(path: AccountPath(index: index))
          accounts.append(account)
        }
        
        await MainActor.run { [accounts] in
          self.didConnect?(accounts, deviceId, {
            self.isLoading = false
          })
        }
      } catch {
        print("Failed to get accounts:", error)
        await MainActor.run {
          self.isLoading = false
        }
      }
    }
    
  }
  
  func setDisconnected() {
    self.tonTransport = nil
    self.state = .idle
  }
  
  func setConnected(deviceId: String) {
    self.connectedDeviceId = deviceId
    self.state = .bluetoothConnected
  }
  
  func setReady(tonTransport: TonTransport) {
    self.tonTransport = tonTransport
    self.state = .appConnected
  }
  
  // MARK: - State
  
  private var state: State = .idle {
    didSet {
      didUpdateState()
    }
  }
  private var isLoading: Bool = false {
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
    configuration.showsLoader = isLoading
    configuration.action = { [weak self] in
      self?.didTapContinueButton()
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
