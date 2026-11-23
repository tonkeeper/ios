import AVFoundation
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import UIKit
import URKit

protocol ScannerViewModuleOutput: AnyObject {
    var didUpdateCameraState: ((ScannerCameraState) -> Void)? { get set }
    var didScanDeeplink: ((ScannedDeeplink) -> Void)? { get set }
    var didScanUR: ((UR) throws -> Bool)? { get set }
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
    func applicationDidBecomeActive()
    func didTapSettingsButton()
    func didTapFlashlightButton(isToggled: Bool)
    func processImageFromGallery(_ image: UIImage)
}

enum ScannerState {
    case video(layer: AVCaptureVideoPreviewLayer)
    case permissionDenied
}

enum ScannerCameraState: Sendable {
    case running
    case permissionDenied
    case failed
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

    var didUpdateCameraState: ((ScannerCameraState) -> Void)?

    var didScanDeeplink: ((ScannedDeeplink) -> Void)?
    var didScanUR: ((UR) throws -> Bool)?
    var didFailScan: ((String?, Bool) -> Void)?

    // MARK: - ScannerViewModel

    var didUpdateTitle: ((NSAttributedString?) -> Void)?
    var didUpdateSubtitle: ((NSAttributedString?) -> Void)?
    var didUpdateIsFlashlightVisible: ((Bool) -> Void)?
    var didUpdateState: ((ScannerState) -> Void)?

    func viewDidLoad() {
        setup()
        analyticsSession?.logOpen()
    }

