import CoreBluetooth
import Foundation
import TKCore

@MainActor
final class WalletImportPairingAnalyticsSession {
    enum Blocker: Equatable {
        case bluetoothOff, bluetoothPermissionDenied, cameraPermissionDenied
        case cameraError, connectionError, importError

        var reason: PairingExitReason {
            switch self {
            case .bluetoothOff: .bluetoothOff
            case .bluetoothPermissionDenied: .bluetoothPermissionDenied
            case .cameraPermissionDenied: .cameraPermissionDenied
            case .cameraError, .connectionError, .importError: .error
            }
        }
    }

    let walletMode: WalletMode
    let walletSource: WalletSource
    let from: AddWalletSource
    let entry: PairingEntry

    private let analyticsProvider: AnalyticsProvider
    private let hasPairingScreen: Bool
    private var hasStarted = false
    private var hasFinished = false
    private var isImporting = false
    private var pendingExitReason: PairingExitReason?
    private var hasAction = false
    private var foundDevices = Set<UUID>()
    private var lastStep: PairingLastStep = ._none
    private var blockers: [Blocker] = []

    init(
        analyticsProvider: AnalyticsProvider,
        walletMode: WalletMode,
        walletSource: WalletSource,
        from: AddWalletSource,
        entry: PairingEntry = .menu,
        hasPairingScreen: Bool = true
    ) {
        self.analyticsProvider = analyticsProvider
        self.walletMode = walletMode
        self.walletSource = walletSource
        self.from = from
        self.entry = entry
        self.hasPairingScreen = hasPairingScreen
    }

    var isActive: Bool {
        isOpen && pendingExitReason == nil
    }

    private var isOpen: Bool {
        hasStarted && !hasFinished
    }

    func beginImport() -> Bool {
        guard isActive, !isImporting else { return false }
        isImporting = true
        return true
    }

    @discardableResult
    func importFailed(error: Error, ledgerModel: LedgerModel? = nil) -> Bool {
        guard isOpen, isImporting else { return false }
        isImporting = false
        analyticsProvider.logWalletImportError(
            walletMode: walletMode, walletSource: walletSource, from: from,
            error: error, ledgerModel: ledgerModel
        )
        let pendingExit = pendingExitReason
        pendingExitReason = nil
        setBlocked(.importError)
        if let pendingExit { return exit(reason: pendingExit) }
        return false
    }

    func start() {
        guard !hasStarted, !hasFinished else { return }
        hasStarted = true
        analyticsProvider.logWalletImportStarted(
            walletMode: walletMode, walletSource: walletSource, from: from, pairingEntry: entry
        )
    }

    func action(_ action: PairingAction) {
        guard isActive, hasPairingScreen, !hasAction else { return }
        hasAction = true
        advance(to: .action)
        analyticsProvider.log(WalletImportPairingAction(
            walletMode: walletMode, walletSource: walletSource, from: from, pairingAction: action
        ))
    }

    func deviceFound(id: UUID, model: LedgerModel?) {
        guard isActive, hasPairingScreen, foundDevices.insert(id).inserted else { return }
        advance(to: .deviceFound)
        analyticsProvider.log(WalletImportLedgerDeviceFound(
            walletMode: walletMode, walletSource: walletSource, from: from,
            ledgerTransport: .bluetooth, ledgerModel: model
        ))
    }

    func advance(to step: PairingLastStep) {
        guard isActive, step.rank > lastStep.rank else { return }
        lastStep = step
    }

    func setBlocked(_ reason: Blocker, isBlocked: Bool = true) {
        guard isActive else { return }
        if reason == .connectionError, isBlocked,
           blockers.contains(.bluetoothOff) || blockers.contains(.bluetoothPermissionDenied)
        { return }
        blockers.removeAll { $0 == reason }
        if isBlocked { blockers.append(reason) }
    }

    func cameraStateChanged(_ state: ScannerCameraState) {
        switch state {
        case .running:
            setBlocked(.cameraPermissionDenied, isBlocked: false)
            setBlocked(.cameraError, isBlocked: false)
            action(.cameraOpened)
        case .permissionDenied:
            setBlocked(.cameraPermissionDenied)
        case .failed:
            setBlocked(.cameraError)
        }
    }

    func bluetoothStateChanged(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            setBlocked(.bluetoothOff, isBlocked: false)
            setBlocked(.bluetoothPermissionDenied, isBlocked: false)
        case .poweredOff:
            setBlocked(.connectionError, isBlocked: false)
            setBlocked(.bluetoothPermissionDenied, isBlocked: false)
            setBlocked(.bluetoothOff)
        case .unauthorized:
            setBlocked(.connectionError, isBlocked: false)
            setBlocked(.bluetoothOff, isBlocked: false)
            setBlocked(.bluetoothPermissionDenied)
        default:
            break
        }
    }

    func success(ledgerModel: LedgerModel? = nil) {
        guard isOpen else { return }
        hasFinished = true
        isImporting = false
        pendingExitReason = nil
        analyticsProvider.logWalletImportSuccess(
            walletMode: walletMode, walletSource: walletSource, from: from,
            ledgerModel: ledgerModel, pairingEntry: entry
        )
    }

    @discardableResult
    func exit(reason: PairingExitReason = .back) -> Bool {
        guard isOpen else { return false }
        if isImporting {
            if pendingExitReason == nil { pendingExitReason = reason }
            return false
        }
        hasFinished = true
        guard hasPairingScreen else { return true }
        analyticsProvider.log(WalletImportPairingExit(
            walletMode: walletMode, walletSource: walletSource, from: from,
            pairingLastStep: lastStep, pairingExitReason: blockers.last?.reason ?? reason
        ))
        return true
    }
}

private extension PairingLastStep {
    var rank: Int {
        switch self {
        case ._none: 0
        case .action: 1
        case .deviceFound: 2
        case .connected: 3
        case .appOpened: 4
        case .accountsView: 5
        }
    }
}
