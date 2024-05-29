import UIKit
import TKUIKit
import SnapKit

final class StakingAmountView: UIView {
    lazy var amountInputContainer = UIView()
    lazy var remainingLabel = UILabel()
    lazy var maxButton = TKButton()
    
    lazy var optionCollectionView = UICollectionView(
        frame: .init(),
        collectionViewLayout: UICollectionViewLayout()
    )
    
    lazy var continueButton = TKButton()
    
    private var continueButtonBottomConstraint: NSLayoutConstraint?
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
                
        addSubview(amountInputContainer)
        
        addSubview(maxButton)
        addSubview(remainingLabel)
        
        optionCollectionView.backgroundColor = .Background.page
        optionCollectionView.isScrollEnabled = false
        addSubview(optionCollectionView)
        
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(continueButton)
        
        let continueButtonBottomConstraint = continueButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        self.continueButtonBottomConstraint = continueButtonBottomConstraint
        
        NSLayoutConstraint.activate([
            continueButtonBottomConstraint,
            continueButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    func embedAmountInputView(_ view: UIView) {
        amountInputContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalTo(amountInputContainer)
        }
    }
    
    func keyboardWillShow(keyboardHeight: CGFloat, animationDuration: Double) {
        continueButtonBottomConstraint?.constant = -(keyboardHeight + 16.0)
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.layoutIfNeeded()
        }
    }
    
    func keyboardWillHide(animationDuration: Double) {
        continueButtonBottomConstraint?.constant = -(safeAreaInsets.bottom)
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.layoutIfNeeded()
        }
    }
}

private extension StakingAmountView {
    func updateLayout(in bounds: CGSize) {
        
        let amountInputContainerMinX = CGFloat.horizontalPadding
        let amountInputContainerMinY = safeAreaInsets.top
        let amountInputContainerWidth = bounds.width - 2 * .horizontalPadding
        let amountInputContainerHeight = CGFloat.amountInputContainerHeight
        
        amountInputContainer.frame = .init(
            x: amountInputContainerMinX,
            y: amountInputContainerMinY,
            width: amountInputContainerWidth,
            height: amountInputContainerHeight
        )
        
        let maxButtonMinX = CGFloat.horizontalPadding
        let maxButtonMinY = amountInputContainerMinY + amountInputContainerHeight + .bottomStackViewTopPadding
        let maxButtonSize = maxButton.sizeThatFits(bounds)
        
        maxButton.frame = .init(
            x: maxButtonMinX,
            y: maxButtonMinY,
            width: maxButtonSize.width,
            height: maxButtonSize.height
        )
        
        let remainingLabelSize = remainingLabel.sizeThatFits(bounds)
        let remainingLabelMinX = bounds.width - remainingLabelSize.width - .horizontalPadding
        let remainingLabelMinY = maxButtonMinY
        
        remainingLabel.frame = .init(
            x: remainingLabelMinX,
            y: remainingLabelMinY,
            width: remainingLabelSize.width,
            height: remainingLabelSize.height
        )
        
        let optionCollectionViewMinX = CGFloat.horizontalPadding
        let optionCollectionViewMinY = maxButtonMinY + maxButtonSize.height + .optionViewTopPadding
        let optionCollectionViewHeight = bounds.height - optionCollectionViewMinY
        
        optionCollectionView.frame = .init(
            x: optionCollectionViewMinX,
            y: optionCollectionViewMinY,
            width: bounds.width - 2 * .horizontalPadding,
            height: optionCollectionViewHeight
        )
    }
}

private extension CGFloat {
    static let horizontalPadding = 16.0
    
    static let amountInputContainerHeight = 178.0
    
    static let bottomStackViewTopPadding = 16.0
    static let bottomStackViewHeight = 36.0
    
    static let optionViewTopPadding = 32.0
    static let optionViewHeight = 76.0
}
