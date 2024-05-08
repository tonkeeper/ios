import UIKit

public extension TKButton {
  struct Configuration {
    public var content: Content
    public var contentPadding: UIEdgeInsets
    public var padding: UIEdgeInsets
    public var spacing: CGFloat
    public var textStyle: TKTextStyle
    public var textColor: UIColor
    public var iconPosition: TKButtonIconPosition
    public var iconTintColor: UIColor
    public var backgroundColors: [TKButtonState: UIColor]
    public var contentAlpha: [TKButtonState: CGFloat]
    public var cornerRadius: CGFloat
    public var isEnabled: Bool
    public var showsLoader: Bool
    public var loaderSize: TKLoaderView.Size
    public var loaderStyle: TKLoaderView.Style
    public var action: (() -> Void)?
    
    public init(content: Content = Content(),
                contentPadding: UIEdgeInsets = .zero,
                padding: UIEdgeInsets = .zero,
                spacing: CGFloat = 0,
                textStyle: TKTextStyle = .label2,
                textColor: UIColor = .white,
                iconPosition: TKButtonIconPosition = .left,
                iconTintColor: UIColor = .white,
                backgroundColors: [TKButtonState : UIColor] = [.normal: .clear],
                contentAlpha: [TKButtonState : CGFloat] = [.normal: 1, .disabled: 0.48],
                cornerRadius: CGFloat = 0,
                isEnabled: Bool = true,
                showsLoader: Bool = false,
                loaderSize: TKLoaderView.Size = .small,
                loaderStyle: TKLoaderView.Style = .primary,
                action: (() -> Void)? = nil) {
      self.content = content
      self.contentPadding = contentPadding
      self.padding = padding
      self.spacing = spacing
      self.textStyle = textStyle
      self.textColor = textColor
      self.iconPosition = iconPosition
      self.iconTintColor = iconTintColor
      self.backgroundColors = backgroundColors
      self.contentAlpha = contentAlpha
      self.cornerRadius = cornerRadius
      self.isEnabled = isEnabled
      self.showsLoader = showsLoader
      self.loaderSize = loaderSize
      self.loaderStyle = loaderStyle
      self.action = action
    }
  }
}

public extension TKButton.Configuration {
  struct Content: Hashable {
    public enum Title: Hashable {
      case plainString(String)
      case attributedString(NSAttributedString)
    }
    public var title: Title?
    public var icon: UIImage?
    
    public init(title: Title? = nil, icon: UIImage? = nil) {
      self.title = title
      self.icon = icon
    }
  }
}

public extension TKButton.Configuration {
  static func actionButtonConfiguration(category: TKActionButtonCategory,
                                        size: TKActionButtonSize) -> TKButton.Configuration {
    TKButton.Configuration(
      content: Content(),
      contentPadding: size.padding,
      textStyle: size.textStyle,
      textColor: category.titleColor,
      backgroundColors: [
        .normal: category.backgroundColor,
        .highlighted: category.highlightedBackgroundColor,
        .disabled: category.disabledBackgroundColor
      ],
      cornerRadius: size.cornerRadius,
      loaderSize: size.loaderViewSize,
      action: nil
    )
  }
  
  static func iconHeaderButtonConfiguration(
    contentPadding: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
    padding: UIEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
  ) -> TKButton.Configuration {
    TKButton.Configuration(
      content: Content(),
      contentPadding: contentPadding,
      padding: padding,
      iconTintColor: .Button.secondaryForeground,
      backgroundColors: [
        .normal: .Button.secondaryBackground,
        .highlighted: .Button.secondaryBackgroundHighlighted,
        .disabled: .Button.secondaryBackgroundDisabled
      ],
      cornerRadius: 16,
      action: nil
    )
  }
  
  static func titleHeaderButtonConfiguration(category: TKActionButtonCategory) -> TKButton.Configuration {
    TKButton.Configuration(
      content: Content(),
      contentPadding: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12),
      padding: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8),
      textStyle: .label2,
      textColor: category.titleColor,
      backgroundColors: [
        .normal: category.backgroundColor,
        .highlighted: category.highlightedBackgroundColor,
        .disabled: category.disabledBackgroundColor
      ],
      cornerRadius: 16,
      action: nil
    )
  }
  
  static func accentButtonConfiguration(padding: UIEdgeInsets) -> TKButton.Configuration {
    TKButton.Configuration(
      content: Content(),
      contentPadding: .zero,
      padding: padding,
      textStyle: .label1,
      textColor: .Accent.blue,
      iconTintColor: .Accent.blue,
      contentAlpha: [.normal: 1, .disabled: 0.48, .highlighted: 0.48],
      action: nil
    )
  }
  
  static func headerAccentButtonConfiguration() -> TKButton.Configuration {
    accentButtonConfiguration(padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
  }
  
  static func fieldAccentButtonConfiguration() -> TKButton.Configuration {
    accentButtonConfiguration(padding: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
  }
  
  static func fiedClearButtonConfiguration() -> TKButton.Configuration {
    TKButton.Configuration(
      content: Content(icon: .TKUIKit.Icons.Size16.xmarkCircle),
      contentPadding: .zero,
      padding: UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20),
      iconTintColor: .Icon.secondary,
      contentAlpha: [.normal: 1, .disabled: 0.48, .highlighted: 0.48],
      action: nil
    )
  }
}
