import CoreBluetooth
import Foundation
import KeeperCore
import LedgerKit
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TonTransport
import UIKit

protocol LedgerConnectModuleOutput: AnyObject {
    var didStartSearch: (() -> Void)? { get set }
    var didFindDevice: ((LedgerPeripheral) -> Void)? { get set }
    var didUpdateConnectionError: ((Bool) -> Void)? { get set }
    var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, _ deviceProductName: String, @escaping (() -> Void)) -> Void)? { get set }
    var didConnectBluetooth: ((_ deviceProductName: String) -> Void)? { get set }
    var didOpenTonApp: ((_ deviceProductName: String?) -> Void)? { get set }
    var didCancel: (() -> Void)? { get set }
}

protocol LedgerConnectViewModel: AnyObject {
    var didUpdateModel: ((LedgerConnectView.Model) -> Void)? { get set }
    var didShowTurnOnBluetoothAlert: (() -> Void)? { get set }
    var didShowBluetoothAuthorisationAlert: (() -> Void)? { get set }
    var didShowPairingRemovedAlert: ((_ retry: @escaping () -> Void) -> Void)? { get set }

    func viewDidLoad()
    func stopTasks()
}

final class LedgerConnectViewModelImplementation: LedgerConnectViewModel, LedgerConnectModuleOutput {
    enum State {
        case searching
        case connecting(LedgerPeripheral)
        case bluetoothConnected(LedgerPeripheral)
        case tonAppMissing(LedgerPeripheral)
        case appConnected(LedgerPeripheral, TonTransport)
    }

    // MARK: - LedgerConnectModuleOutput

    var didStartSearch: (() -> Void)?
    var didFindDevice: ((LedgerPeripheral) -> Void)?
    var didUpdateConnectionError: ((Bool) -> Void)?

    var didConnect: ((_ accounts: [LedgerAccount], _ deviceId: String, _ deviceProductName: String, @escaping (() -> Void)) -> Void)?
    var didConnectBluetooth: ((_ deviceProductName: String) -> Void)?
    var didOpenTonApp: ((_ deviceProductName: String?) -> Void)?
    var didCancel: (() -> Void)?

    // MARK: - LedgerConnectViewModel

    var didUpdateModel: ((LedgerConnectView.Model) -> Void)?
    var didShowTurnOnBluetoothAlert: (() -> Void)?
    var didShowBluetoothAuthorisationAlert: (() -> Void)?
    var didShowPairingRemovedAlert: ((_ retry: @escaping () -> Void) -> Void)?

    private var bluetoothStateTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private(set) var sessionTask: Task<Void, Never>?
    private var pollTonAppTask: Task<Void, Never>?
    private var disconnectTask: Task<Void, Never>?
    private var accountsTask: Task<Void, Never>?

    func viewDidLoad() {
        updateModel()

        listenBluetoothState()
    }

    func stopTasks() {
        bluetoothStateTask?.cancel()
        scanTask?.cancel()
        sessionTask?.cancel()
        pollTonAppTask?.cancel()
        disconnectTask?.cancel()
        accountsTask?.cancel()
    }

    // MARK: - State

    private var state: State = .searching {
        didSet {
            updateModel()
        }
    }

    /// The Ledgers found nearby, in the order they were found.
    private var devices: [LedgerPeripheral] = [] {
        didSet {
            updateModel()
        }
    }

    private var isLoading: Bool = false {
        didSet {
            updateModel()
        }
    }

    // MARK: - Dependencies

    private let urlOpener: URLOpener
    private let transport: LedgerKit.LedgerTransport
    /// Continue reads the first TON accounts once the TON app is open. Without it Continue hands over the connected
    /// Ledger, as multichain pairing opens the TON app later, after the other apps.
    private let readsAccounts: Bool
    private let sleep: @MainActor (UInt64) async throws -> Void

    // MARK: - Init

    init(
        urlOpener: URLOpener,
        transport: LedgerKit.LedgerTransport,
        readsAccounts: Bool,
        sleep: @escaping @MainActor (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.urlOpener = urlOpener
        self.transport = transport
        self.readsAccounts = readsAccounts
        self.sleep = sleep
    }
}

private extension LedgerConnectViewModelImplementation {
    func listenBluetoothState() {
        bluetoothStateTask = Task { @MainActor in
            for await state in transport.bluetoothState() {
                guard !Task.isCancelled else { return }
                if state != .poweredOn { scanTask?.cancel() }
                switch state {
                case .poweredOn:
                    if scanTask?.isCancelled != false { startScanning() }
                    if let peripheral = self.state.peripheral { connect(to: peripheral) }
                case .poweredOff:
                    didShowTurnOnBluetoothAlert?()
                case .unauthorized:
                    didShowBluetoothAuthorisationAlert?()
                default:
                    break
                }
            }
        }
    }

