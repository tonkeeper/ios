import Foundation
import AVFoundation
import UIKit
import SignerCore

protocol ScannerViewModuleOutput: AnyObject {
  var didScanDeeplink: ((Deeplink) -> Void)? { get set }
}

protocol ScannerViewModel: AnyObject {
  
  var didUpdateTitle: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateSubtitle: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateState: ((ScannerState) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewDidDisappear()
  func didTapSettingsButton()
  func didTapFlashlightButton(isToggled: Bool)
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

final class ScannerViewModelImplementation: NSObject, ScannerViewModel, ScannerViewModuleOutput {
  
  // MARK: - ScannerViewModuleOutput
  
  var didScanDeeplink: ((Deeplink) -> Void)?
  
  // MARK: - ScannerViewModel
  
  var didUpdateTitle: ((NSAttributedString?) -> Void)?
  var didUpdateSubtitle: ((NSAttributedString?) -> Void)?
  var didUpdateState: ((ScannerState) -> Void)?
 
  func viewDidLoad() {
    setup()
  }
  
  func viewDidAppear() {
    startRunning()
  }
  
  func viewDidDisappear() {
    stopRunning()
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
  
  private let metadataOutputQueue = DispatchQueue(label: "metadata.capturesession.queue")
  private let captureSession = AVCaptureSession()
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  private let scannerController: ScannerController
  private let title: String?
  private let subtitle: String?
  
  // MARK: - Init
  
  init(urlOpener: URLOpener,
       scannerController: ScannerController,
       title: String?,
       subtitle: String?) {
    self.urlOpener = urlOpener
    self.scannerController = scannerController
    self.title = title
    self.subtitle = subtitle
  }
}

private extension ScannerViewModelImplementation {
  func setup() {
    didUpdateTitle?(
      title?.withTextStyle(
        .h2,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    )
    
    didUpdateSubtitle?(
      subtitle?.withTextStyle(
        .body1,
        color: .white,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    )
    
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
    Task {
      do {
        try setupSession()
        await MainActor.run {
          setupPreview()
        }
      } catch {
        handlePermissionDenied()
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
  
  func setupSession() throws {
    guard let device = AVCaptureDevice.default(for: .video) else {
      throw ScannerError.device(.videoUnavailable)
    }
    
    guard let videoInput = try? AVCaptureDeviceInput(device: device),
          self.captureSession.canAddInput(videoInput) else {
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
   
    startRunning()
  }
  
  func setupPreview() {
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    didUpdateState?(.video(layer: previewLayer))
  }
  
  func startRunning() {
    guard !captureSession.isRunning,
          AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
    metadataOutputQueue.async { [weak self] in
      self?.captureSession.startRunning()
    }
  }
  
  func stopRunning() {
    guard captureSession.isRunning else { return }
    metadataOutputQueue.async { [weak self] in
      self?.captureSession.stopRunning()
    }
  }

}

extension ScannerViewModelImplementation: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput,
                      didOutput metadataObjects: [AVMetadataObject],
                      from connection: AVCaptureConnection) {
    guard !metadataObjects.isEmpty,
          let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          metadataObject.type == .qr,
          let stringValue = metadataObject.stringValue
    else { return }
    do {
      let deeplink = try scannerController.handleScannedQRCode(stringValue)
      self.captureSession.stopRunning()
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      DispatchQueue.main.async {
        self.didScanDeeplink?(deeplink)
      }
    } catch {
      return
    }
  }
}
