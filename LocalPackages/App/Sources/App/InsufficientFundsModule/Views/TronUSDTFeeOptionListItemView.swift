import TKUIKit
import UIKit

enum TronUSDTFeeOptionIcon {
    case battery(fillPercent: CGFloat)
    case ton
    case trx
}

struct TronUSDTFeeOptionListItem: TKListContainerItem {
    let title: String
    let icon: TronUSDTFeeOptionIcon
    let caption: String
    let actionHandler: () -> Void

    var action: TKListContainerItemAction? {
        .custom { _ in
            actionHandler()
        }
    }

    func getView() -> UIView {
        let view = TronUSDTFeeOptionListItemView()
        view.configure(model: .init(
            title: title,
            icon: icon,
            caption: caption
        ))
        // Touch handling is performed by TKListContainerItemViewContainer (UIControl).
        // Keep the custom content view transparent to hit-testing so taps reach the container.
        view.isUserInteractionEnabled = false
        return view
    }

    init(
        title: String,
        icon: TronUSDTFeeOptionIcon,
        caption: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.caption = caption
        actionHandler = action
    }
}

private final class TronUSDTFeeOptionListItemView: UIView, ConfigurableView {
    struct Model {
        let title: String
        let icon: TronUSDTFeeOptionIcon
        let caption: String
    }

    private let iconContainerView = UIView()
    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let batteryIconView = BatteryView(size: .size52)

    private let titleLabel = UILabel()
    private let captionLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()

    private let textStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        return view
    }()

    private let chevronImageView: UIImageView = {
        let view = UIImageView()
        view.image = .TKUIKit.Icons.Size16.chevronRight
        view.tintColor = .Icon.secondary
        view.contentMode = .center
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(model: Model) {
        titleLabel.attributedText = model.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        captionLabel.attributedText = model.caption.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )

        switch model.icon {
        case let .battery(fillPercent):
            iconContainerView.backgroundColor = .clear
            batteryIconView.isHidden = false
            batteryIconView.state = fillPercent > 0 ? .fill(fillPercent) : .empty
            iconImageView.isHidden = true
        case .ton:
            iconContainerView.backgroundColor = .clear
            batteryIconView.isHidden = true
            iconImageView.isHidden = false
            iconImageView.image = .App.Currency.Vector.ton.withRenderingMode(.alwaysOriginal)
        case .trx:
            iconContainerView.backgroundColor = .clear
            batteryIconView.isHidden = true
            iconImageView.isHidden = false
            iconImageView.image = .App.Currency.Vector.trc20.withRenderingMode(.alwaysOriginal)
        }
    }

    private func setup() {
        addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        addSubview(batteryIconView)
        addSubview(textStackView)
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(captionLabel)
        addSubview(chevronImageView)

        textStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStackView.setContentCompressionResistancePriority(.required, for: .vertical)
        captionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        iconContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(44)
        }

        iconImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        batteryIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(21)
        }

        chevronImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        textStackView.snp.makeConstraints { make in
            make.left.equalTo(iconContainerView.snp.right).offset(16)
            make.top.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(20)
            make.right.lessThanOrEqualTo(chevronImageView.snp.left).offset(-12)
        }
    }
}
