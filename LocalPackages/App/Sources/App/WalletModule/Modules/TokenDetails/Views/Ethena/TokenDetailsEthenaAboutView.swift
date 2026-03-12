import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class TokenDetailsEthenaAboutView: UIView {
    struct Configuration: TokenDetailsBannerItem {
        let description: String
        let actionItems: [TKActionLabel.ActionItem]

        func getView() -> UIView {
            let view = TokenDetailsEthenaAboutView()
            view.configuration = self
            return view
        }
    }

    var configuration: Configuration = Configuration(description: "", actionItems: []) {
        didSet {
            didUpdateConfiguration()
            setNeedsLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private let contentView = UIView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let actionLabel = TKActionLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.page
        contentView.backgroundColor = .Background.content

        stackView.axis = .vertical

        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        addSubview(contentView)
        contentView.addSubview(stackView)

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16))
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView).inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(actionLabel)

        titleLabel.attributedText = TKLocales.Ethena.aboutUsde.withTextStyle(
            .label1,
            color: .Text.primary
        )

        actionLabel.numberOfLines = 0
    }

    private func didUpdateConfiguration() {
        actionLabel.setAttributedText(
            configuration.description.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .left
            ),
            actionItems: configuration.actionItems
        )
    }
}
