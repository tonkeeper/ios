//
//  TapticGenerator.swift
//  Tonkeeper
//
//  Created by Grigory on 4.7.23..
//

import Foundation
import UIKit

struct TapticGenerator {
  static func generateTapLightFeedback() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }
  
  static func generateButtonTapMediumFeedback() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }
  
  static func generateTapHeavyFeedback() {
    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
  }
  
  static func generateCopyFeedback() {
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
  }
  
  static func generateSuccessFeedback() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
  
  static func generateFailureFeedback() {
    UINotificationFeedbackGenerator().notificationOccurred(.error)
  }
}
