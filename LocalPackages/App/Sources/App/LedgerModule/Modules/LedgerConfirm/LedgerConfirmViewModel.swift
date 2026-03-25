import BleTransport
import Foundation
import KeeperCore
import TKLocalize
import TKLogging
import TKUIKit
import TonTransport

enum LedgerConfirmError: Error {
    case versionTooLow(version: String, requiredVersion: String)
}

protocol LedgerConfirmModuleOutput: AnyObject {
    var didCancel: (() -> Void)? { get set }
    var didSign: ((LedgerConfirmSignedItem) -> Void)? { get set }
    var didError: ((_ error: LedgerConfirmError) -> Void)? { get set }
}

protocol LedgerConfirmViewModel: AnyObject {
    var didUpdateModel: ((LedgerConfirmView.Model) -> Void)? { get set }
    var showToast: ((ToastPresenter.Configuration) -> Void)? { get set }
    var didShowTurnOnBluetoothAlert: (() -> Void)? { get set }
    var didShowBluetoothAuthorisationAlert: (() -> Void)? { get set }

    func viewDidLoad()
    func stopTasks()
}

final class LedgerConfirmViewModelImplementation: LedgerConfirmViewModel, LedgerConfirmModuleOutput {
    enum Error: Swift.Error {
        case invalidDeviceId
    }

    enum State {
        case idle
        case bluetoothConnected
        case tonAppOpened
        case confirmed(Int)
    }

    // MARK: - LedgerConnectModuleOutput

    var didCancel: (() -> Void)?
    var didSign: ((LedgerConfirmSignedItem) -> Void)?
    var didError: ((_ error: LedgerConfirmError) -> Void)?

    // MARK: - LedgerConnectViewModel

    var didUpdateModel: ((LedgerConfirmView.Model) -> Void)?
    var showToast: ((ToastPresenter.Configuration) -> Void)?
    var didShowTurnOnBluetoothAlert: (() -> Void)?
    var didShowBluetoothAuthorisationAlert: (() -> Void)?

    private var pollTonAppTask: Task<Void, Swift.Error>?
    private var disconnectTask: Task<Void, Never>?

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

    private let confirmItem: LedgerConfirmConfirmItem
    private let wallet: Wallet
    private let ledgerDevice: Wallet.LedgerDevice
    private let bleTransport: BleTransportProtocol

    // MARK: - Init

    init(
        confirmItem: LedgerConfirmConfirmItem,
        wallet: Wallet,
        ledgerDevice: Wallet.LedgerDevice,
        bleTransport: BleTransportProtocol
    ) {
        self.confirmItem = confirmItem
        self.wallet = wallet
        self.ledgerDevice = ledgerDevice
        self.bleTransport = bleTransport
    }
}

private extension LedgerConfirmViewModelImplementation {
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

