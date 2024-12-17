import UIKit
import TKUIKit
import SnapKit

public final class TKInputRecoveryPhraseView: UIView, ConfigurableView {
  
  var bannerViewProvider: (() -> UIView)? {
    didSet {
      bannerView?.removeFromSuperview()
      bannerView = nil
      if let bannerView = bannerViewProvider?() {
        self.bannerView = bannerView
        self.contentStackView.insertArrangedSubview(bannerView, at: 1)
        self.contentStackView.setCustomSpacing(.afterWordInputSpacing, after: bannerView)
      }
    }
  }
  
  let scrollView: UIScrollView = {
    let scrollView = TKUIScrollView()
    scrollView.showsVerticalScrollIndicator = false
    return scrollView
  }()
  
  private let switchWordsCountButtonsContainer: UIView = {
    let contentView = UIView()
    return contentView
  }()
  
  private let switchWordsCountButtonsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 4
    stackView.backgroundColor = .Button.tertiaryBackground
    stackView.directionalLayoutMargins = .switchWordsCountButtonsStackViewPadding
    stackView.layer.cornerRadius = 22
    return stackView
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
  
  private let set24WordsButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .tertiary, size: .small)
    let button = TKButton(configuration: configuration)
    return button
  }()
  private let set12WordsButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
    let button = TKButton(configuration: configuration)
    return button
  }()
  
  let suggestsView = TKInputRecoveryPhraseSuggestsView()
  let pasteButton = TKButton()
  
  var bannerView: UIView?
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      if keyboardHeight.isZero {
        scrollView.contentInset.bottom = safeAreaInsets.bottom + suggestsView.bounds.height
      } else {
        scrollView.contentInset.bottom = keyboardHeight - safeAreaInsets.bottom + suggestsView.bounds.height
      }
      pasteButton.snp.remakeConstraints { make in
        make.centerX.equalTo(self)
        if keyboardHeight.isZero {
          make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        } else {
          make.bottom.equalTo(self).offset(-(keyboardHeight - safeAreaInsets.bottom))
        }
      }
    }
  }
    
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
    suggestsView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 52)
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    public struct InputModel {
      public let index: Int
      public let didUpdateText: (String) -> Void
      public let didBeignEditing: () -> Void
      public let didEndEditing: () -> Void
      public let shouldPaste: (String) -> Bool
      public let didTapReturn: (() -> Void)?
    }
    
    public struct SwitchWordsCountButtonsModel {
      public let selected: Int
      public let didUpdateWordsCount: (Int) -> Void
      public let set12WordsButtonTitle: String
      public let set24WordsButtonTitle: String
    }

    public let titleDescriptionModel: TKTitleDescriptionView.Model
    public let switchWordsCountButtonsModel: SwitchWordsCountButtonsModel
    public let inputs: [InputModel]
    
    public init(titleDescriptionModel: TKTitleDescriptionView.Model,
                switchWordsCountButtonsModel: SwitchWordsCountButtonsModel,
                inputs: [InputModel]) {
      self.titleDescriptionModel = titleDescriptionModel
      self.switchWordsCountButtonsModel = switchWordsCountButtonsModel
      self.inputs = inputs
    }
  }
  
  public func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    
    set12WordsButton.configuration = .actionButtonConfiguration(category: model.switchWordsCountButtonsModel.selected == 12 ? .secondary : .tertiary, size: .small)

    set24WordsButton.configuration = .actionButtonConfiguration(category: model.switchWordsCountButtonsModel.selected == 24 ? .secondary : .tertiary, size: .small)

    
    set12WordsButton.configuration.content = .init(title: .plainString(model.switchWordsCountButtonsModel.set12WordsButtonTitle))
    set24WordsButton.configuration.content = .init(title: .plainString(model.switchWordsCountButtonsModel.set24WordsButtonTitle))
    
    set12WordsButton.configuration.action = {
      model.switchWordsCountButtonsModel.didUpdateWordsCount(12)
    }
    
    set24WordsButton.configuration.action = {
      model.switchWordsCountButtonsModel.didUpdateWordsCount(24)
    }
    
    inputTextFields.forEach { $0.removeFromSuperview() }
    inputTextFields = []
    model.inputs.enumerated()
      .forEach { index, inputModel in
        let textField = TKMnemonicTextField()
        textField.accessoryView = suggestsView
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
        textField.didTapReturn = {
          inputModel.didTapReturn?()
        }

        contentStackView.addArrangedSubview(textField)
        if index == inputTextFields.count - 1 {
          contentStackView.setCustomSpacing(.afterWordInputSpacing + 16, after: textField)
        } else {
          contentStackView.setCustomSpacing(.afterWordInputSpacing, after: textField)
        }
        inputTextFields.append(textField)
      }
    contentStackView.addArrangedSubview(continueButton)
    contentStackView.setCustomSpacing(32, after: continueButton)
  }
  
  func scrollToInput(at index: Int,
                     animationDuration: TimeInterval) {
    guard inputTextFields.count > index else { return }
    let inputTextField = inputTextFields[index]
    let convertedFrame = scrollView.convert(inputTextField.frame, to: inputTextField.superview)
    let scrollViewMaxOrigin = scrollView.contentSize.height
    - scrollView.frame.height
    + scrollView.contentInset.bottom
    
    let maxY: CGFloat
    if let bannerView {
      maxY = bannerView.frame.maxY - .afterWordInputSpacing
    } else {
      maxY = titleDescriptionView.frame.maxY
    }
    
    let originY = min(
      convertedFrame.origin.y
      - maxY
      - convertedFrame.size.height,
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
  
  func configureSuggests(model: TKInputRecoveryPhraseSuggestsView.Model) {
    suggestsView.alpha = model.suggests.isEmpty ? 0 : 1
    suggestsView.configure(model: model)
  }
}

private extension TKInputRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    
    suggestsView.alpha = 0
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    
    contentStackView.addArrangedSubview(switchWordsCountButtonsStackView)
    switchWordsCountButtonsStackView.addArrangedSubview(set24WordsButton)
    switchWordsCountButtonsStackView.addArrangedSubview(set12WordsButton)

    contentStackView.addArrangedSubview(continueButton)
    
    addSubview(pasteButton)
      
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    
    pasteButton.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
    }
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.widthAnchor.constraint(equalTo: widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
    ])
  }
}

private extension CGFloat {
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
  
  static let switchWordsCountButtonsStackViewPadding = NSDirectionalEdgeInsets(
    top: 4,
    leading: 4,
    bottom: 4,
    trailing: 4
  )
}
