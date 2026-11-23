import TKUIKit
import UIKit

/// Plays the animation through the tab bar item's own image, so the system bar draws every frame
/// the way it draws the static icon: the same tint, the same glass, and in Duo's vertical bar too.
@MainActor
final class ItemImageLottieTabBarController: NSObject {
    /// The item, not its index: the tab list can change mid-animation.
    fileprivate struct Playback {
        let item: UITabBarItem
        let image: UIImage?
        let selectedImage: UIImage?
        let animation: TKLottieFrames
        let startTime: CFTimeInterval
        var shownFrame: Int
    }

    private weak let tabBarController: UITabBarController?
    private let resources: [LottieResource]
    private var playback: Playback?
    private var displayLink: CADisplayLink?

    init?(
        tabBarController: UITabBarController,
        items: [LottieResourceConvertible]
    ) {
        self.tabBarController = tabBarController
        let resources = items.compactMap(\.asLottieResource)
        guard resources.count == items.count else {
            return nil
        }
        self.resources = resources
        super.init()
        startAppStateObservation()
        prerenderAnimations()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ItemImageLottieTabBarController: LottieTabBarControlling {
    func playAnimation(at index: Int) {
        stopPlayback()
        guard
            let item = tabBarController?.tabBar.items?[safe: index],
            let animation = renderedAnimation(at: index)
        else {
            return
        }
        let firstFrame = animation.image(at: 0)
        playback = Playback(
            item: item,
            image: item.image,
            selectedImage: item.selectedImage,
            animation: animation,
            startTime: CACurrentMediaTime(),
            shownFrame: 0
        )
        show(firstFrame, on: item)

        let displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        let framerate = Float(animation.framerate)
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: framerate, maximum: framerate, preferred: framerate)
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func uninstall() {
        NotificationCenter.default.removeObserver(self)
        stopPlayback()
    }
}

private extension ItemImageLottieTabBarController {
    @objc
    func step(_ displayLink: CADisplayLink) {
        guard var playback else {
            stopPlayback()
            return
        }
        // The first tick can target a time before the tap.
        let elapsed = max(0, displayLink.targetTimestamp - playback.startTime)
        let frame = Int(elapsed * playback.animation.framerate)
        guard frame < playback.animation.count else {
            stopPlayback()
            return
        }
        guard frame != playback.shownFrame else { return }
        playback.shownFrame = frame
        self.playback = playback
        show(playback.animation.image(at: frame), on: playback.item)
    }

    func show(_ frame: UIImage, on item: UITabBarItem) {
        item.image = frame
        item.selectedImage = frame
    }

    func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
        guard let playback else { return }
        self.playback = nil
        playback.item.image = playback.image
        playback.item.selectedImage = playback.selectedImage
    }

    func startAppStateObservation() {
        for name in LottieTabBarRecovery.notificationNames {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(recoverAfterAppStateChange),
                name: name,
                object: nil
            )
        }
    }

    @objc
    func recoverAfterAppStateChange() {
        stopPlayback()
    }

    /// Rendering a tab's frames takes tens of milliseconds, so it happens one tab per run loop
    /// pass, once per launch, rather than on the tap that switches tabs. The frames outlive this
    /// controller, which is rebuilt on every tab state update and, on Duo, on every bar edge change.
    func prerenderAnimations(from index: Int = 0) {
        guard resources.indices.contains(index) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            _ = renderedAnimation(at: index)
            prerenderAnimations(from: index + 1)
        }
    }

    /// Frames are template images: only their alpha counts, and the bar tints them itself.
    func renderedAnimation(at index: Int) -> TKLottieFrames? {
        guard let resource = resources[safe: index] else { return nil }
        let iconSize = tabBarController?.tabBar.items?[safe: index]?.image?.size ?? .defaultIconSize
        let animation = TKLottieFrames.frames(resource, size: iconSize, scale: UIScreen.main.scale, colors: .template)
        animation?.renderAll()
        return animation
    }
}

private extension CGSize {
    static let defaultIconSize = CGSize(width: 28, height: 28)
}
