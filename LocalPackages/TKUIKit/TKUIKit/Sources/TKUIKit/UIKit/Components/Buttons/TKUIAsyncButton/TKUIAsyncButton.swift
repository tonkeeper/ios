import UIKit

public protocol TKUIAsyncButtonContentView: UIView, ConfigurableView {
    var isEnabled: Bool { get set }
    var loaderSize: TKLoaderView.Size { get }
    func addTapAction(_ action: @escaping () -> Void)
}

final class TKUIAsyncButton<Content: TKUIAsyncButtonContentView>: UIView, ConfigurableView {
    private let content: Content
    private let loaderView: TKLoaderView
    init(content: Content) {
        self.content = content
        self.loaderView = TKLoaderView(
            size: content.loaderSize,
            style: .primary
        )
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ConfigurableView

    func configure(model: Content.Model) {
        content.configure(model: model)
    }
}

private extension TKUIAsyncButton {
    func setup() {
        loaderView.alpha = 0
        addSubview(content)
        addSubview(loaderView)

        content.translatesAutoresizingMaskIntoConstraints = false
        loaderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.leftAnchor.constraint(equalTo: leftAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.rightAnchor.constraint(equalTo: rightAnchor),

            loaderView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loaderView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
