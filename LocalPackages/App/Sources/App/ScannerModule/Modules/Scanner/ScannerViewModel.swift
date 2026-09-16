import AVFoundation
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import UIKit
import URKit

protocol ScannerViewModuleOutput: AnyObject {
    var didScanDeeplink: ((Deeplink) -> Void)? { get set }
    var didScanUR: ((UR) throws -> Void)? { get set }
    var didFailScan: ((String?, Bool) -> Void)? { get set }
}

protocol ScannerViewModel: AnyObject {
    var didUpdateTitle: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateSubtitle: ((NSAttributedString?) -> Void)? { get set }
    var didUpdateIsFlashlightVisible: ((Bool) -> Void)? { get set }
    var didUpdateState: ((ScannerState) -> Void)? { get set }

    func viewDidLoad()
    func viewDidAppear()
    func viewDidDisappear()
    func didTapSettingsButton()
    func didTapFlashlightButton(isToggled: Bool)
    func processImageFromGallery(_ image: UIImage)
}

enum ScannerState {
    case video(layer: AVCaptureVideoPreviewLayer)
    case permissionDenied
}

enum ScannerError: Swift.Error {
    case unauthorized(AVAuthorizationStatus)
    case device(DeviceError)

    enum DeviceError: Swift.Error {
        case videoUnavailable
        case inputInvalid
        case metadataOutputFailure
    }
}

struct ScannerUIConfiguration {
    let title: String?
    let subtitle: String?
    let isFlashlightVisible: Bool
}

final class ScannerViewModelImplementation: NSObject, ScannerViewModel, ScannerViewModuleOutput {
    // MARK: - ScannerViewModuleOutput

    var didScanDeeplink: ((Deeplink) -> Void)?
    var didScanUR: ((UR) throws -> Void)?
    var didFailScan: ((String?, Bool) -> Void)?

    // MARK: - ScannerViewModel

    var didUpdateTitle: ((NSAttributedString?) -> Void)?
    var didUpdateSubtitle: ((NSAttributedString?) -> Void)?
    var didUpdateIsFlashlightVisible: ((Bool) -> Void)?
    var didUpdateState: ((ScannerState) -> Void)?

    func viewDidLoad() {
        setup()
    }

    func viewDidAppear() {
        isViewVisible = true
        sessionQueue.async { [weak self] in
            guard let self else { return }
            isVisible = true
            startSessionIfNeeded()
        }
    }

    func viewDidDisappear() {
        isViewVisible = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            isVisible = false
            guard captureSession.isRunning else { return }
            captureSession.stopRunning()
        }
    }

    func didTapSettingsButton() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        urlOpener.open(url: url)
    }

    func didTapFlashlightButton(isToggled: Bool) {
        guard let captureDevice = AVCaptureDevice.default(for: .video),
              captureDevice.hasTorch
        else { return }

        try? captureDevice.lockForConfiguration()
        try? captureDevice.setTorchModeOn(level: 1)
        captureDevice.torchMode = isToggled ? .on : .off
        captureDevice.unlockForConfiguration()
    }

    // MARK: - State

    private let sessionQueue = DispatchQueue(label: "com.tonkeeper.scanner.session")
    private let metadataOutputQueue = DispatchQueue(label: "metadata.capturesession.queue")
    private let captureSession = AVCaptureSession()

    /// Accessed only on `sessionQueue`.
    private var isSessionReady = false
    private var isVisible = false
    private var sessionRun = 0

    /// Accessed only on the main queue.
    private var isViewVisible = false

    /// Accessed only on `metadataOutputQueue`.
    private var didHandleScan = false
    private var scannedSessionRun = 0

    // MARK: - Dependencies

    private let urlOpener: URLOpener
    private let scannerController: ScannerController
    private let uiConfiguration: ScannerUIConfiguration

    // MARK: - Init

    init(
        urlOpener: URLOpener,
        scannerController: ScannerController,
        uiConfiguration: ScannerUIConfiguration
    ) {
        self.urlOpener = urlOpener
        self.scannerController = scannerController
        self.uiConfiguration = uiConfiguration
    }
}

