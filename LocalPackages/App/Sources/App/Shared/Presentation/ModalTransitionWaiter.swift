import UIKit

@MainActor
enum ModalTransitionWaiter {
    typealias Wait = @MainActor (UIViewController) async -> Void

    static func wait(from source: UIViewController) async {
        while isTransitioning(from: source), !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    static func perform(from source: UIViewController, wait: Wait, action: () -> Void) async {
        repeat {
            guard !Task.isCancelled else { return }
            await wait(source)
        } while isTransitioning(from: source)
        guard !Task.isCancelled else {
            return
        }
        action()
    }

    private static func isTransitioning(from source: UIViewController) -> Bool {
        var controller: UIViewController? = source
        while let current = controller {
            if current.transitionCoordinator != nil || current.isBeingPresented || current.isBeingDismissed {
                return true
            }
            controller = current.presentedViewController
        }
        return false
    }
}
