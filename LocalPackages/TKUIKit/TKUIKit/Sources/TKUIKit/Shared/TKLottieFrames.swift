import Lottie
import UIKit

/// A Lottie animation drawn into one image per frame. System glass glitches over a live animation
/// view, so glass shows an animation as these images, drawn the way it draws a static icon.
/// A frame is drawn the first time it is asked for, in a fraction of a millisecond; drawing them
/// all takes tens of milliseconds.
@MainActor
public final class TKLottieFrames {
    public enum Colors: Hashable {
        /// Every fill and stroke is opaque: only the alpha counts, and whoever shows the frames tints them.
        case template
        case original
    }

    private struct Key: Hashable {
        let name: String
        let bundlePath: String
        let subdirectory: String?
        let width: CGFloat
        let height: CGFloat
        let contentWidth: CGFloat?
        let contentHeight: CGFloat?
        let scale: CGFloat
        let colors: Colors
    }

    public let framerate: Double
    public let count: Int

    public var duration: TimeInterval {
        Double(count) / framerate
    }

    private struct Drawing {
        let animationView: LottieAnimationView
        let renderer: UIGraphicsImageRenderer
    }

    /// Released with its layer tree once every frame is drawn: the images are all that is left to show.
    private var drawing: Drawing?
    private let startFrame: AnimationFrameTime
    private let scale: CGFloat
    private let animationScale: CGFloat
    private let colors: Colors
    private var images: [UIImage?]
    private var undrawnCount: Int

    /// The frames depend only on these inputs, so an animation is set up and each frame drawn once.
    private static var cache = [Key: TKLottieFrames]()

    /// - Parameters:
    ///   - size: The size of every frame. The animation is centred in it, and what falls outside is cut off.
    ///   - contentSize: The size the animation's canvas is drawn at; `nil` keeps the canvas's own size.
    ///   - scale: The screen scale of the frames.
    public static func frames(
        _ resource: LottieResource,
        size: CGSize,
        contentSize: CGSize? = nil,
        scale: CGFloat,
        colors: Colors
    ) -> TKLottieFrames? {
        let key = Key(
            name: resource.name,
            bundlePath: resource.bundle.bundlePath,
            subdirectory: resource.subdirectory,
            width: size.width,
            height: size.height,
            contentWidth: contentSize?.width,
            contentHeight: contentSize?.height,
            scale: scale,
            colors: colors
        )
        if let frames = cache[key] {
            return frames
        }
        guard let frames = TKLottieFrames(
            resource,
            size: size,
            contentSize: contentSize,
            scale: scale,
            colors: colors
        ) else {
            return nil
        }
        cache[key] = frames
        return frames
    }

    /// The frame at `index`, clamped to the animation, drawn on first use.
    public func image(at index: Int) -> UIImage {
        let index = min(max(index, 0), count - 1)
        if let image = images[index] {
            return image
        }
        guard let drawing else {
            // Not reached: the drawing goes only once every frame is drawn.
            return UIImage()
        }
        let animationView = drawing.animationView
        animationView.currentFrame = startFrame + AnimationFrameTime(index)
        // Outside a window the layers, masks included, keep a 1x backing store. The frame can
        // add layers, so the scale is set on every frame, before it is drawn.
        animationView.layer.setContentsScaleRecursively(scale * animationScale)
        animationView.forceDisplayUpdate()
        let image = drawing.renderer.image { context in
            context.cgContext.scaleBy(x: animationScale, y: animationScale)
            animationView.layer.render(in: context.cgContext)
        }
        let frame = switch colors {
        case .template:
            image.withRenderingMode(.alwaysTemplate)
        case .original:
            image.withRenderingMode(.alwaysOriginal)
        }
        images[index] = frame
        undrawnCount -= 1
        if undrawnCount == 0 {
            self.drawing = nil
        }
        return frame
    }

    /// Draws every frame now, for a player that must not draw while it plays.
    public func renderAll() {
        for index in 0 ..< count {
            _ = image(at: index)
        }
    }

    /// Uncached: `frames(_:size:contentSize:scale:colors:)` shares one per set of inputs.
    init?(
        _ resource: LottieResource,
        size: CGSize,
        contentSize: CGSize?,
        scale: CGFloat,
        colors: Colors
    ) {
        guard let animation = LottieAnimation.named(
            resource.name,
            bundle: resource.bundle,
            subdirectory: resource.subdirectory
        ) else {
            return nil
        }
        let animationScale: CGFloat
        if let contentSize {
            guard animation.size.width > 0, animation.size.height > 0 else { return nil }
            animationScale = min(contentSize.width / animation.size.width, contentSize.height / animation.size.height)
        } else {
            animationScale = 1
        }
        let count = Int((animation.endFrame - animation.startFrame).rounded(.down)) + 1
        guard animationScale > 0, count > 0 else { return nil }

        let animationView = LottieAnimationView(
            animation: animation,
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        // Laid out in the canvas's own units; the context scales the drawing up to `size`.
        animationView.frame = CGRect(
            origin: .zero,
            size: CGSize(width: size.width / animationScale, height: size.height / animationScale)
        )
        animationView.contentMode = .center
        if case .template = colors {
            let opaque = ColorValueProvider(LottieColor(r: 0, g: 0, b: 0, a: 1))
            animationView.setValueProvider(opaque, keypath: AnimationKeypath(keypath: "**.Fill 1.Color"))
            animationView.setValueProvider(opaque, keypath: AnimationKeypath(keypath: "**.Stroke 1.Color"))
        }
        animationView.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        drawing = Drawing(
            animationView: animationView,
            renderer: UIGraphicsImageRenderer(size: size, format: format)
        )
        startFrame = animation.startFrame
        framerate = animation.framerate
        self.count = count
        self.scale = scale
        self.animationScale = animationScale
        self.colors = colors
        images = Array(repeating: nil, count: count)
        undrawnCount = count
    }
}

private extension CALayer {
    func setContentsScaleRecursively(_ scale: CGFloat) {
        if contentsScale != scale {
            contentsScale = scale
            setNeedsDisplay()
        }
        mask?.setContentsScaleRecursively(scale)
        sublayers?.forEach { $0.setContentsScaleRecursively(scale) }
    }
}
