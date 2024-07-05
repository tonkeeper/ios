import UIKit
import TKUIKit

final class NotificationBannerView: UIControl, ConfigurableView {
  
  struct Model {
    struct ActionButton {
      let title: String
      let action: (() -> Void)
    }
    
    enum Appearance {
      case regular
      case accentYellow
      case accentRed
      case accentBlue
      
      var tintColor: UIColor {
        switch self {
        case .regular: return .Text.primary
        case .accentYellow: return .black
        case .accentBlue: return .white
        case .accentRed: return .white
        }
      }
      
      var descriptionColor: UIColor {
        switch self {
        case .regular: return .Text.secondary
        case .accentYellow: return .black
        case .accentBlue: return .white
        case .accentRed: return .white
        }
      }
      
      var backgroundColor: UIColor {
        switch self {
        case .regular: return .Background.contentTint
        case .accentYellow: return .Accent.orange
        case .accentBlue: return .Accent.blue
        case .accentRed: return .Accent.red
        }
      }
      
      var captionAlpha: CGFloat {
        switch self {
        case .regular: return 1
        case .accentYellow: return 0.76
        case .accentBlue: return 0.76
        case .accentRed: return 0.76
        }
      }
    }
    
    let title: String?
    let caption: String?
    let appearance: Appearance
    let actionButton: ActionButton?
    let closeAction: (() -> Void)?
    
    init(title: String?,
         caption: String?,
         appearance: Appearance,
         actionButton: ActionButton? = nil,
         closeAction: (() -> Void)?) {
      self.title = title
      self.caption = caption
      self.appearance = appearance
      self.actionButton = actionButton
      self.closeAction = closeAction
    }
  }
  
  func configure(model: Model) {
    containerView.backgroundColor = model.appearance.backgroundColor
    titleLabel.attributedText = model.title?.withTextStyle(
      .label1,
      color: model.appearance.tintColor,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    captionLabel.attributedText = model.caption?.withTextStyle(
      .body2,
      color: model.appearance.descriptionColor,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    captionLabel.alpha = model.appearance.captionAlpha
    
    closeButton.configuration = TKButton.Configuration(
      content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.close),
      contentPadding: UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 0),
      iconTintColor: model.appearance.tintColor,
      contentAlpha: [.highlighted: 0.48],
      isEnabled: true,
      action: model.closeAction
    )
    
    if let actionButtonModel = model.actionButton {
      self.actionButton.isHidden = false
      beforeActionButtonSpacingView.isHidden = false
      self.tapHandler = actionButtonModel.action
      self.actionButton.configuration.content = TKButton.Configuration.Content(
        title: .plainString(actionButtonModel.title),
        icon: .TKUIKit.Icons.Size12.chevronRight
      )
      self.actionButton.configuration.iconPosition = .right
      self.actionButton.configuration.iconTintColor = model.appearance.tintColor
      self.actionButton.configuration.spacing = 2
      self.actionButton.configuration.textColor = model.appearance.tintColor
      self.actionButton.configuration.contentAlpha = [.highlighted: 0.48]
    } else {
      self.tapHandler = nil
      self.actionButton.isHidden = true
      beforeActionButtonSpacingView.isHidden = true
    }
  }
  
  private var tapHandler: (() -> Void)?
  
  override var isHighlighted: Bool {
    didSet {
      containerView.alpha = (isHighlighted && tapHandler != nil) ? 0.88 : 1
    }
  }

  let containerView = TKPassthroughView()
  let titleLabel = UILabel()
  let captionLabel = UILabel()
  let closeButton = TKButton()
  let actionButton = TKButton()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .leading
    return stackView
  }()
  private let beforeActionButtonSpacingView = TKSpacingView(verticalSpacing: .constant(4))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    containerView.layer.cornerRadius = 16
    captionLabel.numberOfLines = 0
    
    stackView.isUserInteractionEnabled = false
    
    addSubview(containerView)
    containerView.addSubview(stackView)
    containerView.addSubview(closeButton)
    stackView.addArrangedSubview(titleLabel)
    stackView.addArrangedSubview(captionLabel)
    stackView.addArrangedSubview(beforeActionButtonSpacingView)
    stackView.addArrangedSubview(actionButton)
    setupConstraints()
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapHandler?()
    }), for: .touchUpInside)
  }
  
  func setupConstraints() {
    closeButton.setContentHuggingPriority(.required, for: .horizontal)
    
    containerView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.left.equalTo(self).offset(CGFloat.containerPadding)
      make.right.equalTo(self).offset(-CGFloat.containerPadding)
    }
    
    closeButton.snp.makeConstraints { make in
      make.top.equalTo(self).offset(CGFloat.containerPadding)
      make.right.equalTo(containerView).offset(-UIEdgeInsets.contentPadding.right)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.equalTo(containerView.snp.top).offset(UIEdgeInsets.contentPadding.top)
      make.left.equalTo(containerView.snp.left).offset(UIEdgeInsets.contentPadding.left)
      make.right.equalTo(closeButton.snp.left)
      make.bottom.equalTo(containerView.snp.bottom).offset(-UIEdgeInsets.contentPadding.bottom)
    }
  }
}

private extension CGFloat {
  static let containerPadding: CGFloat = 0
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
}
