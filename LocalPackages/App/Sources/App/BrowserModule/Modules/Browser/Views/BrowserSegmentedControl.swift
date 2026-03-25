import SnapKit
import TKUIKit
import UIKit

final class BrowserSegmentedControl: UIView, ConfigurableView {
    lazy var exploreButton = createButton()
    lazy var connectedButton = createButton()
    private let buttonContainer = UIView()
    private let selectionIndicatorView = UIView()

    private var exploreButtonTapAction: (() -> Void)?
    private var connectedButtonTapAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        struct Button {
            let title: String
            let tapAction: () -> Void
        }

        let exploreButton: Button
        let connectedButton: Button
        let isExploreTabVisible: Bool
    }

    func configure(model: Model) {
        exploreButton.isHidden = !model.isExploreTabVisible
        exploreButton.setAttributedTitle(
            model.exploreButton.title.withTextStyle(
                .label2,
                color: .Button.secondaryForeground,
                alignment: .center
            ),
            for: .normal
        )
        exploreButton.setAttributedTitle(
            model.exploreButton.title.withTextStyle(
                .label2,
                color: .Button.secondaryForeground.withAlphaComponent(0.48),
                alignment: .center
            ),
            for: .highlighted
        )
        exploreButtonTapAction = model.exploreButton.tapAction

        connectedButton.setAttributedTitle(
            model.connectedButton.title.withTextStyle(
                .label2,
                color: .Button.secondaryForeground,
                alignment: .center
            ),
            for: .normal
        )
        connectedButton.setAttributedTitle(
            model.connectedButton.title.withTextStyle(
                .label2,
                color: .Button.secondaryForeground.withAlphaComponent(0.48),
                alignment: .center
            ),
            for: .highlighted
        )
        connectedButtonTapAction = model.connectedButton.tapAction

        updateConstraintsForExploreVisible(model.isExploreTabVisible)
        if !model.isExploreTabVisible {
            selectConnectedButton()
        }
    }

    func selectExploreButton() {
        guard !exploreButton.isSelected else { return }
        exploreButton.isSelected = true
        connectedButton.isSelected = false
        selectionIndicatorView.snp.remakeConstraints { make in
            make.edges.equalTo(exploreButton)
        }
        animateLayout()
        exploreButtonTapAction?()
    }

    func selectConnectedButton() {
        guard !connectedButton.isSelected else { return }
        connectedButton.isSelected = true
        exploreButton.isSelected = false
        selectionIndicatorView.snp.remakeConstraints { make in
            make.edges.equalTo(connectedButton)
        }
        animateLayout()
        connectedButtonTapAction?()
    }
}

private extension BrowserSegmentedControl {
    func setup() {
        selectionIndicatorView.backgroundColor = .Button.secondaryBackground
        selectionIndicatorView.layer.cornerRadius = 16

        exploreButton.isSelected = true

        connectedButton.addAction(UIAction(handler: { [weak self] _ in
            self?.selectConnectedButton()
        }), for: .touchUpInside)

        exploreButton.addAction(UIAction(handler: { [weak self] _ in
            self?.selectExploreButton()
        }), for: .touchUpInside)

        addSubview(buttonContainer)
        buttonContainer.addSubview(selectionIndicatorView)
        buttonContainer.addSubview(exploreButton)
        buttonContainer.addSubview(connectedButton)

        setupConstraints()
    }

    func setupConstraints() {
        buttonContainer.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(8)
        }

        exploreButton.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(buttonContainer)
            make.height.equalTo(32)
        }

        connectedButton.snp.makeConstraints { make in
            make.top.right.bottom.equalTo(buttonContainer)
            make.left.equalTo(exploreButton.snp.right)
            make.height.equalTo(32)
        }

        selectionIndicatorView.snp.makeConstraints { make in
            make.edges.equalTo(exploreButton)
        }
    }

    func updateConstraintsForExploreVisible(_ isExploreVisible: Bool) {
        connectedButton.snp.remakeConstraints { make in
            make.top.right.bottom.equalTo(buttonContainer)
            make.height.equalTo(32)
            if isExploreVisible {
                make.left.equalTo(exploreButton.snp.right)
            } else {
                make.left.equalTo(buttonContainer)
            }
        }
    }

    func createButton() -> UIButton {
        let button = UIButton()
        button.configuration = {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: 6,
                leading: 12,
                bottom: 6,
                trailing: 12
            )
            return configuration
        }()
        button.configurationUpdateHandler = { configButton in
            var config = configButton.configuration ?? .plain()
            config.background.backgroundColor = .clear
            configButton.configuration = config
        }
        return button
    }

    func animateLayout() {
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: .curveEaseInOut
        ) {
            self.buttonContainer.layoutIfNeeded()
        }
    }
}
