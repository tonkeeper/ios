import UIKit
import TKUIKit

final class StoriesPageViewController: UIViewController {
  
  private let stackView = UIStackView()
  private let backgroundImageView = UIImageView()
  private let titleLabel = UILabel()
  private let descriptionLabel = UILabel()
  
  private let model: StoriesPageModel
  
  init(model: StoriesPageModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  private func setup() {
    backgroundImageView.contentMode = .scaleAspectFill
    backgroundImageView.image = model.backgroundImage
    
    stackView.axis = .vertical
    stackView.spacing = 8
    
    view.addSubview(backgroundImageView)
//    view.addSubview(stackView)
//    stackView.addArrangedSubview(titleLabel)
//    stackView.addArrangedSubview(descriptionLabel)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    backgroundImageView.snp.makeConstraints { make in
      make.edges.equalTo(view)
    }
//    stackView.snp.makeConstraints { make in
//      mak
//    }
  }
}
