import Foundation

public final class SwapAssetsStore: Store<SwapAssetsStore.Event, [SwapAsset]> {
    public enum Event {
        case didUpdateAssets([SwapAsset])
    }

    private let repository: SwapAssetsRepository

    override public func createInitialState() -> [SwapAsset] {
        (try? repository.getAssets()) ?? []
    }

    init(repository: SwapAssetsRepository) {
        self.repository = repository
        super.init(state: (try? repository.getAssets()) ?? [])
    }

    @discardableResult
    public func setAssets(_ assets: [SwapAsset]) async -> [SwapAsset] {
        await withCheckedContinuation { continuation in
            setAssets(assets) { assets in
                continuation.resume(returning: assets)
            }
        }
    }

    public func setAssets(_ assets: [SwapAsset], completion: @escaping ([SwapAsset]) -> Void) {
        do {
            try repository.saveAssets(assets)
            updateState { _ in
                StateUpdate(newState: assets)
            } completion: { [weak self] state in
                self?.sendEvent(.didUpdateAssets(state))
                completion(state)
            }
        } catch {
            completion(state)
        }
    }
}
