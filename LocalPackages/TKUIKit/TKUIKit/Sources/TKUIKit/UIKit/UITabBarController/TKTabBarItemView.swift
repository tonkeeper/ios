import SnapKit
import UIKit

final class TKTabBarItemView: UIView {
    let iconContainer = UIView()
    var onSelect: (() -> Void)?

    var isItemSelected = false {
        didSet { applySelection() }
    }

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    private let titleLabel = UILabel()
    private var title = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isStaticIconHidden: Bool {
        get { iconImageView.isHidden }
        set { iconImageView.isHidden = newValue }
    }

    func configure(title: String, image: UIImage?) {
        self.title = title
        iconImageView.image = image?.withRenderingMode(.alwaysTemplate)
        accessibilityLabel = title
        applySelection()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #unavailable(iOS 17.0) {
            applySelection()
        }
    }
}

private extension TKTabBarItemView {
    func setup() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        tintAdjustmentMode = .normal

        iconContainer.isUserInteractionEnabled = false
        titleLabel.isUserInteractionEnabled = false
        titleLabel.numberOfLines = 1

        iconContainer.addSubview(iconImageView)
        addSubview(iconContainer)
        addSubview(titleLabel)

        iconContainer.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: .iconSize, height: .iconSize))
            make.centerX.equalTo(self)
            make.top.equalTo(self).offset(CGFloat.contentInset)
        }

        iconImageView.snp.makeConstraints { make in
            make.edges.equalTo(iconContainer)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconContainer.snp.bottom).offset(CGFloat.iconTitleSpacing)
            make.height.equalTo(TKTextStyle.label3.lineHeight)
            make.centerX.equalTo(self)
            make.left.greaterThanOrEqualTo(self)
            make.right.lessThanOrEqualTo(self)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (item: TKTabBarItemView, _) in
                item.applySelection()
            }
        }
    }

    @objc
    func handleTap() {
        onSelect?()
    }

    func applySelection() {
        let color = (isItemSelected ? UIColor.TabBar.activeIcon : UIColor.TabBar.inactiveIcon)
            .resolvedColor(with: traitCollection)
        tintColor = color
        iconImageView.tintColor = color
        titleLabel.attributedText = nil
        titleLabel.text = nil
        titleLabel.attributedText = title.withTextStyle(.label3, color: color, alignment: .center)
        titleLabel.textColor = color
        accessibilityTraits = isItemSelected ? [.button, .selected] : .button
    }
}

private extension CGFloat {
    static let iconSize: CGFloat = 28
    static let iconTitleSpacing: CGFloat = 4
    static let contentInset: CGFloat = 1.5
}
