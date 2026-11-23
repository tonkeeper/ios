import Foundation
import LedgerKit
import TKUIKit
import UIKit

/// How the user steers a stage they may skip. It may wait for a choice first or open automatically; in both cases the
/// user can stop it while the app runs. The app of any other stage is opened without asking.
struct LedgerAppChoice: Sendable {
    /// Whether the user lets the Ledger open the app; `false` skips its stage.
    let isConfirmed: @Sendable (LedgerApp) async throws -> Bool
    /// Returns once the user stops the stage of the app they confirmed; the work goes on without it.
    let stopped: @Sendable (LedgerApp) async throws -> Void
}

/// Ledger work that may span device apps, shown step by step: connect, open each app, do what it asks.
struct LedgerSteps<Value: Sendable> {
    struct Stage {
        let app: LedgerApp
        /// What the user does on the device while the app runs; `nil` when it asks nothing.
        let prompt: String?
        /// What the app adds, such as the networks it holds keys for, when the user may skip it.
        let adds: String?
        /// An optional app opens without a separate confirmation. The user can still skip it while it runs.
        let startsAutomatically: Bool

        init(app: LedgerApp, prompt: String?, adds: String? = nil, startsAutomatically: Bool = false) {
            self.app = app
            self.prompt = prompt
            self.adds = adds
            self.startsAutomatically = startsAutomatically
        }
    }

    /// The apps `run` opens, in the order it opens them.
    let stages: [Stage]
    let run: @Sendable (LedgerSession, LedgerAppChoice) async throws -> Value
}

extension LedgerSteps {
    /// Work that opens the app of every stage.
    init(stages: [Stage], run: @escaping @Sendable (LedgerSession) async throws -> Value) {
        self.init(stages: stages) { session, _ in
            try await run(session)
        }
    }

    /// Shows the steps over `viewController` until the work is done. Throws `CancellationError` when the
    /// user cancels or refuses on the device; the sheet has already told them about any other failure.
    @MainActor
    func perform(peripheralID: UUID, transport: LedgerKit.LedgerTransport, from viewController: UIViewController) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            var pending: CheckedContinuation<Value, Error>? = continuation
            let resume = { (result: Result<Value, Error>) in
                pending?.resume(with: result)
                pending = nil
            }
            let viewModel = LedgerStepsViewModel(steps: self, peripheralID: peripheralID, transport: transport)
            let sheet = TKBottomSheetViewController(contentViewController: LedgerConfirmViewController(viewModel: viewModel))
            viewModel.didFinish = { [weak sheet] result in
                guard let sheet else {
                    resume(result)
                    return
                }
                sheet.dismiss { resume(result) }
            }
            sheet.didClose = { isInteractively in
                guard isInteractively else { return }
                resume(.failure(CancellationError()))
            }
            sheet.present(fromViewController: viewController)
        }
    }
}

/// A failure the user can act on; the sheet shows `message` as it is.
struct LedgerStepsFailure: Error {
    let message: String
}

/// Where the steps are, from the phases the session reports and the user's choices. Stages only move forward.
struct LedgerStepsProgress: Equatable {
    /// Why a stage's app was not opened.
    enum Skip: Equatable {
        case notInstalled
        case declined
        /// The user skipped it before the Ledger was asked.
        case skipped
    }

    let stage: Int
    let phase: LedgerSession.Phase
    let hasConnected: Bool
    let notOpened: [Int: Skip]
    /// The current stage waits for the user to confirm or skip its app.
    let isChoosing: Bool

    init(
        stage: Int = 0,
        phase: LedgerSession.Phase = .connecting,
        hasConnected: Bool = false,
        notOpened: [Int: Skip] = [:],
        isChoosing: Bool = false
    ) {
        self.stage = stage
        self.phase = phase
        self.hasConnected = hasConnected
        self.notOpened = notOpened
        self.isChoosing = isChoosing
    }

    /// The session is idle while the user chooses, so a phase that arrives then is an earlier one and leaves the choice on.
    func reporting(_ phase: LedgerSession.Phase, apps: [LedgerApp]) -> LedgerStepsProgress {
        switch phase {
        case .connecting:
            return LedgerStepsProgress(stage: stage, phase: phase, hasConnected: hasConnected, notOpened: notOpened, isChoosing: isChoosing)
        case .connected:
            return LedgerStepsProgress(stage: stage, phase: phase, hasConnected: true, notOpened: notOpened, isChoosing: isChoosing)
        case let .openingApp(app), let .running(app):
            return LedgerStepsProgress(stage: stage(of: app, in: apps) ?? stage, phase: phase, hasConnected: true, notOpened: notOpened, isChoosing: isChoosing)
        case let .notOpened(app, isMissing):
            // An app left behind, such as one the user stopped, does not mark the stage that runs now.
            guard let stage = stage(of: app, in: apps) else {
                return self
            }
            let notOpened = notOpened.merging([stage: isMissing ? .notInstalled : .declined]) { $1 }
            return LedgerStepsProgress(stage: stage, phase: phase, hasConnected: true, notOpened: notOpened, isChoosing: isChoosing)
        }
    }

    /// The stage of `app` waits for the user's choice; `nil` when no stage ahead opens it. The steps ask only once they
    /// have connected.
    func choosing(_ app: LedgerApp, apps: [LedgerApp]) -> LedgerStepsProgress? {
        stage(of: app, in: apps).map { stage in
            LedgerStepsProgress(stage: stage, phase: phase, hasConnected: true, notOpened: notOpened, isChoosing: true)
        }
    }

    /// The user's choice for the stage that waited for it, or their stop of the confirmed stage that runs: a skipped
    /// stage is left behind at once.
    func chose(_ isConfirmed: Bool) -> LedgerStepsProgress {
        guard !isConfirmed else {
            return LedgerStepsProgress(stage: stage, phase: phase, hasConnected: hasConnected, notOpened: notOpened)
        }
        return LedgerStepsProgress(stage: stage + 1, phase: phase, hasConnected: hasConnected, notOpened: notOpened.merging([stage: .skipped]) { $1 })
    }

    /// Set once the work has gone on past the stage without its app: a required app ends the work instead.
    func skip(at index: Int) -> Skip? {
        index < stage ? notOpened[index] : nil
    }

    private func stage(of app: LedgerApp, in apps: [LedgerApp]) -> Int? {
        apps.indices.dropFirst(stage).first { apps[$0] == app }
    }
}