    func startScanning() {
        scanTask?.cancel()
        scanTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            didStartSearch?()
            Log.i("Start scanning bluetooth devices")
            for await peripheral in transport.scan() where !devices.contains(where: { $0.id == peripheral.id }) {
                guard !Task.isCancelled else { return }
                didFindDevice?(peripheral)
                devices.append(peripheral)
                if state.peripheral == nil {
                    select(peripheral)
                }
            }
        }
    }

    /// Scanning goes on, so that the user can still pick another Ledger than the first one found.
    func select(_ peripheral: LedgerPeripheral) {
        guard state.peripheral?.id != peripheral.id else {
            return
        }
        accountsTask?.cancel()
        disconnectTask?.cancel()
        state = .connecting(peripheral)
        isLoading = false
        connect(to: peripheral)
    }

    func connect(to peripheral: LedgerPeripheral) {
        sessionTask?.cancel()
        pollTonAppTask?.cancel()
        sessionTask = Task { @MainActor in
            await runSession(peripheral: peripheral)
        }
    }

    @MainActor
    func runSession(peripheral: LedgerPeripheral) async {
        Log.i("Connecting to \(peripheral.name)...")
        let link: LedgerLink
        do {
            link = try await transport.connect(peripheral.id)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            if case LedgerTransportError.bluetoothUnavailable = error {
                didUpdateConnectionError?(false)
            } else {
                didUpdateConnectionError?(true)
            }
            Log.w("Error connecting to device: \(error.localizedDescription)")
            state = .connecting(peripheral)
            if case LedgerTransportError.pairingRemoved = error {
                didShowPairingRemovedAlert? { [weak self] in
                    self?.connect(to: peripheral)
                }
                return
            }
            do {
                try await sleep(1_000_000_000)
            } catch {
                return
            }
            connect(to: peripheral)
            return
        }
        defer { link.close() }
        guard !Task.isCancelled else {
            return
        }
        Log.i("Connected to \(peripheral.name), udid: \(peripheral.id)")
        disconnectTask?.cancel()
        didUpdateConnectionError?(false)
        setConnected(peripheral: peripheral)
        if readsAccounts {
            waitForAppOpen(link: link, peripheral: peripheral)
        }

        for await _ in link.disconnected {}

        pollTonAppTask?.cancel()
        guard !Task.isCancelled else {
            return
        }
        Log.w("Ledger disconnected")
        accountsTask?.cancel()
        connect(to: peripheral)
        disconnectTask = Task { @MainActor [sleep] in
            do {
                try await sleep(2_000_000_000)
            } catch {
                return
            }
            state = .connecting(peripheral)
        }
    }

    func waitForAppOpen(link: LedgerLink, peripheral: LedgerPeripheral) {
        let tonTransport = TonTransport(link: link)
        pollTonAppTask = Task { @MainActor [sleep] in
            do {
                _ = try await link.waitForApp(.ton, sleep: { try await sleep($0) }) {
                    self.setTonAppMissing($0, peripheral: peripheral)
                }
                try Task.checkCancellation()
                didUpdateConnectionError?(false)
                setReady(peripheral: peripheral, tonTransport: tonTransport)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                didUpdateConnectionError?(true)
                Log.w("Waiting for the TON app failed: \(error.localizedDescription)")
            }
        }
    }

