import Foundation
import KeeperCore
import TKCore

protocol AllUpdatesModuleOutput: AnyObject {
    var didSelectStory: ((Story) -> Void)? { get set }
}

protocol AllUpdatesViewModel: AnyObject {
    var didUpdateSnapshot: ((AllUpdates.Snapshot) -> Void)? { get set }

    func viewDidLoad()
}

final class AllUpdatesViewModelImplementation: AllUpdatesViewModel, AllUpdatesModuleOutput {
    // MARK: - AllUpdatesModuleOutput

    var didSelectStory: ((Story) -> Void)?

    // MARK: - AllUpdatesViewModel

    var didUpdateSnapshot: ((AllUpdates.Snapshot) -> Void)?

    func viewDidLoad() {
        storiesStore.addObserver(self) { observer, _ in
            DispatchQueue.main.async {
                observer.updateSnapshot()
            }
        }
        updateSnapshot()
    }

    // MARK: - State

    private let storiesStore: StoriesStore

    // MARK: - Init

    init(storiesStore: StoriesStore) {
        self.storiesStore = storiesStore
    }

    // MARK: - Private

    private func updateSnapshot() {
        let state = storiesStore.state
        let items = state.stories.map { story in
            AllUpdates.Item(
                id: story.story_id,
                story: story,
                selectionHandler: { [weak self] in
                    self?.didSelectStory?(story)
                }
            )
        }

        var snapshot = AllUpdates.Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)

        didUpdateSnapshot?(snapshot)
    }
}
