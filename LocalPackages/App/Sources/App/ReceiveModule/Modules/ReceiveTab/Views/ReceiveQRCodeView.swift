import TKUIKit
import UIKit

final class ReceiveQRCodeView: UIView {
    let contentContainer = UIView()
    let qrCodeImageView = UIImageView()
    let addressButton = ReceiveAddressButton()
    let iconViewBackgroudView = UIView()
    let iconView = TKListItemIconView()
    let tagView = TKTagView()

    private lazy var addressButtonBottomConstraint: NSLayoutConstraint = addressButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)

    private lazy var addressButtonBottomTagConstraint: NSLayoutConstraint = addressButton.bottomAnchor.constraint(equalTo: tagView.topAnchor, constant: -12)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTagModel(_ tagModel: TKTagView.Configuration?) {
        guard let tagModel else {
            addressButtonBottomTagConstraint.isActive = false
            addressButtonBottomConstraint.isActive = true
            tagView.isHidden = true
            return
        }
        tagView.isHidden = false
        tagView.configuration = tagModel
        addressButtonBottomConstraint.isActive = false
        addressButtonBottomTagConstraint.isActive = true
    }
}

private extension ReceiveQRCodeView {
    func setup() {
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.masksToBounds = true

        iconViewBackgroudView.backgroundColor = .white

        addSubview(contentContainer)
        contentContainer.addSubview(qrCodeImageView)
        contentContainer.addSubview(addressButton)
        contentContainer.addSubview(tagView)
        qrCodeImageView.addSubview(iconViewBackgroudView)
        qrCodeImageView.addSubview(iconView)

        setupConstraints()
    }

    func setupConstraints() {
        iconViewBackgroudView.snp.makeConstraints { make in
            make.center.equalTo(qrCodeImageView)
            make.width.height.equalTo(64)
        }

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false
        addressButton.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        tagView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: topAnchor, constant: .containerPadding),
            contentContainer.leftAnchor.constraint(equalTo: leftAnchor, constant: .containerPadding),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.containerPadding),
            contentContainer.rightAnchor.constraint(equalTo: rightAnchor, constant: -.containerPadding),

            tagView.centerXAnchor.constraint(equalTo: centerXAnchor),
            tagView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

            addressButton.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
            addressButton.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
            addressButton.topAnchor.constraint(equalTo: qrCodeImageView.bottomAnchor, constant: .addressTopInset),

            qrCodeImageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            qrCodeImageView.leftAnchor.constraint(equalTo: contentContainer.leftAnchor),
            qrCodeImageView.rightAnchor.constraint(equalTo: contentContainer.rightAnchor),
            qrCodeImageView.widthAnchor.constraint(equalTo: qrCodeImageView.heightAnchor),

            iconView.widthAnchor.constraint(equalToConstant: .tokenImageSide),
            iconView.heightAnchor.constraint(equalToConstant: .tokenImageSide),
            iconView.centerXAnchor.constraint(equalTo: qrCodeImageView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: qrCodeImageView.centerYAnchor),
        ])
    }
}

private extension CGFloat {
    static let containerPadding: CGFloat = 24
    static let addressTopInset: CGFloat = 12
    static let tokenImageSide: CGFloat = 44
}
