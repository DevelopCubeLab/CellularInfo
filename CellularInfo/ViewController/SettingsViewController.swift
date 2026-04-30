import Foundation
import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    static let versionCode = "1.0"
    
    private var tableView = UITableView()
    private let tableCellList = [
        InfoItemGroup(id: SettingsGroupID.languageSettings, items: [
            InfoItem(id: SettingsItemID.languageSettings, text: NSLocalizedString("LanguageSettings", comment: "")),
            InfoItem(id: SettingsItemID.appIconSettings, text: NSLocalizedString("AppIconSettings", comment: ""))
        ]),
        InfoItemGroup(id: SettingsGroupID.generalSettings, items: [
            InfoItem(id: SettingsItemID.autoRefreshData, text: NSLocalizedString("AutoRefreshData", comment: "")),
            InfoItem(id: SettingsItemID.screenshotCaptureAlert, text: NSLocalizedString("ShowAlertWhenScreenCaptured", comment: "")),
            InfoItem(id: SettingsItemID.experimentalFeatures, text: NSLocalizedString("ExperimentalFeatures", comment: "")),
            InfoItem(id: SettingsItemID.resetAllWarnings, text: NSLocalizedString("ResetAllWarnings", comment: ""))
        ]),
        InfoItemGroup(id: SettingsGroupID.displaySettings, titleText: NSLocalizedString("Display", comment: ""), items: [
            InfoItem(id: SettingsItemID.showCellularDataInGroups, text: NSLocalizedString("ShowCellularDataInGroups", comment: "")),
            InfoItem(id: SettingsItemID.showInactiveSIMSlotsData, text: NSLocalizedString("ShowInactiveSIMSlotsData", comment: "")),
            InfoItem(id: SettingsItemID.forceShowLTEAs4G, text: NSLocalizedString("ShowLTEAs4G", comment: ""))
        ]),
        InfoItemGroup(id: SettingsGroupID.aboutApplication, titleText: NSLocalizedString("About", comment: ""), items: [
            InfoItem(id: SettingsItemID.versionCode, text: NSLocalizedString("Version", comment: "")),
            InfoItem(id: SettingsItemID.reference, text: NSLocalizedString("ReferenceAndAcknowledgements", comment: "")),
            InfoItem(id: SettingsItemID.githubLink, text: "GitHub")
        ]),
        InfoItemGroup(id: SettingsGroupID.recommend, titleText: NSLocalizedString("Recommend", comment: ""), items: [
            InfoItem(id: SettingsItemID.trollSIMSwitcher, text: NSLocalizedString("TrollSIMSwitcherApp", comment: "")),
        ])
    ]
    
    private var allowClickVersionCode = true
    private var versionTapCount = 0
    private static var pendingScrollOffset: CGPoint?
    private var didRestoreScroll = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("Settings", comment: "")
        
        // 为无权限用户提供一个开关，隐藏无权限的item
        if !AppCapability.hasCommCenterSPI() {
            tableCellList[2].addItem(InfoItem(id: SettingsItemID.hideNoPermissionData, text: NSLocalizedString("HideNoPermissionData", comment: "")), afterID: SettingsItemID.showInactiveSIMSlotsData)
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
        updateSettingItems()
        // 刷新开关状态，解决状态不一致的问题
        tableView.reloadData()
        // 清零点击次数，防止卡bug
        versionTapCount = 0
    }
    
    // 动态更新设置列表
    private func updateSettingItems() {
        if SettingsUtils.instance.getEnableExperimentalFeatures() {
            if SettingsUtils.instance.getAutoRefreshData() {
                tableCellList[1].addItem(InfoItem(id: SettingsItemID.timedRefreshData, text: NSLocalizedString("TimedRefreshData", comment: "")), afterID: SettingsItemID.autoRefreshData)
            } else {
                tableCellList[1].removeItems(withID: SettingsItemID.timedRefreshData)
            }
            tableCellList[1].addItem(InfoItem(id: SettingsItemID.checkCarrierBundleCompatibility, text: NSLocalizedString("CheckCarrierBundleCompatibilityBeforeInstall", comment: "")), afterID: SettingsItemID.experimentalFeatures)
        } else {
            tableCellList[1].removeItems(withID: SettingsItemID.timedRefreshData)
            tableCellList[1].removeItems(withID: SettingsItemID.checkCarrierBundleCompatibility)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !didRestoreScroll else { return }

        // 如果有待恢复的滚动位置，等本次界面布局完成后再恢复
        // 主要解决切换首页是否分组，但是App重建View了
        // 只有屏幕小的机器或者横屏并且滚动到了列表下面再去执行这个操作，做细做全套 效果才好
        if let pendingOffset = SettingsViewController.pendingScrollOffset {
            tableView.setContentOffset(pendingOffset, animated: false)
            SettingsViewController.pendingScrollOffset = nil
            didRestoreScroll = true
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
        var cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
        cell.textLabel?.numberOfLines = 0 // 允许换行
        // 获取分组ID
        let groupID = tableCellList[indexPath.section].id
        
        if groupID == SettingsGroupID.languageSettings {
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default // 启用选中效果
        } else if groupID == SettingsGroupID.generalSettings || groupID == SettingsGroupID.displaySettings {
            // 获取item ID
            let itemID = tableCellList[indexPath.section].items[indexPath.row].id
            cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
            if itemID == SettingsItemID.resetAllWarnings {
                cell.textLabel?.textColor = .systemRed // 文本颜色为红色
                cell.textLabel?.textAlignment = .center // 文本在中间
            } else {
                // 创建一个Switch开关
                let switchView = UISwitch(frame: .zero)
                // 设置tag
                switchView.tag = itemID
                // 设置开关状态
                switch itemID {
                case SettingsItemID.autoRefreshData: switchView.isOn = SettingsUtils.instance.getAutoRefreshData()
                case SettingsItemID.timedRefreshData: switchView.isOn = SettingsUtils.instance.getTimedRefreshData()
                case SettingsItemID.screenshotCaptureAlert: switchView.isOn = SettingsUtils.instance.getShowScreenshotCaptureAlert()
                case SettingsItemID.experimentalFeatures: switchView.isOn = SettingsUtils.instance.getEnableExperimentalFeatures()
                case SettingsItemID.checkCarrierBundleCompatibility: switchView.isOn = SettingsUtils.instance.getEnableCheckCarrierBundleCompatibility()
                case SettingsItemID.showCellularDataInGroups: switchView.isOn = SettingsUtils.instance.getShowCellularDataInGroups()
                case SettingsItemID.showInactiveSIMSlotsData: switchView.isOn = SettingsUtils.instance.getShowInactiveSIMSlotsData()
                case SettingsItemID.hideNoPermissionData: switchView.isOn = SettingsUtils.instance.getHideNoPermissionData()
                case SettingsItemID.forceShowLTEAs4G: switchView.isOn = SettingsUtils.instance.getForceShowLTEAs4G()
                default: break
                }
                switchView.addTarget(self, action: #selector(self.onSwitchChanged(_:)), for: .valueChanged) // 设置点击事件
                cell.accessoryView = switchView
                cell.selectionStyle = .none
            }
        } else if groupID == SettingsGroupID.aboutApplication { // 关于
            if tableCellList[indexPath.section].items[indexPath.row].id == SettingsItemID.versionCode { // 版本号
                cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
                cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? NSLocalizedString("Unknown", comment: "未知")
                if version != SettingsViewController.versionCode { // 判断版本号是不是有人篡改
                    cell.detailTextLabel?.text = SettingsViewController.versionCode
                } else {
                    cell.detailTextLabel?.text = version
                }
                cell.selectionStyle = .none
                cell.accessoryType = .none
            } else {
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default // 启用选中效果
            }
        } else if groupID == SettingsGroupID.recommend {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
            // 图标
            let icon = UIImage(named: "TrollSIMSwitcherIcon")
            // 圆角
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
            let rounded = renderer.image { _ in
                UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 40, height: 40), cornerRadius: 8).addClip()
                icon?.draw(in: CGRect(x: 0, y: 0, width: 40, height: 40))
            }
            cell.imageView?.image = rounded
            cell.textLabel?.text = NSLocalizedString("TrollSIMSwitcherApp", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("QuickSwitchApp", comment: "")
            cell.imageView?.contentMode = .scaleAspectFill
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default // 启用选中效果
        }
        
        return cell
        
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 取消选择cell动画
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch tableCellList[indexPath.section].items[indexPath.row].id {
        case SettingsItemID.languageSettings:
            self.navigationController!.pushViewController(LanguageSettingsViewController(), animated: true)
        case SettingsItemID.appIconSettings:
            self.navigationController!.pushViewController(AppIconSettingsViewController(), animated: true)
        case SettingsItemID.resetAllWarnings:
            self.onClickResetAllWarningButton()
        case SettingsItemID.versionCode:
            if allowClickVersionCode {
                versionTapCount += 1
                if versionTapCount >= 7 {
                    versionTapCount = 0
                    if let tab = self.tabBarController as? MainUITabBarController {
                        self.allowClickVersionCode = false
                        tab.startAppBadgeAnimation { // 闭包
                            self.allowClickVersionCode = true
                            // 设定是否开启显示网络类型
                            SettingsUtils.instance.setShowLockNetworkMode(status: true)
                        }
                    }
                    
                }
            }
        case SettingsItemID.githubLink:
            UIUtils.showAlertToUseDefaultBrowserOpenLink(URL: "https://github.com/DevelopCubeLab/CellularInfo", in: self)
        case SettingsItemID.reference:
            self.navigationController!.pushViewController(ReferenceAndAcknowledgementsViewController(), animated: true)
            
        case SettingsItemID.trollSIMSwitcher:
            self.onClickDownloadTrollSIMSwitcherButton()
            
        default: break
        }
        
    }
    
    /// 当开关更改的时候的方法
    @objc func onSwitchChanged(_ sender: UISwitch) {
        if sender.tag == SettingsItemID.autoRefreshData {
            SettingsUtils.instance.setAutoRefreshData(enable: sender.isOn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 延迟0.1秒先让动画放完再刷新
                self.updateSettingItems()
                self.tableView.reloadData()
            }
        } else if sender.tag == SettingsItemID.timedRefreshData {
            SettingsUtils.instance.setTimedRefreshData(enable: sender.isOn)
        } else if sender.tag == SettingsItemID.screenshotCaptureAlert {
            SettingsUtils.instance.setShowScreenshotCaptureAlert(enable: sender.isOn)
        } else if sender.tag == SettingsItemID.experimentalFeatures {
            SettingsUtils.instance.setEnableExperimentalFeatures(enable: sender.isOn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 延迟0.1秒先让动画放完再刷新
                self.updateSettingItems()
                self.tableView.reloadData()
            }
        } else if sender.tag == SettingsItemID.checkCarrierBundleCompatibility {
            SettingsUtils.instance.setEnableCheckCarrierBundleCompatibility(enable: sender.isOn)
        } else if sender.tag == SettingsItemID.showCellularDataInGroups {
            SettingsUtils.instance.setShowCellularDataInGroups(enable: sender.isOn)
            reloadAppView() // 重建App界面
        } else if sender.tag == SettingsItemID.showInactiveSIMSlotsData {
            SettingsUtils.instance.setShowInactiveSIMSlotsData(enable: sender.isOn)
        }  else if sender.tag == SettingsItemID.hideNoPermissionData {
            SettingsUtils.instance.setHideNoPermissionData(enable: sender.isOn)
        } else if sender.tag == SettingsItemID.forceShowLTEAs4G {
            SettingsUtils.instance.setForceShowLTEAs4G(enable: sender.isOn)
        }
    }
    
    /// 重建App界面并且切换到当前的tab
    private func reloadAppView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { // 延迟0.25s 让UISwitch动画放完再去重建App View
            guard let window = UIApplication.shared.windows.first else {
                return
            }

            // 拿到UITableView的滚动位置
            let tableViewScrollPosition = self.tableView.contentOffset
            // 先保存滚动位置，等新的 SettingsViewController 创建完成后恢复
            if tableViewScrollPosition.y > 0 {
                SettingsViewController.pendingScrollOffset = tableViewScrollPosition
            } else {
                SettingsViewController.pendingScrollOffset = nil
            }

            // 重建MainUITabBarController
            let tabBarController = MainUITabBarController()
            window.rootViewController = tabBarController
            window.makeKeyAndVisible()
            // 切换到设置的tab
            tabBarController.selectedIndex = 3
        }
        
    }
    
    /// 点击重设全部警告按钮的回调
    private func onClickResetAllWarningButton() {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("ResetAllWarningMessage", comment: ""),
            preferredStyle: .alert
        )

        // 确定按钮 蓝色
        let confirmAction = UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .destructive) { _ in
            SettingsUtils.instance.resetAllWarning()
            self.sendMessage(message: NSLocalizedString("ResetCompleted", comment: ""))
        }

        // 关闭按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)

        // 显示弹窗
        present(alert, animated: true, completion: nil)
    }
    
    /// 点击下载Troll SIM Switcher的按钮
    private func onClickDownloadTrollSIMSwitcherButton() {
        
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("DownloadTrollSIMSwitcherMessage", comment: ""),
            preferredStyle: .alert
        )

        // 去GitHub下载按钮 蓝色
        let gitHubAction = UIAlertAction(title: "GitHub", style: .default) { _ in
            if let url = URL(string: "https://github.com/DevelopCubeLab/TrollSIMSwitcher/releases") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        // 去Havoc下载按钮 蓝色
        let havocAction = UIAlertAction(title: "Havoc", style: .default) { _ in
            if let url = URL(string: "https://havoc.app/package/trollsimswitch") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        // 关闭 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(gitHubAction)
        alert.addAction(havocAction)
        alert.addAction(cancelAction)

        // 显示弹窗
        present(alert, animated: true, completion: nil)
        
        
    }
    
    /// 使用AppBadge展示消息
    private func sendMessage(message: String) {
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            return
        }
        allowClickVersionCode = false
        // 播放动画
        tab.badgeShowMessage(message: message, stay: 1.0) {
            // 允许再次点击
            self.allowClickVersionCode = true
        }
    }
}
