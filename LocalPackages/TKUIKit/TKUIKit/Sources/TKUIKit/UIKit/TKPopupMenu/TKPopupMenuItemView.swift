import UIKit

final class TKPopupMenuItemView: UIControl, ConfigurableView {
    var didTap: (() -> Void)?
    var didTapFooterAction: (() -> Void)?

    let titleLabel = UILabel()
    let valueLabel = UILabel()
    let descriptionLabel = UILabel()
    let footerTextLabel = UILabel()
    let footerSeparatorLabel = UILabel()
    let footerActionButton = UIButton(type: .system)
    let separatorView = UIView()

    let leftIconImageView = TKImageView()

    let rightIconImageView: UIImageView = {
        let view = UIImageView()
        view.tintColor = .Accent.blue
        return view
    }()

    let selectionView = UIImageView()
    let highlightView = TKHighlightView()
    private var isSelectionEnabled = true

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            highlightView.isHighlighted = isSelectionEnabled ? isHighlighted : false
        }
    }

    override var isSelected: Bool {
        didSet {
            guard isSelected != oldValue else { return }
            selectionView.alpha = isSelectionEnabled && isSelected ? 1 : 0
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        guard let hitView else {
            return nil
        }

        if !footerActionButton.isHidden,
           hitView === footerActionButton || hitView.isDescendant(of: footerActionButton)
        {
            return footerActionButton
        }

        return self
    }

    override var intrinsicContentSize: CGSize {
        sizeThatFits(.zero)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let contentSize = contentStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(
            width: contentSize.width + .horizontalInset * 2,
            height: contentSize.height + .verticalInset * 2
        )
    }

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = .contentSpacing
        stackView.alignment = .center
        return stackView
    }()

    private let textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill
        return stackView
    }()

    private let titleRowStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = .contentSpacing
        stackView.alignment = .center
        return stackView
    }()

    private let accessoryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = .contentSpacing
        stackView.alignment = .center
        return stackView
    }()

    private let footerStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .center
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let title: NSAttributedString
        let value: NSAttributedString?
        let description: NSAttributedString?
        let footerText: NSAttributedString?
        let footerActionTitle: NSAttributedString?
        let icon: UIImage?
        let leftIcon: TKImageView.Model?
        let hasSeparator: Bool
        let isSelectable: Bool
        let isEnabled: Bool
        let footerActionHandler: (() -> Void)?
        let selectionHandler: (() -> Void)?

        init(
            title: String,
            value: String?,
            description: String?,
            icon: UIImage?,
            leftIcon: TKImageView.Model?,
            hasSeparator: Bool = false,
            isSelectable: Bool,
            isEnabled: Bool,
            footerText: String? = nil,
            footerActionTitle: String? = nil,
            footerActionHandler: (() -> Void)? = nil,
            selectionHandler: (() -> Void)? = nil
        ) {
            self.title = title.withTextStyle(.label1, color: .Text.primary)
            self.value = value?.withTextStyle(.body1, color: .Text.secondary)
            self.description = description?.withTextStyle(.body2, color: .Text.secondary)
            self.footerText = footerText?.withTextStyle(.body2, color: .Text.secondary)
            self.footerActionTitle = footerActionTitle?.withTextStyle(.body2, color: .Accent.blue)
            self.icon = icon
            self.leftIcon = leftIcon
            self.hasSeparator = hasSeparator
            self.isSelectable = isSelectable
            self.isEnabled = isEnabled
            self.footerActionHandler = footerActionHandler
            self.selectionHandler = selectionHandler
        }
    }

    func configure(model: Model) {
        titleLabel.attributedText = model.title
        valueLabel.attributedText = model.value
        descriptionLabel.attributedText = model.description
        footerTextLabel.attributedText = model.footerText
        footerActionButton.setAttributedTitle(model.footerActionTitle, for: .normal)
        didTapFooterAction = model.footerActionHandler
        separatorView.isHidden = !model.hasSeparator

        valueLabel.isHidden = model.value == nil
        descriptionLabel.isHidden = model.description == nil
        footerTextLabel.isHidden = model.footerText == nil
        footerActionButton.isHidden = model.footerActionTitle == nil
        footerSeparatorLabel.isHidden = model.footerText == nil || model.footerActionTitle == nil
        footerStackView.isHidden = model.footerText == nil && model.footerActionTitle == nil

        rightIconImageView.image = model.icon
        rightIconImageView.isHidden = model.icon == nil

        isSelectionEnabled = model.isEnabled

        leftIconImageView.image = model.leftIcon?.image
        leftIconImageView.tintColor = model.leftIcon?.tintColor
        leftIconImageView.isHidden = model.leftIcon == nil

        if let corners = model.leftIcon?.corners {
            leftIconImageView.corners = corners
        }
        leftIconImageView.size = .size(CGSize.leftIconSize)

        let showSelectionMark = model.isSelectable && model.isEnabled
        selectionView.isHidden = !showSelectionMark
        selectionView.alpha = showSelectionMark && isSelected ? 1 : 0
        accessoryStackView.isHidden = (!showSelectionMark && model.icon == nil)
        alpha = model.isEnabled ? 1 : 0.9

        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }
}

