import TKUIKit
import UIKit

struct SupportPopupImagePopUpItem: TKPopUp.Item {
    let configuration: SupportPopupImageView.Configuration
    let bottomSpace: CGFloat

    func getView() -> UIView {
        let view = SupportPopupImageView()
        view.configuration = configuration
        return view
    }
}

final class SupportPopupImageView: UIView {
    struct Configuration {
        let image: UIImage?
    }

    var configuration = Configuration(image: nil) {
        didSet {
            didUpdateConfiguration()
        }
    }

    private let backgroundView = UIView()
    private let iconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        iconImageView.contentMode = .scaleAspectFill

        addSubview(backgroundView)
        backgroundView.addSubview(iconImageView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        iconImageView.snp.makeConstraints { make in
            make.height.equalTo(72)
            make.width.equalTo(140)
            make.centerX.verticalEdges.equalTo(backgroundView)
        }
    }

    private func didUpdateConfiguration() {
        iconImageView.image = configuration.image
    }
}
