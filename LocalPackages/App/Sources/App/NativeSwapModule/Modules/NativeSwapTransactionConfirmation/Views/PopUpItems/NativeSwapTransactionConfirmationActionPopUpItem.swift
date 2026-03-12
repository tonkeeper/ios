import SnapKit
import TKLocalize
import TKUIKit
import UIKit

struct NativeSwapTransactionConfirmationActionPopUpItem: TKPopUp.Item {
    let configuration: NativeSwapTransactionConfirmationActionView.Configuration
    let bottomSpace: CGFloat

    func getView() -> UIView {
        let view = NativeSwapTransactionConfirmationActionView()
        view.configuration = configuration
        return view
    }
}

final class NativeSwapTransactionConfirmationActionView: UIView {
    struct Configuration {
        let slider: Slider

        struct Slider {
            let title: NSAttributedString
            let isEnable: Bool
            let appearance: TKSlider.Appearance
            let didConfirm: (() -> Void)?
        }
    }

    var configuration: NativeSwapTransactionConfirmationActionView.Configuration? {
        didSet {
            didUpdateConfiguration()
        }
    }

    private let sliderView = TKSlider()

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        setupConstraints()
    }

    private func setupConstraints() {
        addSubview(sliderView)

        sliderView.snp.makeConstraints { make in
            make.top.left.right.bottom.equalTo(self)
        }
    }

    private func didUpdateConfiguration() {
        guard let configuration else { return }

        sliderView.appearance = configuration.slider.appearance
        sliderView.title = configuration.slider.title
        sliderView.isEnable = configuration.slider.isEnable
        sliderView.didConfirm = configuration.slider.didConfirm
    }
}
