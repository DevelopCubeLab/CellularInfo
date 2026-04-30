import Foundation
import UIKit

class CellularDataViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private let cellularDataController = CellularDataController.instance
    
    private var inGroups = SettingsUtils.instance.getShowCellularDataInGroups()
    private var selectedSegmentIndex = 0
    
    private var cellularDataGroups: [InfoItemGroup] = []
    /// 是否正在刷新数据
    private var isRefreshingData = false
    /// 是否隐藏机密信息
    private var hideConfidential = false
    /// 给长按Cell复制文本的临时缓存变量
    private var currentCopyText: String?
    
    // 分组控制器
    private var slotSegmentedControl: UISegmentedControl!
    private var topContainerView: UIView!
    private var segmentedSeparator: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        /// 设置标题
        title = NSLocalizedString("Cellular", comment: "")
        
        refreshCellularData()
        
        // 长按锁按钮
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(onHideButtonLongPress(_:))
        )
        longPress.minimumPressDuration = 2
        
        // 顶栏右侧的按钮
        if #available(iOS 13.0, *) {
            // 第一个按钮 刷新数据
            let refreshButton = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain,
                target: self,
                action: #selector(onClickRefreshData)
            )
            // 第二个按钮 隐藏/显示机密信息的按钮
            let hideButton = UIBarButtonItem(
                image: UIImage(systemName: hideConfidential ? "lock" : "lock.open"),
                style: .plain,
                target: self,
                action: #selector(toggleHideConfidential)
            )
            // 设置长按
            navigationController?.navigationBar.addGestureRecognizer(longPress)
            
            // 设置两个按钮
            navigationItem.rightBarButtonItems = [refreshButton, hideButton]
        } else {
            // 第一个按钮 刷新数据
            let refreshButton = UIBarButtonItem(
                title: NSLocalizedString("Refresh", comment: ""),
                style: .plain,
                target: self,
                action: #selector(onClickRefreshData)
            )
            // 第二个按钮 隐藏/显示机密信息的按钮
            let hideButton = UIBarButtonItem(
                title: NSLocalizedString("Hide", comment: ""),
                style: .plain,
                target: self,
                action: #selector(toggleHideConfidential)
            )
            // 设置长按
            navigationController?.navigationBar.addGestureRecognizer(longPress)
            
            // 设置两个按钮
            navigationItem.rightBarButtonItems = [refreshButton, hideButton]
        }
        
        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }
        
        // 设置表格视图的代理和数据源
        tableView.delegate = self
        tableView.dataSource = self
        
        // 注册表格单元格
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SecurityTextCell.self, forCellReuseIdentifier: "SecurityTextCell")
        
        // 将表格视图添加到主视图
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        if inGroups { // 判断是否使用分组模式
            // 给选择器设置内容
            var selectItems = [NSLocalizedString("DeviceInfo", comment: "")]
            // 获取设备卡槽数量
            let slotCount = cellularDataController.getSlotCount()
            // Wi-Fi版iPad和iPod Touch和模拟器这些设备就不添加卡槽信息，因为没有基带
            if slotCount > 0 {
                for i in 1...slotCount { // 判断是单卡槽机器还是双卡槽机器
                    selectItems.append(String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), i))
                }
            }
            
            /// 创建分组选择器
            slotSegmentedControl = UISegmentedControl(items: selectItems)
            
            slotSegmentedControl.selectedSegmentIndex = 0
            slotSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
            // 设置切换的事件
            slotSegmentedControl.addTarget(
                self,
                action: #selector(onSegmentChanged(_:)),
                for: .valueChanged
            )
            
            // 顶部选择器的容器View
            topContainerView = UIView()
            topContainerView.backgroundColor = .clear // 暂时不设置分组选择器容器的背景颜色
            topContainerView.translatesAutoresizingMaskIntoConstraints = false
            
            // 分割线
            segmentedSeparator = UIView()
            segmentedSeparator.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 13.0, *) {
                segmentedSeparator.backgroundColor = .separator
            } else {
                segmentedSeparator.backgroundColor = .lightGray
            }
            if #available(iOS 26.0, *) { // iOS 26 强制显示分割线 UI风格又变了 不显示很奇怪
                segmentedSeparator.isHidden = false
            } else if #available(iOS 15.0, *) { // iOS 15.0 ～ iOS 18.x 需要考虑动态出现顶栏的分割线
                segmentedSeparator.isHidden = true
            } else { // 低版本(iOS 15以下)系统默认直接显示
                segmentedSeparator.isHidden = false
            }
            
            topContainerView.addSubview(slotSegmentedControl)
            topContainerView.addSubview(segmentedSeparator)
            
            view.addSubview(topContainerView)
            
            // 手动设置滚动条的位置，解决位置错误的问题
            tableView.verticalScrollIndicatorInsets.top = -1.9
            
            
            // 使用分组的AutoLayout
            NSLayoutConstraint.activate([
                topContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                topContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topContainerView.heightAnchor.constraint(equalToConstant: 56),
                
                slotSegmentedControl.centerYAnchor.constraint(equalTo: topContainerView.centerYAnchor),
                slotSegmentedControl.leadingAnchor.constraint(equalTo: topContainerView.leadingAnchor, constant: 16),
                slotSegmentedControl.trailingAnchor.constraint(equalTo: topContainerView.trailingAnchor, constant: -16),
                slotSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
                
                segmentedSeparator.leadingAnchor.constraint(equalTo: topContainerView.leadingAnchor),
                segmentedSeparator.trailingAnchor.constraint(equalTo: topContainerView.trailingAnchor),
                segmentedSeparator.bottomAnchor.constraint(equalTo: topContainerView.bottomAnchor),
                segmentedSeparator.heightAnchor.constraint(equalToConstant: 0.5),
                
                tableView.topAnchor.constraint(equalTo: topContainerView.bottomAnchor, constant: 0),
                tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
                tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
        } else {
            // 不使用分组（堆叠模式）的AutoLayout
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: view.topAnchor),
                tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
                tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
        }
        
        // 注册成为第一个响应者 否则菜单可能出不来
        self.becomeFirstResponder()
        
        // 注册监听器 当异步数据更改时刷新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCellularItemUpdate),
            name: CellularDataController.cellularDataItemUpdatedNotificationName,
            object: nil
        )
        
        // 注册监听器 当CoreTelephony数据刷新时更新数据
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCellularDataRefresh),
            name: CellularDataController.cellularDataRefreshNotificationName,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 刷新数据
        refreshCellularData()
        
        // 注册监听器 当用户截图且没有隐藏机要信息时发出提示
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreenCapture),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        // 注册监听器 当用户录屏且没有隐藏机要信息时发出通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreenCapture),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        
        if inGroups {
            // 设置顶部标题栏的效果
            if #available(iOS 15.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.shadowColor = .clear   // 移除默认的横线
                
                appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
                
                if #available(iOS 26.0, *) { // iOS 26的顶栏又变了颜色，需要额外适配一下 iOS 15～18不需要额外适配
                    if !UIUtils.getUIRequiresCompatibility() && SystemInfoUtils.getSDKMajorVersion() >= 26 { // 只有未开启兼容性模式或者SDK版本是Xcode 26的才允许这个UI效果
                        topContainerView.backgroundColor = UIColor { trait in
                            if self.traitCollection.userInterfaceStyle == .dark { // 深色模式
                                // iOS 26 顶栏色值 #242424
                                return UIColor(red: 36/255.0, green: 36/255.0, blue: 36/255.0, alpha: 1.0)
                            } else {
                                // iOS 26 顶栏色值 #f5f5f5
                                return UIColor(red: 245/255.0, green: 245/255.0, blue: 245/255.0, alpha: 1.0)
                            }
                        }
                    }
                    
                }
                
                navigationController?.navigationBar.standardAppearance = appearance
                navigationController?.navigationBar.scrollEdgeAppearance = appearance
                
            } else {
                navigationController?.navigationBar.shadowImage = UIImage()
                
                if #available(iOS 13.0, *) {
                    topContainerView.backgroundColor = UIColor { trait in
                        if self.traitCollection.userInterfaceStyle == .dark { // 深色模式
                            if #available(iOS 14.0, *) { // 顶栏色值 #121212
                                return UIColor(red: 18/255.0, green: 18/255.0, blue: 18/255.0, alpha: 1.0)
                            } else { // iOS 13 顶栏色值 #131112
                                return UIColor(red: 19/255.0, green: 17/255.0, blue: 18/255.0, alpha: 1.0)
                            }
                        } else { // 浅色模式
                            if #available(iOS 14.0, *) { // 顶栏色值 #f7f7f7
                                return UIColor(red: 247/255.0, green: 247/255.0, blue: 247/255.0, alpha: 1.0)
                            } else { // iOS 13 顶栏色值 #f6f6f6
                                return UIColor(red: 246/255.0, green: 246/255.0, blue: 246/255.0, alpha: 1.0)
                            }
                        }
                        
                    }
                } else if #available(iOS 12.0, *) { // iOS 12不支持深色模式 直接用浅色模式 顶栏色值 #f9f9f9
                    topContainerView.backgroundColor = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1)
                }
                
            }
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 取消注册监听器防止切换到别的ViewController还能监听到
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        
        // 注册成为第一个响应者 否则菜单可能出不来
        self.resignFirstResponder()
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    // 刷新数据
    private func refreshCellularData() {
        if isRefreshingData {
            return
        }
        isRefreshingData = true
        var cellularData: [InfoItemGroup]
        if inGroups { // 判断是否分组显示数据
            if selectedSegmentIndex == 0 {
                cellularData = [cellularDataController.getDeviceBaseInfoGroup()] + cellularDataController.getDeviceBaseCellularInfoGroup(inGroups: inGroups)
            } else {
                cellularData = cellularDataController.getSlotInfoGroup(slotID: selectedSegmentIndex, inGroups: inGroups) ?? []
            }
        } else { // 堆叠显示
            cellularData =  cellularDataController.getCellularDataGroups(inGroups: inGroups)
        }
        // 为无权限设备准备的 过滤无权限item
        cellularData = UIUtils.filterNoPermissionGroups(cellularData)
        
        DispatchQueue.main.async {
            self.cellularDataGroups = cellularData
            self.tableView.reloadData()
            self.isRefreshingData = false
        }
        
    }
    
    /// 当数据源通知ViewController数据已经准备好更新时的事件
    @objc func onCellularItemUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    /// 当CoreTelephony通知刷新数据或app从后台返回前台时刷新数据
    @objc func onCellularDataRefresh() {
        refreshCellularData()
    }
    
    /// 当用户截图或者录屏时
    @objc func onScreenCapture(_ notification: Notification) {
        // 截图或开始录屏时弹出提示
        if notification.name == UIApplication.userDidTakeScreenshotNotification || UIScreen.main.isCaptured {
            if !hideConfidential && SettingsUtils.instance.getShowScreenshotCaptureAlert() { // 判断是否隐藏机要信息和开启了提示
                UIUtils.showScreenCaptureAlert(viewController: self) {
                    // 点击了立刻隐藏
                    self.toggleHideConfidential()
                }
            }
        }
        
    }
    
    /// 当顶部的分组选择器切换时的事件
    @objc private func onSegmentChanged(_ sender: UISegmentedControl) {
        // 获取切换的索引
        // 0 = 设备信息
        // 1 = 卡槽1
        // 2 = 卡槽2
        self.selectedSegmentIndex = sender.selectedSegmentIndex
        refreshCellularData()
    }
    
    // 点击刷新数据
    @objc private func onClickRefreshData(_ sender: UIBarButtonItem) {
        // 禁用按钮
        sender.isEnabled = false
        // 刷新数据
        refreshCellularData()
        
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            sender.isEnabled = true
            return
        }
        // 是否需要强制恢复按钮可点击状态
        var didCallback = false
        
        // 播放动画
        tab.badgeShowMessage(message: NSLocalizedString("Refreshed", comment: ""), stay: 0.5) {
            didCallback = true
            // 允许再次点击
            sender.isEnabled = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !didCallback { // 强制恢复可点击状态
                sender.isEnabled = true
            }
        }
        
    }
    
    // 切换显示按钮
    @objc private func toggleHideConfidential() {
        if let buttons = navigationItem.rightBarButtonItems, buttons.count > 1 { // 判断下是否有两个按钮
            
            let hideButton = buttons[1] // 拿到隐藏/显示按钮
            
            // 切换显示/隐藏数据的标记
            hideConfidential.toggle()
            
            if #available(iOS 13.0, *) {
                hideButton.image = UIImage(systemName: hideConfidential ? "lock" : "lock.open")
            } else {
                hideButton.title = hideConfidential ? NSLocalizedString("Show", comment: "") : NSLocalizedString("Hide", comment: "")
            }
            // 刷新数据
            tableView.reloadData()
            
        }
        
    }
    
    /// 长按锁按钮
    @objc private func onHideButtonLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        if let tab = self.tabBarController as? MainUITabBarController {
            tab.startAppBadgeAnimation()
        }
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return cellularDataGroups.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellularDataGroups[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return cellularDataGroups[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return cellularDataGroups[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        // 获取数据
        let item = cellularDataGroups[indexPath.section].items[indexPath.row]
        // 设置ID
        cell.tag = item.id
        
        // 强制保证IMSI不会被截图
        if item.id == CommonItemID.IMSI {
            cell = SecurityTextCell(style: .default, reuseIdentifier: "SecurityTextCell")
        }
        
        // 设置文本并且判断是否需要隐藏机要信息
        if hideConfidential && item.isConfidential {
            cell.textLabel?.text = UIUtils.maskConfidential(item.text)
        } else {
            cell.textLabel?.text = item.text
        }
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        cell.selectionStyle = .none // 取消点击特效
        
        // 判断是否显示提示文本
        if item.hintText != nil {
            cell.accessoryType = .detailButton
        } else if item.id == ActionItemID.underlyingData || item.id == ActionItemID.APNConfig || item.id == ActionItemID.carrierBookmark { // 判断是否需要进入二级界面
            cell.accessoryType = .disclosureIndicator // 右侧增加 >
            cell.selectionStyle = .default // 设置点击效果
        } else {
            cell.accessoryType = .none
        }
        
        // 判断是否要允许显示复制按钮
        if item.copyable && item.detailText != nil {
            // 给Cell设置长按手势 用来复制
            if cell.gestureRecognizers?.contains(where: { $0 is UILongPressGestureRecognizer }) != true {
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressCell(_:)))
                cell.addGestureRecognizer(longPress)
            }
            // 取消选中动画 不然长按动画会很奇怪
            cell.selectionStyle = .none
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 获取数据
        let item = cellularDataGroups[indexPath.section].items[indexPath.row]
        if item.id == ActionItemID.underlyingData || item.id == ActionItemID.APNConfig || item.id == ActionItemID.carrierBookmark {
            let cellularDataDetailsViewController = CellularDataDetailsViewController(
                detailType: item.id,
                slotID: cellularDataGroups[indexPath.section].id
            )
            navigationController?.pushViewController(cellularDataDetailsViewController, animated: true)
        }
    }
    
    // MARK: - Cell的右侧的i的点击事件
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        if let hintText = cellularDataGroups[indexPath.section].items[indexPath.row].hintText {
            UIUtils.showAlert(message: hintText, in: self)
        }
        
    }
    
    // MARK: - UITableView滚动滚动条
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #unavailable(iOS 26.0) { // iOS 26.0取消了横线效果 但是去掉横线很难看，因此保留横线常驻
            if #available(iOS 15.0, *) { // 只有iOS 15.0开始才有这个效果，低版本不需要
                if inGroups {
                    let showLine = scrollView.contentOffset.y > 5
                    segmentedSeparator.isHidden = !showLine
                }
            }
        }
    }
    
    /// 处理长按UITableView的Cell的方法
    @objc func handleLongPressCell(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else {
            return
        }
        
        guard let cell = gesture.view as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        
        // 临时保存复制内容
        self.currentCopyText = cellularDataGroups[indexPath.section].items[indexPath.row].detailText
        // 创建菜单
        let menu = UIMenuController.shared
        // 创建复制按钮
        let copyItem = UIMenuItem(title: NSLocalizedString("Copy", comment: ""), action: #selector(copyCellText))
        // 把复制按钮放菜单里
        menu.menuItems = [copyItem]
        // 成为第一个处理的View
        self.becomeFirstResponder()
        // 显示菜单
        if #available(iOS 13.0, *) {
            menu.showMenu(from: cell, rect: cell.bounds)
        } else {
            menu.setTargetRect(cell.bounds, in: cell)
            menu.setMenuVisible(true, animated: true)
        }
    }
    
    /// 成为菜单的接收者
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    /// 成为第一个响应菜单的响应者
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copyCellText)
    }

    /// 复制操作
    @objc func copyCellText() {
        UIPasteboard.general.string = currentCopyText
        sendMessage(message: NSLocalizedString("Copied", comment: ""))
    }
    
    /// 使用AppBadge展示消息
    private func sendMessage(message: String) {
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            return
        }
        
        // 播放动画
        tab.badgeShowMessage(message: message, stay: 0.8) {
            // 允许再次点击
        }
    }
    
}
