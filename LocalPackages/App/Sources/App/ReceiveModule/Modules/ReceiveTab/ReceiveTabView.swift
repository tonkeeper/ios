import TKUIKit
import UIKit

final class ReceiveTabView: UIView, ConfigurableView {
    enum Source {
        case receive
        case paymentQR
    }

    var source: Source = .receive {
        didSet {
            titleDescriptionView.padding = .titleDescriptionPadding(source: source)
        }
    }

    let scrollView = TKUIScrollView()

    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    lazy var titleDescriptionView: TKTitleDescriptionView = {
        let view = TKTitleDescriptionView(size: .medium)
        view.padding = .titleDescriptionPadding(source: source)
        return view
    }()

    let qrCodeView = ReceiveQRCodeView()
    let qrCodeContainer: TKPaddingContainerView = {
        let container = TKPaddingContainerView()
        container.padding = .qrCodePadding
        return container
    }()

    let buttonsView = ReceiveButtonsView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let titleDescriptionModel: TKTitleDescriptionView.Model
        let buttonsModel: ReceiveButtonsView.Model
        let address: String?
        let addressButtonAction: () -> Void
        let iconConfiguration: TKListItemIconView.Configuration
        let tag: TKTagView.Configuration?
    }

    func configure(model: Model) {
        titleDescriptionView.configure(model: model.titleDescriptionModel)
        buttonsView.configure(model: model.buttonsModel)
        qrCodeView.iconView.configuration = model.iconConfiguration
        qrCodeView.setTagModel(model.tag)
        qrCodeView.addressButton.address = model.address
        qrCodeView.addressButton.tapHandler = {
            model.addressButtonAction()
        }
        qrCodeView.sizeToFit()
        setNeedsLayout()
    }
}

private extension ReceiveTabView {
    func setup() {
        backgroundColor = .Background.page

        scrollView.delaysContentTouches = false

        titleDescriptionView.setContentHuggingPriority(.required, for: .vertical)
        scrollView.contentInset.bottom = 32

        addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(titleDescriptionView)
        contentStackView.addArrangedSubview(qrCodeContainer)
        contentStackView.setCustomSpacing(16, after: qrCodeContainer)
        contentStackView.addArrangedSubview(buttonsView)

        qrCodeContainer.setViews([qrCodeView])

        setupConstraints()
    }

    func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.bottom.right.width.equalTo(self)
        }
        contentStackView.snp.makeConstraints { make in
            make.top.left.bottom.right.width.equalTo(scrollView)
        }
    }
}

private extension NSDirectionalEdgeInsets {
    static func titleDescriptionPadding(source: ReceiveTabView.Source) -> NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(
            top: source == .receive ? 24 : 0,
            leading: 32,
            bottom: 16,
            trailing: 32
        )
    }
}

private extension UIEdgeInsets {
    static let qrCodePadding = UIEdgeInsets(
        top: 16,
        left: 47,
        bottom: 0,
        right: 47
    )
}