            Log.i("Connecting to \(peripheral.name)...")
            bleTransport.disconnect { [weak self] _ in
                guard let self else { return }
                self.bleTransport.connect(toPeripheralID: peripheral, disconnectedCallback: {
                    Log.w("Log: Ledger disconnected, isClosed: \(self.isClosed)")
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
                    Log.i("Connected to \(result.name), udid: \(result.uuid)")
                    self.disconnectTask?.cancel()
                    self.setConnected()
                    self.waitForAppOpen()
                }, failure: { _ in
                    if self.isClosed { return }
                    self.connect()
                    self.setDisconnected()
                })
            }
        } catch {
            didCancel?()
        }
    }

    func checkVersion(version: String) -> Result<Void, LedgerConfirmError> {
        switch confirmItem {
        case let .transaction(transaction):
            if transaction.payload == nil {
                return .success(())
            }
            switch transaction.payload {
            case .jettonTransfer:
                return .success(())
            default:
                guard TonTransport.isVersion(version, greaterThanOrEqualTo: "2.1.0") else {
                    return .failure(LedgerConfirmError.versionTooLow(version: version, requiredVersion: "2.1.0"))
                }
                return .success(())
            }
        case .signatureData(_), .transactions:
            guard TonTransport.isVersion(version, greaterThanOrEqualTo: "2.1.0") else {
                return .failure(LedgerConfirmError.versionTooLow(version: version, requiredVersion: "2.1.0"))
            }
            return .success(())
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

                switch checkVersion(version: version) {
                case .success:
                    await MainActor.run {
                        self.setTonAppOpened()
                        self.sign(tonTransport: tonTransport)
                    }
                case let .failure(error):
                    await MainActor.run {
                        self.didError?(error)
                    }
                }
            }
            self.pollTonAppTask = task
        }
        startPollTask()
    }

    func sign(tonTransport: TonTransport) {
        let accountPath = AccountPath(index: ledgerDevice.accountIndex)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch confirmItem {
                case let .transaction(transaction):
                    let signature = try await tonTransport.signTransaction(
                        path: accountPath,
                        transaction: transaction
                    )
                    self.setConfirmed(idx: 0)
                    self.didSign?(.transaction(signature))
                case let .transactions(transactions):
                    var signatures: [Data] = []
                    for (idx, transaction) in transactions.enumerated() {
                        let signature = try await tonTransport.signTransaction(
                            path: accountPath,
                            transaction: transaction
                        )
                        self.setConfirmed(idx: idx)
                        signatures.append(signature)
                    }
                    self.didSign?(.transactions(signatures))
                case let .signatureData(signatureData):
                    let signed = try await tonTransport.signAddressProof(
                        path: accountPath,
                        domain: signatureData.domain.value,
                        timestamp: signatureData.timestamp,
                        payload: signatureData.payload
                    )
                    self.setConfirmed(idx: 0)
                    self.didSign?(.proof(signed))
                }
            } catch {
                defer {
                    self.didCancel?()
                }
                switch error {
                case let transportError as TransportStatusError:
                    switch transportError {
                    case .deniedByUser:
                        return
                    default:
                        self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.unknown))
                    }
                case let tonTransportError as TonTransportError:
                    self.showToast?(ToastPresenter.Configuration(title: tonTransportError.localizedDescription))
                default:
                    self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.unknown))
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

    func setConfirmed(idx: Int) {
        self.state = .confirmed(idx)
    }

    func updateModel() {
        let model = LedgerConfirmView.Model(
            contentViewModel: LedgerContentView.Model(
                bluetoothViewModel: createBluetoothModel(),
                stepModels: [
                    createConnectStepModel(),
                    createTonAppStepModel(),
                ] + createConfirmStepsModel()
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

    func createConfirmStepsModel() -> [LedgerStepView.Model] {
        switch self.confirmItem {
        case .signatureData(_), .transaction:
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

            let content: String = {
                switch self.confirmItem {
                case .transaction(_), .transactions:
                    return TKLocales.LedgerConfirm.Steps.Confirm.description
                case .signatureData:
                    return TKLocales.LedgerConfirm.Steps.ConfirmProof.description
                }
            }()

            return [LedgerStepView.Model(
                content: content,
                linkButton: nil,
                state: stepState
            )]
        case let .transactions(transactions):
            return transactions.enumerated().map { idx, _ in
                let stepState: LedgerStepView.State
                switch state {
                case .idle:
                    stepState = .idle
                case .bluetoothConnected:
                    stepState = .idle
                case .tonAppOpened:
                    stepState = idx == 0 ? .inProgress : .idle
                case let .confirmed(confirmedIndex):
                    if confirmedIndex >= idx {
                        stepState = .done
                    } else if idx == confirmedIndex + 1 {
                        stepState = .inProgress
                    } else {
                        stepState = .idle
                    }
                }

                return LedgerStepView.Model(
                    content: TKLocales.LedgerConfirm.Steps.Confirm.descriptionNumerated(idx + 1),
                    linkButton: nil,
                    state: stepState
                )
            }
        }
    }
}
