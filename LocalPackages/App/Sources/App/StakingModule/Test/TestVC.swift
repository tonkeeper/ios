import UIKit
import TKUIKit
import SnapKit
import KeeperCore

final class TestVC: UIViewController, KeyboardObserving, UITextViewDelegate {
  
  let slider = UnlockSlider()
  let button = TKButton()
  let sliderAction = SliderActionView()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    
    sliderAction.layout(in: self.view) {
      $0.leading.equalToSuperview().offset(16)
      $0.trailing.equalToSuperview().inset(16)
      $0.height.equalTo(56)
      $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
    }
    
    sliderAction.configure(
      model: .init(
        title: "Slide to confirm",
        unlockAction: { [weak self] loadingClosure, isSuccessClosure in
          guard let self else { return }
          
          loadingClosure()
          
          Task {
            let isSuccess = await self.sendTxStub()
            await MainActor.run {
              isSuccessClosure(isSuccess)
            }
          }
        },
        completionAction: { isSuccess in
          guard isSuccess else { return }
          print("[PAG] Call did finish")
        }
      )
    )
  }
  
  func sendTxStub() async -> Bool {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      return false
    }
}

