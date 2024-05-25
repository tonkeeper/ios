import UIKit
import TKUIKit
import TKCore

final class SliderActionView: UIView, ConfigurableView {
  let unlockSlider = UnlockSlider()
  private let loaderView = TKLoaderView(size: .medium, style: .secondary)
  private let resultView = TKResultView(state: .success)
  
  var unlockAction: ((@escaping () -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?
  var completionAction: ((Bool) -> Void)?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let title: NSAttributedString
    let unlockAction: ((@escaping () -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?
    let completionAction: ((Bool) -> Void)?
  }
  
  // MARK: - ConfigurableView
  func configure(model: Model) {
    unlockSlider.title = model.title
    unlockAction = model.unlockAction
    completionAction = model.completionAction
  }
}

// MARK: - Private methods

private extension SliderActionView {
  func setup() {
    showSlider()
    
    unlockSlider.fill(in: self)
    loaderView.fill(in: self)
    resultView.fill(in: self)

    unlockSlider.didUnlock = { [weak self] in
      self?.unlockAction?({
        self?.showLoader()
      }, { isSuccess in
        self?.showResult(isSuccess: isSuccess)
        Task {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          await MainActor.run {
            self?.showSlider()
            self?.completionAction?(isSuccess)
          }
        }
      })
    }
  }
  
  func showSlider() {
    unlockSlider.resetToStartPosition()
    unlockSlider.isHidden = false
    
    resultView.isHidden = true
    
    loaderView.isHidden = true
    loaderView.isLoading = false
  }
  
  func showLoader() {
    unlockSlider.resetToStartPosition()
    unlockSlider.isHidden = true
    
    resultView.isHidden = true
    
    loaderView.isLoading = true
    loaderView.isHidden = false
  }
  
  func showResult(isSuccess: Bool) {
    unlockSlider.resetToStartPosition()
    unlockSlider.isHidden = true
    
    loaderView.isLoading = false
    loaderView.isHidden = true
    
    resultView.isHidden = false
    resultView.state = isSuccess ? .success : .failure
  }
}
