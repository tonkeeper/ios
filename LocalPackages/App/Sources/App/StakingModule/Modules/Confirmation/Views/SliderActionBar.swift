import UIKit
import TKUIKit
import TKCore

final class SliderActionView: UIView, ConfigurableView {
  var model: Model = .init(title: "", unlockAction: nil, completionAction: nil) {
    didSet {
      update()
    }
  }
  
  private let unlockSlider = UnlockSlider()
  private let loaderView = TKLoaderView(size: .medium, style: .secondary)
  private let resultView = TKResultView(state: .success)
  private var unlockAction: ((@escaping () -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?
  private var completionAction: ((Bool) -> Void)?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  func configure(model: Model) {
    self.model = model
  }
}

// MARK: - Private methods

private extension SliderActionView {
  private func update() {
    unlockSlider.title = model.title.withTextStyle(
      .label1,
      color: .Text.secondary
    )
    unlockAction = model.unlockAction
    completionAction = model.completionAction
    
    switch model.state {
    case .idle:
      showSlider()
    case .loading:
      showLoader()
    }
  }
  
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

extension SliderActionView {
  struct Model: Hashable {
    enum State: Hashable {
      case loading
      case idle
    }
    
    var title: String
    var unlockAction: ((@escaping () -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?
    var completionAction: ((Bool) -> Void)?
    var state: State = .idle
    
    func hash(into hasher: inout Hasher) {
      hasher.combine(title.string)
      hasher.combine(state)
    }
    
    static func == (lhs: SliderActionView.Model, rhs: SliderActionView.Model) -> Bool {
      lhs.title == rhs.title && lhs.state == rhs.state
    }
  }
}
