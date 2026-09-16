import Kingfisher
import SwiftUI
import TKUIKit
import UIKit

/// `ImageRenderer` is the iOS 16+ path; SwiftUI does not commit off-screen rendering, so
/// iOS 15 falls back to hosting the card in an off-screen window.
@MainActor
enum PerpsSharePositionRenderer {
    private static let previewHorizontalInset: CGFloat = 16

    static func image(model: PerpsSharePositionCardModel, fittingIn view: UIView) async -> UIImage? {
        let displayScale = view.window?.screen.scale
        let resolvedModel = await loadingRemoteIcon(model, displayScale: displayScale ?? view.traitCollection.displayScale)
        return image(
            model: resolvedModel,
            containerWidth: resolvedContainerWidth(for: view),
            displayScale: displayScale,
            windowScene: view.window?.windowScene,
            userInterfaceStyle: view.traitCollection.userInterfaceStyle
        )
    }

    static func loadingRemoteIcon(
        _ model: PerpsSharePositionCardModel,
        displayScale: CGFloat
    ) async -> PerpsSharePositionCardModel {
        guard model.iconImage == nil, let iconURL = model.iconURL else { return model }
        return model.withLoadedIcon(await loadIcon(iconURL, displayScale: displayScale))
    }

    private static func loadIcon(_ url: URL, displayScale: CGFloat) async -> UIImage? {
        let source = DappIconSource(url: url)
        let pixelSide = PerpsSharePositionCard.iconSide * displayScale
        return await withCheckedContinuation { continuation in
            _ = KingfisherManager.shared.retrieveImage(
                with: source.source,
                options: [
                    .alternativeSources(source.alternativeSources),
                    .processor(DownsamplingImageProcessor(size: CGSize(width: pixelSide, height: pixelSide))),
                ]
            ) { result in
                continuation.resume(returning: try? result.get().image)
            }
        }
    }

    static func image(
        model: PerpsSharePositionCardModel,
        containerWidth: CGFloat,
        displayScale: CGFloat? = nil,
        windowScene: UIWindowScene? = nil,
        userInterfaceStyle: UIUserInterfaceStyle? = nil
    ) -> UIImage? {
        let width = floor(containerWidth - previewHorizontalInset * 2)
        guard width > 0, width.isFinite else { return nil }
        let scale = validScale(displayScale) ?? validScale(windowScene?.screen.scale) ?? UIScreen.main.scale
        // Off-screen rendering has no theme provider above the card, so resolve
        // the scheme from the presenting context's traits explicitly.
        let resolvedTheme = TKResolvedTheme(
            theme: TKThemeManager.shared.theme,
            isSystemDark: (userInterfaceStyle ?? UIScreen.main.traitCollection.userInterfaceStyle) == .dark
        )
        let card = PerpsSharePositionCard(model: model)
            .environment(\.tkResolvedTheme, resolvedTheme)
            .frame(width: width)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: card)
            renderer.scale = scale
            return renderer.uiImage
        }
        return snapshotViaWindow(card, width: width, displayScale: scale, windowScene: windowScene)
    }

    private static func resolvedContainerWidth(for view: UIView) -> CGFloat {
        validWidth(view.window?.bounds.width) ?? validWidth(view.bounds.width) ?? UIScreen.main.bounds.width
    }

    private static func validWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width > 0, width.isFinite else { return nil }
        return width
    }

    private static func validScale(_ scale: CGFloat?) -> CGFloat? {
        guard let scale, scale > 0, scale.isFinite else { return nil }
        return scale
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    private static func snapshotViaWindow(
        _ card: some View,
        width: CGFloat,
        displayScale: CGFloat,
        windowScene: UIWindowScene?
    ) -> UIImage? {
        guard let scene = windowScene ?? activeWindowScene() else { return nil }

        let host = TKHostingController(content: card)
        host.view.backgroundColor = .clear
        let height = ceil(host.view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height)
        guard height > 0, height.isFinite else { return nil }
        let size = CGSize(width: width, height: height)
        host.view.frame = CGRect(origin: .zero, size: size)

        let window = UIWindow(windowScene: scene)
        window.frame = host.view.frame
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = displayScale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}
