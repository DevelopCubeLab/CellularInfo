import Foundation
import UIKit

@available(iOS 14.0, *)
class ConfigureNetworkBandsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    /// 当前实际存在 Band 的网络制式分组
    private var visibleNetworkGroups: [BandRadioAccessTechnology] = []

    /// 固定的网络分组顺序
    private let networkGroups: [BandRadioAccessTechnology] = [
        .NR,
        .LTE,
        .WCDMA,
        .TD_SCDMA,
        .CDMA,
        .GSM
    ]
    
    private var tableView = UITableView()

    private var configureNetworkBandInfoGroup: [InfoItemGroup] = []
    
    /// 按照 5G / 4G / WCDMA / TD-SCDMA / CDMA / 2G 分组后的 UI 数据
    private var groupOptions: [BandRadioAccessTechnology: [Band]] = [:]
    
    /// fSupportedBands 只表示：「这个设备当前允许/支持哪些 Band」
    /// 这个字典不会被 UI 修改
    private var supportedBands: [String: Set<Int>] = [:]
    
    /// fActiveBands「当前 UI 中哪些 Band 是启用状态」
    /// 用户点击 Band、全选、取消全选时，只修改这个字典
    private var activeBands: [String: Set<Int>] = [:]

    /// 从 CoreTelephony 读取到的原始 CTBandInfo
    private var originalBandInfo: CTBandInfo?

    /// 加载数据时发生的错误
    private var loadingError: Error?

    /// 是否存在尚未保存的修改
    /// false：activeBands 与 Modem 当前状态一致
    /// true：用户修改过 activeBands，但还没有保存
    private var hasUnsavedChanges = false
    
    /// 存储是否可编辑，比如卡槽未启用或者无SIM卡不允许保存
    private var canEdit = false
    
    private let cellularDataController = CellularDataController.instance

    /// 当前操作的 SIM Slot
    private var slotID = 1
    
    private var slotSegmentedControl: UISegmentedControl!
    private var topContainerView: UIView!
    private var segmentedSeparator: UIView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("ConfigureNetworkBands", comment: "")

        view.backgroundColor = .systemBackground

        // 右上角的按钮
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem( // 保存按钮
                image: UIImage(systemName: "checkmark"),
                style: .done,
                target: self,
                action: #selector(onClickSaveBandsButton)
            ),
            UIBarButtonItem( // 刷新按钮
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain,
                target: self,
                action: #selector(onClickRefreshData)
            )
        ]

        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }

        tableView.delegate = self
        tableView.dataSource = self

        // 注册表格单元格
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(BandSelectionCell.self, forCellReuseIdentifier: BandSelectionCell.reuseIdentifier)

        tableView.translatesAutoresizingMaskIntoConstraints = false

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
        
        // 额外判断下双卡设备卡槽1未启用卡槽2启用的情况
        if slotCount > 1 {
            // 如果卡槽1未启用，卡槽2启用，则切换到卡槽2 否则还是保留在卡槽1
            if !cellularDataController.getDeviceSlotEnabled(slotID: 1) && cellularDataController.getDeviceSlotEnabled(slotID: 2) {
                slotID = 2
                slotSegmentedControl.selectedSegmentIndex = slotID - 1
            } else if cellularDataController.getDeviceSlotEnabled(slotID: 1) && cellularDataController.getDeviceSlotEnabled(slotID: 2) {
                // 如果卡1 卡2都启用了，则切换到首选流量卡的卡槽
                if cellularDataController.getDataPreferredSlotID() > 0 { // 防止无权限的情况
                    slotID = cellularDataController.getDataPreferredSlotID()
                    slotSegmentedControl.selectedSegmentIndex = slotID - 1
                }
            }
        }
        
        // 顶部选择器的容器View
        topContainerView = UIView()
        topContainerView.backgroundColor = .clear // 暂时不设置分组选择器容器的背景颜色
        topContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 分割线
        segmentedSeparator = UIView()
        segmentedSeparator.translatesAutoresizingMaskIntoConstraints = false
        segmentedSeparator.backgroundColor = .separator
        
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
        
