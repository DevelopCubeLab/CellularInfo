import Foundation
import UIKit

class ToolsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private let NetworkToolsAt = 3
    
    private var tableCellList = [
        InfoItemGroup(id: 0, items: [
            InfoItem(id: ActionItemID.IPCCManager, text: NSLocalizedString("IPCCManager", comment: "")),
            InfoItem(id: ActionItemID.IPCCCompatibilityCheck, text: NSLocalizedString("IPCCCompatibilityCheck", comment: "")),
        ]),
        InfoItemGroup(id: 1, items: [
            InfoItem(id: ActionItemID.activationTicketManager, text: NSLocalizedString("BasebandActivationTicketManager", comment: "")),
        ]),
        InfoItemGroup(id: CellularDataItemGroupID.maintenance, titleText: NSLocalizedString("Maintenance", comment: ""), items: [
            InfoItem(id: ActionItemID.refreshCellularConnection, text: NSLocalizedString("RefreshCellularConnection", comment: "")),
            InfoItem(id: ActionItemID.rebootCommCenterService, text: NSLocalizedString("RebootCommCenterService", comment: "")),
        ]),
        InfoItemGroup(id: CellularDataItemGroupID.NetworkTools, items: [
        ])
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Tools", comment: "")
        
#if DEBUG
        tableCellList[NetworkToolsAt].addItemIfNotExists(InfoItem(id: ActionItemID.SettingNetworkMode, text: NSLocalizedString("LockNetworkMode", comment: "")))
        if #available(iOS 14.0, *) {
            tableCellList[NetworkToolsAt].addItemIfNotExists(InfoItem(id: ActionItemID.SettingNetworkBand, text: NSLocalizedString("ConfigureNetworkBands", comment: "")))
        }
