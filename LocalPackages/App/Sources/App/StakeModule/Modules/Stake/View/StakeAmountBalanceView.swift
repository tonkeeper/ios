//
//  StakeAmountBalanceView.swift
//  Tonkeeper
//
//  Created by Semyon on 13/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeAmountBalanceView: UIView {
    
    var didTapMax: (() -> Void)?
    
    var convertedValue: String = "" {
        didSet {
            availableLabel.attributedText = convertedValue.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .right,
                lineBreakMode: .byTruncatingTail
            )
        }
    }
    
    let maxButton = TKButton()
    let insufficientLabel = UILabel()
    let availableLabel = UILabel()
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 8
        return stackView
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48)
    }
    
    // MARK: - Private methods
    
    private func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(maxButton)
        stackView.addArrangedSubview(availableLabel)
        stackView.addArrangedSubview(insufficientLabel)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        maxButton.setContentHuggingPriority(.required, for: .horizontal)
        maxButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        maxButton.addAction(UIAction(handler: { [weak self] _ in
            self?.didTapMax?()
        }), for: .touchUpInside)
        
        insufficientLabel.isHidden = true
        insufficientLabel.attributedText = "Insufficient balance".withTextStyle(
            .body2,
            color: .Accent.red,
            alignment: .right,
            lineBreakMode: .byTruncatingTail
        )
    
        availableLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        insufficientLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
