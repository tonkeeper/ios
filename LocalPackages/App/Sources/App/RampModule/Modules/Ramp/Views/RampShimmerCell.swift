import TKUIKit
import UIKit

final class RampShimmerCell: UICollectionViewCell {
    struct Model: Hashable {}

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()

    private var rowShimmerViews: [RampShimmerRowView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        stopAnimation()
    }

    func startAnimation() {
        rowShimmerViews.forEach { $0.startAnimation() }
    }

    func stopAnimation() {
        rowShimmerViews.forEach { $0.stopAnimation() }
    }
}

private extension RampShimmerCell {
    func setup() {
        contentView.backgroundColor = .Background.content
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0 ..< 3 {
            let row = RampShimmerRowView()
            rowShimmerViews.append(row)
            stackView.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}

private final class RampShimmerRowView: UIView {
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
