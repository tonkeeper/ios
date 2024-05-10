import UIKit
import TKUIKit
import SnapKit

final class SendV3View: UIView {
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
  
  let recipientTextField = TKTextField(
    textFieldInputView: TKTextFieldInputView(
      textInputControl: TKTextInputTextViewControl()
    )
  )
  
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
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    
    recipientTextField.rightItems = [
      TKTextField.RightItem(view: recipientPasteButton, mode: .empty),
      TKTextField.RightItem(view: recipientScanButton, mode: .empty)
    ]
    commentInputView.commentTextField.rightItems = [TKTextField.RightItem(view: commentPasteButton, mode: .empty)]
    
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    stackView.addArrangedSubview(recipientTextField)
    stackView.addArrangedSubview(amountInputView)
    stackView.addArrangedSubview(commentInputView)
    stackView.addArrangedSubview(continueButton)
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(CGFloat.contentVerticalPadding)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
  }
}

extension SendV3View {
  struct Model {
    struct Recipient {
      let placeholder: String
      let text: String
      let isValid: Bool
    }
    
    struct Amount {
      struct Token {
        enum Image {
          case image(UIImage)
          case asyncImage(ImageDownloadTask)
        }
        let image: Image
        let title: String
      }
      
      let placeholder: String
      let text: String
      let fractionDigits: Int
      let token: Token
    }
    
    struct Comment {
      let placeholder: String
      let text: String
      let isValid: Bool
      let description: NSAttributedString?
    }
    
    struct Button {
      let title: String
      let isEnabled: Bool
      let isActivity: Bool
      let action: (() -> Void)
    }
    
    struct Balance {
      enum Remaining {
        case insufficient
        case remaining(String)
      }
      let converted: String
      let remaining: Remaining
    }
    
    let recipient: Recipient
    let amount: Amount?
    let balance: Balance
    let comment: Comment
    let button: Button
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
