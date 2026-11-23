import QuartzCore

/// A display link calls back before the commit of its frame, so callback `n + 1` comes after `n` commits.
@MainActor
final class AfterFrameCommits: NSObject {
    private let action: () -> Void
    private var remainingCallbacks: Int

    private init(commits: Int, action: @escaping () -> Void) {
        self.action = action
        self.remainingCallbacks = commits + 1
    }

    static func run(after commits: Int, _ action: @escaping () -> Void) {
        let target = AfterFrameCommits(commits: commits, action: action)
        CADisplayLink(target: target, selector: #selector(tick)).add(to: .main, forMode: .common)
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        remainingCallbacks -= 1
        guard remainingCallbacks == 0 else { return }
        displayLink.invalidate()
        action()
    }
}
