//
//  Image+Icons.swift
//  
//
//  Created by Grigory Serebryanyy on 21.10.2023.
//

import SwiftUI

public extension SwiftUI.Image {
  enum Icons {
    public enum Permission {
      public static var camera: Image {
        Image("Icons/84/ic-camera-84", bundle: .module).renderingMode(.template)
      }
    }
  }
}
