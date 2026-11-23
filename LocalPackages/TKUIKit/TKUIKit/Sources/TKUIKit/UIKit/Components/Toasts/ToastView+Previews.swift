import SwiftUI
import UIKit

@available(iOS 17.0, *)
#Preview("Toasts", traits: .fixedLayout(width: 390, height: 420)) {
    VStack(spacing: 16) {
        ToastPreviewHost(variant: .label).frame(height: 48)
        ToastPreviewHost(variant: .loading).frame(height: 48)
        ToastPreviewHost(variant: .progress).frame(height: 56)
        ToastPreviewHost(variant: .done).frame(height: 56)
        ToastPreviewHost(variant: .failed).frame(height: 56)
        ToastPreviewHost(variant: .plain).frame(height: 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
private struct ToastPreviewHost: UIViewRepresentable {
    enum Variant {
        case label
        case loading
        case progress
        case done
        case failed
        case plain
    }

    let variant: Variant

    /// The toast sits in its container the way ToastPresenter places it in the toast window.
    func makeUIView(context _: Context) -> UIView {
        TKPreview.pinTheme(.deepBlue)
        let container = UIView()
        let toastView = ToastView(model: model)
        container.addSubview(toastView)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            toastView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toastView.leftAnchor.constraint(greaterThanOrEqualTo: container.leftAnchor, constant: 20)
                .withPriority(.defaultHigh),
            toastView.rightAnchor.constraint(lessThanOrEqualTo: container.rightAnchor, constant: -20)
                .withPriority(.defaultHigh),
        ])
        return container
    }

    func updateUIView(_: UIView, context _: Context) {}

    private var model: ToastView.Model {
        switch variant {
        case .label:
            ToastView.Model(title: "Label", shape: .oval, isActivity: false)
        case .loading:
            ToastView.Model(title: "Loading", shape: .oval, isActivity: true)
        case .progress:
            ToastView.Model(
                title: "Swapping",
                subtitle: "100 GRAM",
                shape: .oval,
                isActivity: false,
                avatar: .image(.image(.TKUIKit.Icons.Size44.tonLogo), isLoading: true),
                showsDisclosure: true
            )
        case .done:
            ToastView.Model(
                title: "Swapped",
                subtitle: "100 GRAM",
                shape: .oval,
                isActivity: false,
                avatar: .icon(.TKUIKit.Icons.Size32.checkmarkCircle, tintColor: .Accent.green),
                showsDisclosure: true
            )
        case .failed:
            ToastView.Model(
                title: "Swap failed",
                subtitle: "100 GRAM",
                shape: .oval,
                isActivity: false,
                avatar: .icon(.TKUIKit.Icons.Size32.xmarkCircle, tintColor: .Accent.orange),
                showsDisclosure: true
            )
        case .plain:
            ToastView.Model(
                title: "Copied",
                shape: .oval,
                isActivity: false,
                icon: .TKUIKit.Icons.Size16.checkmarkCircle,
                iconTintColor: .Accent.green
            )
        }
    }
}
