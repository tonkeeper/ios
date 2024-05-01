import UIKit

public final class TKAsyncButton<ButtonContent: TKButtonContent>: UIControl {
  
  private let button: TKButtonControl<ButtonContent>
  private let loaderView: LoaderView
  private var tapAction: (() async -> Void)?
  private var isPerformingTask = false {
    didSet {
      didUpdateIsPerformingTask()
    }
  }
  private var isActivityViewVisible = false {
    didSet {
      didUpdateIsActivityViewVisible()
    }
  }
  
  public init(content: ButtonContent,
              buttonCategory: TKButtonCategory,
              buttonSize: TKButtonSize) {
    self.button = TKButtonControl(
      buttonContent: content,
      buttonCategory: buttonCategory,
      buttonSize: buttonSize)
    self.loaderView = LoaderView(
      size: buttonSize.loaderSize,
      style: .primary
    )
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    button.frame = bounds
    loaderView.sizeToFit()
    loaderView.center = .init(x: bounds.midX, y: bounds.midY)
  }
  
  public override var intrinsicContentSize: CGSize {
    button.intrinsicContentSize
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    button.sizeThatFits(size)
  }
  
  public func addTapAction(_ tapAction: @escaping () async -> Void) {
    button.addTapAction { [weak self] in
      guard let self = self else { return }
      isPerformingTask = true
      Task {
        let activityViewTask: Task<Void, Error>? = Task {
          try await Task.sleep(nanoseconds: 150_000_000)
          await MainActor.run {
            self.isActivityViewVisible = true
          }
        }
        await tapAction()
        activityViewTask?.cancel()
        await MainActor.run {
          self.isActivityViewVisible = false
          self.isPerformingTask = false
        }
      }
    }
  }
}

private extension TKAsyncButton {
  func setup() {
    loaderView.alpha = 0
    addSubview(button)
    addSubview(loaderView)
  }
  
  func didUpdateIsActivityViewVisible() {
    UIView.animate(withDuration: 0.1) {
      self.isActivityViewVisible ? self.showActivityView() : self.hideActivityView()
    }
  }
  
  func didUpdateIsPerformingTask() {
    isUserInteractionEnabled = !isPerformingTask
  }
  
  func showActivityView() {
    button.buttonContent.alpha = 0
    loaderView.alpha = 1
    loaderView.startAnimation()
  }
  
  func hideActivityView() {
    button.buttonContent.alpha = 1
    loaderView.alpha = 0
    loaderView.stopAnimation()
  }
}

private extension TKButtonSize {
  var loaderSize: LoaderView.Size {
    switch self {
    case .small:
      return .small
    case .medium:
      return .medium
    case .large:
      return .medium
    }
  }
}
