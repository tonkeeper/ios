import Foundation
import LedgerKit
import TKLocalize
import TKLogging
import TKUIKit
import TonTransport

final class LedgerStepsViewModel<Value: Sendable>: LedgerConfirmViewModel {
    var didUpdateModel: ((LedgerConfirmView.Model) -> Void)?
    var showToast: ((ToastPresenter.Configuration) -> Void)?
    var didShowTurnOnBluetoothAlert: (() -> Void)?
    var didShowBluetoothAuthorisationAlert: (() -> Void)?
    var didShowPairingRemovedAlert: ((_ retry: @escaping () -> Void) -> Void)?

    /// Called once: with the value, or with `CancellationError` when cancelled here or refused on the device.
    var didFinish: ((Result<Value, Error>) -> Void)?

    private let steps: LedgerSteps<Value>
    private let peripheralID: UUID
    private let transport: LedgerKit.LedgerTransport

    private var progress = LedgerStepsProgress() {
        didSet {
            updateModel()
        }
    }

    private var bluetoothStateTask: Task<Void, Never>?
    private var job: Task<Void, Never>?
    /// The run waits here for the user to confirm or skip the current stage's app.
    private var pendingChoice: CheckedContinuation<Bool, Error>?
    /// The stage whose app the Ledger is opening; Skip stops it alone until it is done.
    private var confirmedStage: Int?
    /// Set when the user stops the confirmed stage, which may be before the run waits for it.
    private var isStopped = false
    /// The run waits here for the user to stop the confirmed stage.
    private var pendingStop: CheckedContinuation<Void, Error>?

    init(steps: LedgerSteps<Value>, peripheralID: UUID, transport: LedgerKit.LedgerTransport) {
        self.steps = steps
        self.peripheralID = peripheralID
        self.transport = transport
    }

    func viewDidLoad() {
        updateModel()
        listenBluetoothState()
        start()
    }

    /// Called once the sheet is gone, even when it went with the screen under it: steps it leaves unfinished end as
    /// cancelled, so whoever waits for them goes on.
    func stopTasks() {
        bluetoothStateTask?.cancel()
        cancel()
    }
}

private extension LedgerStepsViewModel {
    func listenBluetoothState() {
        bluetoothStateTask = Task { @MainActor [weak self, transport] in
            for await state in transport.bluetoothState() {
                switch state {
                case .poweredOff:
                    self?.didShowTurnOnBluetoothAlert?()
                case .unauthorized:
                    self?.didShowBluetoothAuthorisationAlert?()
                default:
                    break
                }
            }
        }
    }

    func start() {
        let (phases, reporter) = AsyncStream.makeStream(of: LedgerSession.Phase.self)
        let session = LedgerSession(transport: transport, peripheralID: peripheralID) { reporter.yield($0) }
        let apps = steps.stages.map(\.app)
        let choice = LedgerAppChoice(
            isConfirmed: { app in try await self.choose(app) },
            stopped: { _ in try await self.waitForStop() }
        )
        job = Task { @MainActor [steps] in
            let rendering = Task { @MainActor in
                for await phase in phases {
                    self.progress = self.progress.reporting(phase, apps: apps)
                }
            }
            let result: Result<Value, Error>
            do {
                try await session.connect()
                result = try await .success(steps.run(session, choice))
            } catch {
                result = .failure(error)
            }
            reporter.finish()
            await rendering.value
            await session.close()
            guard !Task.isCancelled else { return }
            finish(result)
        }
    }

