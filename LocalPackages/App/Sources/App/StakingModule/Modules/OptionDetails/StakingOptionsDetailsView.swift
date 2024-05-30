import UIKit
import TKUIKit
import SnapKit
import TKCore


final class StakingOptionDetailsView: UIView, ConfigurableView {
  private let scrollView = TKUIScrollView()
  private let listView = TKModalCardListView()
  private let buttonsContainer = LinkButtonsContainer()
  private let tonStakersButton = TKButton()
  private let twitterButton = TKButton()
  private let communityButton = TKButton()
  private let tonViewerButton = TKButton()
  private let rootVStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.isLayoutMarginsRelativeArrangement = true
    stack.spacing = 8
    stack.directionalLayoutMargins = .init(
      top: .contentInset,
      leading: .contentInset,
      bottom: .contentInset,
      trailing: .contentInset
    )
    
    return stack
  }()
  
  private var buttons: [LinkButtonKind: TKButton] = [
    .tonstakers: TKButton(),
    .twitter: TKButton(),
    .community: TKButton(),
    .tonviewer: TKButton()
  ]
  
  private let hintLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = .zero
    
    return label
  }()
  
  private var chooseButton = TKButton()
  
  struct Model {
    struct LinkButtonModel {
      let kind: LinkButtonKind
      let configuration: TKButton.Configuration
    }
    
    let textList: [(left: String, right: String)]
    let hintText: String
    let subtitle: String
    let linkButtonModels: [[LinkButtonModel]]
    let chooseButtonConfiguration: TKButton.Configuration
    let linkButtonAction: ((LinkButtonKind) -> Void)?
  }

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layoutIfNeeded()
    
    for button in buttons.values {
      button.layer.cornerRadius = button.frame.height/2
    }
  }
  
  func configure(model: Model) {
    let listItems = model.textList.map {
      TKModalCardViewController.Configuration.ListItem(
        left: $0.left,
        rightTop: .value($0.right, numberOfLines: 1, isFullString: true),
        rightBottom: .value(nil, numberOfLines: .zero, isFullString: true)
      )
    }
    listView.configure(model: listItems)
    
    hintLabel.attributedText = model.hintText
      .withTextStyle(
        .body3,
        color: .Text.tertiary,
        alignment: .left
      )
    
    chooseButton.configuration = model.chooseButtonConfiguration
    
    let tkButtons: [[TKButton]] = model.linkButtonModels.map { row in
      row.compactMap { buttonModel in
        buttons[buttonModel.kind]?.configuration = buttonModel.configuration
        buttons[buttonModel.kind]?.configuration.action = {
          model.linkButtonAction?(buttonModel.kind)
        }
        return buttons[buttonModel.kind]
      }
    }
    buttonsContainer.configure(model: .init(title: model.subtitle, buttons: tkButtons))
    
    setNeedsLayout()
  }
}

// MARK: - Private methods

private extension StakingOptionDetailsView {
  func setup() {
    for button in buttons.values {
      button.layer.masksToBounds = true
    }
    
    backgroundColor = .Background.page
    
    rootVStack.addArrangedSubview(listView)
    rootVStack.addArrangedSubview(hintLabel)
    rootVStack.addArrangedSubview(buttonsContainer)
    
    scrollView.delaysContentTouches = false
    scrollView.fill(in: self)
    
    chooseButton.layout(in: self) {
      $0.leading.equalToSuperview().offset(16)
      $0.trailing.equalToSuperview().inset(16)
      $0.bottom.equalTo(safeAreaLayoutGuide).inset(16)
    }
    
    rootVStack.layout(in: scrollView) {
      $0.top.equalToSuperview()
      $0.leading.trailing.bottom.equalToSuperview().priority(.high)
      $0.width.equalTo(scrollView)
    }
  }
}

private extension CGFloat {
  static let contentInset: CGFloat = 16
  static let amountInputHeight: CGFloat = 188
}
