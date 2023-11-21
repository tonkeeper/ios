//
//  QRScannerPresenter.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation
import AVFoundation
import WalletCoreKeeper
import TKCore
import UIKit

final class QRScannerPresenter: NSObject {
  
  enum Error: Swift.Error {
    case unauthorized(AVAuthorizationStatus)
    case device(DeviceError)
    
    enum DeviceError: Swift.Error {
      case videoUnavailable
      case inputInvalid
      case metadataOutputFailure
    }
  }
  
  // MARK: - Module
  
  weak var viewInput: QRScannerViewInput?
  weak var output: QRScannerModuleOutput?
  
  // MARK: - Dependencies
  
  private let urlOpener: URLOpener
  
  // MARK: - State
  
  private let metadataOutputQueue = DispatchQueue(label: "metadata.capturesession.queue")
  private let captureSession = AVCaptureSession()
  
  // MARK: - Init
  
  init(urlOpener: URLOpener) {
    self.urlOpener = urlOpener
  }
}

// MARK: - QRScannerPresenterInput

extension QRScannerPresenter: QRScannerPresenterInput {
  func viewDidLoad() {
    setup()
  }
  
  func viewDidAppear() {
    startRunning()
  }

  func viewDidDisappear() {
    stopRunning()
  }
  
  func didToggleFlashligt(isSelected: Bool) {
    guard let captureDevice = AVCaptureDevice.default(for: .video),
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
  
  func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    urlOpener.open(url: url)
  }
}

private extension QRScannerPresenter {
  func setup() {
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
      viewInput?.showCameraPermissionDenied()
    }
  }
  
  func setupSession() throws {
    guard let device = AVCaptureDevice.default(for: .video) else {
      throw Error.device(.videoUnavailable)
    }
    
    guard let videoInput = try? AVCaptureDeviceInput(device: device),
          self.captureSession.canAddInput(videoInput) else {
      throw Error.device(.inputInvalid)
    }
    
    let metadataOutput = AVCaptureMetadataOutput()
    guard self.captureSession.canAddOutput(metadataOutput) else {
      throw Error.device(.metadataOutputFailure)
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
    viewInput?.showVideoLayer(previewLayer)
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

extension QRScannerPresenter: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(_ output: AVCaptureMetadataOutput,
                      didOutput metadataObjects: [AVMetadataObject],
                      from connection: AVCaptureConnection) {
    guard !metadataObjects.isEmpty,
          let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
          metadataObject.type == .qr,
          let stringValue = metadataObject.stringValue
    else { return }
    guard self.output?.isQrCodeValid(string: stringValue) == true else {
      return
    }
    self.captureSession.stopRunning()
    TapticGenerator.generateSuccessFeedback()
    DispatchQueue.main.async {
      self.output?.didScanQrCode(with: stringValue)
    }
  }
}
