import Foundation
import UIKit

class CellularPlanDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private let cellularDataController = CellularDataController.instance
    
    private var cellularPlan: CTCellularPlanItem
    private var planInfoGroups: [InfoItemGroup] = []
    private var hideConfidential = false
    
    init(cellularPlan: CTCellularPlanItem) {
        self.cellularPlan = cellularPlan
        planInfoGroups = cellularDataController.getCellularPlanInfoGroups(plan: cellularPlan)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置标题为蜂窝数据卡名称
        navigationItem.title = cellularPlan.carrierName
        
        // 隐藏/显示机密信息的按钮
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "lock.open"),
                style: .plain,
                target: self,
                action: #selector(toggleHideConfidential)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("Hide", comment: ""),
                style: .plain,
                target: self,
                action: #selector(toggleHideConfidential)
            )
        }
        // 长按锁按
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(onHideButtonLongPress(_:))
        )
        longPress.minimumPressDuration = 2
        navigationController?.navigationBar.addGestureRecognizer(longPress)
        
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
        
        // 设置监听器
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
        
        // 刷新数据
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // 刷新数据
        reloadData()
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
    }
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func onBecomeActive() {
        self.reloadData()
    }
    
    /// 刷新数据
    private func reloadData() {
        if let plan = CTCellularPlanController.instance.getCellularPlanBy(UUID: cellularPlan.uuid) {
            self.cellularPlan = plan
            planInfoGroups = cellularDataController.getCellularPlanInfoGroups(plan: cellularPlan)
            tableView.reloadData()
        }
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
    
    // 切换显示按钮
    @objc private func toggleHideConfidential() {
        hideConfidential.toggle()

        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem?.image = UIImage(
                systemName: hideConfidential ? "lock" : "lock.open"
            )
        } else {
            navigationItem.rightBarButtonItem?.title = hideConfidential ? NSLocalizedString("Show", comment: "") : NSLocalizedString("Hide", comment: "")
        }

        tableView.reloadData()
    }
    
    /// 长按锁按钮
    @objc private func onHideButtonLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        if let tab = self.navigationController?.tabBarController as? MainUITabBarController {
            tab.startAppBadgeAnimation()
        }
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return planInfoGroups.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return planInfoGroups[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return planInfoGroups[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return planInfoGroups[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        
        // 获取数据
        let item = planInfoGroups[indexPath.section].items[indexPath.row]
        // 设置ID
        cell.tag = item.id
        // 设置文本并且判断是否需要隐藏机要信息
        if hideConfidential && item.isConfidential {
            cell.textLabel?.text = UIUtils.maskConfidential(item.text)
        } else {
            cell.textLabel?.text = item.text
        }
        cell.textLabel?.numberOfLines = 0 // 允许换行
        cell.selectionStyle = .none // 取消点击特效
        // 判断是否是打开/关闭蜂窝数据卡
        if item.id == ActionItemID.turnOnCellularPlan {
            cell.textLabel?.textColor = .systemBlue
            cell.selectionStyle = .default
        } else if item.id == ActionItemID.turnOffCellularPlan {
            cell.textLabel?.textColor = .systemRed
            cell.selectionStyle = .default
        }
        
        //判断是否显示提示文本
        if item.hintText != nil {
            cell.accessoryType = .detailButton
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let itemID = planInfoGroups[indexPath.section].items[indexPath.row].id
        // 判断是否是打开/关闭蜂窝数据卡
        if itemID == ActionItemID.turnOnCellularPlan || itemID == ActionItemID.turnOffCellularPlan {
            self.onClickControlPlanItemCell(actionID: itemID)
        }
        
    }
    
    // MARK: - Cell的右侧的i的点击事件
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        if let hintText = planInfoGroups[indexPath.section].items[indexPath.row].hintText {
            UIUtils.showAlert(message: hintText, in: self)
        }
    }
    
    /// 点击开启/关闭蜂窝数据卡
    private func onClickControlPlanItemCell(actionID: Int) {
        
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
        
        
        if actionID == ActionItemID.turnOnCellularPlan {
            turnText = NSLocalizedString("Enabled", comment: "")
        } else {
            turnText = NSLocalizedString("TurnOff", comment: "")
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
            
            CTCellularPlanController.instance.setCellularPlanItem(item: self.cellularPlan, enable: actionID == ActionItemID.turnOnCellularPlan) { error in
                DispatchQueue.main.async {
                    if case let error as NSError = error {
                        UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription), in: self)
                    } else {
                        self.reloadData()
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

