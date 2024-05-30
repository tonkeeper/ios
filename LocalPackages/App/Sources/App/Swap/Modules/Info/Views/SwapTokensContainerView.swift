import UIKit
import TKUIKit

private extension CGFloat {
    static let swapButtonSize = 40.0
    static let rowHeight = 36.0
}

final class SwapTokensRowView: UIView, ConfigurableView {
    lazy var titleView = TKButton()
    lazy var contentView = UILabel()
    lazy var loaderView = TKLoaderView(size: .small, style: .primary)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleView)
        addSubview(contentView)
        addSubview(loaderView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(model: Model) {
        let titleAction = model.titleAction
        var titleIcon: UIImage?
        if titleAction != nil {
            titleIcon = .TKUIKit.Icons.Size16.informationCircle
        }
        titleView.configuration = .init(
            content: .init(title: .plainString(model.title), icon: titleIcon),
            textStyle: .body2,
            textColor: .Text.secondary,
            iconPosition: .right,
            iconTintColor: .Icon.tertiary
        )
        titleView.configuration.action = titleAction
        
        switch model.content {
        case .loader:
            loaderView.isHidden = false
            contentView.isHidden = true
            contentView.attributedText = nil
        case .text(let text):
            loaderView.isHidden = true
            contentView.isHidden = false
            let contentText = text?.withTextStyle(.body2, color: .Text.primary, alignment: .right)
            contentView.attributedText = contentText
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width / 2.0
        
        let titleViewSize = titleView.sizeThatFits(bounds.size)
        let titleViewWidth = min(titleViewSize.width + 4, width)
        
        titleView.frame = .init(
            x: 0,
            y: 0,
            width: titleViewWidth,
            height: bounds.height
        )
        
        contentView.frame = .init(
            x: width,
            y: 0,
            width: width,
            height: bounds.height
        )
        
        let loaderViewSize = loaderView.sizeThatFits(bounds.size)
        let loaderViewMinX = bounds.width - loaderViewSize.width
        let loaderViewMinY = (bounds.height - loaderViewSize.height) / 2.0
        
        loaderView.frame = .init(
            x: loaderViewMinX,
            y: loaderViewMinY,
            width: loaderViewSize.width,
            height: loaderViewSize.height
        )
    }
}

extension SwapTokensRowView {
    enum ContentType {
        case loader
        case text(String?)
    }
    struct Model {
        let title: String
        let titleAction: (() -> Void)?
        let content: ContentType
    }
}

final class SwapTokensSingleView: UIView, ConfigurableView {
    var didTapToken: (() -> Void)?
    
    private lazy var actionDescriptionLabelView = UILabel()
    private lazy var balanceDescriptionLabelView = UILabel()
    
    lazy var textFieldControl: TKTextInputTextFieldControl = {
        let control = TKTextInputTextFieldControl()
        control.keyboardType = .decimalPad
        control.attributedPlaceholder = "0".withTextStyle(.num2, color: .Text.secondary, alignment: .right)
        return control
    }()
    
    lazy var balanceTextView: TKTextFieldInputView = {
        let textFieldInputView = TKTextFieldInputView(
            textInputControl: textFieldControl
        )
        textFieldInputView.clearButtonMode = .never
        return textFieldInputView
    }()
    
    lazy var maxButtonView: TKButton = {
        let v = TKButton()
        v.configuration = TKButton.Configuration(
            content: .init(title: .plainString("MAX")),
            textStyle: .label2,
            textColor: .Text.accent,
            action: {}
        )
        return v
    }()
        
    private lazy var rowsView: UIStackView = {
        let rowsView = UIStackView()
        rowsView.axis = .vertical
        rowsView.distribution = .fillEqually
        rowsView.alignment = .fill
        rowsView.spacing = 0
        return rowsView
    }()
    
    private lazy var tokenButtonView = TKTokenTagView()
    
    var padding: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.content
        
        addSubview(actionDescriptionLabelView)
        
        tokenButtonView.addTarget(self, action: #selector(didTapTokenView), for: .touchUpInside)
        addSubview(tokenButtonView)
        
        addSubview(balanceDescriptionLabelView)
        addSubview(maxButtonView)
        
        addSubview(balanceTextView)
        
        addSubview(rowsView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let actionDescriptionLabelViewSize = actionDescriptionLabelView.sizeThatFits(size)
        let tokenButtonViewSize = tokenButtonView.sizeThatFits(size)
        let rowsViewHeigth = CGFloat(rowsView.subviews.count) * .rowHeight
        let height = padding.top + actionDescriptionLabelViewSize.height + 8.0 + tokenButtonViewSize.height + rowsViewHeigth + padding.bottom
        return .init(width: size.width, height: height)
    }
    
    func configure(model: Model) {
        let actionIdentifier = UIAction.Identifier(.init(describing: Self.self))
        if let _ = model.maxButtonDidTap {
            maxButtonView.isHidden = false
            maxButtonView.addAction(.init(identifier: actionIdentifier, handler: { _ in model.maxButtonDidTap?() }), for: .touchUpInside)
        } else {
            maxButtonView.isHidden = true
            maxButtonView.removeAction(identifiedBy: actionIdentifier, for: .touchUpInside)
        }
        actionDescriptionLabelView.attributedText = model.actionDescription.withTextStyle(.body2, color: .Text.secondary)
        balanceDescriptionLabelView.attributedText = model.balanceDescription?.withTextStyle(.body2, color: .Text.secondary)
        tokenButtonView.configure(model: model.tokenModel)
        
        let textFieldControlColor: UIColor = model.state == .default ? .Text.primary : .Accent.red
        textFieldControl.defaultTextAttributes = TKTextStyle.num2.getAttributes(color: textFieldControlColor, alignment: .right)
        
        rowsView.subviews.forEach { $0.removeFromSuperview() }
        rowsView.arrangedSubviews.forEach { rowsView.removeArrangedSubview($0) }
        
        for row in model.rows {
            let rowView = SwapTokensRowView()
            rowView.configure(model: row)
            rowsView.addArrangedSubview(rowView)
        }
        
        updateLayout(in: bounds.size)
    }
    
    @objc
    private func didTapTokenView() {
        didTapToken?()
    }
}

private extension SwapTokensSingleView {
    func updateLayout(in bounds: CGSize) {
        let halfWidth = (bounds.width - (padding.left + padding.right)) / 2.0
        
        let actionDescriptionLabelViewSize = actionDescriptionLabelView.sizeThatFits(bounds)
        let actionDescriptionLabelViewMinX = padding.left
        let actionDescriptionLabelViewMinY = padding.top
        
        actionDescriptionLabelView.frame = .init(
            x: actionDescriptionLabelViewMinX,
            y: actionDescriptionLabelViewMinY,
            width: actionDescriptionLabelViewSize.width,
            height: actionDescriptionLabelViewSize.height
        )
        
        let maxButtonViewSize = maxButtonView.sizeThatFits(bounds)
        let maxButtonViewMinX = bounds.width - maxButtonViewSize.width - padding.right
        let maxButtonViewMinY = padding.top
        
        maxButtonView.frame = .init(
            x: maxButtonViewMinX,
            y: maxButtonViewMinY,
            width: maxButtonViewSize.width,
            height: maxButtonViewSize.height
        )
        
        let balanceDescriptionLabelViewSize = balanceDescriptionLabelView.sizeThatFits(bounds)
        var balanceDescriptionLabelViewMinX = bounds.width - balanceDescriptionLabelViewSize.width - padding.right
        if !maxButtonView.isHidden {
            balanceDescriptionLabelViewMinX -= maxButtonViewSize.width + 8.0
        }
        let balanceDescriptionLabelViewMinY = padding.top
        
        balanceDescriptionLabelView.frame = .init(
            x: balanceDescriptionLabelViewMinX,
            y: balanceDescriptionLabelViewMinY,
            width: balanceDescriptionLabelViewSize.width,
            height: balanceDescriptionLabelViewSize.height
        )
        
        let tokenButtonViewSize = tokenButtonView.sizeThatFits(bounds)
        let tokenButtonViewWidth = min(tokenButtonViewSize.width, halfWidth)
        let tokenButtonViewMinX = padding.left
        let tokenButtonViewMinY = actionDescriptionLabelViewMinY + actionDescriptionLabelViewSize.height + 8.0
        
        tokenButtonView.frame = .init(
            x: tokenButtonViewMinX,
            y: tokenButtonViewMinY,
            width: tokenButtonViewWidth,
            height: tokenButtonViewSize.height
        )
        
        let balanceTextViewMinX = tokenButtonViewMinX + tokenButtonViewWidth + 8.0
        let balanceTextViewWidth = min(bounds.width - balanceTextViewMinX - padding.right, halfWidth)
        let balanceTextViewHeight = tokenButtonViewSize.height
        let balanceTextViewMinY = tokenButtonViewMinY
        
        balanceTextView.frame = .init(
            x: bounds.width - padding.right - balanceTextViewWidth,
            y: balanceTextViewMinY,
            width: balanceTextViewWidth,
            height: balanceTextViewHeight
        )
        
        let rowsViewMinX = padding.left
        let rowsViewMinY = balanceTextViewMinY + balanceTextViewHeight + padding.bottom
        let rowsViewWidth = bounds.width - padding.left - padding.right
        let rowsViewHeight = CGFloat.rowHeight * CGFloat(rowsView.subviews.count)
        
        rowsView.frame = .init(
            x: rowsViewMinX,
            y: rowsViewMinY,
            width: rowsViewWidth,
            height: rowsViewHeight
        )
    }
}

extension SwapTokensSingleView {
    struct Model {
        enum State {
            case `default`
            case error
        }
        let actionDescription: String
        let tokenModel: TKTokenTagView.Model
        
        let balanceDescription: String?
        let maxButtonDidTap: (() -> Void)?
        
        let rows: [SwapTokensRowView.Model]
        
        let state: State
        
        init(
            actionDescription: String,
            tokenModel: TKTokenTagView.Model,
            balanceDescription: String? = nil,
            maxButtonDidTap: (() -> Void)? = nil,
            rows: [SwapTokensRowView.Model] = [],
            state: State
        ) {
            self.actionDescription = actionDescription
            self.tokenModel = tokenModel
            self.balanceDescription = balanceDescription
            self.maxButtonDidTap = maxButtonDidTap
            self.rows = rows
            self.state = state
        }
    }
}

final class SwapTokensContainerView: UIView, ConfigurableView {
    private var model: Model? {
        didSet {
            updateState()
        }
    }
    
    var didSelectSendToken: (() -> Void)?
    var didUpdateInputSendToken: ((String) -> Void)?
    var didSelectReceiveToken: (() -> Void)?
    var didUpdateInputReceiveToken: ((String) -> Void)?
    var didSwapTokens: (() -> Void)?
    var didTapMaxButton: (() -> Void)?
    
    lazy var sendSwapTokensView = SwapTokensSingleView()
    lazy var receiveSwapTokensView = SwapTokensSingleView()
    
    private lazy var swapButtonView: UIButton = {
        let v = UIButton()
        let image = UIImage.TKUIKit.Icons.Size28.swapHorizontalOutline
            .withTintColor(.Button.tertiaryForeground, renderingMode: .alwaysOriginal)
        v.setImage(image, for: .normal)
        v.imageView?.contentMode = .scaleAspectFit
        v.imageEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10)
        v.backgroundColor = .Button.tertiaryBackground
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        sendSwapTokensView.layer.cornerRadius = 16.0
        sendSwapTokensView.padding = .init(top: 16, left: 16, bottom: 28, right: 16)
        sendSwapTokensView.didTapToken = { [weak self] in self?.didSelectSendToken?() }
        sendSwapTokensView.balanceTextView.didUpdateText = { [weak self] in
            self?.didUpdateInputSendToken?($0)
        }
        
        addSubview(sendSwapTokensView)
        
        receiveSwapTokensView.layer.cornerRadius = 16.0
        receiveSwapTokensView.padding = .init(top: 28, left: 16, bottom: 16, right: 16)
        receiveSwapTokensView.didTapToken = { [weak self] in self?.didSelectReceiveToken?() }
        receiveSwapTokensView.balanceTextView.didUpdateText = { [weak self] in
            self?.didUpdateInputReceiveToken?($0)
        }
        
        addSubview(receiveSwapTokensView)
        
        swapButtonView.layer.cornerRadius = .swapButtonSize / 2.0
        swapButtonView.addTarget(self, action: #selector(didTapSwapButton), for: .touchUpInside)
        addSubview(swapButtonView)
        
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sendSwapTokensViewSize = sendSwapTokensView.sizeThatFits(size)
        let receiveSwapTokensViewSize = receiveSwapTokensView.sizeThatFits(size)
        let height = sendSwapTokensViewSize.height + 8.0 + receiveSwapTokensViewSize.height
        return .init(width: size.width, height: height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    func configure(model: Model) {
        self.model = model
    }
    
    func updateState() {
        guard let model else { return }
        isUserInteractionEnabled = model.isEnabled
        
        swapButtonView.isHidden = !model.showsSwapButton
        
        var sendBalanceDescription: String = ""
        var isSendBalanceTextFieldEnabled = false
        if let sendSwapTokensBalance = model.sendSwapTokensModel.balance {
            sendBalanceDescription = "Balance: \(sendSwapTokensBalance)"
            isSendBalanceTextFieldEnabled = true
        }
        let sendSwapTokensModel = SwapTokensSingleView.Model(
            actionDescription: "Send",
            tokenModel: model.sendSwapTokensModel.tokenModel ?? .chooseToken,
            balanceDescription: sendBalanceDescription,
            maxButtonDidTap: model.showsSwapButton ? { [weak self] in self?.didTapMaxButton?() } : nil,
            state: model.sendSwapTokensModel.state
        )
        sendSwapTokensView.configure(model: sendSwapTokensModel)
        sendSwapTokensView.textFieldControl.isEnabled = isSendBalanceTextFieldEnabled
        if !isSendBalanceTextFieldEnabled {
            sendSwapTokensView.textFieldControl.text = nil
        }
        
        var receiveBalanceDescription: String = ""
        var isReceiveBalanceTextFieldEnabled = false
        if let receiveSwapTokensBalance = model.receiveSwapTokensModel.balance {
            receiveBalanceDescription = "Balance: \(receiveSwapTokensBalance)"
            isReceiveBalanceTextFieldEnabled = true
        }
        let receiveSwapTokensModel = SwapTokensSingleView.Model(
            actionDescription: "Receive",
            tokenModel: model.receiveSwapTokensModel.tokenModel ?? .chooseToken,
            balanceDescription: receiveBalanceDescription,
            maxButtonDidTap: nil, 
            rows: model.receiveSwapTokensModel.rows,
            state: model.receiveSwapTokensModel.state
        )
        receiveSwapTokensView.configure(model: receiveSwapTokensModel)
        receiveSwapTokensView.textFieldControl.isEnabled = isReceiveBalanceTextFieldEnabled
        if !isReceiveBalanceTextFieldEnabled {
            receiveSwapTokensView.textFieldControl.text = nil
        }
    }
}

@objc
private extension SwapTokensContainerView {
    func didTapSwapButton(_ sender: UIButton) {
        didSwapTokens?()
    }
}

private extension SwapTokensContainerView {
    func updateLayout(in bounds: CGSize) {
        let sendSwapTokensViewSize = sendSwapTokensView.sizeThatFits(bounds)
        let sendSwapTokensViewMinX = 0.0
        let sendSwapTokensViewMinY = 0.0
        
        sendSwapTokensView.frame = .init(
            x: sendSwapTokensViewMinX,
            y: sendSwapTokensViewMinY,
            width: sendSwapTokensViewSize.width,
            height: sendSwapTokensViewSize.height
        )
        
        let receiveSwapTokensViewSize = receiveSwapTokensView.sizeThatFits(bounds)
        let receiveSwapTokensViewMinX = 0.0
        let receiveSwapTokensViewMinY = sendSwapTokensViewSize.height + 8.0
        
        receiveSwapTokensView.frame = .init(
            x: receiveSwapTokensViewMinX,
            y: receiveSwapTokensViewMinY,
            width: receiveSwapTokensViewSize.width,
            height: receiveSwapTokensViewSize.height
        )
        
        let swapButtonViewMinX = bounds.width - .swapButtonSize - 32.0
        let swapButtonViewMinY = receiveSwapTokensViewMinY - (4.0 + .swapButtonSize) / 2.0
        
        swapButtonView.frame = .init(
            x: swapButtonViewMinX,
            y: swapButtonViewMinY,
            width: .swapButtonSize,
            height: .swapButtonSize
        )
    }
}

extension SwapTokensContainerView {
    struct Model {
        struct Send {
            let tokenModel: TKTokenTagView.Model?
            let balance: String?
            let state: SwapTokensSingleView.Model.State
        }
        
        struct Receive {
            let tokenModel: TKTokenTagView.Model?
            let balance: String?
            let state: SwapTokensSingleView.Model.State
            let rows: [SwapTokensRowView.Model]
        }
        
        let isEnabled: Bool
        let showsSwapButton: Bool
        let sendSwapTokensModel: Send
        let receiveSwapTokensModel: Receive
    }
}

extension TKTokenTagView.Model {
    static let chooseToken = TKTokenTagView.Model(
        iconModel: nil,
        title: "CHOOSE".withTextStyle(.label1, color: .Button.tertiaryForeground),
        accessoryType: nil
    )
}
