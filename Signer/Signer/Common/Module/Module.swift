import UIKit

struct Module<View: UIViewController, Output, Input> {
  let view: View
  let output: Output
  let input: Input
}
