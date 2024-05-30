import UIKit

public final class TKUIListItemIconView: UIView, TKConfigurableView {
  
  var badgeIconView: UIView?
  
  private var iconView: UIView?
  private var alignment: Configuration.Alignment = .top
  
  public struct Configuration: Hashable {
    public enum Alignment: Hashable {
      case top
      case center
    }
    
    public enum IconConfiguration: Hashable {
      case none
      case image(TKUIListItemImageIconView.Configuration)
      case emoji(TKUIListItemEmojiIconView.Configuration)
      case imageWithBadge(TKUIListItemImageIconView.Configuration, TKUIListItemImageIconView.Configuration)
    }
    
    public let iconConfiguration: IconConfiguration
    public let alignment: Alignment
    
    public init(iconConfiguration: IconConfiguration, alignment: Alignment) {
      self.iconConfiguration = iconConfiguration
      self.alignment = alignment
    }
  }
  
  public func configure(configuration: Configuration) {
    switch configuration.iconConfiguration {
    case .none:
      configureNone()
    case .image(let configuration):
      configure(imageIconConfiguration: configuration)
    case .emoji(let configuration):
      configure(emojiIconConfiguration: configuration)
    case .imageWithBadge(let mainConfiguration, let badgeConfiguration):
      configure(mainIconConfiguration: mainConfiguration, badgeIconConfiguration: badgeConfiguration)
    }
    self.alignment = configuration.alignment
    setNeedsLayout()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    guard let iconView = iconView else { return .zero }
    return iconView.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    if let iconView {
      iconView.sizeToFit()
      switch alignment {
      case .top:
        iconView.frame = CGRect(
          x: .zero,
          y: .zero,
          width: iconView.bounds.width,
          height: iconView.bounds.height
        )
      case .center:
        iconView.center = CGPoint(
          x: bounds.width/2,
          y: bounds.height/2
        )
      }
      
      if let badgeIconView {
        badgeIconView.sizeToFit()
        badgeIconView.center = CGPoint(
          x: iconView.frame.maxX - badgeIconView.frame.width / 3,
          y: iconView.frame.maxY - badgeIconView.frame.width / 3
        )
        let size = CGSize(
          width: badgeIconView.frame.width + badgeIconView.layer.borderWidth,
          height: badgeIconView.frame.width + badgeIconView.layer.borderWidth
        )
        badgeIconView.frame.size = size
      }
    }
  }
}

private extension TKUIListItemIconView {
  func configureNone() {
    iconView?.removeFromSuperview()
    iconView = nil
    badgeIconView?.removeFromSuperview()
    badgeIconView = nil
  }
  
  func configure(mainIconConfiguration: TKUIListItemImageIconView.Configuration, badgeIconConfiguration: TKUIListItemImageIconView.Configuration) {
    configure(imageIconConfiguration: mainIconConfiguration)
    
    if let badgeImageIconView = badgeIconView as? TKUIListItemImageIconView {
      badgeImageIconView.configure(configuration: badgeIconConfiguration)
    } else {
      badgeIconView?.removeFromSuperview()
      let badgeIconView = TKUIListItemImageIconView()
      badgeIconView.configure(configuration: badgeIconConfiguration)
      addSubview(badgeIconView)
      self.badgeIconView = badgeIconView
    }
  }
  
  func configure(imageIconConfiguration: TKUIListItemImageIconView.Configuration) {
    if let imageIconView = iconView as? TKUIListItemImageIconView {
      imageIconView.configure(configuration: imageIconConfiguration)
    } else {
      iconView?.removeFromSuperview()
      let imageIconView = TKUIListItemImageIconView()
      imageIconView.configure(configuration: imageIconConfiguration)
      addSubview(imageIconView)
      iconView = imageIconView
    }
  }
  
  func configure(emojiIconConfiguration: TKUIListItemEmojiIconView.Configuration) {
    if let emojiIconView = iconView as? TKUIListItemEmojiIconView {
      emojiIconView.configure(configuration: emojiIconConfiguration)
    } else {
      iconView?.removeFromSuperview()
      let emojiIconView = TKUIListItemEmojiIconView()
      emojiIconView.configure(configuration: emojiIconConfiguration)
      addSubview(emojiIconView)
      iconView = emojiIconView
    }
  }
}
