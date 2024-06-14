import UIKit
import TKUIKit

final class LedgerStepView: TKView, ConfigurableView {
  enum State {
    case idle
    case inProgress
    case done
  }
 
  private let stateIndicatorView = IndicatorView()
  private let contentView = UIView()
  private let contentLabel = UILabel()
  private let linkButton = LinkButton()
  
  override func setup() {
    super.setup()
    
    addSubview(stateIndicatorView)
    addSubview(contentView)
    contentView.addSubview(contentLabel)
    contentView.addSubview(linkButton)

    contentLabel.numberOfLines = 0
    
    stateIndicatorView.setContentHuggingPriority(.required, for: .horizontal)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    stateIndicatorView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(2)
      make.left.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.left.equalTo(stateIndicatorView.snp.right).offset(8)
      make.top.right.bottom.equalTo(self)
    }
    
    contentLabel.snp.makeConstraints { make in
      make.left.top.right.equalTo(contentView)
    }
    
    linkButton.snp.makeConstraints { make in
      make.left.bottom.right.equalTo(contentView)
      make.top.equalTo(contentLabel.snp.bottom)
    }
  }
  
  final class Model {
    let content: String
    let linkButton: LinkButton.Model?
    let state: State
    
    init(content: String, 
         linkButton: LinkButton.Model?,
         state: State) {
      self.content = content
      self.linkButton = linkButton
      self.state = state
    }
  }
  
  func configure(model: Model) {
    configure(content: model.content, linkButton: model.linkButton, state: model.state)
  }
  
  private func configure(content: String,
                         linkButton: LinkButton.Model?,
                         state: State) {
    let contentColor: UIColor
    switch state {
    case .idle:
      contentColor = .Text.primary
    case .inProgress:
      contentColor = .Text.primary
    case .done:
      contentColor = .Accent.green
    }
    
    contentLabel.attributedText = content.withTextStyle(
      .body2,
      color: contentColor,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    self.linkButton.configure(model: linkButton)
    
    stateIndicatorView.state = state
  }
}

private extension LedgerStepView {
  final class IndicatorView: TKView {
    
    var state: State = .idle {
      didSet {
        didUpdateState(animated: true)
      }
    }
    
    private let loaderView = TKLoaderView(size: .xSmall, style: .secondary)
    private let imageView = UIImageView()
    
    override func setup() {
      super.setup()
      
      addSubview(loaderView)
      addSubview(imageView)
      
      didUpdateState(animated: false)
      
      setupConstraints()
    }
    
    override var intrinsicContentSize: CGSize {
      CGSize(width: 16, height: 16)
    }
    
    override func setupConstraints() {
      loaderView.snp.makeConstraints { make in
        make.center.equalTo(self)
      }
      
      imageView.snp.makeConstraints { make in
        make.center.equalTo(self)
      }
    }
    
    private func didUpdateState(animated: Bool) {
      let loaderAlpha: CGFloat
      let iconImage: UIImage?
      let iconAlpha: CGFloat
      let iconColor: UIColor?
      
      switch state {
      case .done:
        iconColor = .Accent.green
        loaderAlpha = 0
        iconAlpha = 1
        iconImage = .TKUIKit.Icons.Size16.done
      case .idle:
        iconColor = .Icon.tertiary
        loaderAlpha = 0
        iconAlpha = 1
        iconImage = .TKUIKit.Icons.Size16.dote
      case .inProgress:
        iconColor = nil
        loaderAlpha = 1
        iconAlpha = 0
        iconImage = nil
      }
      
      loaderView.alpha = loaderAlpha
      imageView.alpha = iconAlpha
      imageView.image = iconImage
      imageView.tintColor = iconColor
    }
  }
}

extension LedgerStepView {
  final class LinkButton: UIControl {
    override var isHighlighted: Bool {
      didSet {
        label.alpha = isHighlighted ? 0.48 : 1
      }
    }
    
    private let label = UILabel()
    private var tapClosure: (() -> Void)?
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      addSubview(label)
      label.snp.makeConstraints { make in
        make.edges.equalTo(self)
      }
      addAction(UIAction(handler: { [weak self] _ in
        self?.tapClosure?()
      }), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    struct Model {
      let title: String
      let tapClosure: (() -> Void)?
    }
    
    func configure(model: Model?) {
      label.attributedText = model?.title.withTextStyle(
        .body2,
        color: .Text.accent,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
      tapClosure = model?.tapClosure
    }
  }
}
