import AppUI
import Foundation
import KeeperCore

struct PredictionsSnapshot: Equatable, Sendable {
    let balance: String?
    let cards: [PredictionCardViewData]
}

@MainActor
final class MultichainWalletPredictionsSectionViewModel: ObservableObject {
    @Published private(set) var state: PredictionsSectionState?

    var onOpenPredictions: (() -> Void)?
    var onOpenMarket: ((String) -> Void)?
    var onSelectOutcome: ((String, PredictionOutcome) -> Void)?

    private let snapshots: () -> AsyncThrowingStream<PredictionsSnapshot, Error>
    private let appSettingsStore: AppSettingsStore
    private var snapshot: PredictionsSnapshot?
    private var snapshotsTask: Task<Void, Never>?
    private var isOnScreen = false

    init(
        snapshots: @escaping () -> AsyncThrowingStream<PredictionsSnapshot, Error>,
        appSettingsStore: AppSettingsStore
    ) {
        self.snapshots = snapshots
        self.appSettingsStore = appSettingsStore
        appSettingsStore.addObserver(self) { observer, event in
            guard case .didUpdateIsSecureMode = event else { return }
            Task { @MainActor in observer.applySnapshot() }
        }
    }

    deinit {
        snapshotsTask?.cancel()
    }

    func onAppear() {
        guard !isOnScreen else { return }
        isOnScreen = true
        subscribe()
    }

    func onDisappear() {
        guard isOnScreen else { return }
        isOnScreen = false
        snapshotsTask?.cancel()
        snapshotsTask = nil
    }

    func refresh() {
        guard isOnScreen else { return }
        snapshot = nil
        subscribe()
    }

    func openPredictions() {
        onOpenPredictions?()
    }

    func openMarket(_ card: PredictionCardViewData) {
        onOpenMarket?(card.id)
    }

    func selectOutcome(_ card: PredictionCardViewData, _ outcome: PredictionOutcome) {
        onSelectOutcome?(card.id, outcome)
    }
}

private extension MultichainWalletPredictionsSectionViewModel {
    func subscribe() {
        snapshotsTask?.cancel()
        if snapshot == nil {
            state = .loading
        }
        let stream = snapshots()
        snapshotsTask = Task { [weak self] in
            do {
                for try await snapshot in stream {
                    guard let self, !Task.isCancelled else { return }
                    self.snapshot = snapshot
                    applySnapshot()
                }
            } catch {}
            guard let self, !Task.isCancelled, snapshot == nil else { return }
            state = nil
        }
    }

    func applySnapshot() {
        guard let snapshot else { return }
        guard !snapshot.cards.isEmpty else {
            state = nil
            return
        }
        guard appSettingsStore.getState().isSecureMode else {
            state = .cards(balance: snapshot.balance, cards: snapshot.cards)
            return
        }
        state = .cards(
            balance: snapshot.balance.map { _ in .secureModeValueShort },
            cards: snapshot.cards.map(\.masked)
        )
    }
}

private extension PredictionCardViewData {
    var masked: PredictionCardViewData {
        guard case let .position(position) = footer else { return self }
        return PredictionCardViewData(
            id: id,
            imageSource: imageSource,
            title: title,
            subtitle: subtitle,
            footer: .position(
                PredictionPositionViewData(
                    title: position.title,
                    titleColor: position.titleColor,
                    amount: .secureModeValueShort,
                    change: .secureModeValueShort,
                    changeColor: position.changeColor
                )
            )
        )
    }
}
