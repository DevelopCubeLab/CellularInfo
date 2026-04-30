import Foundation
import UIKit

class CellularPlansViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIViewControllerPreviewingDelegate {
    
    private var tableView = UITableView()
    
    private lazy var cellularPlansStatus: CellularPlanStatus = {
        // 加载全部蜂窝数据卡的数据
        return CTCellularPlanController.instance.getCellularPlansStatus()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("CellularPlans", comment: "")
        
        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }
        
        // 注册3D Touch的监听器
        // 强行给老设备做个兼容，但是我忘记iOS哪个大版本开始彻底去掉了老款支持3D Touch设备的重按功能了
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: tableView)
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
        
        // 注册监听器 当CoreTelephony数据刷新时更新数据
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCellularDataRefresh),
            name: CellularDataController.cellularDataRefreshNotificationName,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 当CoreTelephony通知刷新数据或app从后台返回前台时刷新数据
    @objc func onCellularDataRefresh() {
        // 加载全部蜂窝数据卡
        cellularPlansStatus = CTCellularPlanController.instance.getCellularPlansStatus()
        // 刷新列表
        tableView.reloadData()
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellularPlansStatus.plans.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return String.localizedStringWithFormat(NSLocalizedString("CellularPlanCount", comment: ""), cellularPlansStatus.count)
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        
        let cellularPlan = cellularPlansStatus.plans[indexPath.row]
        if let carrierName = cellularPlan.carrierName { // 这里必须判断下CarrierName是否为nil 在iOS 14的机器上运行会闪退
            if UIDevice.current.userInterfaceIdiom == .pad { // iPad显示的label有问题，所以不显示
                if carrierName.isEmpty { // 没有名字的运营商只能这样显示
                    cell.textLabel?.text = NSLocalizedString("UnknownCarrier", comment: "")
                } else { // 设置运营商名字
                    cell.textLabel?.text = cellularPlan.carrierName
                }
            } else {
                cell.textLabel?.text = (cellularPlan.label ?? "") + " (" + (cellularPlan.carrierName == "" ? NSLocalizedString("UnknownCarrier", comment: "") : cellularPlan.carrierName) + ")"
            }
        } else {
            if let label = cellularPlan.label {
                cell.textLabel?.text = label + " (" + NSLocalizedString("UnknownCarrier", comment: "") + ")"
            } else {
                cell.textLabel?.text = NSLocalizedString("UnknownCarrier", comment: "")
            }
        }
        
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        cell.detailTextLabel?.text = cellularPlan.isSelected ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: "") // 显示当前的卡是否启动
        if #available(iOS 13.0, *) {
            cell.detailTextLabel?.textColor = .secondaryLabel
        } else {
            cell.detailTextLabel?.textColor = .gray
        }
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 15)
        
        cell.accessoryType = .disclosureIndicator // 右侧有个 >
        cell.selectionStyle = .default // 启用选中效果
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 打开蜂窝数据卡详细界面
        let cellularPlanDetailsViewController = CellularPlanDetailsViewController(cellularPlan: cellularPlansStatus.plans[indexPath.row])
        navigationController?.pushViewController(cellularPlanDetailsViewController, animated: true)
        
    }
    
    // MARK: - 长按Cell的peak事件
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: {
            // 预览蜂窝数据卡的详细界面
            return CellularPlanDetailsViewController(cellularPlan: self.cellularPlansStatus.plans[indexPath.row])
        }, actionProvider: { _ in
            
            let plan = self.cellularPlansStatus.plans[indexPath.row]
            let isEnabled = plan.isSelected
            
            // 开关操作
            let toggleAction = UIAction(
                title: isEnabled
                    ? NSLocalizedString("TurnOffThisLine", comment: "")
                    : NSLocalizedString("TurnOnThisLine", comment: ""),
                image: UIImage(systemName: "simcard"),
                attributes: isEnabled ? .destructive : []
            ) { _ in
                // 切换蜂窝数据卡的开关
                self.onClickControlPlanItemCell(cellularPlan: plan)
            }
            
            return UIMenu(title: "", children: [toggleAction])
        })
    }
    
    // MARK: - Peek后的Pop（点击预览进入详情）
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView,
                   willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                   animator: UIContextMenuInteractionCommitAnimating) {
        
        guard let indexPath = configuration.identifier as? IndexPath
        else {
            return
        }
        
        animator.addCompletion {
            // 打开蜂窝数据卡详细界面
            let cellularPlanDetailsViewController = CellularPlanDetailsViewController(cellularPlan: self.cellularPlansStatus.plans[indexPath.row])
            self.navigationController?.pushViewController(cellularPlanDetailsViewController, animated: true)
        }
    }
    
    // MARK: - 老款设备的3D Touch适配 Peek
    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        // 根据触摸点找到对应的 cell
        guard let indexPath = tableView.indexPathForRow(at: location) else {
            return nil
        }
        
        // 高亮当前 cell 区域
        previewingContext.sourceRect = tableView.rectForRow(at: indexPath)
        
        // 返回预览蜂窝数据卡详情的ViewController
        let cellularPlanDetailsViewController = CellularPlanDetailsViewController(cellularPlan: cellularPlansStatus.plans[indexPath.row])
        // 设置View大小
        cellularPlanDetailsViewController.preferredContentSize = CGSize(width: 0, height: 400)
        return cellularPlanDetailsViewController
    }
    
    // MARK: - 老款设备的3D Touch适配 Pop
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        // 点击预览后 push（和普通点击一致）
        navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
    
    /// 点击开启/关闭蜂窝数据卡
    private func onClickControlPlanItemCell(cellularPlan: CTCellularPlanItem) {
        
        let turnText: String
        let labelText: String
        
        if CellularDataController.instance.getDeviceType() == .phone { // iPhone支持卡标签
            labelText = (cellularPlan.label?.isEmpty == false)
                ? cellularPlan.label!
                : NSLocalizedString("Unknown", comment: "未知")
        } else { // iPad 蜂窝版不支持卡标签
            if let carrierName = cellularPlan.carrierName {
                labelText = carrierName.isEmpty ? NSLocalizedString("UnknownCarrier", comment: "") : carrierName
            } else {
                labelText = NSLocalizedString("UnknownCarrier", comment: "")
            }
        }
        
        // 判断开启还是关闭
        if cellularPlan.isSelected {
            turnText = NSLocalizedString("TurnOff", comment: "")
        } else {
            turnText = NSLocalizedString("Enabled", comment: "")
        }
        
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            /*确定%1$@%2$@?*/
            message: String.localizedStringWithFormat(NSLocalizedString("ChangeCellularPlanAlertMessage", comment: ""), turnText, labelText),
            preferredStyle: .alert
        )

        // "确定" 按钮
        let deleteAction = UIAlertAction(title: turnText, style: .default) { _ in
            
            CTCellularPlanController.instance.setCellularPlanItem(item: cellularPlan, enable: !cellularPlan.isSelected) { error in
                
                DispatchQueue.main.async {
                    
                    if case let error as NSError = error {
                        UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription), in: self)
                    } else {
                        self.onCellularDataRefresh()
                    }
                }
            }
        }

        // "取消" 按钮
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)

        // 显示弹窗
        present(alert, animated: true, completion: nil)
    }
    
}
