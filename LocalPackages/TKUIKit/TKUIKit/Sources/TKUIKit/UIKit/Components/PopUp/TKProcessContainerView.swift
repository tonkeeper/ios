import UIKit

public final class TKProcessContainerView: UIView {
  
  public enum State {
    case idle
    case process
    case success
    case failed
  }
  
  public var state: State = .idle {
    didSet {
      switch state {
      case .idle:
        contentContainer.isHidden = false
        resultView.isHidden = true
        loaderView.isHidden = true
      case .process:
        contentContainer.isHidden = true
        resultView.isHidden = true
        loaderView.isHidden = false
      case .success:
        contentContainer.isHidden = true
        loaderView.isHidden = true
        resultView.isHidden = false
        resultView.state = .success
      case .failed:
        contentContainer.isHidden = true
        loaderView.isHidden = true
        resultView.isHidden = false
        resultView.state = .failure
      }
    }
  }
  
  private let contentContainer = UIView()
  private let resultView = TKResultView(state: .success)
  private let loaderView = TKLoaderView(size: .medium, style: .secondary)
 
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func setContent(_ content: UIView) {
    contentContainer.subviews.forEach { $0.removeFromSuperview() }
    contentContainer.addSubview(content)
    content.snp.makeConstraints { make in
      make.edges.equalTo(contentContainer)
    }
  }
  
  private func setup() {
    resultView.isHidden = true
    
    addSubview(contentContainer)
    addSubview(resultView)
    addSubview(loaderView)
    
    contentContainer.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    resultView.snp.makeConstraints { make in
      make.edges.equalTo(self).priority(.high)
    }
    
    loaderView.snp.makeConstraints { make in
      make.edges.equalTo(self).priority(.high)
    }
  }
}
