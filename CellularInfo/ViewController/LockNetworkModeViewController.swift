import Foundation
import UIKit

class LockNetworkModeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    private var networkModeGroups: [InfoItemGroup] = []
    
    private let cellularDataController = CellularDataController.instance
    // 卡槽编号
    private var slotID: Int = 1
    
    // 分组控制器
    private var slotSegmentedControl: UISegmentedControl!
    private var topContainerView: UIView!
    private var segmentedSeparator: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("LockNetworkMode", comment: "")
        
        // 设置背景颜色
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        
        // 设置右上角的按钮
        if #available(iOS 13.0, *) {
            let refreshButton = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain,
                target: self,
                action: #selector(onClickRefreshData)
            )
            // 添加按钮到右上角
            navigationItem.rightBarButtonItem = refreshButton
        } else {
            let refreshButton = UIBarButtonItem(
                title: NSLocalizedString("Refresh", comment: ""),
                style: .plain,
                target: self,
                action: #selector(onClickRefreshData)
            )
            // 添加按钮到右上角
            navigationItem.rightBarButtonItem = refreshButton
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

        // 给选择器设置内容
        var selectItems: [String] = []
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
        
        // 将表格视图添加到主视图
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        
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
        
        // 显示进入的弹窗
        self.showEntryTipsAlert()
        
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
        
#if !DEBUG
        // 判断用户是否没有权利进入当前界面
        if !SettingsUtils.instance.getShowLockNetworkMode() || !SettingsUtils.instance.getEnableExperimentalFeatures() {
            finish() // 退出当前界面
        }
#endif
        
        // 刷新数据
        reloadData()
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 关闭界面
    /// 封装一个Android那样的 doge
    func finish(animated: Bool = true) {
        if let nav = navigationController {
            nav.popViewController(animated: animated)
        } else {
            dismiss(animated: animated)
        }
    }
    
    /// 当CoreTelephony通知刷新数据或app从后台返回前台时刷新数据
    @objc func onCellularDataRefresh() {
        reloadData()
    }
    
    // 点击刷新数据
    @objc private func onClickRefreshData(_ sender: UIBarButtonItem) {
        // 禁用按钮
        sender.isEnabled = false
        // 刷新数据
        reloadData()
        
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            sender.isEnabled = true
            return
        }
        
        // 播放动画
        tab.badgeShowMessage(message: NSLocalizedString("Refreshed", comment: ""), stay: 0.5) {
            // 允许再次点击
            sender.isEnabled = true
        }
        
    }
    
    /// 刷新数据
    private func reloadData() {
        networkModeGroups = cellularDataController.getLockNetworkModeGroup(slotID: slotID)
        tableView.reloadData()
    }
    
    /// 当顶部的分组选择器切换时的事件
    @objc private func onSegmentChanged(_ sender: UISegmentedControl) {
        // 获取切换的索引
        // 0 = 卡槽1
        // 1 = 卡槽2
        self.slotID = sender.selectedSegmentIndex + 1
        reloadData()
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return networkModeGroups.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return networkModeGroups[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return networkModeGroups[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return networkModeGroups[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        // 获取数据
        let item = networkModeGroups[indexPath.section].items[indexPath.row]
        // 设置ID
        cell.tag = item.id
        // 设置文本
        cell.textLabel?.text = item.text
        cell.selectionStyle = .none // 取消点击特效
        
        if networkModeGroups[indexPath.section].id == CellularDataItemGroupID.networkModeSelect {
            if networkModeGroups[indexPath.section].items[indexPath.row].id == ActionItemID.selectNetworkModeUnknown {
                // 未知网络类型 设置成红色
                cell.textLabel?.textColor = .systemRed
            } else {
                // 可选的网络类型设置成蓝色
                cell.textLabel?.textColor = .systemBlue
            }
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if networkModeGroups[indexPath.section].id == CellularDataItemGroupID.networkModeSelect {
            onClickSetNetworkModeCell(item: networkModeGroups[indexPath.section].items[indexPath.row])
        }
        
    }
    
    // MARK: - UITableView滚动滚动条
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if #unavailable(iOS 26.0) { // iOS 26.0取消了横线效果 但是去掉横线很难看，因此保留横线常驻
            if #available(iOS 15.0, *) { // 只有iOS 15.0开始才有这个效果，低版本不需要
                let showLine = scrollView.contentOffset.y > 5
                segmentedSeparator.isHidden = !showLine
            }
        }
    }
    
    // 显示第一次进入的弹窗
    private func showEntryTipsAlert() {
        if SettingsUtils.instance.getShowLockNetworkModeEntryTips() {
            // 强行不让View可以点击
            self.view.isUserInteractionEnabled = false
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("LockNetworkModeEntryTipsMessage", comment: ""),
                preferredStyle: .alert
            )
            
            // 继续 按钮
            let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
                // 恢复View点击
                self.view.isUserInteractionEnabled = true
                self.showNotInstalledIPCCAlert() // 检测用户是否安装了IPCC
            }
            
            // 关闭 按钮
            let exitAction = UIAlertAction(title: NSLocalizedString("Exit", comment: ""), style: .cancel) { _ in
                SettingsUtils.instance.setShowLockNetworkMode(status: false) // 关闭进入权限
                self.finish() // 关闭当前界面
            }

            // 添加按钮，iOS 会自动按照规范排列
            if SettingsUtils.instance.getAllowSetNotShowLockNetworkModeEntryTips() {
                // 不再提示 按钮
                let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .default) { _ in
                    // 设置不再显示提示
                    SettingsUtils.instance.setNotShowLockNetworkModeEntryTips()
                    // 恢复View点击
                    self.view.isUserInteractionEnabled = true
                    self.showNotInstalledIPCCAlert() // 检测用户是否安装了IPCC
                }
                alert.addAction(disableAlertAction)
            }
            alert.addAction(continueAction)
            alert.addAction(exitAction)

            // 显示弹窗
            self.present(alert, animated: true, completion: nil)
        } else {
            self.showNotInstalledIPCCAlert() // 检测用户是否安装了IPCC
        }
    }
    
    /// 如果用户没有安装IPCC 弹出提示
    private func showNotInstalledIPCCAlert() {
        if !AppCapability.hasCommCenterSPI() { // 不管无权限的设备，反正也不能设置网络类型
            return
        }
        
        if IPCCManagerController.getInstalledCarrierBundles().isEmpty { // 判断是否安装了IPCC
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("NotInstalledIPCCAlertMessage", comment: ""),
                preferredStyle: .alert
            )
            
            // 继续 按钮
            let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive)
            
            // 关闭 按钮
            let exitAction = UIAlertAction(title: NSLocalizedString("Exit", comment: ""), style: .cancel) { _ in
                self.finish() // 关闭当前界面
            }

            // 添加按钮，iOS 会自动按照规范排列
            alert.addAction(continueAction)
            alert.addAction(exitAction)

            // 显示弹窗
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func onClickSetNetworkModeCell(item: InfoItem) {
        if SettingsUtils.instance.getShowSetLockNetworkModeAlert() {
            // 强行不让View可以点击
            self.view.isUserInteractionEnabled = false
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: nil,
                preferredStyle: .alert
            )
            
            if item.id == ActionItemID.selectNetworkModeUnknown { // 未知网络类型
                alert.message = NSLocalizedString("SetNetworkUnknownTypeMessage", comment: "") + String.localizedStringWithFormat(NSLocalizedString("SetNetworkTypeMessage", comment: ""), slotID, item.text)
            } else {
                if item.text.contains("2G") || item.text.contains("3G") { // 2G或者3G网络分组
                    alert.message = NSLocalizedString("SetNetwork2G3GMessage", comment: "") + String.localizedStringWithFormat(NSLocalizedString("SetNetworkTypeMessage", comment: ""), slotID, item.text)
                } else { // 4G或者5G的分组
                    /* 确定将卡%1$d的网络类型设定为%2$@? */
                    alert.message = String.localizedStringWithFormat(NSLocalizedString("SetNetworkTypeMessage", comment: ""), slotID, item.text)
                }
            }
            
            // 继续 按钮
            let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
                // 恢复View点击
                self.view.isUserInteractionEnabled = true
                // 设定网络类型
                self.setNetworkMode(item: item)
            }
            
            // 关闭 按钮
            let closeAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel) { _ in
                // 恢复View点击
                self.view.isUserInteractionEnabled = true
            }

            // 添加按钮，iOS 会自动按照规范排列
            if SettingsUtils.instance.getAllowSetNotShowLockNetworkModeAlert() {
                // 不再提示 按钮
                let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .default) { _ in
                    // 设置不再显示提示
                    SettingsUtils.instance.setNotShowLockNetworkModeAlert()
                    // 恢复View点击
                    self.view.isUserInteractionEnabled = true
                }
                alert.addAction(disableAlertAction)
            }
            alert.addAction(continueAction)
            alert.addAction(closeAction)

            // 显示弹窗
            self.present(alert, animated: true, completion: nil)
        } else {
            // 设定网络类型
            self.setNetworkMode(item: item)
        }
    }
    
    /// 设定网络类型
    private func setNetworkMode(item: InfoItem) {
        do {
            if let networkMode = item.detailText {
                if try cellularDataController.setSlotNetworkMode(slotID: slotID, selection: networkMode, preferred: networkMode) {
                    sendMessage(message: NSLocalizedString("AlreadySelected", comment: ""))
                } else {
                    sendMessage(message: NSLocalizedString("SettingFailed", comment: ""))
                }
            }
        } catch let error as NSError{
            UIUtils.showAlert(message: error.localizedDescription, in: self)
        }
        // 刷新数据
        reloadData()
    }
    
    /// 使用AppBadge展示消息
    private func sendMessage(message: String) {
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            return
        }
        
        // 播放动画
        tab.badgeShowMessage(message: message, stay: 0.5) {
            // 允许再次点击
        }
    }
}
