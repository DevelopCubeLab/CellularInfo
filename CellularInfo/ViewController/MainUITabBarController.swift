import Foundation
import UIKit

class MainUITabBarController: UITabBarController {
    
    private var appBadgeView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        
        // 隐藏iPad OS 18开始的顶部TabBar
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            setOverrideTraitCollection(UITraitCollection(horizontalSizeClass: .compact), forChild: self)
        }
        
        // 卡槽信息的ViewController
        let cellularDataViewController = CellularDataViewController()
        if #available(iOS 13.0, *) {
            cellularDataViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Cellular", comment: ""), image: UIImage(systemName: "antenna.radiowaves.left.and.right"), selectedImage: UIImage(systemName: "antenna.radiowaves.left.and.right"))
        } else { // iOS 12就凑活用吧
            cellularDataViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Cellular", comment: ""), image: UIImage(named: "Radiowaves"), selectedImage: UIImage(named: "Radiowaves"))
        }
        

        // 蜂窝套餐信息的ViewController
        let cellularPlansViewController = CellularPlansViewController()
        if #available(iOS 14.0, *) {
            cellularPlansViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("CellularPlans", comment: ""), image: UIImage(systemName: "simcard"), selectedImage: UIImage(systemName: "simcard.fill"))
        } else { // 低版本的兼容icon
            cellularPlansViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("CellularPlans", comment: ""), image: UIImage(named: "simcard"), selectedImage: UIImage(named: "simcard"))
        }

        
        // 工具的ViewController
        let toolsViewController = ToolsViewController()
        if #available(iOS 14.0, *) {
            toolsViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Tools", comment: ""), image: UIImage(systemName: "wrench.and.screwdriver"), selectedImage: UIImage(systemName: "wrench.and.screwdriver.fill"))
        } else if #available(iOS 13.0, *) { // 兼容一下iOS 13，换个icon完事了
            toolsViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Tools", comment: ""), image: UIImage(systemName: "wrench"), selectedImage: UIImage(systemName: "wrench.fill"))
        } else { // iOS 12就凑活用吧
            toolsViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Tools", comment: ""), image: UIImage(named: "wrench.and.screwdriver"), selectedImage: UIImage(named: "wrench.and.screwdriver"))
        }
        
        
        // 设置页面的ViewController
        let settingsViewController = SettingsViewController()
        if #available(iOS 13.0, *) {
            settingsViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Settings", comment: ""), image: UIImage(systemName: "gear"), selectedImage: UIImage(systemName: "gear.fill"))
        } else {
            settingsViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Settings", comment: ""), image: UIImage(named: "gear"), selectedImage: UIImage(named: "gear"))
        }
#if DEBUG
        
        // TODO 删除debug界面入口
        let debugViewController = DebugInterfaceViewController()
        if #available(iOS 13.0, *) {
            debugViewController.tabBarItem = UITabBarItem(title: "调试", image: UIImage(systemName: "wand.and.rays"), selectedImage: UIImage(systemName: "wand.and.rays"))
        } else {
            debugViewController.tabBarItem = UITabBarItem(title: "调试", image: UIImage(named: "Radiowaves"), selectedImage: UIImage(named: "Radiowaves"))
        }
        
        // 添加tabBar item到控制器
        self.viewControllers = [UINavigationController(rootViewController: cellularDataViewController),
                                UINavigationController(rootViewController: cellularPlansViewController),
                                UINavigationController(rootViewController: toolsViewController),
                                UINavigationController(rootViewController: settingsViewController),
                                UINavigationController(rootViewController: debugViewController)]
        
#else
        // 添加tabBar item到控制器
        self.viewControllers = [UINavigationController(rootViewController: cellularDataViewController),
                                UINavigationController(rootViewController: cellularPlansViewController),
                                UINavigationController(rootViewController: toolsViewController),
                                UINavigationController(rootViewController: settingsViewController)]
