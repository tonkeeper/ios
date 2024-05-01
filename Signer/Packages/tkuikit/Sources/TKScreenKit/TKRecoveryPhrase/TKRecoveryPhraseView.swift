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
  
  let titleDescriptionView: TKTitleDescriptionHeaderView = {
    let view = TKTitleDescriptionHeaderView(size: .big)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  let listView = TKRecoveryPhraseListView()
  
  let copyButton = TKButton.titleButton(buttonCategory: .secondary, buttonSize: .large)
  let copyButtonContainer = TKPaddingContainer(padding: .copyButtonContainerPadding)
  
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
    let titleDescriptionModel: TKTitleDescriptionHeaderView.Model
    let phraseListViewModel: TKRecoveryPhraseListView.Model
    
    public init(titleDescriptionModel: TKTitleDescriptionHeaderView.Model,
                phraseListViewModel: TKRecoveryPhraseListView.Model) {
      self.titleDescriptionModel = titleDescriptionModel
      self.phraseListViewModel = phraseListViewModel
    }
  }
  
  public func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    listView.configure(model: model.phraseListViewModel)
  }
}

private extension TKRecoveryPhraseView {
  func setup() {
    backgroundColor = .Background.page
    directionalLayoutMargins.top = .topSpacing
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    addSubview(copyButtonContainer)
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(listView)
    
    copyButtonContainer.contentView = copyButton
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    copyButtonContainer.translatesAutoresizingMaskIntoConstraints = false
    
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
      
      copyButtonContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      copyButtonContainer.leftAnchor.constraint(equalTo: leftAnchor),
      copyButtonContainer.rightAnchor.constraint(equalTo: rightAnchor)
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
  
  static let copyButtonContainerPadding = NSDirectionalEdgeInsets(
    top: 16,
    leading: 32,
    bottom: 32,
    trailing: 32
  )
}