extension ScannerViewModelImplementation {
    func processImageFromGallery(_ image: UIImage) {
        Task {
            let stringValue = await Task.detached {
                QRCodeImageScanner.detectString(in: image)
            }.value
            await MainActor.run {
                guard let stringValue else {
                    self.didFailScan?(TKLocales.Scanner.invalidLink, false)
                    return
                }
                self.processGalleryScannedString(stringValue)
            }
        }
    }
}

private extension ScannerViewModelImplementation {
    func setup() {
        didUpdateTitle?(
            uiConfiguration.title?.withTextStyle(
                .h2,
                color: .white,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
        )

        didUpdateSubtitle?(
            uiConfiguration.subtitle?.withTextStyle(
                .body1,
                color: .white,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
        )
        didUpdateIsFlashlightVisible?(uiConfiguration.isFlashlightVisible)

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupScanner()
        case .notDetermined:
            requestPermission()
        default:
            handlePermissionDenied()
        }
    }

    func setupScanner() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try configureSession()
            } catch {
                handlePermissionDenied()
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                setupPreview()
                sessionQueue.async { [weak self] in
                    guard let self else { return }
                    isSessionReady = true
                    startSessionIfNeeded()
                }
            }
        }
    }

    func requestPermission() {
        Task {
            let accessGranted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                if accessGranted {
                    setupScanner()
                } else {
                    handlePermissionDenied()
                }
            }
        }
    }

    func handlePermissionDenied() {
        Task { @MainActor in
            didUpdateState?(.permissionDenied)
        }
    }

    func configureSession() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw ScannerError.device(.videoUnavailable)
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: device),
              self.captureSession.canAddInput(videoInput)
        else {
            throw ScannerError.device(.inputInvalid)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        guard self.captureSession.canAddOutput(metadataOutput) else {
            throw ScannerError.device(.metadataOutputFailure)
        }

        self.captureSession.beginConfiguration()
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataOutputQueue)
        metadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        self.captureSession.commitConfiguration()
    }

    func setupPreview() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        didUpdateState?(.video(layer: previewLayer))
    }

    func startSessionIfNeeded() {
        guard isSessionReady,
              isVisible,
              !captureSession.isRunning,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        else { return }
        sessionRun += 1
        let run = sessionRun
        metadataOutputQueue.sync {
            didHandleScan = false
            scannedSessionRun = run
        }
        captureSession.startRunning()
    }

    func finishScan(run: Int, deliver: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, run == sessionRun, isVisible else { return }
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, isViewVisible else { return }
                deliver()
            }
        }
    }
}

extension ScannerViewModelImplementation: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didHandleScan,
              !metadataObjects.isEmpty,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue
        else { return }
        do {
            if didScanDeeplink != nil {
                let deeplink = try scannerController.handleScannedQRCode(stringValue)
                didHandleScan = true
                finishScan(run: scannedSessionRun) { [weak self] in
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    self?.didScanDeeplink?(deeplink)
                }
            } else if didScanUR != nil {
                let ur = try scannerController.handleScannedQRCodeUR(stringValue)
                didHandleScan = true
                finishScan(run: scannedSessionRun) { [weak self] in
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    do {
                        try self?.didScanUR?(ur)
                    } catch {}
                }
            }
            return
        } catch KeeperCore.URError.noResult {
            return
        } catch {
            didHandleScan = true
            finishScan(run: scannedSessionRun) { [weak self] in
                self?.didFailScan?(error.localizedDescription, true)
            }
            return
        }
    }
}

private extension ScannerViewModelImplementation {
    func processGalleryScannedString(_ stringValue: String) {
        do {
            if didScanDeeplink != nil {
                let deeplink = try scannerController.handleScannedQRCode(stringValue)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                DispatchQueue.main.async {
                    self.didScanDeeplink?(deeplink)
                }
            } else if didScanUR != nil {
                let ur = try scannerController.handleScannedQRCodeUR(stringValue)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                DispatchQueue.main.async {
                    do {
                        try self.didScanUR?(ur)
                    } catch {
                        self.didFailScan?(TKLocales.Scanner.invalidLink, false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.didFailScan?(TKLocales.Scanner.invalidLink, false)
            }
        }
    }
}