//        // 显示进入的弹窗
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
        if !SettingsUtils.instance.getShowConfigureNetworkBands() {
            finish() // 退出当前界面
        }
#endif
        
        // 刷新数据
        reloadData()
    }

    deinit {
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
    
    /// CellularDataController 数据发生变化
    @objc private func onCellularDataRefresh() {
        reloadData()
    }

    /// 用户点击右上角刷新按钮
    @objc private func onClickRefreshData() {
        // 这里属于用户主动刷新。
        // 因此即使存在未保存修改，也允许重新从 Modem
        // 获取最新的 fActiveBands。
        if hasUnsavedChanges {
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("UnsavedChangesRefreshMessage", comment: ""),
                preferredStyle: .alert
            )

            // 确定按钮 红色
            let confirmAction = UIAlertAction(title: NSLocalizedString("RefreshAnyway", comment: ""), style: .destructive) { _ in
                self.reloadData(force: true)
                // 播放动画
                self.sendMessage(message: NSLocalizedString("Refreshed", comment: ""), stay: 0.5)
            }

            // 取消按钮 蓝色
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

            // 添加按钮，iOS 会自动按照规范排列
            alert.addAction(confirmAction)
            alert.addAction(cancelAction)

            // 显示弹窗
            present(alert, animated: true, completion: nil)
        } else {
            reloadData()
            // 播放动画
            self.sendMessage(message: NSLocalizedString("Refreshed", comment: ""), stay: 0.5)
        }
        
    }

    /// 切换卡槽信息
    @objc private func onSegmentChanged(_ sender: UISegmentedControl) {
        slotID = sender.selectedSegmentIndex + 1
        // 切换 SIM Slot 时，必须重新读取对应 Slot 的数据。
        reloadData(force: true)
    }

    /// 刷新数据
    /// force = 是否强制刷新数据
    private func reloadData(force: Bool = false) {

        // 获取基本信息
        configureNetworkBandInfoGroup = cellularDataController.getConfigureNetworkBandInfoGroup(slotID: slotID)
        
        // 判断是否允许编辑
        canEdit = cellularDataController.getDeviceSlotEnabled(slotID: slotID)
        
        // 设置右上角的保存按钮是否允许点击
        navigationItem.rightBarButtonItems?[0].isEnabled = canEdit
        
        if force {
            // 这一次 reload 是完整重新读取 Modem 状态，
            // 因此旧的未保存修改会被丢弃。
            hasUnsavedChanges = false
        }
        
        if hasUnsavedChanges == false { // 如果有未保存的频段信息则只刷新基本信息

            groupOptions.removeAll()
            visibleNetworkGroups.removeAll()
            supportedBands.removeAll()
            activeBands.removeAll()

            originalBandInfo = nil
            loadingError = nil
            
            do {
                // 获取 CTBandInfo
                let bandInfo = try cellularDataController.getSlotBandInfo(slotID: slotID)

                guard let bandInfo else {
                    return
                }
                
                originalBandInfo = bandInfo

                let activeDictionary = (bandInfo.fActiveBands as? [String: Any]) ?? [:]

                for (ratKey, values) in activeDictionary {
                    let numbers = (values as? [NSNumber] ?? [])
                    activeBands[ratKey] = Set(numbers.map(\.intValue))
                }

                /*
                 fSupportedBands：
                 当前设备允许显示/配置的 Band。
                 这里绝对不能把 SupportedBands 添加到 activeBands。
                 Supported ≠ Active。
                 Supported 只负责决定 UI 显示哪些按钮。
                 */
                let supportedDictionary = (bandInfo.fSupportedBands as? [String: Any]) ?? [:]

                for (ratKey, values) in supportedDictionary {

                    let bandValues = Set((values as? [NSNumber] ?? []).map(\.intValue))
                    supportedBands[ratKey] = bandValues

                    // 根据 SupportedBands 构建 UI
                    let rat = BandRadioAccessTechnology.from(key: ratKey)

                    guard networkGroups.contains(rat) else {
                        continue
                    }

                    groupOptions[rat, default: []].append(contentsOf: bandValues.map {
                        Band(rat: rat, value: $0)
                    })
                    
                }

                // 按照rat排序
                for group in networkGroups {
                    groupOptions[group]?.sort {
                        $0.value < $1.value
                    }
                }

                // 只显示实际存在 Band 的网络制式
                visibleNetworkGroups = networkGroups.filter {
                    guard let bands = groupOptions[$0] else {
                        return false
                    }

                    return !bands.isEmpty
                }

            } catch {
                loadingError = error
            }
        }
        
        // UI刷新
        tableView.reloadData()
    }

    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        if canEdit { // 已启用SIM卡的时候再允许编辑
            // 基本数据组数量+设置频段的组数量+2(保存+重设)
            return configureNetworkBandInfoGroup.count + visibleNetworkGroups.count + 2
        } else {
            return configureNetworkBandInfoGroup.count
        }
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < configureNetworkBandInfoGroup.count {
            return configureNetworkBandInfoGroup[section].items.count
        } else {
            return 1
        }
    }

    // MARK: 设置每一组Section的HeaderView
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        guard section >= configureNetworkBandInfoGroup.count else {
            return nil
        }

        let bandSection = section - configureNetworkBandInfoGroup.count

        guard bandSection < visibleNetworkGroups.count else {
            return nil
        }

        let group = visibleNetworkGroups[bandSection]

        let header = BandSectionHeaderView(reuseIdentifier: nil)

        header.titleLabel.text = group.displayName

        header.onSelectAll = { [weak self] in
            self?.selectAllBands(in: group)
        }

        header.onDeselectAll = { [weak self] in
            self?.deselectAllBands(in: group)
        }

        return header
    }

    // MARK: 设置Section的HeadView的高度
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // 选择频段的HeadView高度为40 其余section为系统默认
        if section >= configureNetworkBandInfoGroup.count && section < (configureNetworkBandInfoGroup.count + visibleNetworkGroups.count) {
            return 40
        }
        return UITableView.automaticDimension
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == configureNetworkBandInfoGroup.count + visibleNetworkGroups.count
            ? loadingError?.localizedDescription
            : nil
    }

    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section < configureNetworkBandInfoGroup.count { // 基本信息组
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
            // 获取数据
            let item = configureNetworkBandInfoGroup[indexPath.section].items[indexPath.row]
            cell.textLabel?.text = item.text
            cell.textLabel?.numberOfLines = 0 // 允许换行
            cell.selectionStyle = .none // 取消点击特效
            return cell
        } else if indexPath.section >= configureNetworkBandInfoGroup.count &&
                    indexPath.section < (configureNetworkBandInfoGroup.count + visibleNetworkGroups.count) { // 设置频段组
            // 设置频段的Cell
            let cell = tableView.dequeueReusableCell(withIdentifier: BandSelectionCell.reuseIdentifier, for: indexPath) as! BandSelectionCell

            let group = visibleNetworkGroups[indexPath.section - configureNetworkBandInfoGroup.count]

            /*
             options = SupportedBands
             activeBands = ActiveBands
             Cell 根据这两个数据决定：
             1. 显示哪些 Band
             2. 哪些 Band 显示为选中
             */
            cell.configure(options: groupOptions[group] ?? [], activeBands: activeBands)

            cell.onToggle = { [weak self] band in
                self?.toggleBands(band)
            }

            return cell
        } else if indexPath.section == (configureNetworkBandInfoGroup.count + visibleNetworkGroups.count) { // 最后一组是保存按钮
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
            cell.textLabel?.text = NSLocalizedString("Save", comment: "")
            cell.textLabel?.textColor = .systemBlue // 文本颜色为蓝色
            cell.textLabel?.textAlignment = .center // 文本在中间
            return cell
        }
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = NSLocalizedString("RestoreDefaultSettings", comment: "")
        cell.textLabel?.textColor = .systemRed // 文本颜色为红色
        cell.textLabel?.textAlignment = .center // 文本在中间
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == configureNetworkBandInfoGroup.count + visibleNetworkGroups.count { // 保存
            tableView.deselectRow(at: indexPath, animated: true)
            onClickSaveBandsButton()
        } else if indexPath.section == (configureNetworkBandInfoGroup.count + visibleNetworkGroups.count + 1) { // 恢复默认
            tableView.deselectRow(at: indexPath, animated: true)
            restoreDefaultActiveBands()
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

    /// 点击单个频段
    private func toggleBands(_ band: Band) {

        let ratKey = activeBands.keys.first {
            BandRadioAccessTechnology.from(key: $0) == band.rat
        }

        guard let ratKey else {
            return
        }

        var values = activeBands[ratKey, default: []]

        if values.contains(band.value) {
            // 当前已启用 → 删除
            values.remove(band.value)
        } else {
            // 当前未启用 → 添加
            values.insert(band.value)
        }

        activeBands[ratKey] = values

        // 用户已经修改了 ActiveBands
        hasUnsavedChanges = true

        tableView.reloadData()
    }
    
    /// 全选当前网络制式
    private func selectAllBands(in rat: BandRadioAccessTechnology) {

        for band in groupOptions[rat] ?? [] {

            guard let ratKey = supportedBands.keys.first(where: {
                BandRadioAccessTechnology.from(key: $0) == band.rat
            }) else {
                continue
            }

            activeBands[
                ratKey,
                default: []
            ].insert(band.value)
        }

        hasUnsavedChanges = true

        tableView.reloadData()
    }

    /// 取消当前网络制式的全部 Band
    private func deselectAllBands(in rat: BandRadioAccessTechnology) {

        for band in groupOptions[rat] ?? [] {

            guard let ratKey = supportedBands.keys.first(where: {
                BandRadioAccessTechnology.from(key: $0) == band.rat
            }) else {
                continue
            }

            activeBands[
                ratKey,
                default: []
            ].remove(band.value)
        }

        hasUnsavedChanges = true

        tableView.reloadData()
    }
    
    /// 点击保存网络频段设置的按钮
    @objc private func onClickSaveBandsButton() {
        
        if SettingsUtils.instance.getShowConfigureNetworkBandsAlert() { // 判断是否弹窗
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("SaveActiveBandsWarningMessage", comment: ""),
                preferredStyle: .alert
            )

            // 确定按钮 红色
            let confirmAction = UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .destructive) { _ in
                // 保存网络频段设置
                self.saveActiveBands()
            }
            
            // 不再提示 按钮
            let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .default) { _ in
                // 设置不再显示提示
                SettingsUtils.instance.setShowConfigureNetworkBandsAlert(show: false)
                // 保存网络频段设置
                self.saveActiveBands()
            }
            alert.addAction(disableAlertAction)

            // 取消按钮 蓝色
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

            // 添加按钮，iOS 会自动按照规范排列
            alert.addAction(confirmAction)
            alert.addAction(cancelAction)

            // 显示弹窗
            present(alert, animated: true, completion: nil)
        } else {
            // 保存网络频段设置
            self.saveActiveBands()
        }
    }
    
    /// 设置频段信息
    private func saveActiveBands() {
        
        let bandInfo = originalBandInfo
        
        guard let bandInfo else {
            return
        }
        // 从原始 ActiveBands 开始这样可以保证一些我们 UI 不认识的 RAT或者 SupportedBands 中不存在的内容，不会被意外删除。
        let updatedActiveBands = (bandInfo.fActiveBands.mutableCopy() as? NSMutableDictionary) ?? NSMutableDictionary()

        /*
         只处理 SupportedBands 中存在的 RAT。
         SupportedBands：决定哪些 Band 是我们可以修改的。
         ActiveBands：决定这些 Band 当前是否启用。
         */
        for ratKey in supportedBands.keys {

            let values = activeBands[ratKey, default: []].sorted()

            updatedActiveBands[ratKey] = NSMutableArray(array: values.map {
                NSNumber(value: $0)
            })
        }

        // 这里只修改 fActiveBands，fSupportedBands 完全不动。
        bandInfo.fActiveBands = updatedActiveBands

        do {

            // 提交给Controller层要求更改频段
            try cellularDataController.setSlotActiveBandInfo(slotID: slotID, bandInfo: bandInfo)
            // 保存完成 此时 UI 状态已经成功写入 Modem，所以不再存在未保存修改。
            hasUnsavedChanges = false
            // UI提示
            sendMessage(message: NSLocalizedString("AlreadySelected", comment: ""))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 延迟刷新 这样UI就不会已选/未选的频段CheckBox闪一下了
                self.reloadData() // 刷新数据
            }
        } catch {
            UIUtils.showAlert(message: error.localizedDescription, in: self)
        }
    }
    
    /// 恢复默认网络频段设置
    private func restoreDefaultActiveBands() {
        
        // 设置一个弹窗
        let alert = UIAlertController(
            title: NSLocalizedString("Alert", comment: ""),
            message: NSLocalizedString("RestoreDefaultActiveBandsWarningMessage", comment: ""),
            preferredStyle: .alert
        )

        // 确定按钮 红色
        let confirmAction = UIAlertAction(title: NSLocalizedString("Confirm", comment: ""), style: .destructive) { _ in
            if self.cellularDataController.restoreSlotActiveBand(slotID: self.slotID) {
                self.sendMessage(message: NSLocalizedString("DefaultNetworkBandRestored", comment: ""))
            } else {
                UIUtils.showAlert(message: NSLocalizedString("FailedRestoreDefaultNetworkBand", comment: ""), in: self)
            }
            self.reloadData(force: true)
        }

        // 关闭按钮 蓝色
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)

        // 添加按钮，iOS 会自动按照规范排列
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)

        // 显示弹窗
        present(alert, animated: true, completion: nil)
    }
    
    private func showEntryTipsAlert() {
        if SettingsUtils.instance.getShowConfigureNetworkBandsEntryTips() {
            // 强行不让View可以点击
            self.view.isUserInteractionEnabled = false
            // 设置一个弹窗
            let alert = UIAlertController(
                title: NSLocalizedString("Alert", comment: ""),
                message: NSLocalizedString("ConfigureNetworkBandsEntryTipsMessage", comment: ""),
                preferredStyle: .alert
            )
            
            // 继续 按钮
            let continueAction = UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .destructive) { _ in
                // 恢复View点击
                self.view.isUserInteractionEnabled = true
            }
            
            // 关闭 按钮
            let exitAction = UIAlertAction(title: NSLocalizedString("Exit", comment: ""), style: .cancel) { _ in
                SettingsUtils.instance.setShowConfigureNetworkBands(show: false) // 关闭进入权限
                self.finish() // 关闭当前界面
            }
            
            // 不再提示 按钮
            let disableAlertAction = UIAlertAction(title: NSLocalizedString("DontShowAgain", comment: ""), style: .default) { _ in
                // 设置不再显示提示
                SettingsUtils.instance.setShowConfigureNetworkBandsEntryTips(show: false)
                // 恢复View点击
                self.view.isUserInteractionEnabled = true
            }
            
            alert.addAction(disableAlertAction)
            alert.addAction(continueAction)
            alert.addAction(exitAction)
            
            // 显示弹窗
            self.present(alert, animated: true, completion: nil)
        }
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