    func viewDidAppear() {
        let appearance = visibility.appear()
        refreshCameraAuthorization()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            sessionViewAppearance = appearance
            captureLifecycle.appear()
            startSessionIfNeeded()
        }
    }

    func applicationDidBecomeActive() {
        guard isViewVisible else { return }
        refreshCameraAuthorization()
        sessionQueue.async { [weak self] in
            self?.startSessionIfNeeded()
        }
    }

    func viewDidDisappear() {
        visibility.disappear()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            captureLifecycle.disappear()
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
    private var captureLifecycle = ScannerCaptureLifecycle()
    private var sessionViewAppearance = 0

    /// Accessed only on the main queue.
    private var visibility = ScannerViewVisibility()
    private var isViewVisible: Bool {
        visibility.isVisible
    }

    private var cameraSetup = ScannerCameraSetupState()
    private var isShowingCameraUnavailable = false
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// Accessed only on `metadataOutputQueue`.
    private var didHandleScan = false
    private var scannedSessionRun = 0
    private var scannedViewAppearance = 0
    private var lastRejectedCameraUR: UR?

    // MARK: - Dependencies

    private let urlOpener: URLOpener
    private let scannerController: ScannerController
    private let uiConfiguration: ScannerUIConfiguration
    private let analyticsSession: ScanAnalyticsSession?

    // MARK: - Init

    init(
        urlOpener: URLOpener,
        scannerController: ScannerController,
        uiConfiguration: ScannerUIConfiguration,
        analyticsSession: ScanAnalyticsSession?
    ) {
        self.urlOpener = urlOpener
        self.scannerController = scannerController
        self.uiConfiguration = uiConfiguration
        self.analyticsSession = analyticsSession
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
                    self.analyticsSession?.logNoCode()
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
        guard cameraSetup.beginConfiguration() else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try configureSession()
            } catch {
                handlePermissionDenied(cameraState: .failed)
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                cameraSetup.didConfigure()
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

    func refreshCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupScanner()
        case .denied, .restricted:
            handlePermissionDenied()
        default:
            break
        }
    }

    func handlePermissionDenied(cameraState: ScannerCameraState = .permissionDenied) {
        Task { @MainActor in
            if cameraState == .failed { cameraSetup.didFailConfiguration() }
            isShowingCameraUnavailable = true
            didUpdateCameraState?(cameraState)
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
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            handlePermissionDenied()
            return
        }
        let previewLayer = previewLayer ?? AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = previewLayer
        isShowingCameraUnavailable = false
        previewLayer.videoGravity = .resizeAspectFill
        didUpdateState?(.video(layer: previewLayer))
    }

    func startSessionIfNeeded() {
        guard isSessionReady,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let run = captureLifecycle.beginRun(isRunning: captureSession.isRunning)
        else { return }
        metadataOutputQueue.sync {
            if scannedSessionRun != run {
                scannerController.resetURDecoding()
                didHandleScan = false
                lastRejectedCameraUR = nil
            }
            scannedSessionRun = run
            scannedViewAppearance = sessionViewAppearance
        }
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        let cameraState: ScannerCameraState = captureSession.isRunning ? .running : .failed
        Task { @MainActor [weak self] in
            guard let self, isViewVisible else { return }
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                handlePermissionDenied()
                return
            }
            if cameraState == .running, isShowingCameraUnavailable { setupPreview() }
            didUpdateCameraState?(cameraState)
        }
    }

    func finishScan(run: Int, appearance: Int, retryRejectedUR: UR? = nil, deliver: @escaping () -> Bool) {
        sessionQueue.async { [weak self] in
            guard let self, captureLifecycle.consumeScan(run: run) else { return }
            if retryRejectedUR == nil, captureSession.isRunning {
                captureSession.stopRunning()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, visibility.allowsDelivery(appearance: appearance) else { return }
                let accepted = deliver()
                sessionQueue.async { [weak self] in
                    guard let self else { return }
                    let shouldStop = captureLifecycle.completeScan(run: run, accepted: accepted)
                    if let retryRejectedUR {
                        if shouldStop, captureSession.isRunning {
                            captureSession.stopRunning()
                        } else if !accepted {
                            metadataOutputQueue.async { [weak self] in
                                guard let self, scannedSessionRun == run else { return }
                                lastRejectedCameraUR = retryRejectedUR
                                didHandleScan = false
                            }
                        }
                    }
                }
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
                finishScan(run: scannedSessionRun, appearance: scannedViewAppearance) { [weak self] in
                    guard let self, let didScanDeeplink else { return false }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    didScanDeeplink(scannedDeeplink(deeplink, code: stringValue, input: .camera))
                    return true
                }
            } else if didScanUR != nil {
                let ur = try scannerController.handleScannedQRCodeUR(stringValue)
                guard ur != lastRejectedCameraUR else { return }
                didHandleScan = true
                finishScan(run: scannedSessionRun, appearance: scannedViewAppearance, retryRejectedUR: ur) { [weak self] in
                    guard let self, let didScanUR else { return false }
                    do {
                        guard try didScanUR(ur) else {
                            reportURRejection(shouldDismiss: true)
                            return false
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        return true
                    } catch {
                        reportURRejection(shouldDismiss: true)
                        return false
                    }
                }
            }
            return
        } catch KeeperCore.URError.noResult {
            return
        } catch {
            didHandleScan = true
            finishScan(run: scannedSessionRun, appearance: scannedViewAppearance) { [weak self] in
                guard let self else { return false }
                analyticsSession?.logError(code: stringValue, input: .camera, rejection: ScanRejection(error: error))
                didFailScan?(error.localizedDescription, true)
                return false
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
                    self.didScanDeeplink?(self.scannedDeeplink(deeplink, code: stringValue, input: .gallery))
                }
            } else if didScanUR != nil {
                let ur = try ScannerURDecoder().decode(stringValue)
                DispatchQueue.main.async {
                    do {
                        guard try self.didScanUR?(ur) == true else {
                            self.reportURRejection(shouldDismiss: false)
                            return
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } catch {
                        self.reportURRejection(shouldDismiss: false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.analyticsSession?.logError(code: stringValue, input: .gallery, rejection: ScanRejection(error: error))
                self.reportURRejection(shouldDismiss: false)
            }
        }
    }

    func scannedDeeplink(_ deeplink: Deeplink, code: String, input: ScanInput) -> ScannedDeeplink {
        ScannedDeeplink(deeplink: deeplink, code: code, input: input, session: analyticsSession)
    }

    func reportURRejection(shouldDismiss: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        didFailScan?(TKLocales.Scanner.invalidLink, shouldDismiss)
    }
}
