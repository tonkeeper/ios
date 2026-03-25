import SnapKit
import TKUIKit
import UIKit

final class InsertAmountProviderView: UIControl {
    let contentView = TKListItemContentView()

    override var isHighlighted: Bool {
        didSet {
            wrapperView.backgroundColor = isHighlighted ? .Background.highlighted : .Background.content
        }
    }

    private let wrapperView = UIView()
    private let switchImageView = TKImageView()
    private let shimmerView = InsertAmountProviderShimmerView()

    var providerViewState: InsertAmountProviderViewState? {
        didSet { applyState() }
    }

    private var isLoading = false {
        didSet {
            isUserInteractionEnabled = !isLoading
            contentView.isHidden = isLoading
            switchImageView.isHidden = isLoading
            shimmerView.isHidden = !isLoading
            if isLoading {
                shimmerView.startAnimation()
            } else {
                shimmerView.stopAnimation()
            }
        }
    }

    var didTap: (() -> Void)?

    private func applyState() {
        guard let providerViewState else { return }
        switch providerViewState {
        case .loading:
            isLoading = true
        case let .data(configuration):
            isLoading = false
            contentView.configuration = configuration
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wrapperView.backgroundColor = .Background.content
        wrapperView.layer.cornerRadius = 16
        wrapperView.layer.masksToBounds = true

        switchImageView.configure(
            model: TKImageView.Model(
                image: .image(.TKUIKit.Icons.Size16.switch),
                tintColor: .Icon.tertiary,
                size: .size(CGSize(width: 16, height: 16))
            )
        )

        addSubview(wrapperView)
        wrapperView.addSubview(contentView)
        wrapperView.addSubview(switchImageView)
        wrapperView.addSubview(shimmerView)

        wrapperView.isUserInteractionEnabled = false
        shimmerView.isHidden = true
        contentView.isUserInteractionEnabled = false
        addTarget(self, action: #selector(didTapView), for: .touchUpInside)

        setupConstraints()
    }

    private func setupConstraints() {
        contentView.snp.makeConstraints { make in
            make.top.bottom.leading
                .equalToSuperview()
                .inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 0))
            make.trailing.equalTo(switchImageView.snp.leading).offset(-8)
        }

        switchImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(22)
        }

        shimmerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        wrapperView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @objc
    private func didTapView() {
        didTap?()
    }
}

private final class InsertAmountProviderShimmerView: UIView {
    private let iconShimmer = TKShimmerView()
    private let titleShimmer = TKShimmerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        iconShimmer.startAnimation()
        titleShimmer.startAnimation()
    }

    func stopAnimation() {
        iconShimmer.stopAnimation()
        titleShimmer.stopAnimation()
    }

    private func setup() {
        addSubview(iconShimmer)
        addSubview(titleShimmer)
        iconShimmer.translatesAutoresizingMaskIntoConstraints = false
        titleShimmer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 72),
            iconShimmer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconShimmer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconShimmer.widthAnchor.constraint(equalToConstant: 44),
            iconShimmer.heightAnchor.constraint(equalToConstant: 44),
            titleShimmer.leadingAnchor.constraint(equalTo: iconShimmer.trailingAnchor, constant: 16),
            titleShimmer.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleShimmer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            titleShimmer.heightAnchor.constraint(equalToConstant: 20),
            titleShimmer.widthAnchor.constraint(equalToConstant: 120),
        ])
    }
}
