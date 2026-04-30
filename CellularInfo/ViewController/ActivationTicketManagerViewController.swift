import Foundation
import UIKit

class ActivationTicketManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private var activationTicketGroup: [InfoItemGroup] = []
    // 是否获取到数据的标记
    private var haveTicketData = false
    private var activationTicketText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("BasebandActivationTicketManager", comment: "")
        
        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }
        
        // 设置表格视图的代理和数据源
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        
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
        
        reloadData()
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        tableView.reloadData()
    }
    
    private func reloadData() {
        // 获取基本数据
        activationTicketGroup = CellularDataController.instance.getActivationTicketInfoGroup()
        // 获取ticket
        do {
            activationTicketText = try BaseBandServiceController.getBaseBandActivationTicket()
            haveTicketData = true // 设置已经获取到数据
        } catch let error as NSError {
            let errorMessage: String
            if error.code == -1 { // 未找到RootHelper
                if #available(iOS 14.0, *) { // 高版本提示RootHelper丢失
                    errorMessage = NSLocalizedString("RootHelperMissingMessage", comment: "")
                } else { // 低版本提示用户安装RootHelper
                    errorMessage = NSLocalizedString("InstallRootHelperMessage", comment: "")
                }
            } else if error.code == 1 { // 无权限
                errorMessage = NSLocalizedString("NoPermission", comment: "")
            } else if error.code == 13 { // RootHelper无权限 一般出现在iOS 17.0以上版本 直接用Filza安装的情况
                errorMessage = NSLocalizedString("RootHelperNoPermission", comment: "")
            } else { // 其他错误
                errorMessage = String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code , error.localizedDescription)
            }
            // 弹窗提示用户
            UIUtils.showAlert(message: errorMessage, in: self)
            // 错误提示放到Cell里
            activationTicketText = errorMessage
            
        }
        tableView.reloadData()
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return activationTicketGroup.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activationTicketGroup[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return activationTicketGroup[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return activationTicketGroup[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        // 获取数据
        let item = activationTicketGroup[indexPath.section].items[indexPath.row]
        // 设置文本
        cell.textLabel?.text = item.text
        cell.textLabel?.numberOfLines = 0 // 允许换行
        cell.selectionStyle = .none // 取消点击特效
        
        if item.id == CoreTelephonyItemID.activationTicket {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SecurityTextCell", for: indexPath) as! SecurityTextCell
            cell.setText(activationTicketText)
            cell.selectionStyle = .none // 取消点击特效
            return cell
        } else if item.id == ActionItemID.copy || item.id == ActionItemID.paste {
            cell.textLabel?.text = item.text
            cell.textLabel?.textColor = haveTicketData ? .systemBlue : .systemGray // 获取到数据时设置成蓝色 没有获取到数据时为灰色
            cell.selectionStyle = haveTicketData ? .default : .none // 设置点击效果
        } else if item.id == ActionItemID.save {
            cell.textLabel?.text = item.text
            cell.textLabel?.textColor = haveTicketData ? .systemRed : .systemGray // 获取到数据时设置成红色 没有获取到数据时为灰色
            cell.selectionStyle = haveTicketData ? .default : .none // 设置点击效果
        } else {
            cell.textLabel?.text = item.text
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if haveTicketData {
            // 获取数据
            let item = activationTicketGroup[indexPath.section].items[indexPath.row]
            
            if item.id == ActionItemID.copy { // 复制基带激活信息
                self.copyActivationTicket()
            } else if item.id == ActionItemID.paste { // 从剪贴板粘贴
                self.pasteActivationTicket()
            } else if item.id == ActionItemID.save { // 保存用户的基带激活信息
                self.saveActivationTicket()
            }
        }
        
    }
    
    /// 复制基带激活信息
    private func copyActivationTicket() {
        UIPasteboard.general.string = activationTicketText
        
        if SettingsUtils.instance.getShowCopyActivationTicketTips() {
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("CopyActivationTicketMessage", comment: ""),
                preferredStyle: .alert
            )

            // 不再提示 按钮 红色
            let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .destructive) { _ in
                // 设置不再显示提示
                SettingsUtils.instance.setShowCopyActivationTicketTipsTips(enable: false)
            }

            // 关闭 按钮 蓝色
            let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

            // 添加按钮，iOS 会自动按照规范排列
            alert.addAction(cancelAction)
            alert.addAction(disableAlertAction)
            
            // 显示弹窗
            self.present(alert, animated: true, completion: nil)
        } else {
            sendMessage(message: NSLocalizedString("Copied", comment: ""))
        }
    }
    
    /// 粘贴基带激活信息
    private func pasteActivationTicket() {
        // 从剪贴板读取纯文本
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.sendMessage(message: NSLocalizedString("PasteboardEmpty", comment: ""))
            return
        }

        // 校验是否为合法 ticket
        if !BaseBandServiceController.isLikelyActivationTicket(text) {
            UIUtils.showAlert(message: NSLocalizedString("PasteActivationTicketIncorrectMessage", comment: ""), in: self)
            return
        }
        // 保存数据
        self.activationTicketText = text
        // 刷新UI
        tableView.reloadData()

        // 已粘贴
        self.sendMessage(message: NSLocalizedString("Pasted", comment: ""))
    }
    
    /// 保存基带激活信息
    private func saveActivationTicket() {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("SaveActivationTicketConfirmMessage", comment: ""),
            preferredStyle: .alert
        )

        // 保存 按钮 红色
        let rebootNowAction = UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .destructive) { _ in
            if self.haveTicketData && !self.activationTicketText.isEmpty { // 确保信息正确
                do {
                    let result = try BaseBandServiceController.setBaseBandActivationTicket(ticket: self.activationTicketText)
                    if result { // 保存成功 提示重启
                        self.requireRebootAlert()
                    } else { // 保存失败
                        UIUtils.showAlert(message: NSLocalizedString("SaveActivationTicketFailedMessage", comment: ""), in: self)
                    }
                } catch let error as NSError {
                    if error.code == 1 { // 无权限
                        UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, NSLocalizedString("NoPermission", comment: "")), in: self)
                    } else { // 其他错误
                        UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code , error.localizedDescription), in: self)
                    }
                }
            }
        }

        // 关闭 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(cancelAction)
        alert.addAction(rebootNowAction)
        
        // 显示弹窗
        self.present(alert, animated: true, completion: nil)
    }
    
    /// 保存基带激活信息后询问用户是否重启
    private func requireRebootAlert() {
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("SaveActivationTicketSuccessfulMessage", comment: ""),
            preferredStyle: .alert
        )

        // 立即重启 按钮 红色
        let rebootNowAction = UIAlertAction(title: NSLocalizedString("RebootNow", comment: ""), style: .destructive) { _ in
            // 重启设备
            do {
                try BaseBandServiceController.rebootDevice()
            } catch let error as NSError { // 出现错误的话抛异常 一般也到不了这一步，前面的UI检查就已经拦住了用户操作了
                UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code , error.localizedDescription), in: self)
            }
        }

        // 关闭 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(cancelAction)
        alert.addAction(rebootNowAction)
        
        // 显示弹窗
        self.present(alert, animated: true, completion: nil)
    }
    
    /// 使用AppBadge展示消息
    private func sendMessage(message: String) {
        // 寻找AppBadge
        guard let tab = self.tabBarController as? MainUITabBarController else {
            return
        }
        
        // 播放动画
        tab.badgeShowMessage(message: message, stay: 1.5) {
            // 允许再次点击
        }
    }
}
