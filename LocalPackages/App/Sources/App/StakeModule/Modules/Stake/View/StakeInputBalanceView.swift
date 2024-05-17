//
//  StakeInputBalanceView.swift
//
//
//  Created by Semyon on 13/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeInputBalanceView: UIView {
    
    // MARK: - UI
    
    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        return stackView
    }()
    
    let balanceButton = TKButton()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Methods
    
    private func setup() {
        addSubview(contentStackView)
        
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        balanceButton.setContentHuggingPriority(.required, for: .horizontal)
        balanceButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        contentStackView.addArrangedSubview(UIView())
        contentStackView.addArrangedSubview(balanceButton)
        contentStackView.addArrangedSubview(UIView())
    }
    
    // MARK: - Public Methods
    
    func configure(amount: String, isNeedIcon: Bool) {
        var configuration = TKButton.Configuration.stakeBalanceButtonConfiguration()
        configuration.content.title = .plainString(amount)
        configuration.content.icon = isNeedIcon ? .TKUIKit.Icons.Size16.chevronRight : nil
        balanceButton.configuration = configuration
    }
}
