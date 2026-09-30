import Foundation
import KeeperCore

/// Holds the market read a draft reviews against, and decides when to ask for a
/// new one. One copy of that policy: a draft owns an instance and says only what
/// to load and what to recompute, never how the read is kept.
@MainActor
final class PerpsDraftReviewer {
    private var reviewer: (any PerpetualReviewer)?
    private var loadTask: Task<Void, Never>?

    var current: (any PerpetualReviewer)? {
        reviewer
    }

    /// True while nothing is loaded or the read is worth replacing.
    var needsLoad: Bool {
        reviewer?.isStale != false
    }

    func loadIfNeeded(
        _ load: @escaping () async -> (any PerpetualReviewer)?,
        then recompute: @escaping () -> Void
    ) {
        guard loadTask == nil else { return }
        loadTask = Task { @MainActor [weak self] in
            defer { self?.loadTask = nil }
            guard let loaded = await load(), let self else { return }
            self.reviewer = loaded
            recompute()
        }
    }
}
