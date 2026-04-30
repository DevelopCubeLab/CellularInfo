import Foundation
import UIKit

class CellularDataDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    /// 需要展示的数据类型
    let detailType: Int
    /// 卡槽ID
    let slotID: Int
    /// 给长按Cell复制文本的临时缓存变量
    private var currentCopyText: String?
    
    init(detailType: Int, slotID: Int) {
        self.detailType = detailType
        self.slotID = slotID
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var tableView = UITableView()
    
    /// 是否隐藏机密信息
    private var hideConfidential = false
    
    private var carrierBookmarks: [CarrierBookmark] = []
    private var APNList: [CellularAPN] = []
    private var underlyingDataGroups: [InfoItemGroup] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("CFBundleDisplayName", comment: "")
        
        if SettingsUtils.instance.getShowCellularDataInGroups() { // 分组显示数据时，顶栏会被CellularDataViewController改变，因此需要还原
            // 设置顶部标题栏的效果
            if #available(iOS 15.0, *) {
                let standardAppearance = UINavigationBarAppearance()
                standardAppearance.configureWithOpaqueBackground()
                standardAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)

                let scrollEdgeAppearance = UINavigationBarAppearance()
                scrollEdgeAppearance.configureWithTransparentBackground()
                scrollEdgeAppearance.shadowColor = .clear

                navigationController?.navigationBar.standardAppearance = standardAppearance
                navigationController?.navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
            }
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
        tableView.register(SecurityTextCell.self, forCellReuseIdentifier: "SecurityTextCell")

        // 将表格视图添加到主视图
        view.addSubview(tableView)

        // 设置表格视图的布局
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 加载数据
        loadData()
        
        if detailType == ActionItemID.underlyingData { // 只有原始数据才需要监听数据更改
            // 注册监听器 当CoreTelephony数据刷新时更新数据
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(onCellularDataRefresh),
                name: CellularDataController.cellularDataRefreshNotificationName,
                object: nil
            )
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 刷新数据
        loadData()
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 当CoreTelephony通知刷新数据或app从后台返回前台时刷新数据
    @objc func onCellularDataRefresh() {
        loadData()
    }
    
    // 点击刷新数据
    @objc private func onClickRefreshData(_ sender: UIBarButtonItem) {
        // 禁用按钮
        sender.isEnabled = false
        // 刷新数据
        loadData()
        
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
    
    /// 加载数据
    private func loadData() {
        switch detailType {
        case ActionItemID.carrierBookmark: // 获取运营商书签
            navigationItem.title = NSLocalizedString("CarrierBookmarks", comment: "")
            CellularDataController.instance.fetchSlotCarrierBookmarks(slotID: slotID) { bookmarks, error in
                
                if let error = error {
                    DispatchQueue.main.async {
                        UIUtils.showAlert(message: error.localizedDescription, in: self)
                    }
                    return
                }
                
                guard let bookmarks = bookmarks else {
                    DispatchQueue.main.async {
                        self.finish()
                    }
                    return
                }
                // 保存数据
                self.carrierBookmarks = bookmarks
                
                DispatchQueue.main.async { // 刷新列表
                    self.tableView.reloadData()
                }
            }
        case ActionItemID.APNConfig: // APN
            navigationItem.title = NSLocalizedString("APNSettings", comment: "")
            do {
                APNList = try CellularDataController.instance.getSlotAPNConfigList(slotID: slotID)
                DispatchQueue.main.async { // 刷新列表
                    self.tableView.reloadData()
                }
            } catch let error as NSError {
                UIUtils.showAlert(message: error.localizedDescription, in: self)
            }
        case ActionItemID.underlyingData: // 原始数据
            navigationItem.title = NSLocalizedString("UnderlyingData", comment: "")
            if slotID == CellularDataItemGroupID.deviceCellularInfo {
                underlyingDataGroups = [CellularDataController.instance.getDeviceBaseCellularUnderlyingInfoGroup()]
            } else if slotID == CellularDataItemGroupID.slot1BaseInfo || slotID == CellularDataItemGroupID.slot2BaseInfo {
                underlyingDataGroups = CellularDataController.instance.getSlotUnderlyingInfoGroup(slotID: slotID).map { [$0] } ?? []
            } else { // 处理异常请求
                finish()
            }
            // 为无权限设备准备的 过滤无权限item
            underlyingDataGroups = UIUtils.filterNoPermissionGroups(underlyingDataGroups)
            DispatchQueue.main.async { // 刷新列表
                self.tableView.reloadData()
            }
        default:
            // 参数无效 退出当前的界面
            finish()
        }
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
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        switch detailType {
        case ActionItemID.carrierBookmark: return 1
        case ActionItemID.APNConfig: return APNList.count
        case ActionItemID.underlyingData: return underlyingDataGroups.count
        default: return 0
        }
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch detailType {
        case ActionItemID.carrierBookmark: return max(carrierBookmarks.count, 1) // 如果有书签就显示书签，没有书签就显示一行 无
        case ActionItemID.APNConfig: return 13
        case ActionItemID.underlyingData: return underlyingDataGroups[section].items.count
        default: return 0
        }
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if detailType ==  ActionItemID.APNConfig {
            return APNList[section].apn
        } else if detailType == ActionItemID.underlyingData {
            return underlyingDataGroups[section].titleText
        }
        return nil
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if detailType == ActionItemID.underlyingData {
            return underlyingDataGroups[section].footerText
        } else if detailType == ActionItemID.carrierBookmark {
            if !carrierBookmarks.isEmpty { // 显示运营商书签的提示文本
                return NSLocalizedString("CarrierBookmarksHint", comment: "")
            }
        }
        return nil
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        switch detailType {
        case ActionItemID.carrierBookmark:
            if carrierBookmarks.isEmpty { // 处理没有运营商书签的情况
                cell.textLabel?.text = NSLocalizedString("NoCarrierBookmarks", comment: "")
                if #available(iOS 13.0, *) {
                    cell.textLabel?.textColor = .secondaryLabel
                } else {
                    cell.textLabel?.textColor = .darkGray
                }
                cell.selectionStyle = .none
            } else { // 运营商书签
                cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
                cell.textLabel?.text = carrierBookmarks[indexPath.row].title
                cell.textLabel?.textColor = UIColor.systemBlue
                if #available(iOS 13.0, *) {
                    cell.detailTextLabel?.textColor = .secondaryLabel
                } else {
                    cell.detailTextLabel?.textColor = .darkGray
                }
                cell.detailTextLabel?.text = carrierBookmarks[indexPath.row].URL
                cell.accessoryType = .disclosureIndicator // 右侧增加 >
            }
        case ActionItemID.APNConfig:
            let apn = APNList[indexPath.section]
            
            let title: String
            let value: String
            
            switch indexPath.row {
            case 0:
                title = NSLocalizedString("APNType", comment: "")
                value = CellularAPN.getTypeMaskText(mask: apn.typeMask)
            case 1:
                title = NSLocalizedString("APN", comment: "")
                value = apn.apn ?? "-"
            case 2:
                title = NSLocalizedString("Username", comment: "")
                value = apn.username ?? NSLocalizedString("Unknown", comment: "未知")
            case 3:
                title = NSLocalizedString("Password", comment: "")
                value = apn.password ?? NSLocalizedString("Unknown", comment: "未知")
            case 4:
                title = NSLocalizedString("APNAllowRadioTechnology", comment: "")
                value = CellularAPN.getTechnologyText(mask: apn.technologyMask)
            case 5:
                title = NSLocalizedString("APNAllowedProtocol", comment: "")
                value = CellularAPN.getProtocolText(mask: apn.allowedProtocolMask)
            case 6:
                title = NSLocalizedString("APNRoamingProtocol", comment: "")
                value = CellularAPN.getProtocolText(mask: apn.roamingProtocolMask)
            case 7:
                title = NSLocalizedString("AlwaysOn", comment: "")
                value = apn.alwaysOn == 1 ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            case 8:
                title = NSLocalizedString("APNInactivityTimer", comment: "")
                if let timer = apn.inactivityTimer {
                    value = timer == 0 ? NSLocalizedString("NoLimit", comment: "") : String.localizedStringWithFormat(NSLocalizedString("TimeSeconds", comment: ""), timer)
                } else {
                    value = NSLocalizedString("Unknown", comment: "未知")
                }
            case 9:
                title = NSLocalizedString("UseNetworkMTU", comment: "")
                value = apn.useNetworkMTU == 1 ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            case 10:
                title = NSLocalizedString("IPv6Compatibility", comment: "")
                value = apn.xlat464 == 1 ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            case 11:
                title = NSLocalizedString("APNSupport5GSaHandover", comment: "")
                value = apn.support5GSaHandover == 1 ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            case 12:
                title = NSLocalizedString("APNSupportSwitchNetworkType", comment: "")
                value = apn.supportSwitchOver == 1 ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            default:
                title = "-"
                value = "-"
            }
            
            cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = value
            cell.selectionStyle = .none
        case ActionItemID.underlyingData:
            // 获取数据
            let item = underlyingDataGroups[indexPath.section].items[indexPath.row]
            // 强制保护机要信息
            if item.isConfidential {
                cell = tableView.dequeueReusableCell(withIdentifier: "SecurityTextCell", for: indexPath) as! SecurityTextCell
            }
            cell.selectionStyle = .none // 取消点击特效
            // 设置ID
            cell.tag = item.id
            // 设置文本并且判断是否需要隐藏机要信息
            if hideConfidential && item.isConfidential {
                cell.textLabel?.text = UIUtils.maskConfidential(item.text)
            } else {
                cell.textLabel?.text = item.text
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
            cell.textLabel?.numberOfLines = 0 // 允许换行
        default: break
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch detailType {
        case ActionItemID.carrierBookmark:
            if !carrierBookmarks.isEmpty {
                UIUtils.showAlertToUseDefaultBrowserOpenLink(URL: carrierBookmarks[indexPath.row].URL, in: self)
            }
        case ActionItemID.APNConfig:
            break
        case ActionItemID.underlyingData:
            break
        default: break
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
        if detailType == ActionItemID.underlyingData {
            self.currentCopyText = underlyingDataGroups[indexPath.section].items[indexPath.row].detailText
        } else {
            return
        }
        
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

