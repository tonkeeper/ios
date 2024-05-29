import TKUIKit
import UIKit

final class SwapSearchTokenTextField: UIView {
    var didUpdateText: ((String) -> Void)?
    
    let textField: TKTextInputTextFieldControl = {
        let v = TKTextInputTextFieldControl()
        v.backgroundColor = .Background.content
        v.attributedPlaceholder = "Search".withTextStyle(.body1, color: .Text.secondary)
        
        let leftView = TKUIIconButton()
        let leftViewImage = UIImage(systemName: "magnifyingglass")?.withTintColor(
            .Text.secondary,
            renderingMode: .alwaysOriginal
        )
        leftView.configure(model: .init(image: leftViewImage ?? .init(), title: ""))
        leftView.padding = .init(top: 10, left: 10, bottom: 10, right: 10)
        
        v.leftViewMode = .always
        v.leftView = leftView
        
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textField)
        textField.didUpdateText = { [weak self] in
            self?.didUpdateText?($0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        textField.frame = bounds
        
        let size = min(bounds.width, bounds.height)
        let cornerRadius = min(size / 2.0, 16.0)
        textField.layer.cornerRadius = cornerRadius
    }
}

final class SwapSearchTokenView: UIView {
    lazy var textField = SwapSearchTokenTextField()
    
    lazy var closeButton: TKUIHeaderIconButton = {
        let v = TKUIHeaderIconButton()
        v.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )
        v.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return v
    }()
    
    lazy var navigationBarView: TKNavigationBarContainer = {
        let titleView = UILabel()
        titleView.attributedText = "Choose Token".withTextStyle(.h3, color: .Text.primary)
                
        let v = TKNavigationBarContainer(
            contentView: textField,
            contentViewSize: { _, size in .init(width: size.width, height: 48) }
        )
        v.barViews = [titleView, closeButton]
        return v
    }()
    
    let collectionView = TKUICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewLayout()
    )
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        collectionView.backgroundColor = .Background.page
        collectionView.showsVerticalScrollIndicator = false
        addSubview(collectionView)
        
        addSubview(navigationBarView)
        navigationBarView.scrollView = collectionView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
}

private extension SwapSearchTokenView {
    func updateLayout(in bounds: CGSize) {
        collectionView.contentSize = bounds
        collectionView.frame = .init(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let size = navigationBarView.sizeThatFits(bounds)
        navigationBarView.frame = .init(x: 0, y: 0, width: bounds.width, height: size.height)
        
        collectionView.contentInset.top = navigationBarView.additionalInset
        collectionView.verticalScrollIndicatorInsets.top = navigationBarView.additionalInset
    }
}
