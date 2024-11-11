import Foundation
import UIKit
import TKUIKit
import TKCore
import TKLocalize
import TonSwift
import KeeperCore
import TonTransport
import BleTransport

protocol LedgerConnectModuleOutput: AnyObject {
  var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, _ deviceProductName: String, @escaping (() -> Void)) -> Void)? { get set }
  var didCancel: (() -> Void)? { get set }
}

protocol LedgerConnectViewModel: AnyObject {
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)? { get set }
  var didShowTurnOnBluetoothAlert: (() -> Void)? { get set }
  var didShowBluetoothAuthorisationAlert: (() -> Void)? { get set }
  
  func viewDidLoad()
  func stopTasks()
}

final class LedgerConnectViewModelImplementation: LedgerConnectViewModel, LedgerConnectModuleOutput {
  enum State {
    case idle
    case bluetoothConnected
    case appConnected
  }
  
  // MARK: - LedgerConnectModuleOutput
  
  var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, _ deviceProductName: String, @escaping (() -> Void)) -> Void)?
  var didCancel: (() -> Void)?
  
  // MARK: - LedgerConnectViewModel
  
  var didUpdateModel: ((LedgerConnectView.Model) -> Void)?
  var didShowTurnOnBluetoothAlert: (() -> Void)?
  var didShowBluetoothAuthorisationAlert: (() -> Void)?
  
  private var pollTonAppTask: Task<Void, Swift.Error>? = nil
  private var disconnectTask: Task<Void, Never>? = nil
  private var accountsTask: Task<Void, Never>? = nil
  
  private var tonTransport: TonTransport? = nil
  private var connectedDeviceId: String? = nil
  private var connectedDeviceProductName: String? = nil
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
    accountsTask?.cancel()
    
    bleTransport.stopScanning()
    bleTransport.disconnect(completion: nil)
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
  
  private let urlOpener: URLOpener
  private let bleTransport: BleTransportProtocol
  
  // MARK: - Init
  
  init(urlOpener: URLOpener,
       bleTransport: BleTransportProtocol) {
    self.urlOpener = urlOpener
    self.bleTransport = bleTransport
  }
}

private extension LedgerConnectViewModelImplementation {
  func listenBluetoothState() {
    bleTransport.bluetoothStateCallback { state in
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
  
  func connect(peripheralInfo: PeripheralInfo) {
    print("Connecting to \(peripheralInfo.peripheral.name)...")
    
    bleTransport.disconnect() { [weak self] _ in
      guard let self else { return }
      self.bleTransport.connect(toPeripheralID: peripheralInfo.peripheral, disconnectedCallback: {
        print("Log: Ledger disconnected, isClosed: \(self.isClosed)")
        if self.isClosed { return }
        
        self.pollTonAppTask?.cancel()
        self.accountsTask?.cancel()
        self.startScan()
        
        self.disconnectTask = Task {
          do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try Task.checkCancellation()
            await MainActor.run {
              self.setDisconnected()
            }
          } catch {}
        }
      }, success: { result in
        print("Connected to \(result.name), udid: \(result.uuid)")
        self.bleTransport.stopScanning()
        self.disconnectTask?.cancel()
        self.setConnected(peripheralInfo: peripheralInfo)
        self.waitForAppOpen()
      }, failure: { error in
        print("Error connecting to device: \(error.localizedDescription)")
        self.startScan()
        self.setDisconnected()
      })
    }
  }
  
  func startScan() {
    print("Start scanning bluetooth devices")
    bleTransport.stopScanning()
    
    var connecting = false
    
    bleTransport.scan(duration: 25.0) { discoveries in
      guard let firstDiscovery = discoveries.first else { return }
      if !connecting {
        connecting = true
        self.connect(peripheralInfo: firstDiscovery)
      }
    } stopped: { error in
      if let error = error {
        switch error {
        case .scanningTimedOut:
          if !connecting {
            self.startScan()
          }
        default:
          print("Bluetooth scan error: \(error.localizedDescription)")
        }
      }
    }
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
        await MainActor.run {
          self.setReady(tonTransport: tonTransport)
        }
      }
      self.pollTonAppTask = task
    }
    startPollTask()
  }
  
  func didTapContinueButton() {
    guard let tonTransport = tonTransport, let deviceId = connectedDeviceId, let deviceProductName = connectedDeviceProductName else { return }
    self.isLoading = true
    self.accountsTask = Task {
      do {
        var accounts: [LedgerAccount] = []
        
        for index in 0..<10 {
          try Task.checkCancellation()
          let account = try await tonTransport.getAccount(path: AccountPath(index: index))
          accounts.append(account)
        }
        
        await MainActor.run { [accounts] in
          self.didConnect?(accounts, deviceId, deviceProductName, {
            self.isLoading = false
          })
        }
      } catch {
        print("get accounts error: \(error.localizedDescription)")
        await MainActor.run {
          self.isLoading = false
        }
      }
    }
  }
  
  func didTapInstallTonApp() {
    guard let ledgerLiveURL = URL(string: "ledgerlive://myledger?installApp=TON") else { return }
    
    if urlOpener.canOpen(url: ledgerLiveURL) {
      urlOpener.open(url: ledgerLiveURL)
    } else if let ledgerLiveStoreURL = URL(string: "https://apps.apple.com/app/ledger-live/id1361671700") {
      urlOpener.open(url: ledgerLiveStoreURL)
    }
  }
  
  func setDisconnected() {
    self.tonTransport = nil
    self.state = .idle
  }
  
  func setConnected(peripheralInfo: PeripheralInfo) {
    let deviceModel = LedgerDevice.getDeviceWith(serviceUUID: peripheralInfo.serviceUUID)
    self.connectedDeviceProductName = deviceModel.productName
    self.connectedDeviceId = peripheralInfo.peripheral.uuid.uuidString
    self.state = .bluetoothConnected
  }
  
  func setReady(tonTransport: TonTransport) {
    self.tonTransport = tonTransport
    self.state = .appConnected
  }
  
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
    configuration.content.title = .plainString(TKLocales.Actions.continueAction)
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
        tapClosure: { [weak self] in
          self?.didTapInstallTonApp()
        }
      ),
      state: stepState
    )
  }
}
