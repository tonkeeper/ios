import SwiftUI
import UIKit

public struct AnchorViewResolver: View {
    public var onResolveView: (UIView) -> Void

    public init(onResolveView: @escaping (UIView) -> Void) {
        self.onResolveView = onResolveView
    }

    public var body: some View {
        AnchorViewRepresentable(onResolveView: onResolveView)
            .allowsHitTesting(false)
    }
}

private struct AnchorViewRepresentable: UIViewRepresentable {
    var onResolveView: (UIView) -> Void

    func makeUIView(context _: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            onResolveView(view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        DispatchQueue.main.async {
            onResolveView(uiView)
        }
    }
}
