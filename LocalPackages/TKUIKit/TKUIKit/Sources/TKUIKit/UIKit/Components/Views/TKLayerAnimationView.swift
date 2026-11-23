import UIKit

/// A view that runs Core Animation animations on its layers and keeps them through what drops them:
/// leaving the window and the app going to the background. The render server moves the layers, so a
/// running animation costs the main thread nothing per frame.
///
/// The animations are on the layers while the view animates and is in a window. A subclass builds them
/// in `addAnimations()`, takes them off in `removeAnimations()` and sets its layer colors in `updateColors()`,
/// which also runs when the interface style changes.
public class TKLayerAnimationView: UIView {
    public private(set) var isAnimating = false

    private var foregroundObserver: NSObjectProtocol?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartAnimations()
        }
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: TKLayerAnimationView, _: UITraitCollection) in
                self?.updateColors()
            }
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    public func startAnimation() {
        isAnimating = true
        restartAnimations()
    }

    public func stopAnimation() {
        isAnimating = false
        removeAnimations()
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        restartAnimations()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0), traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    /// Builds the animations again from the current state, for example after what they show changed.
    func restartAnimations() {
        removeAnimations()
        guard isAnimating, window != nil else { return }
        addAnimations()
    }

    func addAnimations() {}

    func removeAnimations() {}

    func updateColors() {}
}
