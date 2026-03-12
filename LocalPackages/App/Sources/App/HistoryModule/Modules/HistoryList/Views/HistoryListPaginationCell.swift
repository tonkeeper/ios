import TKUIKit
import UIKit

final class HistoryListPaginationCell: UICollectionViewCell, ConfigurableView {
    enum State {
        case none
        case loading
        case error(title: String?, retryButtonAction: () -> Void)
        case spamFooter(text: String)
    }

    var state: State = .none {
        didSet {
            didChangeState()
        }
    }

    private let loaderView = TKLoaderView(size: .medium, style: .primary)
    private let retryButton = TKButton(configuration: .actionButtonConfiguration(category: .tertiary, size: .small))
    private let footerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        loaderView.sizeToFit()
        loaderView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    struct Model {
        let state: State
    }

    func configure(model: Model) {
        self.state = model.state
    }
}

private extension HistoryListPaginationCell {
    func setup() {
        contentView.addSubview(loaderView)
        contentView.addSubview(retryButton)
        contentView.addSubview(footerLabel)

        setupFooterLabel()
        setupConstraints()

        didChangeState()
    }

    func setupFooterLabel() {
        footerLabel.numberOfLines = 0
        footerLabel.textAlignment = .center
    }

    func setupConstraints() {
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            footerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            footerLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            footerLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    func didChangeState() {
        switch state {
        case .none:
            loaderView.isLoading = false
            loaderView.isHidden = true
            retryButton.isHidden = true
            footerLabel.isHidden = true
        case .loading:
            loaderView.isLoading = true
            loaderView.isHidden = false
            retryButton.isHidden = true
            footerLabel.isHidden = true
        case let .error(title, retryButtonAction):
            loaderView.isLoading = false
            loaderView.isHidden = true
            retryButton.isHidden = false
            footerLabel.isHidden = true
            retryButton.configuration.content.title = .plainString(title ?? "")
            retryButton.configuration.action = retryButtonAction
        case let .spamFooter(text):
            loaderView.isLoading = false
            loaderView.isHidden = true
            retryButton.isHidden = true
            footerLabel.isHidden = false
            footerLabel.attributedText = text.withTextStyle(.body2, color: .Text.secondary)
        }
        setNeedsLayout()
    }
}
