import SnapKit
import UIKit

final class KeystoneImportScanView: UIView {
    var didTapOpenKeystoneButton: (() -> Void)?

    let scannerContainer = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embedScannerView(_ scannerView: UIView) {
        scannerContainer.addSubview(scannerView)
        scannerView.snp.makeConstraints { make in
            make.edges.equalTo(scannerContainer)
        }
    }
}

private extension KeystoneImportScanView {
    func setup() {
        addSubview(scannerContainer)

        setupConstraints()
    }

    func setupConstraints() {
        scannerContainer.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
