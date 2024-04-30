import UIKit
import TKUIKit

public final class TKCheckRecoveryPhraseView: UIView, ConfigurableView {
  let scrollView: UIScrollView = {
    let scrollView = TKUIScrollView()
    scrollView.showsVerticalScrollIndicator = false
    return scrollView
  }()
  
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .contentStackViewPadding
    return stackView
  }()
  
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  var inputTextFields = [TKMnemonicTextField]()
  
  let continueButton = TKButton()
  let continueButtonContainer = TKPaddingContainerView()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    public struct InputModel {
      public let index: Int
      public let didUpdateText: (String) -> Void
      public let didBeignEditing: () -> Void
      public let didEndEditing: () -> Void
      public let shouldPaste: (String) -> Bool
    }

    public let titleDescriptionModel: TKTitleDescriptionView.Model
    public let inputs: [InputModel]
    
    public init(titleDescriptionModel: TKTitleDescriptionView.Model,
                inputs: [InputModel]) {
      self.titleDescriptionModel = titleDescriptionModel
      self.inputs = inputs
    }
  }
  
  public func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    
    inputTextFields.forEach { $0.removeFromSuperview() }
    inputTextFields = []
    model.inputs
      .enumerated()
      .forEach { index, inputModel in
        let textField = TKMnemonicTextField()
        textField.indexNumber = inputModel.index
        textField.didUpdateText = { text in
          inputModel.didUpdateText(text)
        }
        textField.didBeginEditing = {
          inputModel.didBeignEditing()
        }
        textField.didEndEditing = {
          inputModel.didEndEditing()
        }
        textField.shouldPaste = { text in
          inputModel.shouldPaste(text)
        }
        textField.didTapReturn = { [weak self] in
          let nextIndex = index + 1
          if nextIndex < model.inputs.count {
            self?.inputTextFields[nextIndex].becomeFirstResponder()
          }
        }
        
        contentStackView.addArrangedSubview(textField)
        contentStackView.setCustomSpacing(.afterWordInputSpacing, after: textField)
        inputTextFields.append(textField)
      }
    contentStackView.addArrangedSubview(continueButtonContainer)
  }
  
  func scrollToInput(at index: Int,
                     animationDuration: TimeInterval) {
    guard inputTextFields.count > index else { return }
    let inputTextField = inputTextFields[index]
    let convertedFrame = scrollView.convert(inputTextField.frame, to: inputTextField.superview)
    let scrollViewMaxOrigin = scrollView.contentSize.height
    - scrollView.frame.height
    + scrollView.contentInset.bottom
    let originY = min(
      convertedFrame.origin.y - titleDescriptionView.frame.maxY - convertedFrame.size.height,
      scrollViewMaxOrigin
    )
    UIView.animate(withDuration: animationDuration) {
      self.scrollView.contentOffset = .init(x: 0, y: originY)
    }
  }
  
  func scrollToBottom(animationDuration: TimeInterval) {
    if scrollView.contentSize.height < scrollView.bounds.size.height { return }
    let bottomOffset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.adjustedContentInset.bottom)
    UIView.animate(withDuration: animationDuration) {
      self.scrollView.contentOffset = bottomOffset
    }
  }
}

private extension TKCheckRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(continueButtonContainer)
    
    continueButtonContainer.padding = .continueButtonContainerPadding
    continueButtonContainer.setViews([continueButton])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.widthAnchor.constraint(equalTo: widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        .withPriority(.defaultHigh),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor)
        .withPriority(.defaultHigh),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        .withPriority(.defaultHigh)
    ])
  }
}

private extension CGFloat {
  static let buttonsContainerSpacing: CGFloat = 16
  static let topSpacing: CGFloat = 44
  static let afterWordInputSpacing: CGFloat = 16
}

private extension UIEdgeInsets {
  static let continueButtonContainerPadding = UIEdgeInsets(
    top: 16,
    left: 0,
    bottom: 32,
    right: 0
  )
}

private extension NSDirectionalEdgeInsets {
  static let titleDescriptionPadding = NSDirectionalEdgeInsets(
    top: 11,
    leading: 0,
    bottom: 16,
    trailing: 0
  )
  
  static let contentStackViewPadding = NSDirectionalEdgeInsets(
    top: 0,
    leading: 32,
    bottom: 0,
    trailing: 32
  )
}
