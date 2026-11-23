import SwiftUI
import UIKit

public final class TKConfirmSliderView: UIView {
    public var appearance: TKConfirmSlider.Appearance {
        get { model.appearance }
        set { model.appearance = newValue }
    }

    public var isEnabled: Bool {
        get { model.isEnabled }
        set { model.isEnabled = newValue }
    }

    public var process: TKActionBarProcess {
        get { model.process }
        set {
            if newValue == .idle, model.process != .idle {
                model.resetToken += 1
            }
            model.process = newValue
        }
    }

    public var handleAccessibilityIdentifier: String? {
        get { model.handleAccessibilityIdentifier }
        set { model.handleAccessibilityIdentifier = newValue }
    }

    public var didConfirm: (() -> Void)? {
        get { model.didConfirm }
        set { model.didConfirm = newValue }
    }

    private let model = Model()
    private lazy var hostingController = TKHostingController(content: Content(model: model))

    override public init(frame: CGRect) {
        super.init(frame: frame)
        let hostedView: UIView = hostingController.view
        hostedView.backgroundColor = .clear
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        addSubview(hostedView)
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: TKConfirmSlider.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    private final class Model: ObservableObject {
        @Published var appearance: TKConfirmSlider.Appearance = .standard
        @Published var isEnabled = true
        @Published var process: TKActionBarProcess = .idle
        @Published var resetToken = 0
        @Published var handleAccessibilityIdentifier: String?
        var didConfirm: (() -> Void)?
    }

    private struct Content: View {
        @ObservedObject var model: Model

        var body: some View {
            TKConfirmSlider(
                appearance: model.appearance,
                isEnabled: model.isEnabled,
                process: model.process,
                resetToken: model.resetToken,
                handleAccessibilityIdentifier: model.handleAccessibilityIdentifier
            ) { [weak model] in
                model?.didConfirm?()
            }
        }
    }
}
