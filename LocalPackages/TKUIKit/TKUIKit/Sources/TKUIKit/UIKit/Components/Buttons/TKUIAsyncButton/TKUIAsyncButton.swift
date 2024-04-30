import UIKit

public protocol TKUIAsyncButtonContentView: UIView, ConfigurableView {
  var isEnabled: Bool { get set }
  var loaderSize: TKLoaderView.Size { get }
  var contentView: UIView { get }
  
  func addTapAction(_ action: @escaping () -> Void)
}

public final class TKUIAsyncButton<Content: TKUIAsyncButtonContentView>: UIView, ConfigurableView {
  
  public var isLoading: Bool = false {
    didSet {
      isActivityViewVisible = isLoading
    }
  }
  
  public var isEnabled: Bool {
    get {
      content.isEnabled
    }
    set {
      content.isEnabled = newValue
    }
  }
  
  private let content: Content
  private let loaderView: TKLoaderView
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
  
  public init(content: Content) {
    self.content = content
    self.loaderView = TKLoaderView(
      size: content.loaderSize,
      style: .primary
    )
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  public func configure(model: Content.Model) {
    content.configure(model: model)
  }
  
  public func addTapAction(_ action: @escaping () async -> Void) {
    let tapAction = { [weak self] in
      guard let self = self else { return }
      isPerformingTask = true
      Task {
        let activityViewTask: Task<Void, Error>? = Task {
          try await Task.sleep(nanoseconds: 150_000_000)
          await MainActor.run {
            self.isActivityViewVisible = true
          }
        }
        await action()
        activityViewTask?.cancel()
        await MainActor.run {
          self.isActivityViewVisible = false
          self.isPerformingTask = false
        }
      }
    }

    content.addTapAction(tapAction)
  }
}

private extension TKUIAsyncButton {
  func setup() {
    loaderView.alpha = 0
    addSubview(content)
    addSubview(loaderView)
    
    content.translatesAutoresizingMaskIntoConstraints = false
    loaderView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: topAnchor),
      content.leftAnchor.constraint(equalTo: leftAnchor),
      content.bottomAnchor.constraint(equalTo: bottomAnchor),
      content.rightAnchor.constraint(equalTo: rightAnchor),
      
      loaderView.centerXAnchor.constraint(equalTo: centerXAnchor),
      loaderView.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
  
  func didUpdateIsActivityViewVisible() {
    UIView.animate(withDuration: 0.2) {
      self.isActivityViewVisible ? self.showActivityView() : self.hideActivityView()
    }
  }
  
  func didUpdateIsPerformingTask() {
    isUserInteractionEnabled = !isPerformingTask
  }
  
  func showActivityView() {
    content.contentView.alpha = 0
    loaderView.alpha = 1
    loaderView.isLoading = true
  }
  
  func hideActivityView() {
    content.contentView.alpha = 1
    loaderView.alpha = 0
    loaderView.isLoading = false
  }
}
