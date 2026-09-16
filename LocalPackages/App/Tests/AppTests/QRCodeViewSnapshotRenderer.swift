import SwiftUI
@testable import TKUIKit
import UIKit

enum QRCodeViewSnapshotRenderer {
    @MainActor
    static func render<Content: View>(
        _ view: Content,
        size: CGSize
    ) async throws -> UIImage {
        let renderedView = view
            .frame(width: size.width, height: size.height)
            .environment(\.displayScale, UIScreen.main.scale)
            .environment(\.qrCodeTapReaderEnabled, false)

        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: renderedView)
            renderer.scale = UIScreen.main.scale
            if let image = renderer.uiImage {
                return image
            }
        }

        let rootViewController = UIViewController()
        let hostingController = TKHostingController(content: renderedView)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        rootViewController.addChild(hostingController)
        rootViewController.view.addSubview(hostingController.view)
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = UIColor.white
        hostingController.didMove(toParent: rootViewController)

        rootViewController.view.setNeedsLayout()
        rootViewController.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            hostingController.view.layer.render(in: context.cgContext)
        }

        hostingController.willMove(toParent: nil as UIViewController?)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        window.isHidden = true

        return image
    }
}
