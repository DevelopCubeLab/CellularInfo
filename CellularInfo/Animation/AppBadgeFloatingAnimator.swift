import Foundation
import UIKit

final class AppBadgeFloatingAnimator {

    private static var isAnimating = false

    static func showMessage(on badgeView: UIView, message: String, stay: Float, completion: (() -> Void)? = nil) {

        guard !isAnimating else {
            return
        }
        isAnimating = true

        guard let stack = badgeView.subviews.first(where: { $0 is UIStackView }) as? UIStackView,
              let label = stack.arrangedSubviews.first(where: { $0 is UILabel }) as? UILabel,
              let _ = badgeView.superview
        else { return }

        let originalText = label.text
        // 修改文本
        label.text = message

        // 原始位置
        let originalTransform = badgeView.transform

        // 下落动画（线性）
        UIView.animate(withDuration: 0.20, delay: 0, options: [.curveLinear]) {
            let dropTransform = originalTransform
                .translatedBy(x: 0, y: 85) // 下落位置
                .scaledBy(x: 1.16, y: 1.16) // 扩大
            badgeView.transform = dropTransform
        } completion: { _ in

            // 停留 stay 时间
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(stay)) {

                UIView.animate(withDuration: 0.18,
                               delay: 0,
                               options: [.curveEaseIn]) {
                    let overshoot = originalTransform
                        .translatedBy(x: 0, y: -4)
                        .scaledBy(x: 0.90, y: 0.90) // 缩小
                    badgeView.transform = overshoot
                } completion: { _ in

                    UIView.animate(withDuration: 0.22,
                                   delay: 0,
                                   usingSpringWithDamping: 0.85,
                                   initialSpringVelocity: 0.4,
                                   options: [.curveEaseOut]) {
                        badgeView.transform = originalTransform
                    } completion: { _ in
                        // 结束动画后
                        label.text = originalText
                        isAnimating = false
                        completion?()
                    }
                }
            }
        }
    }
}
