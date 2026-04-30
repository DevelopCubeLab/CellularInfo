import Foundation
import UIKit

/// 截图隐藏信息的 Cell
/// 支持：
/// 1. 明文显示（UITextView）
/// 2. 自动换行 + 自适应高度
/// 3. 截图隐藏
class SecurityTextCell: UITableViewCell {
    
    private let secureField = UITextField()
    private weak var tableView: UITableView?
    private let proxyLabel = ProxyLabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 清空 secureField 内部内容（防止复用叠加）
        secureField.subviews.forEach { sub in
            sub.subviews.forEach { $0.removeFromSuperview() }
        }
    }
    
    private func setupUI() {
        // 隐藏默认 textLabel，避免冲突
        textLabel?.isHidden = true
        proxyLabel.onTextChanged = { [weak self] text in
            self?.setText(text ?? "")
        }
        
        secureField.isSecureTextEntry = true // 保护内容
        secureField.isUserInteractionEnabled = false
        secureField.translatesAutoresizingMaskIntoConstraints = false
        secureField.text = " " // 激活 secure 渲染（至少一个字符）
        secureField.textColor = .clear // 隐藏圆点
        secureField.tintColor = .clear // 隐藏光标
        secureField.backgroundColor = .clear
        
        contentView.addSubview(secureField)
        
        NSLayoutConstraint.activate([
            secureField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            secureField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            secureField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            secureField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        // 提高抗压缩优先级，防止被压成一条
        secureField.setContentCompressionResistancePriority(.required, for: .vertical)
        secureField.setContentHuggingPriority(.required, for: .vertical)
    }
    
    /// 外部调用：只需要传入文本即可
    func configure(text: String, tableView: UITableView) {
        self.tableView = tableView
        
        self.layoutIfNeeded()
        
        guard let secureView = self.secureField.subviews.first(where: {
            String(describing: type(of: $0)).contains("Canvas")
        }) ?? self.secureField.subviews.first else {
            return
        }
        
        // 清空已有内容（避免复用问题）
        secureView.subviews.forEach { $0.removeFromSuperview() }
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = self.textLabel?.font
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.text = text
        
        secureView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: secureView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: secureView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: secureView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: secureView.trailingAnchor)
        ])
        
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    /// 简化接口：仅设置文本（不依赖 configure）
    /// 可以在未调用 configure 的情况下直接使用
    func setText(_ text: String) {
        
        self.layoutIfNeeded()
        
        guard let secureView = self.secureField.subviews.first(where: {
            String(describing: type(of: $0)).contains("Canvas")
        }) ?? self.secureField.subviews.first else {
            return
        }
        
        secureView.subviews.forEach { $0.removeFromSuperview() }
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear // 去掉背景颜色
        textView.font = self.textLabel?.font
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.text = text
        
        secureView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: secureView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: secureView.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: secureView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: secureView.trailingAnchor)
        ])
        
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        
        contentView.bounds.size.width = targetSize.width
        contentView.layoutIfNeeded()
        
        guard let secureView = secureField.subviews.first(where: {
            String(describing: type(of: $0)).contains("Canvas")
        }) ?? secureField.subviews.first,
              let textView = secureView.subviews.first as? UITextView else {
            return super.systemLayoutSizeFitting(targetSize,
                                                 withHorizontalFittingPriority: horizontalFittingPriority,
                                                 verticalFittingPriority: verticalFittingPriority)
        }
        
        let availableWidth = max(targetSize.width - 32, 1)
        let fittedHeight = ceil(
            textView.sizeThatFits(
                CGSize(width: availableWidth, height: .greatestFiniteMagnitude)
            ).height
        )
        
        // 上下 padding（12 + 12）
        let totalHeight = fittedHeight + 24
        
        return CGSize(width: targetSize.width, height: max(totalHeight, 44))
    }
    
    override var textLabel: UILabel? {
        return proxyLabel
    }
}

class ProxyLabel: UILabel {
    var onTextChanged: ((String?) -> Void)?
    
    override var text: String? {
        didSet {
            onTextChanged?(text)
        }
    }
}
