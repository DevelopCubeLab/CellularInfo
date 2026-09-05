import Foundation
import UIKit

// 左侧显示 Section 标题，右侧提供「全选」和「取消全选」按钮。
@available(iOS 14.0, *)
final class BandSectionHeaderView: UITableViewHeaderFooterView {

    /// Section 标题
    let titleLabel = UILabel()

    /// 点击「全选」后的回调
    var onSelectAll: (() -> Void)?

    /// 点击「取消全选」后的回调
    var onDeselectAll: (() -> Void)?

    /// 全选按钮
    private let selectAllButton = UIButton(type: .system)

    /// 取消全选按钮
    private let deselectAllButton = UIButton(type: .system)

    // MARK: - Initialization
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        // 标题字体
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        // 设置按钮文字
        selectAllButton.setTitle(NSLocalizedString("SelectAll", comment: ""), for: .normal)

        deselectAllButton.setTitle(NSLocalizedString("DeselectAll", comment: ""), for: .normal)

        // 添加按钮点击事件
        //
        // 注意这里故意使用 handleSelectAll / handleDeselectAll，
        // 不使用 selectAll / deselectAll，避免与 UIKit
        // 或其他 Objective-C Selector 产生命名冲突。
        selectAllButton.addTarget(self, action: #selector(handleSelectAll), for: .touchUpInside)

        deselectAllButton.addTarget(self, action: #selector(handleDeselectAll), for: .touchUpInside)

        // 两个按钮组成一个横向 StackView
        let buttonStack = UIStackView(
            arrangedSubviews: [selectAllButton,deselectAllButton]
        )

        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 添加到 Header
        contentView.addSubview(titleLabel)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            // Section 标题
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            // 右侧按钮
            buttonStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            // 防止标题和按钮重叠
            buttonStack.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor,constant: 12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 点击「全选」
    @objc private func handleSelectAll() {
        onSelectAll?()
    }

    /// 点击「取消全选」
    @objc private func handleDeselectAll() {
        onDeselectAll?()
    }
}
