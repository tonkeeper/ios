import SwiftUI

public extension SwiftUI.Image {
  enum TKUIKit {
    public enum Icons {
      public enum Size84 {
        public static var camera: Image {
          Image("Icons/84/ic-camera-84", bundle: .module)
            .renderingMode(.template)
        }
      }
    }
  }
}
