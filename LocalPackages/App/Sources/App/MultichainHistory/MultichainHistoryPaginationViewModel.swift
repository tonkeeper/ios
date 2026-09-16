import Foundation
import KeeperCore

@MainActor
final class MultichainHistoryPaginationViewModel {
    private let walletId: String
    private let limit: Int
    private let category: MultichainHistoryCategory
    private let hideDust: Bool?
    private let multichainService: MultichainService

    private var activeTask: Task<Void, Never>?
    private var activeGeneration: Int?
    private var nextGeneration = 0

    init(
        walletId: String,
        limit: Int,
        category: MultichainHistoryCategory,
        hideDust: Bool? = nil,
        multichainService: MultichainService
    ) {
        self.walletId = walletId
        self.limit = limit
        self.category = category
        self.hideDust = hideDust
        self.multichainService = multichainService
    }

    func start(
        cursor: String?,
        onSuccess: @escaping (MultichainWalletActivitiesPage) -> Void,
        onFailure: @escaping (MultichainServiceError) -> Void
    ) -> Task<Void, Never> {
        cancel()
        nextGeneration += 1
        let generation = nextGeneration
        activeGeneration = generation

        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await self.loadNextPage(
                cursor: cursor,
                generation: generation,
                onSuccess: onSuccess,
                onFailure: onFailure
            )
        }
        activeTask = task
        return task
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        activeGeneration = nil
    }
}

private extension MultichainHistoryPaginationViewModel {
    func loadNextPage(
        cursor: String?,
        generation: Int,
        onSuccess: @escaping (MultichainWalletActivitiesPage) -> Void,
        onFailure: @escaping (MultichainServiceError) -> Void
    ) async {
        defer {
            if activeGeneration == generation {
                activeTask = nil
                activeGeneration = nil
            }
        }

        let page: MultichainWalletActivitiesPage
        do {
            page = try await category.fetchActivities(
                using: multichainService,
                walletId: walletId,
                limit: limit,
                cursor: cursor,
                hideDust: hideDust
            )
        } catch {
            guard isCurrent(generation), !Task.isCancelled, !isCancelled(error) else {
                return
            }
            onFailure(error)
            return
        }

        guard isCurrent(generation), !Task.isCancelled else {
            return
        }

        onSuccess(page)
    }

    func isCurrent(_ generation: Int) -> Bool {
        activeGeneration == generation
    }

    func isCancelled(_ error: MultichainServiceError) -> Bool {
        if case .cancelled = error {
            return true
        }
        return false
    }
}
