import UIKit

public final class TKTokenTagView: UIControl, ConfigurableView {
    private var highlithedColor: UIColor = .Button.tertiaryBackgroundHighlighted
    private var normalColor: UIColor = .Button.tertiaryBackground
    
    public override var isHighlighted: Bool {
        didSet {
            backgroundView.backgroundColor = isHighlighted ? highlithedColor : normalColor
        }
    }
    
    private var image: TKListItemIconImageView.Model.Image? {
        didSet {
            imageDownloadTask?.cancel()
            switch image {
            case .image(let uIImage):
                imageView.image = uIImage
            case .asyncImage(let imageDownloadTask):
                self.imageDownloadTask = imageDownloadTask
                imageDownloadTask.start(imageView: imageView, size: CGSize(width: 24, height: 24), cornerRadius: 12)
            case nil:
                imageView.image = nil
            }
        }
    }
    
    private let imageView = UIImageView()
    private let label = UILabel()
    private let switchImageView = UIImageView()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 8,
            leading: 8,
            bottom: 8,
            trailing: 12
        )
        stackView.alignment = .center
        stackView.spacing = 6
        return stackView
    }()
    
    let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .Button.tertiaryBackground
        return view
    }()
    
    private var imageDownloadTask: ImageDownloadTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelSize = label.sizeThatFits(size)
        let imageSize: CGFloat
        if image == nil {
            imageSize = 0
        } else {
            imageSize = 30.0
        }
        let width = 20.0 + imageSize + labelSize.width
        return .init(width: width, height: 40)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = 20
    }
    
    public func configure(model: Model) {
        self.highlithedColor = model.highlithedColor
        self.normalColor = model.normalColor
        backgroundView.backgroundColor = model.normalColor
        
        stackView.subviews.forEach { $0.removeFromSuperview() }
        stackView.arrangedSubviews.forEach { [weak self] in self?.stackView.removeArrangedSubview($0) }
        if let iconModel = model.iconModel {
            image = iconModel
            stackView.addArrangedSubview(imageView)
        } else {
            image = nil
        }
        label.attributedText = model.title
        stackView.addArrangedSubview(label)
        if let _ = model.accessoryType {
            stackView.addArrangedSubview(switchImageView)
        }
    }
    
    private func setup() {
        addSubview(backgroundView)
        addSubview(stackView)
        
        setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        switchImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        layer.masksToBounds = true
        
        imageView.contentMode = .scaleAspectFit
        backgroundView.isUserInteractionEnabled = false
        label.isUserInteractionEnabled = false
        
        switchImageView.image = .TKUIKit.Icons.Size16.switch
        switchImageView.tintColor = .Icon.secondary
        switchImageView.isUserInteractionEnabled = false
        
        stackView.isUserInteractionEnabled = false
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(stackView)
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
        
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
    }
}

public extension TKTokenTagView {
    struct Model {
        public enum AccessoryType {
            case swicth
        }
        let iconModel: TKListItemIconImageView.Model.Image?
        let title: NSAttributedString?
        
        let accessoryType: AccessoryType?
        let highlithedColor: UIColor
        let normalColor: UIColor
        
        public init(
            iconModel: TKListItemIconImageView.Model.Image?,
            title: NSAttributedString?,
            accessoryType: AccessoryType?,
            highlithedColor: UIColor = .Button.tertiaryBackgroundHighlighted,
            normalColor: UIColor = .Button.tertiaryBackground
        ) {
            self.iconModel = iconModel
            self.title = title
            self.accessoryType = accessoryType
            self.highlithedColor = highlithedColor
            self.normalColor = normalColor
        }
    }
}
