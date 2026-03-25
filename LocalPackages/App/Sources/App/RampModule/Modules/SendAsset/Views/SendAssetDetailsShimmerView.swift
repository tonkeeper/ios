import SnapKit
import TKUIKit
import UIKit

final class SendAssetDetailsShimmerView: UIView {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private var rowShimmerViews: [SendAssetDetailRowShimmerView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        rowShimmerViews.forEach { $0.startAnimation() }
    }

    func stopAnimation() {
        rowShimmerViews.forEach { $0.stopAnimation() }
    }

    private func setup() {
        backgroundColor = .Background.content
        layer.cornerRadius = 16

        for _ in 0 ..< 4 {
            let row = SendAssetDetailRowShimmerView()
            rowShimmerViews.append(row)
            stackView.addArrangedSubview(row)
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(16)
        }
    }
}

private final class SendAssetDetailRowShimmerView: UIView {
    private let titleShimmer = TKShimmerView()
    private let valueShimmer = TKShimmerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimation() {
        titleShimmer.startAnimation()
        valueShimmer.startAnimation()
    }

    func stopAnimation() {
        titleShimmer.stopAnimation()
        valueShimmer.stopAnimation()
    }

    private func setup() {
        addSubview(titleShimmer)
        addSubview(valueShimmer)

        titleShimmer.snp.makeConstraints { make in
            make.leading.top.bottom.equalTo(self)
            make.width.equalTo(90)
            make.height.equalTo(18)
        }
        valueShimmer.snp.makeConstraints { make in
            make.trailing.top.bottom.equalTo(self)
            make.leading.greaterThanOrEqualTo(titleShimmer.snp.trailing).offset(8)
            make.width.equalTo(60)
            make.height.equalTo(18)
        }
    }
}