#endif
        
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
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
        
        /// 判断是否显示设置网络类型
        if SettingsUtils.instance.getShowLockNetworkMode() {
            tableCellList[NetworkToolsAt].addItemIfNotExists(InfoItem(id: ActionItemID.SettingNetworkMode, text: NSLocalizedString("LockNetworkMode", comment: "")))
            tableView.reloadData()
        } else {
#if !DEBUG
            // 删除该分组
            tableCellList[NetworkToolsAt].removeItems(withID: ActionItemID.SettingNetworkMode)
            tableView.reloadData()
#endif
        }
        
        /// 判断是否显示设置网络频段
        if #available(iOS 14.0, *) {
            if SettingsUtils.instance.getShowConfigureNetworkBands() {
                tableCellList[NetworkToolsAt].addItemIfNotExists(InfoItem(id: ActionItemID.SettingNetworkBand, text: NSLocalizedString("ConfigureNetworkBands", comment: "")))
                tableView.reloadData()
            } else {
#if !DEBUG
                // 删除该分组
                tableCellList[NetworkToolsAt].removeItems(withID: ActionItemID.SettingNetworkBand)
                tableView.reloadData()
#endif
            }
        }
        
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableCellList.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableCellList[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableCellList[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return tableCellList[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
        
        if tableCellList[indexPath.section].id == CellularDataItemGroupID.maintenance {
            cell.textLabel?.textColor = .systemBlue // 设置成蓝色
        } else {
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default // 启用选中效果
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
#if !targetEnvironment(simulator)
        if !CellularDataController.instance.deviceSupportsCellular {
            UIUtils.showAlert(message: NSLocalizedString("DeviceNotSupportedCellular", comment: ""), in: self)
            return
        }
#endif
        
        switch tableCellList[indexPath.section].items[indexPath.row].id {
        case ActionItemID.IPCCManager: // IPCC管理
            self.navigationController!.pushViewController(IPCCManagerViewController(), animated: true)
        case ActionItemID.IPCCCompatibilityCheck: // IPCC兼容性检测
            self.navigationController!.pushViewController(IPCCCompatibilityCheckViewController(), animated: true)
        case ActionItemID.activationTicketManager: // 基带激活信息管理
            self.navigationController!.pushViewController(ActivationTicketManagerViewController(), animated: true)
        case ActionItemID.refreshCellularConnection: // 刷新蜂窝网络信号
            self.refreshCellularConnection()
        case ActionItemID.rebootCommCenterService: // 重启蜂窝网络服务
            self.rebootCommCenterService()
        case ActionItemID.SettingNetworkMode: // 设置网络模式
            let lockNetworkModeViewController = LockNetworkModeViewController()
            lockNetworkModeViewController.hidesBottomBarWhenPushed = true // 隐藏底部导航栏
            self.navigationController!.pushViewController(lockNetworkModeViewController, animated: true)
        case ActionItemID.SettingNetworkBand: // 设置网络频段
            if #available(iOS 14.0, *) {
                let configureNetworkBandsViewController = ConfigureNetworkBandsViewController()
                configureNetworkBandsViewController.hidesBottomBarWhenPushed = true // 隐藏底部导航栏
                self.navigationController!.pushViewController(configureNetworkBandsViewController, animated: true)
            }
        default: break
        }
        
    }
    
    /// 刷新蜂窝网络信号
    private func refreshCellularConnection() {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("RefreshCellularConnectionMessage", comment: ""),
            preferredStyle: .alert
        )
        
        // "确定" 按钮
        let confirmAction = UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .default) { _ in
            if AppCapability.hasCommCenterSPI() { // 该API不会抛异常 无权限只是被CommCenter丢弃请求 需要手动判断
                CoreTelephonyController.instance.refreshCellularConnection()
                self.sendMessage(message: NSLocalizedString("Refreshing", comment: ""), stay: 5)
            } else { // 无权限
                UIUtils.showAlert(message: NSLocalizedString("NoPermission", comment: ""), in: self)
            }
        }

        // "取消" 按钮
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)

        // 显示弹窗
        present(alert, animated: true, completion: nil)
        
    }
    
    /// 重启蜂窝网络服务 CommCenter
    private func rebootCommCenterService() {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("RebootCommCenterMessage", comment: ""),
            preferredStyle: .alert
        )

        // "确定" 按钮 红色
        let confirmAction = UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .destructive) { _ in
            do {
                let result = try BaseBandServiceController.restartCommCenterService()
                if result {
                    self.sendMessage(message: NSLocalizedString("RestartingServices", comment: ""), stay: 8)
                } else {
                    UIUtils.showAlert(message: NSLocalizedString("RestartingServicesFailed", comment: ""), in: self)
                }
            } catch let error as NSError {
                
                if error.code == -1 { // 未找到RootHelper
                    if #available(iOS 14.0, *) { // 高版本提示RootHelper丢失
                        UIUtils.showAlert(message: NSLocalizedString("RootHelperMissingMessage", comment: ""), in: self)
                    } else if error.code == 13 { // RootHelper无权限 一般出现在iOS 17.0以上版本 直接用Filza安装的情况
                        UIUtils.showAlert(message: NSLocalizedString("RootHelperNoPermission", comment: ""), in: self)
                    } else { // 低版本提示用户安装RootHelper
                        UIUtils.showAlert(message: NSLocalizedString("InstallRootHelperMessage", comment: ""), in: self)
                    }
                } else if error.code == 1 { // 无权限
                    UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, NSLocalizedString("NoPermission", comment: "")), in: self)
                } else { // 其他错误
                    UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code , error.localizedDescription), in: self)
                }
            }
        }

        // "取消" 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(confirmAction) // 红色
        alert.addAction(cancelAction) // 蓝色

        // 显示弹窗
        present(alert, animated: true, completion: nil)
    }
    
    /// 使用AppBadge展示消息
    private func sendMessage(message: String, stay: Float = 1.5) {
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            return
        }
        
        // 播放动画
        tab.badgeShowMessage(message: message, stay: stay) {
            // 允许再次点击
        }
    }
    
}

