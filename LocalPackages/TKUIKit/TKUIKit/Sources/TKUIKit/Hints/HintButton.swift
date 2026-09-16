import SwiftUI
import UIKit

public struct HintButton<Label: View, Content: View>: View {
    private let configuration: HintConfiguration
    private let doubleTapAction: (() -> Void)?
    private let content: (HintPosition.Direction?) -> Content
    private let label: () -> Label

    @StateObject private var sourceViewStore = HintSourceViewStore()
    @State private var isPressed = false

    public init(
        configuration: HintConfiguration,
        doubleTapAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (HintPosition.Direction?) -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.configuration = configuration
        self.doubleTapAction = doubleTapAction
        self.content = content
        self.label = label
    }

    public var body: some View {
        Group {
            if let doubleTapAction {
                label()
                    .tkTapAnimation(isPressed: isPressed, haptic: .light)
                    .overlay(
                        HintButtonTapView(
                            onSingleTap: toggleHint,
                            onDoubleTap: {
                                dismissHint()
                                doubleTapAction()
                            },
                            onPressChanged: { isPressed in
                                self.isPressed = isPressed
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    )
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        toggleHint()
                    }
            } else {
                Button(action: toggleHint) {
                    label()
                }
                .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
            }
        }
        .background(
            TKHintSourceViewResolver { sourceView in
                sourceViewStore.view = sourceView
            }
        )
        .onDisappear {
            HintController.dismiss(sourceView: sourceViewStore.view)
        }
    }

    private func toggleHint() {
        guard let sourceView = sourceViewStore.view else { return }

        HintController.toggle(
            sourceView: sourceView,
            configuration: configuration,
            contentViewControllerProvider: { position in
                let hostingController = TKHostingController(content: content(position))
                hostingController.view.backgroundColor = .clear
                hostingController.preferredContentSize = preferredContentSize(for: hostingController)
                return hostingController
            }
        )
    }

    private func dismissHint() {
        HintController.dismiss(sourceView: sourceViewStore.view)
    }

    private func preferredContentSize<Root: View>(
        for hostingController: UIHostingController<Root>
    ) -> CGSize {
        let fittingSize = hostingController.sizeThatFits(
            in: CGSize(
                width: configuration.maximumWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        )

        let width: CGFloat
        if fittingSize.width.isFinite, fittingSize.width > 0 {
            width = min(configuration.maximumWidth, ceil(fittingSize.width))
        } else {
            width = configuration.maximumWidth
        }

        return CGSize(
            width: width,
            height: ceil(fittingSize.height)
        )
    }
}

private struct HintButtonTapView: UIViewRepresentable {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onPressChanged: (Bool) -> Void

    func makeUIView(context: Context) -> HintButtonTapUIView {
        let view = HintButtonTapUIView()
        view.backgroundColor = .clear
        view.coordinator = context.coordinator

        let singleTapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.singleTap)
        )
        singleTapRecognizer.numberOfTapsRequired = 1

        let doubleTapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.doubleTap)
        )
        doubleTapRecognizer.numberOfTapsRequired = 2

        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        view.addGestureRecognizer(singleTapRecognizer)
        view.addGestureRecognizer(doubleTapRecognizer)

        return view
    }

    func updateUIView(_ uiView: HintButtonTapUIView, context: Context) {
        uiView.coordinator = context.coordinator
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPressChanged = onPressChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSingleTap: onSingleTap,
            onDoubleTap: onDoubleTap,
            onPressChanged: onPressChanged
        )
    }

    final class Coordinator: NSObject {
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void
        var onPressChanged: (Bool) -> Void

        init(
            onSingleTap: @escaping () -> Void,
            onDoubleTap: @escaping () -> Void,
            onPressChanged: @escaping (Bool) -> Void
        ) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onPressChanged = onPressChanged
        }

        @objc
        func singleTap() {
            onSingleTap()
        }

        @objc
        func doubleTap() {
            onDoubleTap()
        }
    }

    final class HintButtonTapUIView: UIView {
        weak var coordinator: Coordinator?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            coordinator?.onPressChanged(true)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            coordinator?.onPressChanged(false)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            coordinator?.onPressChanged(false)
        }
    }
}
