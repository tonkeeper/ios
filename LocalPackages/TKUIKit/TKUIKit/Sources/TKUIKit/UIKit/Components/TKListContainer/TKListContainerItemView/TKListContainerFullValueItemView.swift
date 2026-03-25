import UIKit

public struct TKListContainerFullValueItemItem: TKListContainerItem {
    public func getView() -> UIView {
        return TKListContainerFullValueItemView(
            configuration: TKListContainerFullValueItemView.Configuration(
                title: title,
                value: value
            )
        )
    }

    public var action: TKListContainerItemAction? {
        .copy(copyValue: copyValue)
    }

    private let title: String
    private let value: String
    private let copyValue: String?

    public init(
        title: String,
        value: String,
        copyValue: String?
    ) {
        self.title = title
        self.value = value
        self.copyValue = copyValue
    }
}

final class TKListContainerFullValueItemView: UIView {
    struct Configuration {
        let title: String
        let value: String
    }

    private let configuration: Configuration

    private let stackView = TKPassthroughStackView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    init(configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view is UIControl ? view : nil
    }

    private func setup() {
        valueLabel.numberOfLines = 0

        stackView.axis = .vertical
        stackView.alignment = .leading

        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(valueLabel)

        setupConstraints()
        setupConfiguration()
    }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(16)
        }
    }

    private func setupConfiguration() {
        titleLabel.attributedText = configuration.title.withTextStyle(
            .body1,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        valueLabel.attributedText = configuration.value.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
    }
}
