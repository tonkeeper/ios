import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class WalletBalanceHeaderButtonsRedesignView: UIView, ConfigurableView {
    private lazy var tooltipHostingController: UIHostingController<TKTooltipView> = {
        let hostingController = UIHostingController(rootView: TKTooltipView(configuration: nil))
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        hostingController.view.alpha = 0
        hostingController.view.isHidden = true
        hostingController.view.transform = CGAffineTransform(translationX: 0, y: 6)
        return hostingController
    }()

    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fill
        view.spacing = 0
        return view
    }()

    private let withdrawButton = TKIconCircleButton()
    private let depositButton = TKIconCircleButton()
    private let swapButton = TKIconCircleButton()
    private let stakeButton = TKIconCircleButton()

    private var isTooltipVisible = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        struct Tooltip {
            let title: String
            let badgeTitle: String?
        }

        struct Button {
            let title: String
            let icon: UIImage
            let isEnabled: Bool
            let action: () -> Void
        }

        let withdrawButton: Button
        let depositButton: Button
        let swapButton: Button?
        let stakeButton: Button?
        let tooltip: Tooltip?
    }

    func configure(model: Model) {
        withdrawButton.configuration = buttonConfiguration(model: model.withdrawButton)
        depositButton.configuration = buttonConfiguration(model: model.depositButton)

        if let swap = model.swapButton {
            swapButton.configuration = buttonConfiguration(model: swap)
            swapButton.isHidden = false
        } else {
            swapButton.isHidden = true
        }

        if let stake = model.stakeButton {
            stakeButton.configuration = buttonConfiguration(model: stake)
            stakeButton.isHidden = false
        } else {
            stakeButton.isHidden = true
        }

        if let tooltip = model.tooltip {
            tooltipHostingController.rootView = TKTooltipView(
                configuration: TKTooltipView.Configuration(
                    title: tooltip.title,
                    badgeTitle: tooltip.badgeTitle
                )
            )
            setTooltipVisible(true, animated: !isTooltipVisible)
        } else {
            setTooltipVisible(false, animated: isTooltipVisible) { [weak self] in
                self?.tooltipHostingController.rootView = TKTooltipView(configuration: nil)
            }
        }
    }

    func isTooltipContains(point: CGPoint) -> Bool {
        guard isTooltipVisible, !tooltipHostingController.view.isHidden else {
            return false
        }

        return tooltipHostingController.view.frame.contains(point)
    }
}

private extension WalletBalanceHeaderButtonsRedesignView {
    func setup() {
        clipsToBounds = false

        addSubview(tooltipHostingController.view)

        stackView.addArrangedSubview(withdrawButton)
        stackView.addArrangedSubview(depositButton)
        stackView.addArrangedSubview(swapButton)
        stackView.addArrangedSubview(stakeButton)

        addSubview(stackView)
        setupConstraints()
    }

    func setupConstraints() {
        tooltipHostingController.view.snp.makeConstraints { make in
            make.leading.equalTo(withdrawButton.snp.leading).offset(14)
            make.bottom.equalTo(withdrawButton.snp.top).offset(2)
            make.height.equalTo(46)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.centerX.equalTo(self)
            make.bottom.equalTo(self).inset(NSDirectionalEdgeInsets.padding.bottom)
        }

        for button in [withdrawButton, depositButton, swapButton, stakeButton] {
            button.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(76)
            }
        }
    }

    func setTooltipVisible(
        _ isVisible: Bool,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard isTooltipVisible != isVisible || !animated else {
            completion?()
            return
        }

        isTooltipVisible = isVisible

        let animations = {
            self.tooltipHostingController.view.alpha = isVisible ? 1 : 0
            self.tooltipHostingController.view.transform = isVisible ? .identity : CGAffineTransform(translationX: 0, y: 6)
        }

        if isVisible {
            tooltipHostingController.view.isHidden = false
        }

        if animated {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState]
            ) {
                animations()
            } completion: { _ in
                if !isVisible {
                    self.tooltipHostingController.view.isHidden = true
                }
                completion?()
            }
        } else {
            animations()
            tooltipHostingController.view.isHidden = !isVisible
            completion?()
        }
    }

    private func buttonConfiguration(model: Model.Button) -> TKIconCircleButton.Configuration {
        TKIconCircleButton.Configuration(
            title: model.title,
            icon: model.icon,
            isEnable: model.isEnabled,
            action: model.action
        )
    }
}

private extension NSDirectionalEdgeInsets {
    /// [DEPOSIT] TODO: - check insets
    static var padding = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 12,
        trailing: 16
    )
}
