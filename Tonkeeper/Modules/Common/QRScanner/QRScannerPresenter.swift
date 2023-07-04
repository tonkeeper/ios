//
//  QRScannerPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation
import AVFoundation
import WalletCore

final class QRScannerPresenter: NSObject {
  
  // MARK: - Module
  
  weak var viewInput: QRScannerViewInput?
  weak var output: QRScannerModuleOutput?

  // MARK: - State
  
  private let captureSession = AVCaptureSession()
  private var captureDevice: AVCaptureDevice? {
    AVCaptureDevice.default(.builtInDualCamera,
                            for: .video,
                            position: .back)
  }
}

// MARK: - QRScannerPresenterInput

extension QRScannerPresenter: QRScannerPresenterInput {
  func viewDidLoad() {
    checkCameraPermission()
  }
  
  func didToggleFlashligt(isSelected: Bool) {
    guard let captureDevice = captureDevice,
              captureDevice.hasTorch
    else { return }
    
    try? captureDevice.lockForConfiguration()
    try? captureDevice.setTorchModeOn(level: 1)
    captureDevice.torchMode = isSelected ? .on : .off
    captureDevice.unlockForConfiguration()
  }
  
  func didTapSwipeButton() {
    output?.qrScannerModuleDidFinish()
  }
}

// MARK: - Camera

private extension QRScannerPresenter {
  func checkCameraPermission() {
    let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    switch authorizationStatus {
    case .notDetermined:
      requestCameraPermission()
    case .authorized:
      setupCamera()
    case .restricted, .denied:
      handleCameraPermissionDenied()
    @unknown default:
      return
    }
  }
  
  func requestCameraPermission() {
    Task {
      let accessGranted = await AVCaptureDevice.requestAccess(for: .video)
      await MainActor.run {
        handlePermissionRequestResult(accessGranted: accessGranted)
      }
    }
  }
  
  func handlePermissionRequestResult(accessGranted: Bool) {
    if accessGranted {
      setupCamera()
    } else {
      handleCameraPermissionDenied()
    }
  }
  
  func setupCamera() {
    Task {
      guard let captureDevice = captureDevice else {
        return
      }
      
      do {
        let input = try AVCaptureDeviceInput(device: captureDevice)
        captureSession.addInput(input)
      } catch {
        print(error)
      }
      
      let captureMetadataOutput = AVCaptureMetadataOutput()
      captureSession.addOutput(captureMetadataOutput)
      
      captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
      captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
      
      let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      videoLayer.videoGravity = .resizeAspectFill
      
      captureSession.startRunning()
      
      Task { @MainActor in
        viewInput?.showVideoLayer(videoLayer)
      }
    }
  }
  
  func handleCameraPermissionDenied() {
    
  }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerPresenter: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput,
                      didOutput metadataObjects: [AVMetadataObject],
                      from connection: AVCaptureConnection) {
    guard !metadataObjects.isEmpty,
          let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          metadataObject.type == .qr,
          let stringValue = metadataObject.stringValue
    else { return }
    captureSession.stopRunning()
    self.output?.didScanQrCode(with: stringValue)
  }
}
