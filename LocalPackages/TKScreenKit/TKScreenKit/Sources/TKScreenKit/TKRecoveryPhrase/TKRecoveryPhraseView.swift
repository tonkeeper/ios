import UIKit
import TKUIKit

public final class TKRecoveryPhraseView: UIView, ConfigurableView {
  
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
  
  let listView = TKRecoveryPhraseListView()
  
  let buttonsContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .copyButtonContainerPadding
    return container
  }()
  
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
    public struct Button {
      public let model: TKUIActionButton.Model
      public let category: TKUIActionButtonCategory
      public let action: () -> Void
      public init(model: TKUIActionButton.Model,
                  category: TKUIActionButtonCategory,
                  action: @escaping () -> Void) {
        self.model = model
        self.category = category
        self.action = action
      }
    }
    
    public let titleDescriptionModel: TKTitleDescriptionView.Model
    public let phraseListViewModel: TKRecoveryPhraseListView.Model
    public let buttons: [Button]
    
    public init(titleDescriptionModel: TKTitleDescriptionView.Model,
                phraseListViewModel: TKRecoveryPhraseListView.Model,
                buttons: [Button]) {
      self.titleDescriptionModel = titleDescriptionModel
      self.phraseListViewModel = phraseListViewModel
      self.buttons = buttons
    }
  }
  
  public func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    listView.configure(model: model.phraseListViewModel)
    let buttons = model.buttons.map { buttonModel in
      let button = TKUIActionButton(
        category: buttonModel.category,
        size: .large
      )
      button.configure(model: buttonModel.model)
      button.addTapAction(buttonModel.action)
      return button
    }
    buttonsContainer.setViews(buttons)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    scrollView.contentInset.bottom = buttonsContainer.bounds.height
  }
}

private extension TKRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    directionalLayoutMargins.top = .topSpacing
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    addSubview(buttonsContainer)
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(listView)
        
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    
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
        .withPriority(.defaultHigh),
      
      buttonsContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      buttonsContainer.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsContainer.rightAnchor.constraint(equalTo: rightAnchor)
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
    top: 0,
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

private extension UIEdgeInsets {
  static let copyButtonContainerPadding = UIEdgeInsets(
    top: 16,
    left: 32,
    bottom: 32,
    right: 32
  )
}
