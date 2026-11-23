import CoreBluetooth
import Foundation
import KeeperCore
import LedgerKit
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
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
    var didShowPairingRemovedAlert: ((_ retry: @escaping () -> Void) -> Void)? { get set }

    func viewDidLoad()
    func stopTasks()
}

final class LedgerConfirmViewModelImplementation: LedgerConfirmViewModel, LedgerConfirmModuleOutput {
    enum State {
        case idle
        case bluetoothConnected
        case tonAppMissing
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
    var didShowPairingRemovedAlert: ((_ retry: @escaping () -> Void) -> Void)?

    private var bluetoothStateTask: Task<Void, Never>?
    private var sessionTask: Task<Void, Never>?
    private var pollTonAppTask: Task<Void, Never>?
    private var disconnectTask: Task<Void, Never>?

    private var isClosed: Bool = false

    func viewDidLoad() {
        updateModel()
        didUpdateState()

        listenBluetoothState()
    }

    func stopTasks() {
        isClosed = true

        bluetoothStateTask?.cancel()
        sessionTask?.cancel()
        pollTonAppTask?.cancel()
        disconnectTask?.cancel()
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
    private let transport: LedgerKit.LedgerTransport
    private let knownJettonResolver: ((Transaction) -> KnownJetton?)?

    // MARK: - Init

    init(
        confirmItem: LedgerConfirmConfirmItem,
        wallet: Wallet,
        ledgerDevice: Wallet.LedgerDevice,
        transport: LedgerKit.LedgerTransport,
        knownJettonResolver: ((Transaction) -> KnownJetton?)?
    ) {
        self.confirmItem = confirmItem
        self.wallet = wallet
        self.ledgerDevice = ledgerDevice
        self.transport = transport
        self.knownJettonResolver = knownJettonResolver
    }
}

private extension LedgerConfirmViewModelImplementation {
    func listenBluetoothState() {
        bluetoothStateTask = Task { @MainActor in
            for await state in transport.bluetoothState() {
                switch state {
                case .poweredOn:
                    connect()
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

    func connect() {
        guard let peripheralID = UUID(uuidString: ledgerDevice.deviceId) else {
            didCancel?()
            return
        }
        sessionTask?.cancel()
        sessionTask = Task { @MainActor in
            await runSession(peripheralID: peripheralID)
        }
    }

    @MainActor
    func runSession(peripheralID: UUID) async {
        Log.i("Connecting to \(ledgerDevice.deviceModel)...")
        let link: LedgerLink
        do {
            link = try await transport.connect(peripheralID)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            Log.w("Error connecting to device: \(error.localizedDescription)")
            setDisconnected()
            if case LedgerTransportError.pairingRemoved = error {
                didShowPairingRemovedAlert? { [weak self] in
                    self?.connect()
                }
                return
            }
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            connect()
            return
        }
        defer { link.close() }
        guard !Task.isCancelled else {
            return
        }
        Log.i("Connected to \(ledgerDevice.deviceModel), udid: \(peripheralID)")
        disconnectTask?.cancel()
        setConnected()
        waitForAppOpen(link: link)

        for await _ in link.disconnected {}

        pollTonAppTask?.cancel()
        guard !Task.isCancelled else {
            return
        }
        Log.w("Ledger disconnected")
        connect()
        disconnectTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }
            setDisconnected()
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

    func waitForAppOpen(link: LedgerLink) {
        let tonTransport = TonTransport(link: link)
        pollTonAppTask = Task { @MainActor in
            do {
                let version = try await link.waitForApp(.ton) { self.setTonAppMissing($0) }
                try Task.checkCancellation()
                switch checkVersion(version: version) {
                case .success:
                    setTonAppOpened()
                    sign(tonTransport: tonTransport, appVersion: version)
                case let .failure(error):
                    didError?(error)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                Log.w("Waiting for the TON app failed: \(error.localizedDescription)")
            }
        }
    }

    func sign(tonTransport: TonTransport, appVersion: String) {
        let accountPath = AccountPath(index: ledgerDevice.accountIndex)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let publicKey = try wallet.publicKey
                switch confirmItem {
                case let .transaction(transaction):
                    let signature = try await signTransaction(
                        transaction,
                        path: accountPath,
                        publicKey: publicKey,
                        tonTransport: tonTransport,
                        appVersion: appVersion
                    )
                    self.setConfirmed(idx: 0)
                    self.didSign?(.transaction(signature))
                case let .transactions(transactions):
                    var signatures: [Data] = []
                    for (idx, transaction) in transactions.enumerated() {
                        let signature = try await signTransaction(
                            transaction,
                            path: accountPath,
                            publicKey: publicKey,
                            tonTransport: tonTransport,
                            appVersion: appVersion
                        )
                        self.setConfirmed(idx: idx)
                        signatures.append(signature)
                    }
                    self.didSign?(.transactions(signatures))
                case let .signatureData(signatureData):
                    let signed = try await tonTransport.signAddressProof(
                        path: accountPath,
                        publicKey: publicKey,
                        domain: signatureData.domain.value,
                        timestamp: signatureData.timestamp,
                        payload: signatureData.payload
                    )
                    self.setConfirmed(idx: 0)
                    self.didSign?(.proof(signed))
                }
            } catch {
                guard !self.isClosed else {
                    return
                }
                self.stopTasks()
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
                case TonTransportError.publicKeyMismatch:
                    self.showToast?(ToastPresenter.Configuration(title: TKLocales.LedgerSteps.otherWallet))
                case let tonTransportError as TonTransportError:
                    self.showToast?(ToastPresenter.Configuration(title: tonTransportError.localizedDescription))
                default:
                    self.showToast?(ToastPresenter.Configuration(title: TKLocales.Errors.unknown))
                }
            }
        }
    }

    /// The known-jetton hint only changes what the device displays, so a device that cannot
    /// parse it (older firmware, list mismatch) gets the plain transfer instead of an error.
    func signTransaction(
        _ transaction: Transaction,
        path: AccountPath,
        publicKey: TonSwift.PublicKey,
        tonTransport: TonTransport,
        appVersion: String
    ) async throws -> Data {
        guard let knownJetton = knownJettonResolver?(transaction),
              let minAppVersion = LedgerKnownJettons.minAppVersion(jettonId: knownJetton.jettonId),
              TonTransport.isVersion(appVersion, greaterThanOrEqualTo: minAppVersion)
        else {
            return try await tonTransport.signTransaction(path: path, publicKey: publicKey, transaction: transaction)
        }
        do {
            return try await tonTransport.signTransaction(
                path: path,
                publicKey: publicKey,
                transaction: transaction.settingKnownJetton(knownJetton)
            )
        } catch TransportStatusError.txParsingFailed {
            Log.w("Ledger rejected the known-jetton hint, signing without it")
            return try await tonTransport.signTransaction(path: path, publicKey: publicKey, transaction: transaction)
        }
    }

    func setDisconnected() {
        self.state = .idle
    }

    func setConnected() {
        self.state = .bluetoothConnected
    }

    func setTonAppMissing(_ isMissing: Bool) {
        switch (state, isMissing) {
        case (.bluetoothConnected, true):
            state = .tonAppMissing
        case (.tonAppMissing, false):
            state = .bluetoothConnected
        default:
            break
        }
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
        case .tonAppMissing:
            bluetoothState = .disconnected
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
        case .bluetoothConnected, .tonAppMissing:
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
        case .tonAppMissing:
            stepState = .failed
        case .tonAppOpened:
            stepState = .done
        case .confirmed:
            stepState = .done
        }
        return LedgerStepView.Model(
            content: stepState == .failed ? TKLocales.LedgerSteps.appMissing(LedgerApp.ton.name) : TKLocales.LedgerConfirm.Steps.TonApp.description,
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
            case .bluetoothConnected, .tonAppMissing:
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
                case .bluetoothConnected, .tonAppMissing:
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
