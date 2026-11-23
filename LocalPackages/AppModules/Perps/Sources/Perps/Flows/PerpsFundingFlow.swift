import PerpsModels
import TKLogging

@MainActor
final class PerpsFundingFlow {
    enum DepositStart {
        case unavailable
        case keyNotKept
        case ready(any PerpsDepositing, passcodeProvider: @Sendable () async -> String?)
    }

    private let makeDeposit: @MainActor () -> (any PerpsDepositing)?
    private let passcodeProvider: @Sendable () async -> String?
    private(set) var depositKeyTask: Task<Void, Never>?
    /// The funding asset list being loaded for the picker; a tap meanwhile is ignored.
    private(set) var fundingAssetsTask: Task<Void, Never>?

    init(makeDeposit: @escaping @MainActor () -> (any PerpsDepositing)?, passcodeProvider: @escaping @Sendable () async -> String?) {
        self.makeDeposit = makeDeposit
        self.passcodeProvider = passcodeProvider
    }

    func startDeposit(_ onStart: @escaping @MainActor (DepositStart) -> Void) {
        guard depositKeyTask == nil else { return }
        PerpsOperationLog.event("entry", outcome: "started", fields: ["flow": "deposit"])
        guard let deposit = makeDeposit() else {
            PerpsOperationLog.event("entry", outcome: "unavailable", source: "wallet", fields: ["flow": "deposit"])
            onStart(.unavailable)
            return
        }
        guard !deposit.holdsTradingKey else {
            onStart(.ready(deposit, passcodeProvider: passcodeProvider))
            return
        }
        depositKeyTask = Task { @MainActor [weak self, passcodeProvider] in
            defer { self?.depositKeyTask = nil }
            guard let passcode = await passcodeProvider() else {
                PerpsOperationLog.event("unlock", outcome: "cancelled", source: "user", fields: ["flow": "deposit"])
                return
            }
            guard await deposit.keepTradingKey(passcode: passcode) else {
                PerpsOperationLog.event("trading_key", outcome: "failed", source: "wallet", fields: ["flow": "deposit"])
                onStart(.keyNotKept)
                return
            }
            onStart(.ready(deposit, passcodeProvider: { passcode }))
        }
    }

    func loadAssets(
        _ load: @escaping @MainActor () async -> [PerpsDepositSourceOption],
        onLoad: @escaping @MainActor ([PerpsDepositSourceOption]) -> Void
    ) {
        guard fundingAssetsTask == nil else { return }
        fundingAssetsTask = Task { @MainActor [weak self] in
            let options = await load()
            guard let self else { return }
            fundingAssetsTask = nil
            guard !Task.isCancelled, !options.isEmpty else { return }
            onLoad(options)
        }
    }
}