private extension TKPopupMenuItemView {
    func setup() {
        addAction(UIAction(handler: { [weak self] _ in
            guard self?.isSelectionEnabled == true else { return }
            self?.didTap?()
        }), for: .touchUpInside)

        backgroundColor = .Background.contentTint

        selectionView.image = .TKUIKit.Icons.Size16.doneBold
        selectionView.tintColor = .Accent.blue
        selectionView.alpha = isSelected ? 1 : 0

        titleLabel.textAlignment = .left

        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        descriptionLabel.numberOfLines = 1
        descriptionLabel.lineBreakMode = .byTruncatingTail
        descriptionLabel.textAlignment = .left

        footerTextLabel.numberOfLines = 1
        footerTextLabel.lineBreakMode = .byTruncatingTail
        footerTextLabel.textAlignment = .left

        footerSeparatorLabel.attributedText = "·".withTextStyle(.body2, color: .Text.secondary)
        footerSeparatorLabel.setContentHuggingPriority(.required, for: .horizontal)
        footerSeparatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        footerActionButton.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
        footerActionButton.contentHorizontalAlignment = .left
        footerActionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        footerActionButton.addAction(UIAction(handler: { [weak self] _ in
            self?.didTapFooterAction?()
        }), for: .touchUpInside)

        separatorView.backgroundColor = .Separator.common

        textStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        textStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        addSubview(highlightView)
        addSubview(contentStackView)
        addSubview(separatorView)

        contentStackView.addArrangedSubview(leftIconImageView)
        contentStackView.addArrangedSubview(textStackView)
        contentStackView.addArrangedSubview(accessoryStackView)
        contentStackView.setCustomSpacing(12, after: textStackView)

        textStackView.addArrangedSubview(titleRowStackView)
        textStackView.addArrangedSubview(descriptionLabel)
        textStackView.addArrangedSubview(footerStackView)

        footerStackView.addArrangedSubview(footerTextLabel)
        footerStackView.addArrangedSubview(footerSeparatorLabel)
        footerStackView.addArrangedSubview(footerActionButton)

        titleRowStackView.addArrangedSubview(titleLabel)
        titleRowStackView.addArrangedSubview(valueLabel)

        accessoryStackView.addArrangedSubview(rightIconImageView)
        accessoryStackView.addArrangedSubview(selectionView)

        setupConstraints()
    }

    func setupConstraints() {
        highlightView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: .verticalInset,
                left: .horizontalInset,
                bottom: .verticalInset,
                right: .horizontalInset
            ))
        }

        leftIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(CGSize.leftIconSize)
        }

        rightIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(CGSize.accessorySize)
        }

        selectionView.snp.makeConstraints { make in
            make.width.height.equalTo(CGSize.accessorySize)
        }

        separatorView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(CGFloat.horizontalInset)
            make.bottom.equalToSuperview()
            make.height.equalTo(CGFloat.separatorHeight)
        }
    }
}

private extension CGSize {
    static let leftIconSize = CGSize(width: 24, height: 24)
    static let accessorySize = CGSize(width: 16, height: 16)
}

private extension CGFloat {
    static let contentSpacing: CGFloat = 8
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 12
    static let separatorHeight: CGFloat = 1 / UIScreen.main.scale
}
