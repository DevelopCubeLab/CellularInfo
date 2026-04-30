import Foundation
import UIKit
import UniformTypeIdentifiers

class IPCCManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, UIDropInteractionDelegate {
    
    private var tableView = UITableView()
    private var managerGroups: [InfoItemGroup] = []
    private var installedIPCCList: [CarrierBundleInfo] = []
    
    /// 从其他app分享来的IPCC文件的URL缓存
    private var pendingImportURL: URL?
    /// 拖动文件进来的叠加View 给用户一个引导
    private var dropOverlayView: UIView?
    
    /// 给长按Cell复制文本的临时缓存变量
    private var currentCopyText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("IPCCManager", comment: "")
        
        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
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
        
        // 刷新数据
        reloadData()
        
        // 允许用户拖拽 IPCC 文件到当前页面。
        // 注意：tableView 覆盖了整个页面，DropInteraction 必须加到 tableView 上，
        // 否则事件会被 tableView 吃掉，外层 view 收不到拖放回调。
        let drop = UIDropInteraction(delegate: self)
        tableView.addInteraction(drop)
        
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
        
        // 刷新数据
        reloadData()
        
        // 判断缓存是否存在，存在再去调用弹窗
        // 必须要这样，不然App如果没在后台的话弹窗不会显示出来
        if let url = pendingImportURL {
            self.importIPCCFileFromOtherApplication(url: url)
        }
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
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
    
