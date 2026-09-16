import AVFoundation
import PhotosUI
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

final class ScannerViewController: GenericViewViewController<ScannerView> {
    private let viewModel: ScannerViewModel

    // MARK: - Init

    init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.viewDidDisappear()
    }
}

// MARK: - Private

private extension ScannerViewController {
    func setup() {
        customView.flashlightButton.didToggle = { [weak self] isToggled in
            self?.viewModel.didTapFlashlightButton(isToggled: isToggled)
        }

        customView.titleLabel.text = TKLocales.Scanner.title

        let swipeDownButton = QRScannerSwipeDownButton()
        swipeDownButton.addTarget(self, action: #selector(didTapSwipeDownButton), for: .touchUpInside)
        navigationItem.leftBarButtonItem = .customView(swipeDownButton, pinnedTo: .leading)
        swipeDownButton.sizeToFit()

        customView.galleryButton.addTarget(self, action: #selector(didTapGalleryButton), for: .touchUpInside)
    }

    @objc
    func didTapGalleryButton() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc
    func didTapSwipeDownButton() {
        dismiss(animated: true)
    }

    func setupBindings() {
        viewModel.didUpdateState = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .permissionDenied:
                let viewController = TKHostingController(content: NoCameraPermissionView(buttonHandler: { [weak self] in
                    self?.viewModel.didTapSettingsButton()
                }))
                addChild(viewController)
                customView.setCameraPermissionDeniedView(viewController.view)
                viewController.didMove(toParent: self)
            case let .video(layer):
                customView.setVideoPreviewLayer(layer)
            }
        }

        viewModel.didUpdateTitle = { [weak customView] title in
            customView?.titleLabel.attributedText = title
        }

        viewModel.didUpdateSubtitle = { [weak customView] subtitle in
            customView?.subtitleLabel.attributedText = subtitle
        }

        viewModel.didUpdateIsFlashlightVisible = { [weak customView] isVisible in
            customView?.flashlightButton.isHidden = !isVisible
        }
    }
}

extension ScannerViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        let itemProvider = result.itemProvider
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.viewModel.processImageFromGallery(image)
            }
        }
    }
}
