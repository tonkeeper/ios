import UIKit
import TKUIKit

public final class TKInputRecoveryPhraseView: UIView, ConfigurableView {
  
  var didUpdateText: ((String, Int) -> Void)?
  var didBeginEditing: ((Int) -> Void)?
  var didEndEditing: ((Int) -> Void)?
  var shouldPaste: ((String, Int) -> Bool)?
  
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
  
  let titleDescriptionView: TKTitleDescriptionHeaderView = {
    let view = TKTitleDescriptionHeaderView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  var wordInputTextFields = [TKTextInputContainer<TKMnemonicInputView>]()
  
  let continueButton = TKButton.titleButton(buttonCategory: .primary, buttonSize: .large)
  let continueButtonContainer = TKPaddingContainer(padding: .continueButtonContainerPadding)
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    public struct WordInputModel {
      let index: Int
      public init(index: Int) {
        self.index = index
      }
    }
    let titleDescriptionModel: TKTitleDescriptionHeaderView.Model
    let wordInputModels: [WordInputModel]
    
    public init(titleDescriptionModel: TKTitleDescriptionHeaderView.Model,
                wordInputModels: [WordInputModel]) {
      self.titleDescriptionModel = titleDescriptionModel
      self.wordInputModels = wordInputModels
    }
  }
  
  public func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    
    wordInputTextFields.forEach { $0.removeFromSuperview() }
    let textFields = model
      .wordInputModels
      .enumerated()
      .map { index, wordInputModel in
        let textField = TKTextField.mnemonicTextField()
        textField.indexNumber = wordInputModel.index
        textField.didUpdateText = { [weak self] in
          self?.didUpdateText?($0, index)
        }
        textField.didBeginEditing = { [weak self] in
          self?.didBeginEditing?(index)
        }
        textField.didEndEditing = { [weak self] in
          self?.didEndEditing?(index)
        }
        textField.shouldPaste = { [weak self] text in
          (self?.shouldPaste?(text, index) ?? true)
        }
        return textField
      }
    textFields.forEach {
      contentStackView.addArrangedSubview($0)
      contentStackView.setCustomSpacing(.afterWordInputSpacing, after: $0)
    }
    self.wordInputTextFields = textFields
    
    contentStackView.addArrangedSubview(continueButtonContainer)
  }
}

private extension TKInputRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(continueButtonContainer)
    
    continueButtonContainer.contentView = continueButton
    
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
  
  static let continueButtonContainerPadding = NSDirectionalEdgeInsets(
    top: 16,
    leading: 0,
    bottom: 32,
    trailing: 0
  )
}