#endif
    
        DispatchQueue.main.async {
            self.showAppBadge()
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkDeviceTypeMatch()
    }
    
    /// 检查设备类型是否匹配
    private func checkDeviceTypeMatch() {
        
        if let deviceType = CellularDataController.instance.getDeviceType() {
            if deviceType != UIDevice.current.userInterfaceIdiom {
                UIUtils.showAlert(message: NSLocalizedString("DeviceTypeMismatchMessage", comment: ""), in: self)
            }
        }
    }
    
    private func showAppBadge() {
        // Only show badge in portrait orientation
        guard appBadgeView == nil else { return }
        guard view.bounds.height > view.bounds.width else { return }

//        if view.safeAreaInsets.top == 0 || view.safeAreaInsets.top == 20 || UIDevice.current.userInterfaceIdiom == .pad { // iPad 和老款不显示
//            return
//        }
        
        // 按照不同系统版本来设置背景颜色
        var backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        
        if #available(iOS 27.0, *) { // iOS 27 配色
            backgroundColor = UIColor.systemGray.withAlphaComponent(0.6)
        } else if #available(iOS 26.0, *) { // iOS 26 配色
            backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.6)
        } else if #available(iOS 18.0, *) { // iOS 18 配色
            backgroundColor = UIColor.systemYellow.withAlphaComponent(0.7)
        } else if #available(iOS 17.4, *) { // iOS 17.4 ~ 17.x 配色
            backgroundColor = UIColor.red.withAlphaComponent(0.5)
        } else if #available(iOS 17.0.1, *) { // iOS 17.0.1 ~ 17.3.1 配色
            backgroundColor = UIColor.systemPink.withAlphaComponent(0.65)
        } else if #available(iOS 17.0, *) { // iOS 17.0 配色
            backgroundColor = UIColor.systemPink.withAlphaComponent(0.5)
        } else if #available(iOS 16.5.1, *) { // iOS 16.5.1 ~ 16.7.x 配色
            backgroundColor = UIColor.systemMint.withAlphaComponent(0.7)
        }  else if #available(iOS 16.0, *) { // iOS 16.0 ~ 16.5 配色
            backgroundColor = UIColor.systemCyan.withAlphaComponent(0.75)
        } else if #available(iOS 15.0, *) { // iOS 15 配色
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        } else if #available(iOS 14.0, *) { // iOS 14 配色
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
        } else if #available(iOS 13.0, *) { // iOS 13 配色
            backgroundColor = UIColor.systemBrown.withAlphaComponent(0.65)
        } else if #available(iOS 12.0, *) { // iOS 12 配色
            backgroundColor = UIColor.systemTeal.withAlphaComponent(0.9)
        }
        
        let badgeView = UIView()
        badgeView.backgroundColor = backgroundColor
        badgeView.layer.cornerRadius = 14
        badgeView.layer.masksToBounds = true
        // 默认限制最大宽度为150
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.widthAnchor.constraint(lessThanOrEqualToConstant: 120).isActive = true
        // 限制最小宽度
        badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true

        let iconView = UIImageView(image: UIImage(named: "AppIcon60x60"))
        iconView.contentMode = .scaleAspectFit
        iconView.layer.cornerRadius = 5 // icon的圆角
        iconView.clipsToBounds = true
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let label = UILabel()
        label.text = NSLocalizedString("CFBundleDisplayName", comment: "") + " " + SettingsViewController.versionCode
        label.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center // 文本居中
        
        label.numberOfLines = 2 // 允许显示2行
        label.adjustsFontSizeToFitWidth = true // 允许因为字太多导致被压缩
        label.baselineAdjustment = .alignCenters
        label.minimumScaleFactor = 0.7 // 直接缩小字体
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        label.lineBreakMode = .byClipping

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        badgeView.addSubview(stack)
        stack.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor).isActive = true
        stack.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 10).isActive = true
        stack.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10).isActive = true

        print("view.safeAreaInsets.top: \(view.safeAreaInsets.top)")
        view.addSubview(badgeView)
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        
        // 判断安全区的高度来显示icon
        // 已知安全区高度：
        // iPhone XR/11 标准模式 = 48
        // iPhone XR 放大模式 = 44
        // iPhone 12 mini = 50
        // iPhone 13 mini = 50
        // iPhone 13 Pro Max = 47
        // iPhone 14 Pro = 59 (模拟器获取)
        // iPhone 14 Pro Max = 58
        // iPhone 15 Pro Max = 59
        // iPhone 16 Pro Max = 62
        // iPhone 17 Pro = 62
        // iPhone 17 Pro Max = 62
        // iPhone Air = 68
        // iPhone SE3 = 20
        // iPad mini 6 竖屏 = 24
        var badgeViewTopAnchor = CGFloat(0)
        
        switch view.safeAreaInsets.top {
        case 19..<26:
            badgeViewTopAnchor = -30
        case ..<45: // 老款刘海屏 放大模式
            badgeViewTopAnchor = 0.5
            // 限制最小宽度
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
            // 限制最大宽度
            badgeView.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
            // 设置文字大小
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        case ..<51: // 老款刘海屏 标准模式
            badgeViewTopAnchor = 4
            // 限制最小宽度
            badgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
            // 限制最大宽度
            badgeView.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
            // 设置文字大小
            label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        case 58..<60: // 14/15 Pro/PM 灵动岛
            badgeViewTopAnchor = 16
        case 60..<65: // 16 Pro Max～17 Pro/PM 灵动岛
            badgeViewTopAnchor = 18.5
        case 68: // iPhone Air 单独适配
            badgeViewTopAnchor = 24.5
        default: // 其余情况
            badgeViewTopAnchor = 20
        }
        
        NSLayoutConstraint.activate([
            badgeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            badgeView.topAnchor.constraint(equalTo: view.topAnchor, constant: badgeViewTopAnchor), // badge 的顶部位置
            badgeView.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // 用户如果点击到Badge就震动一下
        badgeView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(onBadgeTapped)
        ))

        self.appBadgeView = badgeView

        badgeView.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0.3) {
            badgeView.alpha = 1
        }
    }
    
    @objc private func onBadgeTapped() {
        let impact: UIImpactFeedbackGenerator
        if #available(iOS 13.0, *) {
            impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred(intensity: 1.5)
        } else {
            impact = UIImpactFeedbackGenerator(style: .heavy)
        }
        impact.prepare()
        impact.impactOccurred()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let isPortrait = size.height > size.width

        coordinator.animate(alongsideTransition: { _ in
            if isPortrait { // 当屏幕旋转时
                if self.appBadgeView == nil {
                    self.showAppBadge()
                }
                self.appBadgeView?.isHidden = false
                self.appBadgeView?.alpha = 0
                UIView.animate(withDuration: 0.2, delay: 0.3) { // 增加点延迟解决旋转动画能看到AppBadge的问题
                    self.appBadgeView?.alpha = 1
                }
            } else {
                self.appBadgeView?.isHidden = true
            }
        })
    }
    
    func startAppBadgeAnimation(completion: (() -> Void)? = nil) {
        guard let badgeView = appBadgeView else {
            completion?()
            return
        }

        if UIDevice.current.userInterfaceIdiom == .phone { // 如果是iPhone必须竖屏才给显示
            guard view.bounds.height > view.bounds.width else {
                completion?()
                return
            }
        }
        
        AppBadgePhysicsAnimator.play(on: badgeView, in: self.view, completion: completion)
    }
    
    // 发送消息
    func badgeShowMessage(message: String, stay: Float, completion: (() -> Void)? = nil) {
        guard let badgeView = appBadgeView else {
            completion?()
            return
        }
        AppBadgeFloatingAnimator.showMessage(on: badgeView, message: message, stay: stay, completion: completion)
    }
    
}
