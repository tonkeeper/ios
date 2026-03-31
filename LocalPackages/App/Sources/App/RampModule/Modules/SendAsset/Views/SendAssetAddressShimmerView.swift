import SnapKit
import TKUIKit
import UIKit

final class SendAssetAddressShimmerView: UIView {
    private let titleShimmer = TKShimmerView()
    private let addressLineShimmer = TKShimmerView()
    private let copyButtonShimmer = TKShimmerView()
    private let qrButtonShimmer = TKShimmerView()

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
        addressLineShimmer.startAnimation()
        copyButtonShimmer.startAnimation()
        qrButtonShimmer.startAnimation()
    }

    func stopAnimation() {
        titleShimmer.stopAnimation()
        addressLineShimmer.stopAnimation()
        copyButtonShimmer.stopAnimation()
        qrButtonShimmer.stopAnimation()
    }

    private func setup() {
        backgroundColor = .Background.content
        layer.cornerRadius = 16

        let buttonsStack = UIStackView(arrangedSubviews: [copyButtonShimmer, qrButtonShimmer])
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 12
        buttonsStack.alignment = .center

        addSubview(titleShimmer)
        addSubview(addressLineShimmer)
        addSubview(buttonsStack)

        titleShimmer.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self).inset(16)
            make.height.equalTo(18)
        }
        addressLineShimmer.snp.makeConstraints { make in
            make.top.equalTo(titleShimmer.snp.bottom).offset(8)
            make.leading.trailing.equalTo(self).inset(16)
            make.height.equalTo(48)
        }
        buttonsStack.snp.makeConstraints { make in
            make.top.equalTo(addressLineShimmer.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalTo(self).inset(16)
        }
        copyButtonShimmer.snp.makeConstraints { make in
            make.height.equalTo(TKActionButtonSize.medium.height)
            make.width.equalTo(120)
        }
        qrButtonShimmer.snp.makeConstraints { make in
            make.size.equalTo(TKActionButtonSize.medium.height)
        }
        qrButtonShimmer.layer.cornerRadius = TKActionButtonSize.medium.height / 2
    }
}
