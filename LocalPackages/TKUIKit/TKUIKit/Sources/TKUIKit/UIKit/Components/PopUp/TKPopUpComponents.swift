import UIKit

public extension TKPopUp {
  enum Component {}
}

public extension TKPopUp.Component {
  struct LabelComponent: TKPopUp.Item {
    public func getView() -> UIView {
      let label = UILabel()
      label.numberOfLines = numberOfLines
      label.attributedText = text
      return label
    }
    
    private let text: NSAttributedString
    private let numberOfLines: Int
    public let bottomSpace: CGFloat
    
    public init(text: NSAttributedString,
                numberOfLines: Int = 1,
                bottomSpace: CGFloat = 0) {
      self.text = text
      self.numberOfLines = numberOfLines
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct GroupComponent: TKPopUp.Item {
    public func getView() -> UIView {
      let containerView = UIView()
      let stackView = UIStackView()
      stackView.axis = .vertical
      
      containerView.addSubview(stackView)
      stackView.snp.makeConstraints { make in
        make.edges.equalTo(containerView).inset(padding)
      }
      
      for item in items {
        let view = item.getView()
        stackView.addArrangedSubview(view)
        stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(item.bottomSpace)))
      }
      
      return containerView
    }
    
    private let padding: UIEdgeInsets
    private let items: [TKPopUp.Item]
    public let bottomSpace: CGFloat
    
    public init(padding: UIEdgeInsets,
                items: [TKPopUp.Item],
                bottomSpace: CGFloat = 0) {
      self.padding = padding
      self.items = items
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct ImageComponent: TKPopUp.Item {
    public func getView() -> UIView {
      let containerView = UIView()
      let imageView = TKImageView()
      
      containerView.addSubview(imageView)
      imageView.snp.makeConstraints { make in
        make.top.bottom.equalTo(containerView)
        make.centerX.equalTo(containerView)
      }
      
      imageView.configure(model: image)
      
      return containerView
    }
    private let image: TKImageView.Model
    public let bottomSpace: CGFloat
    
    public init(image: TKImageView.Model,
                bottomSpace: CGFloat) {
      self.image = image
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct ButtonComponent: TKPopUp.Item {
    public func getView() -> UIView {
      let button = TKButton()
      button.configuration = buttonConfiguration
      return button
    }
    private let buttonConfiguration: TKButton.Configuration
    public let bottomSpace: CGFloat
    
    public init(buttonConfiguration: TKButton.Configuration,
                bottomSpace: CGFloat = 0) {
      self.buttonConfiguration = buttonConfiguration
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct ButtonGroupComponent: TKPopUp.Item {
    public func getView() -> UIView {
      let containerView = UIView()
      
      let stackView = UIStackView()
      stackView.spacing = 16
      stackView.axis = .vertical
      
      containerView.addSubview(stackView)
      stackView.snp.makeConstraints { make in
        make.edges.equalTo(containerView).inset(16)
      }
      
      for button in buttons {
        let view = button.getView()
        stackView.addArrangedSubview(view)
      }
      
      return containerView
    }
    
    private let buttons: [ButtonComponent]
    public let bottomSpace: CGFloat
    
    public init(buttons: [ButtonComponent],
                bottomSpace: CGFloat = 0) {
      self.buttons = buttons
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct TickItem: TKPopUp.Item {
    public func getView() -> UIView {
      let view = TKDetailsTickView()
      view.configure(model: model)
      return view
    }
    
    private let model: TKDetailsTickView.Model
    public let bottomSpace: CGFloat
    
    public init(model: TKDetailsTickView.Model,
                bottomSpace: CGFloat = 0) {
      self.model = model
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct DetailsDescription: TKPopUp.Item {
    public func getView() -> UIView {
      let view = TKDetailsDescriptionView()
      view.configure(model: model)
      return view
    }
    
    private let model: TKDetailsDescriptionView.Model
    public let bottomSpace: CGFloat
    
    public init(model: TKDetailsDescriptionView.Model,
                bottomSpace: CGFloat = 0) {
      self.model = model
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct TitleCaption: TKPopUp.Item {
    public func getView() -> UIView {
      item.getView()
    }
    
    private let item: TKPopUp.Item
    public let bottomSpace: CGFloat
    
    public init(title: String,
                caption: String?,
                bottomSpace: CGFloat) {
      var items = [TKPopUp.Item]()
      items.append(TKPopUp.Component.LabelComponent(
        text: title
          .withTextStyle(.h2, color: .Text.primary, alignment: .center),
        numberOfLines: 0,
        bottomSpace: 4
      ))
      if let caption {
        items.append(TKPopUp.Component.LabelComponent(
          text: caption
            .withTextStyle(.body1, color: .Text.secondary, alignment: .center),
          numberOfLines: 0))
      }
      item = GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 32, bottom: 16, right: 32),
        items: items
      )
      self.bottomSpace = bottomSpace
    }
  }
}

public extension TKPopUp.Component {
  struct List: TKPopUp.Item {
    public func getView() -> UIView {
      let view = TKListContainerView()
      view.configuration = configuration
      return view
    }
    
    private let configuration: TKListContainerView.Configuration
    public let bottomSpace: CGFloat
    
    public init(configuration: TKListContainerView.Configuration,
                bottomSpace: CGFloat = 0) {
      self.configuration = configuration
      self.bottomSpace = bottomSpace
    }
  }
}