    func didTapContinueButton() {
        if !readsAccounts, case let .bluetoothConnected(peripheral) = state {
            didConnect?([], peripheral.id.uuidString, peripheral.device.productName) {}
            return
        }
        guard case let .appConnected(peripheral, tonTransport) = state else { return }
        self.isLoading = true
        self.accountsTask = Task { @MainActor in
            do {
                var accounts: [LedgerAccount] = []

                for index in 0 ..< 20 {
                    try Task.checkCancellation()
                    let account = try await tonTransport.getAccount(path: AccountPath(index: index))
                    accounts.append(account)
                }

                self.didUpdateConnectionError?(false)
                self.didConnect?(accounts, peripheral.id.uuidString, peripheral.device.productName) {
                    self.isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.didUpdateConnectionError?(true)
                Log.w("get accounts error: \(error.localizedDescription)")
                self.isLoading = false
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

    func setConnected(peripheral: LedgerPeripheral) {
        let shouldLog = !state.isConnected
        self.state = .bluetoothConnected(peripheral)
        if shouldLog {
            didConnectBluetooth?(peripheral.device.productName)
        }
    }

    func setTonAppMissing(_ isMissing: Bool, peripheral: LedgerPeripheral) {
        switch (state, isMissing) {
        case (.bluetoothConnected, true):
            state = .tonAppMissing(peripheral)
        case (.tonAppMissing, false):
            state = .bluetoothConnected(peripheral)
        default:
            break
        }
    }

    func setReady(peripheral: LedgerPeripheral, tonTransport: TonTransport) {
        let shouldLog = !state.isAppConnected
        self.state = .appConnected(peripheral, tonTransport)
        if shouldLog {
            didOpenTonApp?(peripheral.device.productName)
        }
    }

    func updateModel() {
        let model = LedgerConnectView.Model(
            contentViewModel: LedgerContentView.Model(
                bluetoothViewModel: createBluetoothModel(),
                stepModels: [createConnectStepModel()] + (readsAccounts ? [createTonAppStepModel()] : [])
            ),
            devices: devices.map(createDeviceModel),
            cancelButton: createCancelButtonModel(),
            continuteButton: createContinueButtonModel()
        )
        didUpdateModel?(model)
    }

    func createBluetoothModel() -> LedgerBluetoothView.Model {
        let bluetoothState: LedgerBluetoothViewState
        switch state {
        case .searching, .connecting, .tonAppMissing:
            bluetoothState = .disconnected
        case .bluetoothConnected, .appConnected:
            bluetoothState = .ready
        }
        return LedgerBluetoothView.Model(state: bluetoothState)
    }

    func createDeviceModel(_ peripheral: LedgerPeripheral) -> TKListItemButton.Configuration {
        TKListItemButton.Configuration(
            listItemConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: TKListItemIconView.Configuration(
                    content: .image(
                        TKImageView.Model(
                            image: .image(.TKUIKit.Icons.Size28.ledger),
                            tintColor: .Accent.blue,
                            size: .size(CGSize(width: 28, height: 28))
                        )
                    ),
                    alignment: .center,
                    backgroundColor: .clear,
                    size: CGSize(width: 28, height: 28)
                ),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: TKListItemTitleView.Configuration(title: peripheral.name),
                    captionViewsConfigurations: [
                        TKListItemTextView.Configuration(text: peripheral.device.productName, color: .Text.secondary, textStyle: .body2),
                    ]
                )
            ),
            accessory: state.peripheral?.id == peripheral.id
                ? .icon(TKListItemIconAccessoryView.Configuration(icon: .TKUIKit.Icons.Size28.donemarkOutline, tintColor: .Accent.blue))
                : .chevron,
            isEnable: true,
            tapClosure: { [weak self] in
                self?.select(peripheral)
            }
        )
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
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        configuration.content.title = .plainString(TKLocales.Actions.continueAction)
        configuration.isEnabled = readsAccounts ? state.isAppConnected : state.isConnected
        configuration.showsLoader = isLoading
        configuration.action = { [weak self] in
            self?.didTapContinueButton()
        }
        return configuration
    }

    func createConnectStepModel() -> LedgerStepView.Model {
        LedgerStepView.Model(
            content: TKLocales.LedgerConnect.Steps.BluetoothConnect.description,
            linkButton: nil,
            state: state.isConnected ? .done : .inProgress
        )
    }

    func createTonAppStepModel() -> LedgerStepView.Model {
        let stepState: LedgerStepView.State
        switch state {
        case .searching, .connecting:
            stepState = .idle
        case .bluetoothConnected:
            stepState = .inProgress
        case .tonAppMissing:
            stepState = .failed
        case .appConnected:
            stepState = .done
        }
        return LedgerStepView.Model(
            content: stepState == .failed ? TKLocales.LedgerSteps.appMissing(LedgerApp.ton.name) : TKLocales.LedgerConnect.Steps.TonApp.description,
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

private extension LedgerConnectViewModelImplementation.State {
    var peripheral: LedgerPeripheral? {
        switch self {
        case .searching:
            nil
        case let .connecting(peripheral), let .bluetoothConnected(peripheral), let .tonAppMissing(peripheral), let .appConnected(peripheral, _):
            peripheral
        }
    }

    var isConnected: Bool {
        switch self {
        case .searching, .connecting:
            false
        case .bluetoothConnected, .tonAppMissing, .appConnected:
            true
        }
    }

    var isAppConnected: Bool {
        if case .appConnected = self { true } else { false }
    }
}
