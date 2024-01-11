import UIKit

public struct MVVMModule<View: UIViewController, Output, Input> {
  public let view: View
  public let output: Output
  public let input: Input
  
  public init(view: View, output: Output, input: Input) {
    self.view = view
    self.output = output
    self.input = input
  }
}
