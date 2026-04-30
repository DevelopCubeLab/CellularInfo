import Foundation
import UniformTypeIdentifiers
import UIKit

class IPCCCompatibilityCheckViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate, UIDropInteractionDelegate {
    
    private var tableView = UITableView()
    
    private var compatibilityCheckGroup: [InfoItemGroup] = []
    
    private var selectIPCCFilePath: URL?
    
    /// 拖动文件进来的叠加View 给用户一个引导
    private var dropOverlayView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("IPCCCompatibilityCheck", comment: "")
        
        compatibilityCheckGroup = CellularDataController.instance.getIPCCCompatibilityCheckBasicGroup()
        
        // 设置背景颜色
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
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
        
        // 允许用户拖拽 IPCC 文件到当前页面。
        // 注意：tableView 覆盖了整个页面，DropInteraction 必须加到 tableView 上，
        // 否则事件会被 tableView 吃掉，外层 view 收不到拖放回调。
        let drop = UIDropInteraction(delegate: self)
        tableView.addInteraction(drop)
    }
    
    /// 销毁ViewController触发
    deinit {
        // 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return compatibilityCheckGroup.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return compatibilityCheckGroup[section].items.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return compatibilityCheckGroup[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return compatibilityCheckGroup[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "Cell")
        
        // 获取数据
        let item = compatibilityCheckGroup[indexPath.section].items[indexPath.row]
        
        cell.textLabel?.text = compatibilityCheckGroup[indexPath.section].items[indexPath.row].text
        cell.textLabel?.numberOfLines = 0 // 允许换行
        cell.selectionStyle = .none // 取消点击特效
        // 选择文件cell
        if item.id == ActionItemID.selectIPCCFile {
            cell.textLabel?.textColor = .systemBlue // 设置成蓝色
            cell.selectionStyle = .default
        }
        
        // 检测结果的Cell
        if compatibilityCheckGroup[indexPath.section].id == CellularDataItemGroupID.IPCCCompatibility {
            cell.detailTextLabel?.numberOfLines = 0 // 允许换行
            if #available(iOS 13.0, *) {
                let detailText = NSMutableAttributedString()
                if let text = item.detailText {
                    detailText.append(NSAttributedString(string: text + " "))
                }
                switch item.id {
                case -1: detailText.append(UIUtils.sealWithQuestionMark(color: .systemOrange))
                case 0: detailText.append(UIUtils.sealWithRedXMark())
                case 1: detailText.append(UIUtils.sealWithGreenCheckmark())
                default: break
                }
                cell.detailTextLabel?.attributedText = detailText
            } else { // iOS 13以下 只显示结果文本
                cell.detailTextLabel?.text = (item.id == 1) ? NSLocalizedString("Compatible", comment: "") : NSLocalizedString("Incompatible", comment: "")
            }
        }
        
        // 安装此IPCC的Cell
        if compatibilityCheckGroup[indexPath.section].id == CellularDataItemGroupID.installIPCC {
            if item.id == ActionItemID.installSelectIPCCWithWarning || item.id == ActionItemID.installSelectIPCCUseComputerWithWarning {
                cell.textLabel?.textColor = .systemRed // 设置为红色按钮
                cell.selectionStyle = .default
            } else {
                cell.textLabel?.textColor = .systemBlue // 设置为蓝色按钮
                cell.selectionStyle = .default
            }
        }
        
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 获取数据
        let item = compatibilityCheckGroup[indexPath.section].items[indexPath.row]
        
        if item.id == ActionItemID.selectIPCCFile {
            // 打开文件选择器
            self.presentIPCCDocumentPicker()
        } else if item.id == ActionItemID.installSelectIPCC || item.id == ActionItemID.installSelectIPCCWithWarning {
            self.installSelectIPCCFile(item: item)
        } else if item.id == ActionItemID.installSelectIPCCUseComputer || item.id == ActionItemID.installSelectIPCCUseComputerWithWarning {
            UIUtils.showAlert(message: item.detailText ?? "", in: self)
        }
            
    }
    
    /// 外部调用：直接使用URL进行IPCC兼容性检测
    func handleExternalIPCCFile(path: URL) {
        // 确保在主线程 保证UI安全 延迟0.3s执行 让动画先放完 这样防止有时候UITableView不显示结果的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.checkIPCCFileCompatibilityAndShowResult(path: path)
        }
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
            
            // 文件已就绪，开始检测
            self.checkIPCCFileCompatibilityAndShowResult(path: url)
        }
        
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
            dropOverlayView = UIUtils.showDropOverlay(baseView: self.view, hintText: NSLocalizedString("DropToCheckIPCCFileCompatibility", comment: ""))
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
                    NSLog("[CellularInfo]<IPCC Drop to Check> loadFileRepresentation failed: \(error)")
                    return
                }

                guard let url = url else {
                    NSLog("[CellularInfo]<IPCC Drop to Check> nil file url")
                    return
                }

                self.handleDroppedFile(url, fileManager: fileManager, IPCCDir: IPCCDir)
            }
        } else {
            provider.loadFileRepresentation(forTypeIdentifier: "public.data") { url, error in
                if let error = error {
                    NSLog("[CellularInfo]<IPCC Drop to Check> loadFileRepresentation failed: \(error)")
                    return
                }

                guard let url = url else {
                    NSLog("[CellularInfo]<IPCC Drop to Check> nil file url")
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

            NSLog("[CellularInfo]<IPCC Drop to Check> copied to \(destURL)")

            DispatchQueue.main.async {
                self.checkIPCCFileCompatibilityAndShowResult(path: destURL)
            }

        } catch {
            NSLog("[CellularInfo]<IPCC Drop to Check> copy failed: \(error)")
        }
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
    
    /// 检测IPCC文件的兼容性 并且显示检测结果
    private func checkIPCCFileCompatibilityAndShowResult(path: URL) {
        do {
            compatibilityCheckGroup = CellularDataController.instance.getIPCCCompatibilityCheckBasicGroup() + (try IPCCManagerController.getIPCCCompatibilityCheckResult(path: path))
            tableView.reloadData()
            // 暂存下选择的文件Path用来准备给用户安装IPCC
            selectIPCCFilePath = path
            
            sendMessage(message: NSLocalizedString("CheckCompleted", comment: ""))
            
            // 轻微震动两下
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // 滚动到最底部
            DispatchQueue.main.async {
                let lastSection = self.tableView.numberOfSections - 1
                guard lastSection >= 0 else { return }
                let lastRow = self.tableView.numberOfRows(inSection: lastSection) - 1
                guard lastRow >= 0 else { return }

                let indexPath = IndexPath(row: lastRow, section: lastSection)
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
            
            
        } catch let error as NSError { // 显示异常
            UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription), in: self)
        }
    }
    
    private func installSelectIPCCFile(item: InfoItem) {
        
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: item.detailText,
            preferredStyle: .alert
        )
        
        // 继续 按钮 红色/蓝色
        let continueAction = UIAlertAction(title: NSLocalizedString("ContinueInstall", comment: ""), style: item.id == ActionItemID.installSelectIPCCWithWarning ? .destructive : .default) { _ in
            
            /// 跳转到IPCC管理界面去安装IPCC
            if let path = self.selectIPCCFilePath {
                let managerViewController = IPCCManagerViewController()
                managerViewController.installIPCCFileWithAfterCheckCompatibility(path: path)
                self.navigationController?.pushViewController(managerViewController, animated: true)
            }
            
        }

        // 关闭 按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(continueAction)
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
        
        // 播放动画
        tab.badgeShowMessage(message: message, stay: 1.5) {
            // 允许再次点击
        }
    }
}