    /// 刷新数据
    private func reloadData() {
        managerGroups = CellularDataController.instance.getIPCCManagerGroup()
        installedIPCCList = IPCCManagerController.getInstalledCarrierBundles()
        tableView.reloadData()
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        if !installedIPCCList.isEmpty {
            return managerGroups.count + 1
        }
        return managerGroups.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < managerGroups.count {
            return managerGroups[section].items.count
        } else {
            return installedIPCCList.count
        }
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < managerGroups.count {
            return managerGroups[section].titleText
        } else {
            if !installedIPCCList.isEmpty {
                return NSLocalizedString("InstalledIPCC", comment: "")
            }
        }
        return nil
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section < managerGroups.count {
            return managerGroups[section].footerText
        } else if section == managerGroups.count && !installedIPCCList.isEmpty {
            return NSLocalizedString("InstalledIPCCFooterText", comment: "")
        }
        return nil
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        if indexPath.section < managerGroups.count { // 防止越界
            // 获取数据
            let item = managerGroups[indexPath.section].items[indexPath.row]
            // 设置ID
            cell.tag = item.id
            
            cell.textLabel?.text = item.text
        
            cell.textLabel?.numberOfLines = 0 // 允许换行
            cell.selectionStyle = .none // 取消点击特效
            
            if item.id == ActionItemID.installIPCC || item.id == ActionItemID.refreshCarrierBundles { // 安装IPCC 和 刷新运营商配置
                cell.textLabel?.textColor = .systemBlue
                cell.selectionStyle = .default
            } else if item.id == ActionItemID.restoreIPCCToSystem { // 恢复IPCC为系统版本
                cell.textLabel?.textColor = .systemRed
                cell.selectionStyle = .default
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
            
        } else {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
            
            let bundle = installedIPCCList[indexPath.row]
            
            cell.textLabel?.text = bundle.carrierName
            cell.detailTextLabel?.text = bundle.version
        }
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section < managerGroups.count { // 防止越界
            // 获取数据
            let item = managerGroups[indexPath.section].items[indexPath.row]
            
            if item.id == ActionItemID.installIPCC { // 安装IPCC
                
                if SettingsUtils.instance.getShowInstallIPCCTips() {
                    // 设置一个弹窗
                    let alert = UIAlertController(
                        title: NSLocalizedString("Alert", comment: ""),
                        message: NSLocalizedString("InstallIPCCTips", comment: ""),
                        preferredStyle: .alert
                    )
                    
                    // 继续 按钮 蓝色
                    let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
                        // 打开文件选择器
                        self.presentIPCCDocumentPicker()
                    }

                    // 不再提示 按钮 红色
                    let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .destructive) { _ in
                        // 设置不再显示提示
                        SettingsUtils.instance.setShowInstallIPCCTips(enable: false)
                        // 打开文件选择器
                        self.presentIPCCDocumentPicker()
                    }

                    // 关闭 按钮 蓝色
                    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

                    // 添加按钮，iOS 会自动按照规范排列
                    alert.addAction(continueAction)
                    alert.addAction(disableAlertAction)
                    alert.addAction(cancelAction)

                    // 显示弹窗
                    present(alert, animated: true, completion: nil)
                    
                } else { // 不显示弹窗直接选择IPCC
                    presentIPCCDocumentPicker()
                }
                
            } else if item.id == ActionItemID.refreshCarrierBundles {
                do {
                    if try IPCCManagerController.refreshCarrierBundles() {
                        sendMessage(message: NSLocalizedString("Refreshed", comment: ""))
                    }
                } catch let error as NSError {
                    if error.code == 2 { // 无权限
                        UIUtils.showAlert(message: NSLocalizedString("NoPermission", comment: ""), in: self)
                    } else { // 其他错误
                        UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code , error.localizedDescription), in: self)
                    }
                }
            } else if item.id == ActionItemID.restoreIPCCToSystem {
                    // 设置一个弹窗
                    let alert = UIAlertController(
                        title: NSLocalizedString("Alert", comment: ""),
                        message: NSLocalizedString("restoreIPCCToSystemTips", comment: ""),
                        preferredStyle: .alert
                    )
                    
                    // 继续 按钮 红色
                    let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
                        // 恢复IPCC
                        self.restoreIPCCToSystem()
                    }

                    // 关闭 按钮 蓝色
                    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

                    // 添加按钮，iOS 会自动按照规范排列
                    alert.addAction(continueAction)
                    alert.addAction(cancelAction)

                    // 显示弹窗
                    present(alert, animated: true, completion: nil)
                    
                managerGroups = CellularDataController.instance.getIPCCManagerGroup()
                tableView.reloadData()
            }
        } else if indexPath.section == managerGroups.count { // 点击IPCC的详情
            if indexPath.row < installedIPCCList.count { // 防止越界
                let bundle = installedIPCCList[indexPath.row]
                let detailText = String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), bundle.carrierName)
                    .appending("\n")
                    .appending(String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), bundle.version))
                    .appending("\n")
                    .appending(String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsDevices", comment: ""), bundle.supportDevice.joined(separator: "\n")))
                    .appending("\n")
                    .appending(String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsSIM", comment: ""), bundle.supportSIMs.joined(separator: "\n")))
                UIUtils.showAlert(title: NSLocalizedString("CarrierBundleDetails", comment: ""), message: detailText, in: self)
            }
            
        }
        
    }
    
    // MARK: - 左侧添加导出按钮
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        if indexPath.section == managerGroups.count {
            let exportAction = UIContextualAction(style: .normal, title: NSLocalizedString("Export", comment: "")) { (action, view, completionHandler) in
                self.exportCarrierBundle(forRowAt: indexPath)
                completionHandler(true)
            }
            exportAction.backgroundColor = .systemBlue // 导出按钮的颜色
            
            return UISwipeActionsConfiguration(actions: [exportAction])
        }
        return nil
    }

    // MARK: - 允许滑动删除的cell
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if !managerGroups.isEmpty {
            return indexPath.section == managerGroups.count  // 仅允许已安装那一组能横滑删除
        }
        return false
    }
    
    // MARK: - Cell滑动删除功能
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.section == managerGroups.count { // 只允许已安装那一组能横滑删除
            if editingStyle == .delete {
                deleteCarrierBundle(forRowAt: indexPath)
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
        self.currentCopyText = managerGroups[indexPath.section].items[indexPath.row].detailText
        // 创建菜单
        let menu = UIMenuController.shared
        // 创建复制按钮
        let copyItem = UIMenuItem(title: NSLocalizedString("Copy", comment: ""), action: #selector(copyCellText))
        // 把复制按钮放菜单里
        menu.menuItems = [copyItem]
        // 成为第一个处理的View
        cell.becomeFirstResponder()
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
    
    /// 隐藏拖拽IPCC文件的时候的叠层
    private func hideDropOverlay() {
        guard let overlay = dropOverlayView else {
            return
        }
        
        UIView.animate(withDuration: 0.2, animations: { // 做个消失动画
            overlay.alpha = 0
        }) { _ in
            overlay.removeFromSuperview()
        }
        
        dropOverlayView = nil
    }
    
    /// 打开文件选择器
    private func presentIPCCDocumentPicker() {
        let picker: UIDocumentPickerViewController
        
        if #available(iOS 14.0, *) {
            if let fileType = UTType(filenameExtension: "ipcc") { // 只要ipcc扩展名的文件
                // asCopy必须是true 证书签名的情况下如果描述文件和Bundle ID和描述文件的不一致就无法打开文件
                picker = UIDocumentPickerViewController(forOpeningContentTypes: [fileType], asCopy: true)
            } else {
                picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
            }
        } else { // 低系统版本无法筛选，无所谓，后面有检查
            picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        }
        
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    /// 用户取消选择文件
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 用户取消选择，不做处理
    }
    
    /// 用户选择了文件
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            UIUtils.showAlert(message: NSLocalizedString("SelectFileMessage", comment: ""), in: self)
            return
        }
        installCarrierBundleConfirm(url: url)
    }
    
    /// 接收从其他App分享IPCC文件并且安装IPCC的方法
    func receiveFileFromOtherApplication(url: URL) {
        // 只缓存，其余什么都不需要做，等viewDidAppear去处理
        pendingImportURL = url
    }
    
    /// 是否允许处理当前拖放会话
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        // 只允许单个文件
        guard session.items.count == 1 else {
            return false
        }
        
        let provider = session.items.first!.itemProvider
        let identifiers = provider.registeredTypeIdentifiers
        
        // 获取文件类型再决定是否允许拖拽
        if identifiers.contains(where: { $0 == "public.file-url" || $0 == "public.data" || $0 == "com.pkware.zip-archive" }) {
            return true
        }
        
        // 判断文件类型 只支持 iOS 14.0+
        if #available(iOS 14.0, *) {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) ||
                provider.hasItemConformingToTypeIdentifier(UTType.zip.identifier) {
                return true
            }
        }
        
        return false
    }
    
    /// 拖入过程中的提案，明确告诉系统这是 copy 行为
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    /// 拖入页面时给一个UI反馈，方便确认文件拖已经进来了
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        if dropOverlayView == nil {
            dropOverlayView = UIUtils.showDropOverlay(baseView: self.view, hintText: NSLocalizedString("DropToInstallIPCC", comment: ""))
            // 拖拽到可识别区域后震动一下
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    /// 离开拖动识别区域的事件
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        hideDropOverlay()
    }
    
    /// 用户拖拽了一个文件到当前View Controller并且安装
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        hideDropOverlay()
        let fileManager = FileManager.default
        let IPCCDir = fileManager.temporaryDirectory.appendingPathComponent("IPCC", isDirectory: true)
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: IPCCDir.path) {
            do {
                try fileManager.createDirectory(at: IPCCDir, withIntermediateDirectories: true)
            } catch { // 如果无法创建就返回
                return
            }
        }

        // 只处理单个文件（前面 canHandle 已经保证）
        guard let item = session.items.first else { return }
        let provider = item.itemProvider

        if #available(iOS 14.0, *) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                if let error = error {
                    NSLog("[CellularInfo]<IPCC Drop to Install> loadFileRepresentation failed: \(error)")
                    return
                }

                guard let url = url else {
                    NSLog("[CellularInfo]<IPCC Drop to Install> nil file url")
                    return
                }

                self.handleDroppedFile(url, fileManager: fileManager, IPCCDir: IPCCDir)
            }
        } else {
            provider.loadFileRepresentation(forTypeIdentifier: "public.data") { url, error in
                if let error = error {
                    NSLog("[CellularInfo]<IPCC Drop to Install> loadFileRepresentation failed: \(error)")
                    return
                }

                guard let url = url else {
                    NSLog("[CellularInfo]<IPCC Drop to Install> nil file url")
                    return
                }

                self.handleDroppedFile(url, fileManager: fileManager, IPCCDir: IPCCDir)
            }
        }
    }

    /// 处理拖拽进来的文件：复制到 tmp/IPCC 并触发导入流程
    private func handleDroppedFile(_ sourceURL: URL, fileManager: FileManager, IPCCDir: URL) {
        let fileName = sourceURL.lastPathComponent.isEmpty
            ? UUID().uuidString + ".ipcc"
            : sourceURL.lastPathComponent

        let destURL = IPCCDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destURL)

            NSLog("[CellularInfo]<IPCC Drop to Install> copied to \(destURL)")

            DispatchQueue.main.async {
                self.importIPCCFileFromOtherApplication(url: destURL)
            }

        } catch {
            NSLog("[CellularInfo]<IPCC Drop to Install> copy failed: \(error)")
        }
    }
    
    /// 从其他App安装IPCC
    /// 设置了一个弹窗，防止用户误操作
    func importIPCCFileFromOtherApplication(url: URL) {
        
        // 清除缓存
        pendingImportURL = nil
        
        // 判断文件类型
        // 主要是为了低版本iOS限制的，还有LiveContainer.高版本iOS直接不允许选择其他类型的文件
        guard url.pathExtension.lowercased() == "ipcc" else {
            UIUtils.showAlert(message: NSLocalizedString("NeedSelectIPCCFileTypeMessage", comment: ""), in: self)
            return
        }
        
        // 设计一个弹窗，防止用户误操作
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("InstallIPCCTips", comment: ""),
            preferredStyle: .alert
        )
        
        // 继续 安装IPCC
        let confirmAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
            // 开始安装IPCC流程
            self.installCarrierBundleConfirm(url: url)
        }
        
        // 运行兼容性检测 按钮
        let checkCompatibilityAction = UIAlertAction(title: NSLocalizedString("RunCompatibilityCheck", comment: ""), style: .default) { _ in
            // 跳转到IPCC兼容性检测页面，并把当前IPCC文件URL传过去自动开始检测
            let compatibilityCheckViewController = IPCCCompatibilityCheckViewController()
            compatibilityCheckViewController.handleExternalIPCCFile(path: url)
            self.navigationController?.pushViewController(compatibilityCheckViewController, animated: true)
        }
        
        // 取消
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(checkCompatibilityAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }
    
    /// 给IPCC兼容性检测准备的方法
    func installIPCCFileWithAfterCheckCompatibility(path: URL) {
        // 确保在主线程 保证UI安全 延迟0.3s执行 让动画先放完 这样防止有时候UITableView不显示结果的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.installCarrierBundle(url: path) // 跳过检测 直接安装 因为之前用户已经检测了
        }
    }
    
    /// 安装IPCC的确认过程
    private func installCarrierBundleConfirm(url: URL) {
        // 开始访问安全域资源（必须覆盖整个异步生命周期）
        let granted = url.startAccessingSecurityScopedResource()
        
        // 不要在这里用 defer 释放权限（会在异步开始后提前释放）
        
        // 确保iCloud文件已经下载到本地
        FileUtils.ensureFileDownloaded(url: url) { success in
            // 在异步回调结束时再释放权限
            defer {
                if granted {
                    url.stopAccessingSecurityScopedResource() // 释放访问权限
                }
            }
            
            if !success {
                UIUtils.showAlert(message: NSLocalizedString("DownloadFailed", comment: ""), in: self)
                return
            }
            
            // 文件已就绪，继续原有安装流程
            self.continueInstallCarrierBundle(url: url)
        }
    }

    /// 实际执行IPCC安装确认逻辑（在文件确保可用之后调用）
    private func continueInstallCarrierBundle(url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "ipcc" else {
            UIUtils.showAlert(message: NSLocalizedString("NeedSelectIPCCFileTypeMessage", comment: ""), in: self)
            return
        }
        
        // 检查IPCC文件的兼容性
        if SettingsUtils.instance.getEnableCheckCarrierBundleCompatibility() {
            do {
                let result = try IPCCManagerController.IPCCFileCompatibilityCheck(path: url)
                
                // 设置一个弹窗
                let alert = UIAlertController(
                    title: NSLocalizedString("Alert", comment: ""),
                    message: nil,
                    preferredStyle: .alert
                )
                
                var messageText: String
                let confirmActionStyle: UIAlertAction.Style
                if result.issues.contains(.deviceNotSupported) { // IPCC文件与设备不匹配
                    /*
                     ⚠️安装的IPCC文件与当前设备不兼容
                     
                     当前设备主板编号: %1$@
                     IPCC文件兼容的主板编号: %2$@
                     
                     无法成功安装此IPCC,不建议继续安装此IPCC
                     */
                    
                    messageText = String.localizedStringWithFormat(
                        NSLocalizedString("IPCCFileNotSupportedDeviceMessage", comment: ""),
                        SystemInfoUtils.getDeviceLogicBoardID(), // 当前系统的主板编号
                        result.carrierBundleInfo.supportDevice.joined(separator: ", ") // IPCC文件支持的主板编号
                    )
                    confirmActionStyle = .destructive
                } else if result.issues.contains(.belowSystemVersion) { // IPCC文件低于系统默认版本IPCC
                    /*
                     ⚠️安装的IPCC文件版本低于当前系统默认IPCC版本
                     
                     %1$@
                     IPCC文件版本: %2$@
                     
                     可以正常安装此IPCC，但是系统不会使用该IPCC文件，不建议继续安装此IPCC
                     */
                    messageText = String.localizedStringWithFormat(
                        NSLocalizedString("IPCCFileBelowSystemVersionMessage", comment: ""),
                        CellularDataController.instance.getSystemDefaultIPCCVersion().text, // 偷个懒，直接从已有组件里拿数据
                        result.carrierBundleInfo.version
                    )
                    confirmActionStyle = .destructive
                } else if result.issues.contains(.installPathLocked) { // 安装目录被锁定
                    /*
                     ⚠️安装IPCC的系统目录已被锁定，无法成功安装IPCC文件，建议解锁后再安装IPCC
                     
                     是否继续安装?
                     */
                    messageText = NSLocalizedString("InstallPathLockedMessage", comment: "")
                    confirmActionStyle = .destructive
                } else if result.issues.contains(.duplicateInstall) { // 安装了重复的IPCC
                    /*
                     已经安装%1$@ %2$@版本的IPCC文件
                     
                     是否再次安装此IPCC文件?
                     */
                    messageText = String.localizedStringWithFormat(
                        NSLocalizedString("DuplicateInstallIPCCFileMessage", comment: ""),
                        result.carrierBundleInfo.carrierName, // IPCC文件的运营商名称
                        result.carrierBundleInfo.version // IPCC文件的版本
                    )
                    confirmActionStyle = .default
                } else if result.issues.contains(.versionDowngrade) { // 降级安装IPCC
                    /*
                     已经安装%1$@的IPCC文件
                     当前选择的IPCC文件低于已安装的IPCC版本
                     IPCC文件版本: %2$@
                     
                     系统不支持直接降级IPCC版本，继续安装此IPCC会导致系统恢复IPCC为系统默认版本
                     是否继续安装此IPCC文件？
                     */
                    messageText = String.localizedStringWithFormat(
                        NSLocalizedString("DowngradeInstallIPCCMessage", comment: ""),
                        result.carrierBundleInfo.carrierName, // IPCC文件的运营商名称
                        result.carrierBundleInfo.version // IPCC文件的版本
                    )
                    confirmActionStyle = .default
                } else { // 是否安装IPCC 正常流程
                    /*
                     是否安装%1$@ %2$@版本的IPCC文件?
                     */
                    messageText = String.localizedStringWithFormat(
                        NSLocalizedString("ConfirmInstallIPCCMessage", comment: ""),
                        result.carrierBundleInfo.carrierName, // IPCC文件的运营商名称
                        result.carrierBundleInfo.version // IPCC文件的版本
                    )
                    confirmActionStyle = .default
                }
                
                // 设置弹窗的信息
                alert.message = messageText
                
                // 继续 按钮 红色/蓝色
                let continueAction = UIAlertAction(title: NSLocalizedString("ContinueInstall", comment: ""), style: confirmActionStyle) { _ in
                    self.installCarrierBundle(url: url)
                }

                // 关闭 按钮 蓝色
                let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

                // 添加按钮，iOS 会自动按照规范排列
                alert.addAction(continueAction)
                alert.addAction(cancelAction)

                // 显示弹窗
                present(alert, animated: true, completion: nil)
                
            } catch { // 处理异常
                UIUtils.showAlert(message: NSLocalizedString("InvalidIPCCFile", comment: ""), in: self)
            }
        } else {
            // 直接安装IPCC
            self.installCarrierBundle(url: url)
        }
    }
    
    /// 安装IPCC的主要流程
    private func installCarrierBundle(url: URL) {
        do {
            let success = try IPCCManagerController.installIPCC(path: url)
            if success { // 安装成功
                
                // 获取安装后的判断结果
                let installResult = IPCCManagerController.checkInstalledIPCCResult(url: url, beforeInstallList: installedIPCCList)
                var message: String
                
                switch installResult { // 进一步判断安装结果
                    
                case .success(let carrierName, let version): // 安装成功
                    // 安装%1$@ %2$@版本的IPCC成功，请等待系统刷新蜂窝网络状态
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("InstallIPCCSuccessfulMessage", comment: ""),
                        carrierName,
                        version,
                    )
                    
                case .invalidBundle(let carrierName, let version):
                    // 安装%1$@ %2$@版本的IPCC失败，该IPCC文件可能损坏或被篡改，系统已将%3$@的IPCC版本还原为系统默认IPCC版本
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("InvalidIPCCAfterInstallMessage", comment: ""),
                        carrierName,
                        version,
                        carrierName
                    )

                case .upgraded(let carrierName, let old, let new):
                    // 安装IPCC成功，%1$@的IPCC版本已由%2$@版本升级为%3$@版本
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("IPCCUpgradedMessage", comment: ""),
                        carrierName,
                        old,
                        new
                    )

                case .downgraded(let carrierName, let old, let new):
                    // 安装IPCC失败，系统不支持直接降级IPCC版本。已将%1$@的IPCC恢复为系统默认版本。%2$@版本的IPCC已被系统移除，如需使用%3$@版本，请再次安装该IPCC文件。
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("IPCCDowngradedMessage", comment: ""),
                        carrierName,
                        old,
                        new
                    )

                case .sameVersion(let carrierName, let version):
                    // 安装IPCC成功，%1$@ %2$@版本已经安装过，因此系统不会刷新当前状态
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("IPCCSameVersionMessage", comment: ""),
                        carrierName,
                        version
                    )
                case .upgradedFailed(let carrierName, let install, let current):
                    // 尝试将%1$@从%2$@升级为%3$@失败，可能是当前版本IPCC文件不兼容当前系统版本
                    message = String.localizedStringWithFormat(
                        NSLocalizedString("InstallIPCCUpgradedFailedMessage", comment: ""),
                        carrierName,
                        current,
                        install
                    )
                case .failed:
                    message = NSLocalizedString("InstallIPCCFailedMessage", comment: "")
                
                case .pathLocked(lockedPath: let lockedPath):
                    /*
                     安装IPCC失败，安装目录被锁定，请先解除锁定后再次安装
                     被锁定的目录: %@
                     */
                    message = String.localizedStringWithFormat(NSLocalizedString("InstallIPCCFailedWithPathLockedMessage", comment: ""), lockedPath.joined(separator: "\n"))
                case .permissionDenied:
                    message = NSLocalizedString("NoPermission", comment: "")
                }
                // 弹出弹窗
                UIUtils.showAlert(message: message, in: self)
            } else {
                // 安装失败
                UIUtils.showAlert(message: NSLocalizedString("InstallIPCCFailedMessage", comment: ""), in: self)
            }
            
        } catch let error as NSError {
            if error.code == -12 { // IPCC文件无法访问
                UIUtils.showAlert(message: NSLocalizedString("InstallIPCCCanNotAccessFileMessage", comment: ""), in: self)
            } else {
                UIUtils.showAlert(message: error.localizedDescription, in: self)
            }
        }
        
        reloadData()
    }
    
    /// 恢复IPCC为系统默认
    func restoreIPCCToSystem() {
        do {
            try IPCCManagerController.restoreCarrierBundleToSystem()
            UIUtils.showAlert(message: NSLocalizedString("RestoreIPCCToSystemSuccessful", comment: ""), in: self)
        } catch let error as CarrierBundleError { // 恢复失败
            
            switch error {
            case .permissionDenied: // 无权限
                UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("RestoreIPCCToSystemFailedWithReason", comment: ""), NSLocalizedString("NoPermission", comment: "")), in: self)
            case .noCarrierBundleInstalled: // 没有安装任何IPCC
                UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("RestoreIPCCToSystemFailedWithReason", comment: ""), NSLocalizedString("NoIPCCInstalled", comment: "")), in: self)
            case .pathLocked(let lockedPath): // 安装目录被锁定
                UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("RestoreIPCCToSystemFailedWithReason", comment: ""), String.localizedStringWithFormat(NSLocalizedString("PathLockedWithPath", comment: ""), lockedPath.joined(separator: "\n"))), in: self)
            default: // 其他错误的情况
                UIUtils.showAlert(message: error.localizedDescription, in: self)
            }
            
        } catch {
            UIUtils.showAlert(message: NSLocalizedString("RestoreIPCCToSystemFailed", comment: ""), in: self)
        }
        // 刷新数据
        reloadData()
    }
    
    func exportCarrierBundle(forRowAt indexPath: IndexPath) {
        if indexPath.row > installedIPCCList.count { // 防止数组越界
            return
        }
        // 拿到需要删除的IPCC的数据对象
        let carrierBundleItem = installedIPCCList[indexPath.row]
        
        // 设计一个弹窗，防止用户误操作
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: String.localizedStringWithFormat(NSLocalizedString("ExportCarrierBundleMessage", comment: ""), carrierBundleItem.carrierName, carrierBundleItem.version),
            preferredStyle: .alert
        )
        // 继续
        let confirmAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
            do {
                let path = try IPCCManagerController.exportInstalledCarrierBundle(forCarrierBundleInfo: carrierBundleItem)
                
                // 调用系统分享文件
                let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)

                // iPad 必须加这个，否则会崩
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
                    popover.permittedArrowDirections = []
                }

                self.present(activityVC, animated: true)
                
            } catch {
                UIUtils.showAlert(message: NSLocalizedString("ExportCarrierBundleFailed", comment: ""), in: self)
            }
        }
        
        // 取消
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }
    
    /// 删除某个IPCC
    func deleteCarrierBundle(forRowAt indexPath: IndexPath) {
        if indexPath.row > installedIPCCList.count { // 防止数组越界
            return
        }
        // 拿到需要删除的IPCC的数据对象
        let carrierBundleItem = installedIPCCList[indexPath.row]
        
        // 设计一个弹窗，防止用户误操作
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: String.localizedStringWithFormat(NSLocalizedString("DeleteCarrierBundleMessage", comment: ""), carrierBundleItem.carrierName, carrierBundleItem.version),
            preferredStyle: .alert
        )
        
        // 继续
        let confirmAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
            
            do {
                try IPCCManagerController.deleteInstalledCarrierBundle(forCarrierBundleInfo: carrierBundleItem)
                UIUtils.showAlert(message: NSLocalizedString("DeleteCarrierBundleSuccessful", comment: ""), in: self)
            } catch let error as CarrierBundleError {
                switch error {
                case .resetCarrierBundleFailed: // 刷新IPCC状态失败
                    UIUtils.showAlert(message: NSLocalizedString("DeleteCarrierBundleFailed", comment: ""), in: self)
                case .permissionDenied: // 权限被拒绝
                    UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("DeleteCarrierBundleFailedWithReason", comment: ""), NSLocalizedString("NoPermission", comment: "")), in: self)
                case .invalidPath: // 删除文件目录不被接受
                    UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("DeleteCarrierBundleFailedWithReason", comment: ""), NSLocalizedString("InvalidPath", comment: "")), in: self)
                case .fileNotFound: // 需要删除的IPCC文件不存在
                    UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("DeleteCarrierBundleFailedWithReason", comment: ""), NSLocalizedString("FileNotFound", comment: "")), in: self)
                default: // 其他错误的情况
                    UIUtils.showAlert(message: error.localizedDescription, in: self)
                }
            } catch {
                UIUtils.showAlert(message: NSLocalizedString("DeleteCarrierBundleFailed", comment: ""), in: self)
            }
            // 刷新数据
            self.reloadData()
        }
        
        // 取消
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
        
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
