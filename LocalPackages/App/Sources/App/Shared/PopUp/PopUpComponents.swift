import UIKit
import TKUIKit

extension PopUp {
  enum Component {}
}

extension PopUp.Component {
  struct LabelComponent: PopUp.Item {
    func getView() -> UIView {
      let label = UILabel()
      label.numberOfLines = numberOfLines
      label.attributedText = text
      return label
    }
    
    private let text: NSAttributedString
    private let numberOfLines: Int
    let bottomSpace: CGFloat
    
    init(text: NSAttributedString,
         numberOfLines: Int = 1,
         bottomSpace: CGFloat = 0) {
      self.text = text
      self.numberOfLines = numberOfLines
      self.bottomSpace = bottomSpace
    }
  }
}

extension PopUp.Component {
  struct GroupComponent: PopUp.Item {
    func getView() -> UIView {
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
    private let items: [PopUp.Item]
    let bottomSpace: CGFloat
    
    init(padding: UIEdgeInsets,
         items: [PopUp.Item],
         bottomSpace: CGFloat = 0) {
      self.padding = padding
      self.items = items
      self.bottomSpace = bottomSpace
    }
  }
}

extension PopUp.Component {
  struct ImageComponent: PopUp.Item {
    func getView() -> UIView {
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
    let bottomSpace: CGFloat
    
    init(image: TKImageView.Model,
         bottomSpace: CGFloat) {
      self.image = image
      self.bottomSpace = bottomSpace
    }
  }
}

extension PopUp.Component {
  struct ButtonComponent: PopUp.Item {
    func getView() -> UIView {
      let button = TKButton()
      button.configuration = buttonConfiguration
      return button
    }
    private let buttonConfiguration: TKButton.Configuration
    let bottomSpace: CGFloat
    
    init(buttonConfiguration: TKButton.Configuration,
         bottomSpace: CGFloat = 0) {
      self.buttonConfiguration = buttonConfiguration
      self.bottomSpace = bottomSpace
    }
  }
}

extension PopUp.Component {
  struct ButtonGroupComponent: PopUp.Item {
    var bottomSpace: CGFloat { 0 }
    
    func getView() -> UIView {
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
    
    init(buttons: [ButtonComponent]) {
      self.buttons = buttons
    }
  }
}

extension PopUp.Component {
  struct TickItem: PopUp.Item {
    func getView() -> UIView {
      let view = TKDetailsTickView()
      view.configure(model: model)
      return view
    }
    
    private let model: TKDetailsTickView.Model
    let bottomSpace: CGFloat
    
    init(model: TKDetailsTickView.Model,
         bottomSpace: CGFloat = 0) {
      self.model = model
      self.bottomSpace = bottomSpace
    }
  }
}