    /// Waits for the user's choice when the stage of `app` may be skipped, unless that stage starts automatically.
    @MainActor
    func choose(_ app: LedgerApp) async throws -> Bool {
        confirmedStage = nil
        isStopped = false
        guard let choosing = progress.choosing(app, apps: steps.stages.map(\.app)) else {
            return true
        }
        let stage = steps.stages[choosing.stage]
        guard stage.adds != nil else {
            return true
        }
        if stage.startsAutomatically {
            confirmedStage = choosing.stage
            progress = choosing.chose(true)
            return true
        }
        let isConfirmed = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingChoice = continuation
                progress = choosing
            }
        } onCancel: {
            Task { @MainActor in
                self.answerChoice(.failure(CancellationError()))
            }
        }
        progress = progress.chose(isConfirmed)
        if isConfirmed {
            confirmedStage = choosing.stage
        }
        return isConfirmed
    }

    func answerChoice(_ answer: Result<Bool, Error>) {
        let pendingChoice = pendingChoice
        self.pendingChoice = nil
        pendingChoice?.resume(with: answer)
    }

    /// Returns once the user stops the stage they confirmed; throws `CancellationError` once its work is done.
    @MainActor
    func waitForStop() async throws {
        guard !isStopped else {
            return
        }
        defer {
            confirmedStage = nil
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingStop = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.answerStop(.failure(CancellationError()))
            }
        }
    }

    func answerStop(_ answer: Result<Void, Error>) {
        let pendingStop = pendingStop
        self.pendingStop = nil
        pendingStop?.resume(with: answer)
    }

    /// Stops the confirmed stage while its app runs, and the work goes on without it; at any other stage the steps are
    /// cancelled.
    func cancelCurrent() {
        guard let confirmedStage, confirmedStage == progress.stage else {
            cancel()
            return
        }
        self.confirmedStage = nil
        isStopped = true
        progress = progress.chose(false)
        answerStop(.success(()))
    }

    @MainActor
    func finish(_ result: Result<Value, Error>) {
        if case let .failure(error) = result {
            if case LedgerTransportError.pairingRemoved = error {
                didShowPairingRemovedAlert? { [weak self] in
                    self?.start()
                }
                return
            }
            if !error.isRefusalOnDevice {
                Log.w("Ledger steps failed", error: error)
                showToast?(ToastPresenter.Configuration(title: message(for: error)))
            }
        }
        let didFinish = didFinish
        self.didFinish = nil
        didFinish?(result.mapError { $0.isRefusalOnDevice ? CancellationError() as Error : $0 })
    }

    func message(for error: Error) -> String {
        if let transportError = error as? LedgerTransportError {
            switch transportError {
            case .timeout, .disconnected, .peripheralNotFound:
                return TKLocales.LedgerConnect.Steps.BluetoothConnect.description
            case .bluetoothUnavailable:
                return TKLocales.Bluetooth.PoweredOffAlert.message
            case .bluetoothUnsupported:
                return TKLocales.Errors.unknown
            default:
                break
            }
        }
        if let failure = error as? LedgerStepsFailure {
            return failure.message
        }
        if case .publicKeyMismatch? = error as? TonTransportError {
            return TKLocales.LedgerSteps.otherWallet
        }
        guard let status = error as? LedgerStatusError, status.isAppMissing, steps.stages.indices.contains(progress.stage) else {
            return TKLocales.Errors.unknown
        }
        return TKLocales.LedgerSteps.appMissing(steps.stages[progress.stage].app.name)
    }

    func cancel() {
        job?.cancel()
        let didFinish = didFinish
        self.didFinish = nil
        didFinish?(.failure(CancellationError()))
    }

    func updateModel() {
        let model = LedgerConfirmView.Model(
            contentViewModel: LedgerContentView.Model(
                bluetoothViewModel: LedgerBluetoothView.Model(state: progress.hasConnected ? .ready : .disconnected),
                stepModels: [
                    LedgerStepView.Model(
                        content: TKLocales.LedgerConfirm.Steps.BluetoothConnect.description,
                        linkButton: nil,
                        state: progress.hasConnected ? .done : .inProgress
                    ),
                ] + steps.stages.enumerated().flatMap { stepModels(index: $0.offset, stage: $0.element) }
            ),
            cancelButton: progress.isChoosing || isAutomaticallyStartedStage ? skipButtonModel() : cancelButtonModel(),
            confirmButton: progress.isChoosing ? confirmButtonModel() : nil
        )
        didUpdateModel?(model)
    }

    func stepModels(index: Int, stage: LedgerSteps<Value>.Stage) -> [LedgerStepView.Model] {
        let isCurrent = index == progress.stage
        let isChoosing = isCurrent && progress.isChoosing
        let isRunning = isCurrent && progress.phase == .running(stage.app)
        let skip = progress.skip(at: index)
        let openState: LedgerStepView.State = if skip != nil {
            .skipped
        } else if index < progress.stage || isRunning {
            .done
        } else if isCurrent, progress.hasConnected, !isChoosing {
            .inProgress
        } else {
            .idle
        }
        let caption: String? = switch skip {
        case .notInstalled: TKLocales.LedgerSteps.appNotInstalled
        case .declined: TKLocales.LedgerSteps.appDeclined
        case .skipped: TKLocales.LedgerSteps.appSkipped
        case nil: (isChoosing || isCurrent && stage.startsAutomatically) ? stage.adds.map(TKLocales.LedgerSteps.adds) : nil
        }
        let open = LedgerStepView.Model(content: TKLocales.LedgerSteps.openApp(stage.app.name), caption: caption, linkButton: nil, state: openState)
        guard let prompt = stage.prompt else {
            return [open]
        }
        let promptState: LedgerStepView.State = skip != nil ? .idle : index < progress.stage ? .done : isRunning ? .inProgress : .idle
        return [open, LedgerStepView.Model(content: prompt, linkButton: nil, state: promptState)]
    }

    func cancelButtonModel() -> TKButton.Configuration {
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        configuration.content.title = .plainString(TKLocales.Actions.cancel)
        configuration.action = { [weak self] in
            self?.cancelCurrent()
        }
        return configuration
    }

    func skipButtonModel() -> TKButton.Configuration {
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        configuration.content.title = .plainString(TKLocales.LedgerSteps.skip)
        configuration.action = { [weak self] in
            guard let self else { return }
            if progress.isChoosing {
                answerChoice(.success(false))
            } else {
                cancelCurrent()
            }
        }
        return configuration
    }

    func confirmButtonModel() -> TKButton.Configuration {
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        configuration.content.title = .plainString(TKLocales.LedgerSteps.confirm)
        configuration.action = { [weak self] in
            self?.answerChoice(.success(true))
        }
        return configuration
    }
}

private extension LedgerStepsViewModel {
    var isAutomaticallyStartedStage: Bool {
        guard let confirmedStage, confirmedStage == progress.stage else {
            return false
        }
        return steps.stages[confirmedStage].startsAutomatically
    }
}

private extension Error {
    var isRefusalOnDevice: Bool {
        if let status = self as? LedgerStatusError {
            return status.isRefused
        }
        guard case .deniedByUser? = self as? TransportStatusError else {
            return false
        }
        return true
    }
}
