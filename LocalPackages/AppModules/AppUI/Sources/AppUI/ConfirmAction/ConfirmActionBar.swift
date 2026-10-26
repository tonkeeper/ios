import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

/// The UIKit slider and process container every confirmation already uses: UI tests find the
/// handle by its accessibility identifier and swipe it as a UIKit control.
struct ConfirmActionBar: UIViewRepresentable {
    let state: ConfirmActionBarState

    /// `TKSlider` insets its 56pt track by 16pt vertically; the button gets the same insets.
    static let height: CGFloat = 88
    private static let verticalInset: CGFloat = 16

    func makeUIView(context: Context) -> TKProcessContainerView {
        let view = TKProcessContainerView(successTitle: state.successTitle, errorTitle: state.failureTitle)
        context.coordinator.install(state.kind, in: view)
        update(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: TKProcessContainerView, context: Context) {
        if context.coordinator.kind != state.kind {
            context.coordinator.install(state.kind, in: view)
        }
        update(view, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func update(_ view: TKProcessContainerView, coordinator: Coordinator) {
        view.successTitle = state.successTitle
        view.errorTitle = state.failureTitle
        let returnedToIdle = state.process == .idle && coordinator.process != .idle
        let reEnabled = state.isEnabled && !coordinator.isEnabled
        if returnedToIdle || reEnabled || state.resetToken != coordinator.resetToken {
            coordinator.slider?.reset()
        }
        coordinator.process = state.process
        coordinator.isEnabled = state.isEnabled
        coordinator.resetToken = state.resetToken
        view.state = state.process.containerState

        let onConfirm = state.onConfirm
        if let slider = coordinator.slider {
            slider.isEnable = state.isEnabled
            slider.swipeHandleAccessibilityIdentifier = state.accessibilityIdentifier
            slider.didConfirm = onConfirm
        }
        if let button = coordinator.button, case let .button(title) = state.kind {
            var configuration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
            configuration.content = .init(title: .plainString(title))
            configuration.isEnabled = state.isEnabled
            configuration.action = onConfirm
            button.configuration = configuration
        }
    }

    final class Coordinator {
        var kind: ConfirmActionBarState.Kind?
        var process: ConfirmActionBarState.Process = .idle
        var isEnabled = true
        var resetToken = 0
        var slider: TKSlider?
        var button: TKButton?

        func install(_ kind: ConfirmActionBarState.Kind, in view: TKProcessContainerView) {
            self.kind = kind
            switch kind {
            case let .slider(title, subtitle):
                let slider = TKSlider()
                let text = NSMutableAttributedString()
                text.append(title.withTextStyle(.label2, color: .Text.secondary, alignment: .center))
                text.append("\n".withTextStyle(.body3, color: .Text.tertiary, alignment: .center))
                text.append(subtitle.withTextStyle(.body3, color: .Text.tertiary, alignment: .center))
                slider.title = text
                slider.appearance = .standart
                self.slider = slider
                button = nil
                view.setContent(slider)
            case .button:
                let button = TKButton()
                let container = UIView()
                container.addSubview(button)
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    button.topAnchor.constraint(equalTo: container.topAnchor, constant: ConfirmActionBar.verticalInset),
                    button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -ConfirmActionBar.verticalInset),
                ])
                self.button = button
                slider = nil
                view.setContent(container)
            }
        }
    }
}

private extension ConfirmActionBarState.Process {
    var containerState: TKProcessContainerView.State {
        switch self {
        case .idle: .idle
        case .processing: .process
        case .success: .success
        case .failed: .failed
        }
    }
}
