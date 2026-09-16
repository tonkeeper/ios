import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class ScannerView: UIView {
    let videoContainerView = UIView()
    let overlayView = UIView()
    let flashlightButton = ToggleButton()
    let galleryButton = TKButton()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let cameraPermissionViewContainer = UIView()
    let holeRectView = UIView()

    private let maskLayer = CAShapeLayer()
    private let cornersLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoContainerView.frame = bounds
        videoContainerView.layer.sublayers?.forEach { $0.frame = bounds }
        overlayView.frame = bounds

        let holeRect = calculateHoleRect(bounds: bounds)
        let holePath = holePath(bounds: bounds, holeRect: holeRect)
        maskLayer.path = holePath.cgPath

        cornersLayer.frame = holeRect
        cornersLayer.path = cornersPath(holeRect: holeRect)

        let flashlightButtonFrame = CGRect(
            x: bounds.width / 2 - .flashlightButtonSide / 2,
            y: holeRect.maxY + .flashlightButtonTopOffset,
            width: .flashlightButtonSide,
            height: .flashlightButtonSide
        )
        flashlightButton.frame = flashlightButtonFrame
        flashlightButton.layer.cornerRadius = flashlightButtonFrame.height / 2

        let safeBottom = safeAreaInsets.bottom
        let galleryBottomMargin: CGFloat = 32
        let galleryHorizontalInset: CGFloat = 32
        let maxGalleryWidth = bounds.width - galleryHorizontalInset * 2
        let naturalSize = galleryButton.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let galleryWidth = min(naturalSize.width, maxGalleryWidth)
        let galleryHeight = naturalSize.height
        galleryButton.frame = CGRect(
            x: (bounds.width - galleryWidth) / 2,
            y: bounds.height - safeBottom - galleryBottomMargin - galleryHeight,
            width: galleryWidth,
            height: galleryHeight
        )

        holeRectView.frame = holeRect

        cameraPermissionViewContainer.frame = bounds
    }

    func setVideoPreviewLayer(_ layer: CALayer) {
        videoContainerView.layer.insertSublayer(layer, at: 0)
        layer.frame = videoContainerView.layer.bounds
    }

    func setCameraPermissionDeniedView(_ view: UIView) {
        cameraPermissionViewContainer.isHidden = false
        cameraPermissionViewContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: cameraPermissionViewContainer.topAnchor),
            view.leftAnchor.constraint(equalTo: cameraPermissionViewContainer.leftAnchor),
            view.bottomAnchor.constraint(equalTo: cameraPermissionViewContainer.bottomAnchor),
            view.rightAnchor.constraint(equalTo: cameraPermissionViewContainer.rightAnchor),
        ])
    }
}

private extension ScannerView {
    func setup() {
        subtitleLabel.numberOfLines = 0
        subtitleLabel.alpha = 0.64

        cameraPermissionViewContainer.isHidden = true
        addSubview(videoContainerView)
        videoContainerView.addSubview(overlayView)
        overlayView.addSubview(flashlightButton)
        overlayView.addSubview(galleryButton)
        overlayView.addSubview(holeRectView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        overlayView.addSubview(stackView)

        layer.addSublayer(cornersLayer)

        addSubview(cameraPermissionViewContainer)

        backgroundColor = .black
        overlayView.backgroundColor = .black.withAlphaComponent(0.72)

        cornersLayer.strokeColor = UIColor.white.cgColor
        cornersLayer.fillColor = UIColor.clear.cgColor
        cornersLayer.lineWidth = 3
        cornersLayer.lineCap = .round

        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer

        setupFlashlightButton()
        setupGalleryButton()

        stackView.snp.makeConstraints { make in
            make.bottom.equalTo(holeRectView.snp.top).offset(-CGFloat.titleBottomOffset)
            make.left.right.equalTo(self).inset(32)
        }
    }

    func setupFlashlightButton() {
        flashlightButton.setBackgroundColor(
            .Background.overlayLight,
            for: .deselected
        )
        flashlightButton.setBackgroundColor(
            .white,
            for: .selected
        )
        flashlightButton.setTintColor(
            .white,
            for: .deselected
        )
        flashlightButton.setTintColor(
            .Icon.primaryAlternate,
            for: .selected
        )
        flashlightButton.setImage(
            .TKUIKit.Icons.Size56.flashlightOff,
            for: .normal
        )
    }

    func setupGalleryButton() {
        var configuration = TKButton.Configuration.actionButtonConfiguration(
            category: .overlay,
            size: .medium
        )
        configuration.backgroundColors = [
            .normal: .Background.overlayLight,
            .highlighted: .Background.overlayExtraLight,
        ]
        configuration.content.title = .attributedString(TKLocales.Scanner.selectFromGallery.withTextStyle(.label1, color: .white))
        galleryButton.configuration = configuration
    }

    func calculateHoleRect(bounds: CGRect) -> CGRect {
        let side = bounds.width - (.holeSideOffset * 2)
        let x: CGFloat = .holeSideOffset
        let y: CGFloat = bounds.height / 2 - side / 2
        return CGRect(
            x: x,
            y: y,
            width: side,
            height: side
        )
    }

    func holePath(bounds: CGRect, holeRect: CGRect) -> UIBezierPath {
        let path = UIBezierPath(rect: bounds)
        path.append(.init(roundedRect: holeRect, cornerRadius: .cornerRadius))
        return path
    }

    func cornersPath(holeRect: CGRect) -> CGPath {
        let path = CGMutablePath()
        addCorner(
            path: path,
            start: .init(x: 0, y: .cornerSide),
            end: .init(x: .cornerSide, y: 0),
            corner: .init(x: 0, y: 0)
        )
        addCorner(
            path: path,
            start: .init(x: holeRect.width - .cornerSide, y: 0),
            end: .init(x: holeRect.width, y: .cornerSide),
            corner: .init(x: holeRect.width, y: 0)
        )
        addCorner(
            path: path,
            start: .init(x: holeRect.width, y: holeRect.height - .cornerSide),
            end: .init(x: holeRect.width - .cornerSide, y: holeRect.height),
            corner: .init(x: holeRect.width, y: holeRect.height)
        )
        addCorner(
            path: path,
            start: .init(x: .cornerSide, y: holeRect.height),
            end: .init(x: 0, y: holeRect.height - .cornerSide),
            corner: .init(x: 0, y: holeRect.height)
        )
        return path
    }

    func addCorner(
        path: CGMutablePath,
        start: CGPoint,
        end: CGPoint,
        corner: CGPoint
    ) {
        path.move(to: start)
        path.addArc(
            tangent1End: corner,
            tangent2End: end,
            radius: .cornerRadius
        )
        path.addLine(to: end)
    }
}

private extension CGFloat {
    static let holeSideOffset: CGFloat = 56
    static let cornerRadius: CGFloat = 8
    static let cornerSide: CGFloat = 24
    static let flashlightButtonSide: CGFloat = 56
    static let flashlightButtonTopOffset: CGFloat = 32
    static let titleBottomOffset: CGFloat = 32
}
