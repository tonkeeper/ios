//
//  AppStoreReviewer.swift
//
//
//  Created by Grigory on 13.10.23..
//

import UIKit
import StoreKit

public protocol AppStoreReviewer {
  func requestReview()
}

extension UIApplication: AppStoreReviewer {
  public func requestReview() {
    if let scene = connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
      SKStoreReviewController.requestReview(in: scene)
    }
  }
}
