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
                processContainer.isHidden = true
            case .process:
                contentContainer.isHidden = true
                resultView.isHidden = true
                processContainer.isHidden = false
            case .success:
                contentContainer.isHidden = true
                processContainer.isHidden = true
                resultView.isHidden = false
                resultView.state = .success
            case .failed:
                contentContainer.isHidden = true
                processContainer.isHidden = true
                resultView.isHidden = false
                resultView.state = .failure
            }
        }
    }

    public var successTitle: String {
        didSet {
            resultView.successTitle = successTitle
        }
    }

    public var errorTitle: String {
        didSet {
            resultView.errorTitle = errorTitle
        }
    }

    public var processTitle: String {
        didSet {
            processTitleLabel.text = processTitle
            processTitleLabel.isHidden = processTitle.isEmpty
        }
    }

    private let contentContainer = UIView()
    private let resultView = TKResultView(state: .success)
    private let processContainer = UIView()
    private let processStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        return stackView
    }()

    private let loaderView = TKLoaderView(size: .medium, style: .secondary)
    private let processTitleLabel: UILabel = {
        let label = UILabel()
        label.font = TKTextStyle.label2.font
        label.textAlignment = .center
        label.textColor = .Text.secondary
        label.isHidden = true
        return label
    }()

    public init(
        frame: CGRect = .zero,
        successTitle: String = "Done",
        errorTitle: String = "Error",
        processTitle: String = ""
    ) {
        self.successTitle = successTitle
        self.errorTitle = errorTitle
        self.processTitle = processTitle
        super.init(frame: frame)
        setup()
        resultView.successTitle = successTitle
        resultView.errorTitle = errorTitle
        processTitleLabel.text = processTitle
        processTitleLabel.isHidden = processTitle.isEmpty
    }

    @available(*, unavailable)
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
        processContainer.isHidden = true

        addSubview(contentContainer)
        addSubview(resultView)
        addSubview(processContainer)

        processContainer.addSubview(processStackView)
        processStackView.addArrangedSubview(loaderView)
        processStackView.addArrangedSubview(processTitleLabel)

        contentContainer.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        resultView.snp.makeConstraints { make in
            make.edges.equalTo(self).priority(.high)
        }

        processContainer.snp.makeConstraints { make in
            make.edges.equalTo(self).priority(.high)
        }

        processStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            processStackView.centerXAnchor.constraint(equalTo: processContainer.centerXAnchor),
            processStackView.centerYAnchor.constraint(equalTo: processContainer.centerYAnchor),
        ])
    }
}
