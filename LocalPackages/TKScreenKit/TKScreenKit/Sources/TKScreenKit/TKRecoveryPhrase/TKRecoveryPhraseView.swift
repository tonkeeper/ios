import SnapKit
import TKUIKit
import UIKit

public final class TKRecoveryPhraseView: UIView, ConfigurableView {
    let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        return stackView
    }()

    let titleDescriptionView: TKTitleDescriptionView = {
        var bounds = UIScreen.main.bounds
        let view = TKTitleDescriptionView(size: bounds.height > 568 ? .big : .small)
        view.padding = .titleDescriptionPadding
        return view
    }()

    let titleDescriptionViewContainer = UIView()

    let bannerView = TKRecoverPhraseBannerView()
    let bannerViewContainer = UIView()

    let listView = TKRecoveryPhraseListView()
    let listViewContainer = UIView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ConfigurableView

    public struct Model {
        public struct Button {
            public let configuration: TKButton.Configuration
            public let isFullWidth: Bool
            public init(configuration: TKButton.Configuration, isFullWidth: Bool) {
                self.configuration = configuration
                self.isFullWidth = isFullWidth
            }
        }

        public let titleDescriptionModel: TKTitleDescriptionView.Model
        public let bannerViewModel: TKRecoverPhraseBannerView.Model?
        public let phraseListViewModel: TKRecoveryPhraseListView.Model
        public let buttons: [Button]

        public init(
            titleDescriptionModel: TKTitleDescriptionView.Model,
            bannerViewModel: TKRecoverPhraseBannerView.Model? = nil,
            phraseListViewModel: TKRecoveryPhraseListView.Model,
            buttons: [Button]
        ) {
            self.titleDescriptionModel = titleDescriptionModel
            self.bannerViewModel = bannerViewModel
            self.phraseListViewModel = phraseListViewModel
            self.buttons = buttons
        }
    }

    public func configure(model: Model) {
        titleDescriptionView.configure(model: model.titleDescriptionModel)
        listView.configure(model: model.phraseListViewModel)
        buttonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for buttonModel in model.buttons {
            let button = TKButton()
            button.configuration = buttonModel.configuration
            buttonsStackView.addArrangedSubview(button)
            if buttonModel.isFullWidth {
                button.snp.makeConstraints { make in
                    make.left.right.equalTo(buttonsStackView).inset(16)
                }
            }
        }

        if let bannerViewModel = model.bannerViewModel {
            bannerViewContainer.isHidden = false
            bannerView.configure(model: bannerViewModel)
        } else {
            bannerViewContainer.isHidden = true
        }
    }
}

private extension TKRecoveryPhraseView {
    func setup() {
        backgroundColor = .Background.page
        directionalLayoutMargins.top = .topSpacing

        buttonsStackView.spacing = 12

        addSubview(contentStackView)
        addSubview(buttonsStackView)

        titleDescriptionViewContainer.addSubview(titleDescriptionView)
        bannerViewContainer.addSubview(bannerView)
        listViewContainer.addSubview(listView)

        contentStackView.addArrangedSubview(titleDescriptionViewContainer)
        contentStackView.addArrangedSubview(bannerViewContainer)
        contentStackView.addArrangedSubview(listViewContainer)

        setupConstraints()
    }

    func setupConstraints() {
        contentStackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.equalTo(self)
            make.bottom.equalTo(buttonsStackView.snp.top).offset(-16)
        }

        buttonsStackView.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.left.right.equalTo(self)
        }

        titleDescriptionView.snp.makeConstraints { make in
            make.left.right.equalTo(titleDescriptionViewContainer).inset(32)
            make.bottom.equalTo(titleDescriptionViewContainer).offset(-16)
            make.top.equalTo(titleDescriptionViewContainer)
        }

        bannerView.snp.makeConstraints { make in
            make.edges.equalTo(bannerViewContainer)
        }

        listView.snp.makeConstraints { make in
            make.top.bottom.equalTo(listViewContainer).inset(16)
            make.left.right.equalTo(listViewContainer).inset(40)
        }
    }
}

private extension CGFloat {
    static let buttonsContainerSpacing: CGFloat = 16
    static let topSpacing: CGFloat = 44
    static let afterWordInputSpacing: CGFloat = 16
}

private extension NSDirectionalEdgeInsets {
    static let titleDescriptionPadding = NSDirectionalEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 16,
        trailing: 0
    )

    static let contentStackViewPadding = NSDirectionalEdgeInsets(
        top: 0,
        leading: 32,
        bottom: 0,
        trailing: 32
    )
}
