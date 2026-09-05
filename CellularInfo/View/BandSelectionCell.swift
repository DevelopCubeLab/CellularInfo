import UIKit

// MARK: - BandSelectionCell
// 用于显示 Band 选项，每行最多显示 4 个。
// 每个 Band 使用一个 UIButton 表示，可以点击进行选择/取消选择。
@available(iOS 14.0, *)
final class BandSelectionCell: UITableViewCell {

    static let reuseIdentifier = "BandSelectionCell"

    // 点击 Band 后回调给 ViewController
    var onToggle: ((Band) -> Void)?

    // 垂直 StackView：里面包含多行 Band
    private let stackView = UIStackView()

    // 当前 Cell 对应的 Band 选项
    private var options: [Band] = []

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // 不显示 UITableViewCell 默认的选中效果
        selectionStyle = .none

        // StackView 设置为垂直排列
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        // StackView 填满 Cell 的 layoutMargins 区域
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure
    /// 配置 Band 列表
    ///
    /// - Parameters:
    ///   - options: 当前需要显示的所有 Band
    ///   - activeBands: 当前已经启用的 Band
    func configure(options: [Band], activeBands: [String: Set<Int>]) {
        self.options = options

        // Cell 复用时先清空之前创建的 UI
        stackView.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }

        // 没有 Band 时显示 None
        guard !options.isEmpty else {
            let label = UILabel()
            label.text = NSLocalizedString("None", comment: "")
            label.textColor = .secondaryLabel

            stackView.addArrangedSubview(label)
            return
        }

        // 设置每一行显示多少个频段
        var columnCount = 4
        if (CellularDataController.instance.getDeviceType() ?? UIDevice.current.userInterfaceIdiom) == .phone {
            // iPhone竖屏每行 4 个，横屏每行 6 个
            // 旋转的时候有bug 效果不太好
//            columnCount = traitCollection.verticalSizeClass == .compact ? 6 : 4
            columnCount = 4
        } else {
            // iPad固定每行8个
            columnCount = 8
        }

        // 每行最多放columnCount个频段
        for start in stride(from: 0, to: options.count, by: columnCount) {

            let row = UIStackView()

            // 横向排列
            row.axis = .horizontal

            // columnCount个按钮平均分配宽度
            row.distribution = .fillEqually

            // 按钮之间的间距
            row.spacing = 6

            // 添加当前这一行的频段
            for index in start..<min(start + columnCount, options.count) {

                let band = options[index]

                // 判断当前频段是否已经启用
                let isActive = activeBands.contains { ratKey, values in
                    BandRadioAccessTechnology.from(key: ratKey) == band.rat
                        && values.contains(band.value)
                }

                let button = makeBandButton(
                    band: band,
                    selected: isActive,
                    index: index
                )

                row.addArrangedSubview(button)
            }

            // 如果这一行不足columnCount个，用空 UIView 补齐
            // 这样可以保持前面的按钮宽度一致
            while row.arrangedSubviews.count < columnCount {
                row.addArrangedSubview(UIView())
            }

            stackView.addArrangedSubview(row)
        }
    }
    
    /// 创建一个 Band 按钮
    private func makeBandButton(
        band: Band,
        selected: Bool,
        index: Int
    ) -> UIButton {

        let button = UIButton(type: .system)

        // 文字靠左
        button.contentHorizontalAlignment = .leading

        // 按钮上下的空间
        button.contentEdgeInsets = UIEdgeInsets(
            top: 2,
            left: 0,
            bottom: 2,
            right: 0
        )

        // 使用系统 Body 字体
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)

        // 设置 Band 名称
        button.setTitle(
            band.displayName,
            for: .normal
        )

        // 根据当前状态显示不同的 SF Symbol
        button.setImage(
            UIImage(
                systemName: selected
                    ? "checkmark.circle.fill"
                    : "circle"
            ),
            for: .normal
        )

        // 图标颜色
        button.tintColor = .systemBlue

        // 强制图标在左、文字在右
        button.semanticContentAttribute = .forceLeftToRight

        // 图标保持合适的比例
        button.imageView?.contentMode = .scaleAspectFit

        // CheckBox图标和文字之间距离
        // left 控制CheckBox和文本的距离，
        button.imageEdgeInsets = UIEdgeInsets(
            top: 0,
            left: -4,
            bottom: 0,
            right: 0
        )

        // VoiceOver 无障碍名称
        button.accessibilityLabel = band.displayName

        // VoiceOver 当前状态
        button.accessibilityValue = selected
            ? NSLocalizedString("Selected", comment: "")
            : NSLocalizedString("NotSelected", comment: "")

        // 保存当前 Band 在 options 中的下标
        // 点击按钮时通过 tag 找回对应的 Band
        button.tag = index

        // 添加点击事件
        button.addTarget(
            self,
            action: #selector(toggleBand(_:)),
            for: .touchUpInside
        )

        return button
    }

    /// Band 按钮点击事件
    @objc private func toggleBand(_ sender: UIButton) {

        // 防止异常 tag 导致数组越界
        guard options.indices.contains(sender.tag) else {
            return
        }

        // 将点击的 Band 回调给 ViewController
        onToggle?(options[sender.tag])
    }
}
