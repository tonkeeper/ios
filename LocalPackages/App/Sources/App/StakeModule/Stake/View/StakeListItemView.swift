//
//  StakingListItemView.swift
//
//
//  Created by Semyon on 13/05/2024.
//

import UIKit
import TKUIKit
import SnapKit

final class StakeListItemView: UIView {
    
    // MARK: - Spec
    
    enum Spec {
        static let animationDuration = 0.1
        static let animationScale = CGAffineTransform(scaleX: 0.98, y: 0.98)
        
        static let backgroundColor = UIColor.Background.content
        static let highlightableBackgroundColor = UIColor.Background.highlighted
        
        static let cornerRadius: CGFloat = 16
    }
    
    // MARK: - UI
    
    private let listItemView = TKUIListItemView()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public struct Configuration: Hashable {
        let listItemConfiguration: TKUIListItemView.Configuration
    }
    
    // MARK: - Methods
    
    private func setup() {
        backgroundColor = Spec.backgroundColor
        layer.cornerRadius = Spec.cornerRadius
        
        addSubview(listItemView)
        listItemView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets.stakingPadding)
        }
    }
    
    public func configure(configuration: Configuration) {
        listItemView.configure(configuration: configuration.listItemConfiguration)
    }
}

extension StakeListItemView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        pressAnimation(isPressed: true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        pressAnimation(isPressed: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        pressAnimation(isPressed: false)
    }
    
    private func pressAnimation(isPressed: Bool) {
        UIView.animate(withDuration: Spec.animationDuration, delay: 0, options: .curveEaseOut) { [weak self] in
            guard let self else { return }
            self.transform = isPressed ? Spec.animationScale : .identity
        }
        backgroundColor = isPressed ? Spec.highlightableBackgroundColor : Spec.backgroundColor
    }
}

private extension UIEdgeInsets {
    static let stakingPadding = UIEdgeInsets(
        top: 16,
        left: 16,
        bottom: 16,
        right: 22
    )
}
