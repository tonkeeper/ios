import UIKit
import TKUIKit
import SnapKit

open class SearchBar: UISearchBar {
  
  enum TextFieldState {
    case inactive
    case active
    
    var borderColor: UIColor {
      switch self {
      case .inactive:
        return .Background.content
      case .active:
        return .Field.activeBorder
      }
    }
  }
  
  var textDidChange: ((String) -> Void)?
  
  var textFieldState: TextFieldState = .inactive {
    didSet {
      UIView.animate(withDuration: 0.2) {
        self.didUpdateState()
      }
    }
  }
  
  open override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 48) }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    delegate = self
    
    backgroundImage = UIImage()
    backgroundColor = .Background.content
    
    layer.borderWidth = 1.5
    layer.cornerRadius = 16
    
    searchTextField.autocapitalizationType = .none
    searchTextField.autocorrectionType = .no
    searchTextField.keyboardAppearance = .dark
    searchTextField.font = TKTextStyle.body1.font
    searchTextField.backgroundColor = .clear
    searchTextField.attributedPlaceholder = "Search".withTextStyle(.body1, color: .Text.secondary)
    searchTextField.defaultTextAttributes = [
      .font : TKTextStyle.body1.font,
      .foregroundColor : UIColor.Text.primary
    ]
    
    let magnifyingGlassIcon = UIImage.TKUIKit.Icons.Size16.magnifyingGlass.withTintColor(.Icon.secondary, renderingMode: .alwaysOriginal)
    setImage(magnifyingGlassIcon, for: .search, state: .normal)
    
    let clearButton = searchTextField.value(forKey: "clearButton") as? UIButton
    let xmarkCircleIcon = UIImage.TKUIKit.Icons.Size16.xmarkCircle
    clearButton?.setImage(xmarkCircleIcon, for: .normal)
    clearButton?.tintColor = .Icon.secondary
    
    searchTextField.addAction(UIAction(handler: { [weak self] _ in
      self?.editingDidBegin()
    }), for: .editingDidBegin)
    
    searchTextField.addAction(UIAction(handler: { [weak self] _ in
      self?.editingDidEnd()
    }), for: .editingDidEnd)
    
    didUpdateState()
  }
  
  private func editingDidBegin() {
    textFieldState = .active
  }
  
  private func editingDidEnd() {
    textFieldState = .inactive
  }
  
  private func didUpdateState() {
    layer.borderColor = textFieldState.borderColor.cgColor
  }
}

extension SearchBar: UISearchBarDelegate {
  public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    textDidChange?(searchText)
  }
}
