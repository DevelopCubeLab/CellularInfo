import Foundation
import UIKit

class UIUtils {
    
    /// 获取是否开启UI兼容性 iOS 26的操作
    static func getUIRequiresCompatibility() -> Bool {
        return Bundle.main.infoDictionary?["UIRequiresCompatibility"] as? Bool ?? false
    }
    
    // 通用弹窗提示
    static func showAlert(title: String = NSLocalizedString("Alert", comment: ""), message: String, in viewController: UIViewController) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let closeAction = UIAlertAction(
            title: NSLocalizedString("Close", comment: ""),
            style: .cancel,
            handler: nil
        )
        alert.addAction(closeAction)
        viewController.present(alert, animated: true, completion: nil)
    }
    
    /// 弹窗提示并使用默认浏览器打开链接
    static func showAlertToUseDefaultBrowserOpenLink(URL urlString: String?, in viewController: UIViewController) {
        
        if let urlString = urlString, let url = URL(string: urlString) {
            let alert = UIAlertController(
                title: nil,
                message: NSLocalizedString("UseDefaultBrowserOpenLink", comment: ""),
                preferredStyle: .alert
            )
            
            let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
            
            let open = UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default) { _ in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            
            alert.addAction(cancel)
            alert.addAction(open)
            
            viewController.present(alert, animated: true)
        }
        
    }
    
    // 显示截图/录屏的弹窗
    static func showScreenCaptureAlert(viewController: UIViewController, showHideNowButton: Bool = true, onHideNow: (() -> Void)? = nil) {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("ScreenCaptureMessage", comment: ""),
            preferredStyle: .alert
        )

        // 不再提示 按钮 红色
        let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .destructive) { _ in
            // 设置不再显示提示
            SettingsUtils.instance.setShowScreenshotCaptureAlert(enable: false)
        }
        
        // 立刻隐藏 按钮 蓝色
        let hideNowAction = UIAlertAction(title: NSLocalizedString("HideNow", comment: ""), style: .default) { _ in
            onHideNow?() // 发送回调
        }

        // 关闭 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(disableAlertAction)
        if showHideNowButton {
            alert.addAction(hideNowAction)
        }
        
        alert.addAction(cancelAction)

        // 显示弹窗
        viewController.present(alert, animated: true, completion: nil)
    }
    
    /// 对机密字符串进行打码
    /// - Parameter text: 原始文本
    /// - Returns: 打码后的文本
    static func maskConfidential(_ text: String) -> String {

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return text }

        // 如果是“标签: 值”结构，只对值部分做打码
        if let colonRange = trimmed.range(of: ":") {
            let labelPart = String(trimmed[..<colonRange.upperBound]) // 包含冒号
            let valuePart = trimmed[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)

            if valuePart.isEmpty {
                return text
            }

            let maskedValue = maskConfidentialValue(valuePart)
            return labelPart + " " + maskedValue
        }

        return maskConfidentialValue(trimmed)
    }

    /// 只对“纯值”做打码（不含标签）
    private static func maskConfidentialValue(_ value: String) -> String {

        // 不打码的占位文本（本地化值）
        let skipSet: Set<String> = [
            NSLocalizedString("NotSet", comment: ""),
            NSLocalizedString("Unknown", comment: ""),
            NSLocalizedString("None", comment: ""),
            NSLocalizedString("NotObtained", comment: "")
        ]

        if skipSet.contains(value) {
            return value
        }

        // 手机号（+开头）或者太短的内容 → 全打码
        if value.hasPrefix("+") || value.count <= 8 {
            return String(repeating: "*", count: max(value.count, 4))
        }

        // 较长字符串 → 保留首尾4位
        if value.count >= 12 {
            return maskKeepEdges(value, keep: 4)
        }
        
        // 纯数字且较长 → 保留首尾3位
        let digitsOnly = value.allSatisfy { $0.isNumber }
        if digitsOnly && value.count >= 8 {
            return maskKeepEdges(value, keep: 3)
        }

        return value
    }

    /// 前后保留N位，中间打码
    private static func maskKeepEdges(_ s: String, keep: Int) -> String {
        guard s.count > keep * 2 else {
            return String(repeating: "*", count: s.count)
        }

        let prefix = s.prefix(keep)
        let suffix = s.suffix(keep)
        let stars = String(repeating: "*", count: s.count - keep * 2)

        return prefix + stars + suffix
    }
    
    /// 保留小数
    static func formatDouble(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    static func filterNoPermissionGroups(_ groups: [InfoItemGroup], excludedIDs: Set<Int> = [ActionItemID.APNConfig]) -> [InfoItemGroup] {
        // 如果有权限，直接返回原数据
        guard !AppCapability.hasCommCenterSPI(),
              SettingsUtils.instance.getHideNoPermissionData() else {
            return groups
        }
        
        let noPermissionText = NSLocalizedString("NoPermission", comment: "")
        
        return groups.compactMap { group in
            
            let filteredItems = group.items.filter { item in
                let value = (item.detailText ?? "") + item.text
                let noPermission = value.contains(noPermissionText)
                let excluded = excludedIDs.contains(item.id)
                if item.id == CoreTelephonyItemID.SIMStatus && !SettingsUtils.instance.getShowInactiveSIMSlotsData() { // 暂时排除SIM卡状态item
                    return true
                }
                return !noPermission && !excluded
            }
            
            // 整个 group 被清空 → 丢弃
            guard !filteredItems.isEmpty else {
                return nil
            }
            
            // 返回新的 group（不污染原数据）
            return InfoItemGroup(
                id: group.id,
                titleText: group.titleText,
                items: filteredItems,
                footerText: group.footerText
            )
        }
    }
    
    /// 显示拖拽IPCC文件的时候的叠层
    static func showDropOverlay(baseView view: UIView, hintText: String) -> UIView {

        // 创建虚线框
        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.65)
        overlay.layer.cornerRadius = 8
        overlay.translatesAutoresizingMaskIntoConstraints = false
        // 创建一个文本
        let label = UILabel()
        label.isUserInteractionEnabled = false
        label.text = hintText
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(label)
        view.addSubview(overlay)

        // 设置约束
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            overlay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            overlay.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            overlay.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),

            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            label.leftAnchor.constraint(greaterThanOrEqualTo: overlay.leftAnchor, constant: 20),
            label.rightAnchor.constraint(lessThanOrEqualTo: overlay.rightAnchor, constant: -20)
        ])

        // 给边框绘制虚线框
        let dashedLayer = CAShapeLayer()
        dashedLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        dashedLayer.lineWidth = 2
        dashedLayer.lineDashPattern = [6, 4]
        dashedLayer.fillColor = nil

        overlay.layer.addSublayer(dashedLayer)

        DispatchQueue.main.async {
            dashedLayer.frame = overlay.bounds
            dashedLayer.path = UIBezierPath(
                roundedRect: overlay.bounds,
                cornerRadius: overlay.layer.cornerRadius
            ).cgPath
        }
        
        overlay.alpha = 0

        UIView.animate(withDuration: 0.2) {
            overlay.alpha = 1
        }
        
        return overlay
    }
    
    // 设置SF Symbol到cell.detailTextLabel?.attributedText
    @available(iOS 13.0, *)
    static func symbolAttributedString(_ name: String, color: UIColor) -> NSAttributedString {
        let attachment = NSTextAttachment()
        if let baseImage = UIImage(systemName: name) {
            attachment.image = baseImage.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        return NSAttributedString(attachment: attachment)
    }
    
    @available(iOS 13.0, *)
    static func sealWithGreenCheckmark() -> NSAttributedString {
        return symbolAttributedString("checkmark.seal.fill", color: .systemGreen)
    }
    
    @available(iOS 13.0, *)
    static func sealWithRedXMark() -> NSAttributedString {
        return symbolAttributedString("xmark.seal.fill", color: .systemRed)
    }
    
    @available(iOS 13.0, *)
    static func sealWithMark(isChecked: Bool) -> NSAttributedString {
        return isChecked ? sealWithGreenCheckmark() : sealWithRedXMark()
    }
    
    // 设置一个带?的SF Symbol到cell.detailTextLabel?.attributedText
    @available(iOS 13.0, *)
    static func sealWithQuestionMark(color: UIColor) -> NSAttributedString {
        let size = CGSize(width: 22, height: 22) // 控制大小
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            // 绘制 seal.fill 底图
            if let seal = UIImage(systemName: "seal.fill")?.withTintColor(color, renderingMode: .alwaysOriginal) {
                seal.draw(in: CGRect(origin: .zero, size: size))
            }

            // 绘制 questionmark
            if let qmark = UIImage(systemName: "questionmark")?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let qSize = CGSize(width: size.width * 0.5, height: size.height * 0.5)
                let qOrigin = CGPoint(
                    x: (size.width - qSize.width) / 2,
                    y: (size.height - qSize.height) / 2
                )
                qmark.draw(in: CGRect(origin: qOrigin, size: qSize))
            }
        }

        let attachment = NSTextAttachment()
        attachment.image = image

        // 调整基线对齐，让图标垂直居中
        let font = UIFont.systemFont(ofSize: 17) // TableView 默认字体
        let mid = (font.capHeight - size.height) / 2
        attachment.bounds = CGRect(x: 0, y: mid, width: size.width, height: size.height)

        return NSAttributedString(attachment: attachment)
    }
    
    // 创建SF Symbol 叠加的效果
    @available(iOS 13.0, *)
    static func makeCompositeSymbol(base: String, baseColor: UIColor = .systemGray2, overlay: String, overlayColor: UIColor = .systemBlue, size: CGSize? = nil) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)

        guard let baseImage = UIImage(systemName: base, withConfiguration: config),
              let overlayImage = UIImage(systemName: overlay, withConfiguration: config)?.withTintColor(overlayColor, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let baseSize = size ?? baseImage.size
        let renderer = UIGraphicsImageRenderer(size: baseSize)

        let image = renderer.image { _ in
            // 绘制底图
            baseImage.withTintColor(baseColor, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(origin: .zero, size: baseSize))

            // 叠加层按比例绘制
            let overlayScale: CGFloat = 0.35
            let maxOverlayWidth = baseSize.width * overlayScale
            let aspectRatio = overlayImage.size.width / overlayImage.size.height
            let overlayWidth = maxOverlayWidth
            let overlayHeight = overlayWidth / aspectRatio

            let overlaySize = CGSize(width: overlayWidth, height: overlayHeight)
            let margin = baseSize.width * 0.1
            let overlayOrigin = CGPoint(
                x: baseSize.width - overlaySize.width - margin,
                y: baseSize.height - overlaySize.height - margin
            )

            overlayImage.draw(in: CGRect(origin: overlayOrigin, size: overlaySize))
        }

        return image
    }
}
