import SnapKit
import TKUIKit
import UIKit

final class SendV3View: UIView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let scrollView = TKUIScrollView()
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = .contentVerticalPadding
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
        return stackView
    }()

    lazy var recipientTextField: TKTextField = {
        let textInputControl = TKTextInputTextViewControl()
        return TKTextField(
            textFieldInputView: TKTextFieldInputView(
                textInputControl: textInputControl
            )
        )
    }()

    let recipientDescriptionLabel = TKActionLabel()
    let recipientDescriptionContainer = UIView()
    let amountInputView = SendV3AmountInputView()

    let commentInputView = SendV3CommentInputView()

    let continueButton = TKButton(
        configuration: .actionButtonConfiguration(
            category: .primary,
            size: .large
        )
    )

    let recipientPasteButton = TKButton()
    let recipientScanButton = TKButton()
    let commentPasteButton = TKButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        scrollView.delaysContentTouches = false

        recipientTextField.rightItems = [
            TKTextField.RightItem(view: recipientPasteButton, mode: .empty),
            TKTextField.RightItem(view: recipientScanButton, mode: .empty),
        ]
        commentInputView.commentTextField.rightItems = [
            TKTextField.RightItem(
                view: commentPasteButton,
                mode: .empty,
                padding: .init(top: 0, left: 0, bottom: 0, right: 8)
            ),
        ]

        navigationBar.centerView = titleView
        navigationBar.scrollView = scrollView

        recipientDescriptionLabel.numberOfLines = 0
        recipientDescriptionContainer.isHidden = true

        addSubview(scrollView)
        addSubview(navigationBar)
        scrollView.addSubview(stackView)

        recipientDescriptionContainer.addSubview(recipientDescriptionLabel)

        stackView.addArrangedSubview(recipientTextField)
        stackView.addArrangedSubview(recipientDescriptionContainer)
        stackView.addArrangedSubview(amountInputView)
        stackView.addArrangedSubview(commentInputView)
        stackView.addArrangedSubview(continueButton)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(self)
            make.width.equalTo(self)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(scrollView)
            make.left.right.bottom.equalTo(scrollView).priority(.high)
            make.width.equalTo(scrollView)
        }

        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        recipientDescriptionLabel.snp.makeConstraints { make in
            make.edges.equalTo(recipientDescriptionContainer)
        }
    }
}

private extension CGFloat {
    static let contentVerticalPadding: CGFloat = 16
}
