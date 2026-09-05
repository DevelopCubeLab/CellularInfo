import Foundation
import UIKit

class CellularDataController {
    
    // 单例实例
    static let instance = CellularDataController()
    
    static let cellularDataRefreshNotificationName = Notification.Name("CellularInfoDataRefreshUpdated")
    static let cellularDataItemUpdatedNotificationName = Notification.Name("CellularInfoItemUpdated")
    
    // 数据提供者的对象
    private let coreTelephonyController: CoreTelephonyController = CoreTelephonyController.instance
    
    private lazy var coreTelephonyCompatibleController: CoreTelephonyCompatibleController? = {
        if #available(iOS 15.0, *) {
            return CoreTelephonyCompatibleController.instance()
        } else {
            return nil
        }
    }()
    
    private let coreTelephonyNetworkInfoController = CoreTelephonyNetworkInfoController.instance
    private let cellularPlanController = CTCellularPlanController.instance
    private let deviceInfoController = MGDeviceInfoController.instance
    // IMEI数量
    private let IMEICount: Int
    // 设备是否支持蜂窝网络
    let deviceSupportsCellular: Bool
    // 设备类型 这个是从基带获取的 被hook的难度会增加
    private var deviceTypeBaseBand: UIUserInterfaceIdiom?
    // 获取设备是否支持安装eSIM 因为比较耗时 把结果保存
    private var allowInstallESIM: Bool = false
    private var hasAllowInstallESIMResult: Bool = false
    // 数据刷新的时间 防止短时间内频繁发送更新UI的通知
    private var lastNotifyTime: TimeInterval = 0
    
    // 私有构造函数
    private init() {
        // 两个渠道获取设备卡槽数量 先用CoreTelephony的
        if coreTelephonyController.getDeviceSlotCount() != 0 {
            IMEICount = coreTelephonyController.getDeviceSlotCount()
        } else { // 没有获取到再用MGDevice的
            IMEICount =  deviceInfoController.getIMEICount()
        }
        
        self.deviceSupportsCellular = coreTelephonyController.getDeviceSupportsCellular()
        
        // 监听 CoreTelephony 数据变化
        coreTelephonyController.onDataUpdated = { [weak self] in
            // 处理更新的通知
            self?.handleCellularDataUpdate()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startTimerIfNeeded),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopTimer),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
    }
    
    /// 销毁这个class的时候
    deinit {
        /// 销毁全部监听器
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 处理数据更新
    private func handleCellularDataUpdate() {
        if SettingsUtils.instance.getAutoRefreshData() { // 判断用户是否开启自动刷新功能
            let now = Date().timeIntervalSince1970
            if (now - lastNotifyTime) > 0.5 { // 做抖动处理 去除500ms内的频繁刷新请求
                DispatchQueue.main.async { // 保证在主线程的时候再发送通知
                    // 发送通知
                    NotificationCenter.default.post(name: Self.cellularDataRefreshNotificationName, object: nil)
                }
                // 保存当前的时间戳
                lastNotifyTime = now
            }
        }
    }
    
    /// 开启定时刷新
    @objc func startTimerIfNeeded() {
        // 判断用户是否开启自动刷新和定时刷新数据
        if SettingsUtils.instance.getAutoRefreshData() && SettingsUtils.instance.getTimedRefreshData() {
            coreTelephonyController.startRefreshDataTimer()
        } else {
            coreTelephonyController.stopRefreshDataTimer()
        }
    }

    // 关闭定时刷新
    @objc func stopTimer() {
        coreTelephonyController.stopRefreshDataTimer()
    }
    
    /// 获取设备的基本信息
    func getDeviceBasicInfo() -> InfoItem {
        var deviceBasicInfo = ""
        if !SystemInfoUtils.isRunningOniPadOS() {
            deviceBasicInfo = SystemInfoUtils.getDeviceName() + " " + SystemInfoUtils.getDiskTotalSpace() + " (" + String.localizedStringWithFormat(NSLocalizedString("iOSVersion", comment: ""), SystemInfoUtils.getSystemVersion()) + ")"
        } else {
            deviceBasicInfo = SystemInfoUtils.getDeviceName() + " " + SystemInfoUtils.getDiskTotalSpace() + " (" + String.localizedStringWithFormat(NSLocalizedString("iPadOSVersion", comment: ""), SystemInfoUtils.getSystemVersion()) + ")"
        }
        
        if let regionCode = SystemInfoUtils.getDeviceRegionCode() {
            deviceBasicInfo = deviceBasicInfo + " " + regionCode
        }
        
        return InfoItem(
            id: CommonItemID.deviceBasicInfo,
            text: deviceBasicInfo,
            isConfidential: false
        )
    }
    
    // 获取设备是iPhone还是iPad
    func getDeviceType() -> UIUserInterfaceIdiom? {
        if #available(iOS 15.0, *) {
            if deviceTypeBaseBand != nil { // 查询是否存在缓存
                return deviceTypeBaseBand
            } else {
                if let deviceType = coreTelephonyController.getDeviceType() {
                    self.deviceTypeBaseBand = deviceType // 缓存
                    return deviceType
                }
            }
        }
        return nil
    }
    
    /// 获取设备主板ID
    /// showFull = 是否显示完整的主板编号
    func getDeviceLogicBoardID(showFull: Bool = true) -> InfoItem {
        return InfoItem(
            id: CommonItemID.logicBoardID,
            text: String.localizedStringWithFormat(NSLocalizedString("LogicBoardID", comment: ""), showFull ? SystemInfoUtils.getHardwareModel() : SystemInfoUtils.getDeviceLogicBoardID()),
            detailText: showFull ? SystemInfoUtils.getHardwareModel() : SystemInfoUtils.getDeviceLogicBoardID(),
            copyable: true
        )
    }
    
    /// 获取设备是否支持蜂窝网络
    func getDeviceSupportsCellular() -> InfoItem {
        return InfoItem(
            id: CoreTelephonyItemID.supportsCellular,
            text: String.localizedStringWithFormat(NSLocalizedString("SupportsCellular", comment: ""),
                                                   coreTelephonyController.getDeviceSupportsCellular() ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
        )
    }
    
    /// 获取设备卡槽数量
    /// 无需额外权利即可获取
    func getSlotCount() -> Int {
        return coreTelephonyNetworkInfoController.getDeviceSlotCount()
    }
    
    /// 获取IMEI数量
    func getIMEICount() -> Int {
        return IMEICount
    }
    
    /// 获取启用的SIM卡数量
    func getEnableSIMCount() -> Int {
        do {
            return try coreTelephonyController.getActiveContexts().count
        } catch {
            return 0
        }
    }
    
    // 获取设备卡槽是否未启用
    func getDeviceSlotEnabled(slotID: Int) -> Bool {
        
        if slotID < 0 || slotID > 2 { // 去除不存在的卡槽情况
            return false
        }
        if slotID > getSlotCount() { // 查询的卡槽位不能超过设备卡槽数量
            return false
        }
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
            return getSlotEnableSIM(context: context)
        }
        return false
    }
    
    // 获取当前首选卡槽的ID
    func getDataPreferredSlotID() -> Int {
        do {
            return Int(try coreTelephonyController.getDataPreferredSlotID())
        } catch {
            return -1
        }
    }
    
    /// 获取运营商锁状态
    func getDeviceCarrierLockState() -> InfoItem? {
        do {
            if #available(iOS 14.0, *) { // 高版本系统直接从CoreTelephony里面获取
                let lockState = try coreTelephonyController.getDeviceCarrierLockState()
                let lockStateText: String
                switch lockState {
                case 0:
                    if deviceTypeBaseBand == .pad { // 额外判断下iPad
                        lockStateText = NSLocalizedString("Unknown", comment: "未知").appending(" (").appending(NSLocalizedString("NotSupportedOniPad", comment: "")).appending(")")
                    } else {
                        lockStateText = NSLocalizedString("Unknown", comment: "未知")
                    }
                case 1: lockStateText = NSLocalizedString("Unlocked", comment: "")
                case 2: lockStateText = NSLocalizedString("Locked", comment: "")
                case -1: lockStateText = NSLocalizedString("CurrentOSVersionNotSupported", comment: "") // 这个状态时自己加的，未来提供一个备用查询方法 失败了 暂时没有替代方法
                default: lockStateText = String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), String(lockState))
                }
                return InfoItem(
                    id: CoreTelephonyItemID.carrierLock,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierLock", comment: ""), lockStateText)
                )
            } else {
                return nil
                // 低版本系统用RootHelper读取基带配置文件
                // 很遗憾 低版本无该字段 无法判断
//                return InfoItem(
//                    id: CoreTelephonyItemID.carrierLock,
//                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierLock", comment: ""),
//                                                           try BaseBandServiceController.getDeviceCarrierLockState() ?
//                                                           NSLocalizedString("Locked", comment: "") :
//                                                            NSLocalizedString("Unlocked", comment: ""))
//                )
            }
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.carrierLock,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierLock", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取设备是否支持5G
    func getDeviceSupports5G() -> InfoItem {
        // TODO 未来的iOS系统版本如果淘汰了iPhone 11系列，那么iPhone全系都是支持5G的了，直接返回true，iPad的情况有些复杂有待观察
        
        if AppCapability.hasCommCenterSPI() { // 因为查询API在无权限时不抛异常，因此只能手动判断了
            return InfoItem(
                id: CoreTelephonyItemID.supports5G,
                text: String.localizedStringWithFormat(NSLocalizedString("Supports5G", comment: ""), try! coreTelephonyController.getDeviceSupports5G() ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
            )
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.supports5G,
                text: String.localizedStringWithFormat(NSLocalizedString("Supports5G", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取设备双卡能力
    private func getDualSimCapability() -> InfoItem {
        
        do {
            let dualSimCapability: String
            switch try coreTelephonyController.getDeviceDualSimCapability() {
            case 0: dualSimCapability = NSLocalizedString("NoPermission", comment: "")
            case 2: dualSimCapability = NSLocalizedString("DualSIM", comment: "")
            case 3: dualSimCapability = NSLocalizedString("SingleSIM", comment: "")
            case 4: dualSimCapability = NSLocalizedString("Checking", comment: "") // 基带服务重启中会导致返回这个结果
            default: dualSimCapability = NSLocalizedString("Unknown", comment: "") + "(\(try! coreTelephonyController.getDeviceDualSimCapability()))"
            }
            return InfoItem(
                id: CoreTelephonyItemID.dualSimCapability,
                text: String.localizedStringWithFormat(NSLocalizedString("DualSimCapability", comment: ""), dualSimCapability)
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.dualSimCapability,
                    text: String.localizedStringWithFormat(NSLocalizedString("DualSimCapability", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else if error.code == 19 { // 设备不支持
                return InfoItem(
                    id: CoreTelephonyItemID.dualSimCapability,
                    text: String.localizedStringWithFormat(NSLocalizedString("DualSimCapability", comment: ""), NSLocalizedString("DeviceNotSupported", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.dualSimCapability,
                    text: String.localizedStringWithFormat(NSLocalizedString("DualSimCapability", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                )
            }
        }
    }
    
    /// 获取SIM卡槽状态
    private func getSIMTrayStatus() -> InfoItem {
        do {
            let status = try coreTelephonyController.getDeviceSIMTrayStatus()
            
            let SIMTrayStatusText: String
            switch CoreTelephonyEnumMapper.mapSIMTrayStatus(status) {
            case .absent:
                if let onlyESIM = try? coreTelephonyController.getDeviceIsEmbeddedSIMOnlyDevice() { // 这里判断下是不是纯eSIM机型
                    SIMTrayStatusText = onlyESIM ? NSLocalizedString("AbsentSIMTray", comment: "") : NSLocalizedString("SIMTrayNotInserted", comment: "")
                } else {
                    SIMTrayStatusText = NSLocalizedString("Unknown", comment: "未知")
                }
            case .noSIM:
                SIMTrayStatusText = NSLocalizedString("NoSIM", comment: "")
            case .withSIM:
                SIMTrayStatusText = NSLocalizedString("WithSIM", comment: "")
            case .unknown:
                SIMTrayStatusText = NSLocalizedString("Unknown", comment: "未知")
            }
            
            return InfoItem(
                id: CoreTelephonyItemID.SIMTrayStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMTrayStatus", comment: ""), SIMTrayStatusText)
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.SIMTrayStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMTrayStatus", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取是否有SIM卡已就绪
    func getDeviceIsAnySIMReadyInfo() -> InfoItem {
        do {
            let ready = try getDeviceIsAnySIMReady()
            return InfoItem(
                id: CoreTelephonyItemID.anySIMReady,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMReady", comment: ""), ready ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        } catch let error as NSError {
            if error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyItemID.anySIMReady,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMReady", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.anySIMReady,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMReady", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                )
            }
        }
    }
    
    /// 获取是否有SIM卡已就绪
    /// 已经行低版本兼容设计
    func getDeviceIsAnySIMReady() throws -> Bool {
        if #available(iOS 16.4, *) {
            return try coreTelephonyController.getDeviceIsAnySIMReady()
        } else { // 手动做个低版本兼容
            let contextList = try coreTelephonyController.getActiveContexts() // 获取所有活跃的context
            for context in contextList { // 遍历所有context
                let SIMStatus = try coreTelephonyController.getSlotSIMStatus(context: context) // 获取SIM卡状态
                let status = CoreTelephonyEnumMapper.mapSIMStatus(SIMStatus)
                if status.isReady { // 如果有一个已就绪的则返回
                    return true
                }
            }
        }
        return false
    }
    
    /// 获取SIM卡槽状态
    private func getEmbeddedSIMOnlyDevice() -> InfoItem {
        do {
            let embeddedSIMOnlyDevice = try coreTelephonyController.getDeviceIsEmbeddedSIMOnlyDevice()
            return InfoItem(
                id: CoreTelephonyItemID.embeddedSIMOnlyDevice,
                text: String.localizedStringWithFormat(NSLocalizedString("EmbeddedSIMOnlyDevice", comment: ""), embeddedSIMOnlyDevice ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.embeddedSIMOnlyDevice,
                text: String.localizedStringWithFormat(NSLocalizedString("EmbeddedSIMOnlyDevice", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取设备是否支持eSIM
    private func getSupportsEmbeddedSIM() -> InfoItem {
        
        if AppCapability.hasCommCenterPublicCellularPlan() { // 因为查询API在无权限时不抛异常，因此只能手动判断了
            // 有 SPI 权利或 public-cellular-plan 权利都可以获取正确的数据
            return InfoItem(
                id: CoreTelephonyItemID.supportsEmbeddedSIM,
                text: String.localizedStringWithFormat(NSLocalizedString("SupportsEmbeddedSIM", comment: ""),
                                                       coreTelephonyController.getDeviceSupportsEmbeddedSIM() ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
            )
        } else { // 证书签名的话需要 public-cellular-plan 权利
            if #available(iOS 16.0, *) {
                return InfoItem(
                    id: CoreTelephonyItemID.supportsEmbeddedSIM,
                    text: String.localizedStringWithFormat(NSLocalizedString("SupportsEmbeddedSIM", comment: ""), NSLocalizedString("NeedPublicCellularPlanEntitlements", comment: "")),
                    hintText: NSLocalizedString("PublicCellularPlanEntitlementsHint", comment: "")
                )
            } else { // 低版本系统+无权限
                return InfoItem(
                    id: CoreTelephonyItemID.supportsEmbeddedSIM,
                    text: String.localizedStringWithFormat(NSLocalizedString("SupportsEmbeddedSIM", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
    }
    
    /// 获取设备是否开启 允许切换蜂窝数据
    private func getDeviceDynamicDataSimSwitchState() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let enabled = try coreTelephonyController.getDeviceDynamicDataSimSwitchEnabled()
                return InfoItem(
                    id: CoreTelephonyItemID.dynamicDataSimSwitch,
                    text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitch", comment: ""), enabled ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 45 { // iOS 13+单卡设备不支持/iPad蜂窝版不支持
                    return InfoItem(
                        id: CoreTelephonyItemID.dynamicDataSimSwitch,
                        text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitch", comment: ""), NSLocalizedString("DeviceNotSupported", comment: ""))
                    )
                } else { // 例如 13 错误 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.dynamicDataSimSwitch,
                        text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitch", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                }
                
            }
        } else {
            return nil
        }
    }
    
    /// 获取设备是否开启 允许在通话时切换蜂窝数据
    private func getDeviceDynamicDataSimSwitchOnCallState() -> InfoItem {
        do {
            let enabled = try coreTelephonyController.getDeviceDynamicDataSimSwitchOnCallEnabled()
            return InfoItem(
                id: CoreTelephonyItemID.dynamicDataSimSwitchOnCall,
                text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitchOnCall", comment: ""), enabled ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
            )
        } catch let error as NSError {
            if error.code == 45 {
                return InfoItem(
                    id: CoreTelephonyItemID.dynamicDataSimSwitchOnCall,
                    text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitchOnCall", comment: ""), NSLocalizedString("DeviceNotSupported", comment: ""))
                )
            } else { // 例如 13 错误 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.dynamicDataSimSwitchOnCall,
                    text: String.localizedStringWithFormat(NSLocalizedString("DynamicDataSimSwitchOnCall", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
    }
    
    /// 获取设备是否启用工厂测试模式
    private func getDeviceFactoryDebugEnabled() -> InfoItem? {
        if #available(iOS 15.4, *) {
            do {
                return InfoItem(
                    id: CoreTelephonyItemID.factoryDebugMode,
                    text: String.localizedStringWithFormat(NSLocalizedString("FactoryDebugMode", comment: ""), try coreTelephonyController.getDeviceFactoryDebugEnabled() ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: "")),
                    hintText: NSLocalizedString("FactoryDebugModeHit", comment: ""),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.factoryDebugMode,
                    text: String.localizedStringWithFormat(NSLocalizedString("FactoryDebugMode", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("FactoryDebugModeHit", comment: ""),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取设备是否是RC版固件
    func getDeviceReleaseCandidateFlag() -> InfoItem? {
        if #available(iOS 15.4, *) {
            return InfoItem(
                id: CoreTelephonyItemID.releaseCandidate,
                text: String.localizedStringWithFormat(NSLocalizedString("BasebandReleaseCandidateFlag", comment: ""), coreTelephonyController.getDeviceReleaseCandidateFlag() ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                hintText: NSLocalizedString("BasebandReleaseCandidateFlagHint", comment: "")
            )
        }
        return nil
    }
    
    /// 获取设备eSIM健康状态
    private func getEmbeddedSIMHealth() -> InfoItem? {
        if #available(iOS 16.0, *) {
            
            do {
                let result = try coreTelephonyController.checkDeviceEmbeddedSIMHealth()
                return InfoItem(
                    id: CoreTelephonyItemID.supportsEmbeddedSIM,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmbeddedSIMHealth", comment: ""),
                                                           result ? NSLocalizedString("Healthy", comment: "") : NSLocalizedString("IssueDetected", comment: ""))
                )
            } catch { // 抛异常=不支持或者无权限直接不显示这一行
                return nil
            }
        }
        return nil
    }
    
    /// 获取设备是否可以转移蜂窝数据套餐
    func getDeviceCellularPlanTransferable() -> InfoItem {
        if #available(iOS 13.0, *) {
            do {
                let transferable = try coreTelephonyController.getDeviceCellularPlanTransferable()
                return InfoItem(
                    id: CoreTelephonyItemID.cellularPlanTransferable,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanTransferCapability", comment: ""), transferable ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 1 || error.code == 13 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularPlanTransferable,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanTransferCapability", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else if error.code == 19 || error.code == 4099 { // 设备不支持
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularPlanTransferable,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanTransferCapability", comment: ""), NSLocalizedString("DeviceNotSupported", comment: ""))
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularPlanTransferable,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanTransferCapability", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
            }
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.cellularPlanTransferable,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanTransferCapability", comment: ""), NSLocalizedString("CurrentOSVersionNotSupported", comment: ""))
            )
        }
    }
    
    /// 获取设备是否支持安装eSIM 同步方法 很卡 用异步方法替代
    @available(*, deprecated, message: "Use getAllowInstallEmbeddedSIMItem(onUpdate: @escaping (InfoItem) -> Void) instead")
    private func getAllowInstallEmbeddedSIM() -> InfoItem {
        return InfoItem(
            id: CoreTelephonyItemID.allowInstallEmbeddedSIM,
            text: String.localizedStringWithFormat(NSLocalizedString("AllowInstallEmbeddedSIM", comment: ""),
                                                   coreTelephonyController.getDeviceAllowInstallEmbeddedSIM() ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")),
            hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "")
        )
    }
    
    /// 获取设备是否支持安装 eSIM（异步）
    /// - Parameter onUpdate: 异步拿到结果后回调一个“更新后的 InfoItem”，由 UI 去替换并刷新
    func getAllowInstallEmbeddedSIMItem(onUpdate: @escaping (InfoItem) -> Void) -> InfoItem {
        
        // 1. 先看下有没有缓存
        if hasAllowInstallESIMResult {
            // 判断是否有权限
            if !AppCapability.hasCommCenterPublicCellularPlan() {
                return InfoItem(
                    id: CoreTelephonyItemID.allowInstallEmbeddedSIM,
                    text: String.localizedStringWithFormat(
                        NSLocalizedString("AllowInstallEmbeddedSIM", comment: ""), NSLocalizedString("NeedPublicCellularPlanEntitlements", comment: "")
                    ),
                    hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "").appending("\n\n").appending(NSLocalizedString("PublicCellularPlanEntitlementsHint", comment: ""))
                )
            }
            // 有缓存直接返回缓存的数据
            return InfoItem(
                id: CoreTelephonyItemID.allowInstallEmbeddedSIM,
                text: String.localizedStringWithFormat(
                    NSLocalizedString("AllowInstallEmbeddedSIM", comment: ""),
                    allowInstallESIM ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")
                ),
                hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "")
            )
            
        }
        
        // 2. 先给 UI 一个占位，避免卡顿
        let placeholder = InfoItem(
            id: CoreTelephonyItemID.allowInstallEmbeddedSIM,
            text: String.localizedStringWithFormat(
                NSLocalizedString("AllowInstallEmbeddedSIM", comment: ""),
                NSLocalizedString("Checking", comment: "")
            ),
            hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "")
        )
        
        // 3. 异步查询
        coreTelephonyController.getDeviceAllowInstallEmbeddedSIM {  [weak self] allowed in
            
            guard let self = self else {
                return
            }
            
            // 设置缓存
            self.allowInstallESIM = allowed
            self.hasAllowInstallESIMResult = true
            
            let updated = InfoItem(
                id: CoreTelephonyItemID.allowInstallEmbeddedSIM,
                text: String.localizedStringWithFormat(
                    NSLocalizedString("AllowInstallEmbeddedSIM", comment: ""),
                    allowed ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")
                ),
                hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "")
            )
            
            // 更新item
            onUpdate(updated)
        }
        
        return placeholder
    }
    
    /// 获取设备的蜂窝数据是否已开启
    /// 无权限也能获取正确结果
    func getDeviceCellularDataEnabled() -> InfoItem {
        do {
            let enabled = try coreTelephonyController.getCellularDataEnabled()
            return InfoItem(
                id: CoreTelephonyItemID.cellularDataEnabled,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), enabled ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.cellularDataEnabled,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
            )
        }
    }
    
    // 获取蜂窝网络连接可用性
    func getInternetConnectionAvailability() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let availability = try coreTelephonyController.getDeviceInternetConnectionAvailability()
                let availabilityText: String
                if availability.available && availability.csiError == 0 {
                    availabilityText = NSLocalizedString("Connected", comment: "")
                } else {
                    switch availability.csiError {
                    case -1: availabilityText = NSLocalizedString("CellularDataDisabled", comment: "")
                    case -2: availabilityText = NSLocalizedString("DataRoamingDisabled", comment: "")
                    case -3: availabilityText = NSLocalizedString("Checking", comment: "") // TODO 暂时不知道这个具体含义 短暂出现 使用 检查中占位
                    case -5: availabilityText = NSLocalizedString("NotConnected", comment: "")
                    case 1, 24: availabilityText = NSLocalizedString("SwitchingCellularData", comment: "")
                    case 94: availabilityText = NSLocalizedString("ManuallySelectNetwork", comment: "")
                    default: availabilityText = String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), String(availability.csiError))
                    }
                }
                return InfoItem(
                    id: CoreTelephonyItemID.cellularDataConnectionAvailability,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularDataConnection", comment: ""), availabilityText),
                    isConfidential: false
                )
            } catch let error as NSError { // 无权限
                if error.code == 13 {
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularDataConnectionAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularDataConnection", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                        isConfidential: false
                    )
                } else if error.code == 35 { // 基带服务重启中
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularDataConnectionAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularDataConnection", comment: ""), NSLocalizedString("Checking", comment: "")), // 使用获取中占位
                        isConfidential: false
                    )
                } else if error.code == 19 { // 模拟器/无蜂窝网络模块设备
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularDataConnectionAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularDataConnection", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")),
                        isConfidential: false
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID.cellularDataConnectionAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularDataConnection", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)")),
                        isConfidential: false
                    )
                }
                
            }
        } else {
            return nil
        }
    }
    
    /// 获取首选网络卡槽选择的网络类型
    func getPreferredDataSelectRateInfo() -> InfoItem? {
        do {
            let context = try coreTelephonyController.getDataPreferredContext()
            return InfoItem(
                id: CommonItemID.dataSIMNetworkType,
                text: String.localizedStringWithFormat(NSLocalizedString("DataSIMNetworkType", comment: ""), getRateText(radioGeneration: getSlotSelectRate(context: context), indicator4GText: coreTelephonyController.getSlot4GIndicatorText(context: context)))
            )
        } catch {
            return nil
        }
    }
    
    /// 获取首选蜂窝网络卡信息
    func getPreferredDataSlotInfo() -> InfoItem? {
        do {
            let context = try coreTelephonyController.getDataPreferredContext()
            if let label = context.label {// 不能强制解包 否则iOS 14以下设备闪退 获取不到label
                // 单卡或者iPad蜂窝版显示的Label是有问题的，所以隐藏掉
                if (try? coreTelephonyController.getSlotShortLabelText(context: context)) == nil { // 通过这个方法排除iPad或者纯单卡槽的机器
                    return InfoItem(
                        id: CommonItemID.preferredDataSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("PreferredDataSlot", comment: ""), String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), context.slotID))
                    )
                } else {
                    return InfoItem(
                        id: CommonItemID.preferredDataSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("PreferredDataSlotNumber", comment: ""), context.slotID, label)
                    )
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    /// 获取首选默认语音通话卡信息
    /// iPad蜂窝版不支持 错误代码 35
    /// 无权限抛异常 错误代码 1
    func getDefaultVoiceSlotInfo() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let context = try coreTelephonyController.getUserDefaultVoiceSubscriptionContext()
                // 默认语音号码获取到的context数据不全，需要靠别的API获取
                do {
                    // 用这个判断设备是否允许使用标签 但是不用他的数据，因为这个数据是短的Label 不全
                    let _ = try coreTelephonyController.getSlotShortLabelText(context: context)
                    // 从这里获取的才是全的
                    let labelText = try coreTelephonyController.getSlotLabelText(context: context)
                    return InfoItem(
                        id: CommonItemID.defaultVoiceSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoiceSlot", comment: ""), String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), context.slotID), labelText)
                    )
                } catch { // 抛异常=不支持标签 所以直接不显示标签
                    return InfoItem(
                        id: CommonItemID.defaultVoiceSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), context.slotID))
                    )
                }
                
            } catch let error as NSError {
                if error.code == 1 || error.code == 13 {
                    return InfoItem(
                        id: CommonItemID.defaultVoiceSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else if error.code == 35 { // iPad 蜂窝版不支持
                    return nil
                } else {
                    return InfoItem(
                        id: CommonItemID.defaultVoiceSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                    )
                }
            }
        } else { // 手动兼容下iOS 12
            do {
                let contextInfo = try coreTelephonyController.getActiveContextsInfo()
                if let voicePreferred = contextInfo.voicePreferred {
                    let slotNumber = voicePreferred.uuidString.last.map { String($0) } ?? NSLocalizedString("Unknown", comment: "未知")
                    return InfoItem(
                        id: CommonItemID.defaultVoiceSlot,
                        text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), String.localizedStringWithFormat(NSLocalizedString("SlotNumberText", comment: ""), slotNumber))
                    )
                }
            } catch {
                return InfoItem(
                    id: CommonItemID.defaultVoiceSlot,
                    text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取设备是否开启数据漫游
    func getDeviceEnableDataRoaming() -> InfoItem {
        do {
            let enable = try coreTelephonyController.getDeviceEnableDataRoaming()
            return InfoItem(
                id: CoreTelephonyItemID.dataRoaming,
                text: String.localizedStringWithFormat(NSLocalizedString("DataRoaming", comment: ""), enable ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: "")),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.dataRoaming,
                text: String.localizedStringWithFormat(NSLocalizedString("DataRoaming", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取基带芯片组的唯一标识符
    func getBasebandUniqueID() -> InfoItem {
        if let basebandUniqueID = deviceInfoController.getBasebandUniqueId() {
            return InfoItem(
                id: MGDeviceInfoItemID.baseBandUniqueID,
                text: String.localizedStringWithFormat(NSLocalizedString("BasebandUniqueID", comment: ""), basebandUniqueID),
                detailText: basebandUniqueID, // 放到detail里面方便来复制
                isConfidential: true,
                copyable: true
            )
        } else {
            return InfoItem(
                id: MGDeviceInfoItemID.baseBandUniqueID,
                text: String.localizedStringWithFormat(NSLocalizedString("BasebandUniqueID", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                isConfidential: false
            )
        }
    }
    
    // 获取设备基带(调制解调器)固件版本号
    func getDeviceModemFirmwareVersion() -> InfoItem {
        do {
            if let version = try coreTelephonyController.getDeviceModemFirmwareVersion() {
                return InfoItem(
                    id: CommonItemID.modemFirmware,
                    text: String.localizedStringWithFormat(NSLocalizedString("ModemFirmware", comment: ""), version),
                    detailText: version,
                    copyable: true
                )
            } else {
                return InfoItem(
                    id: CommonItemID.modemFirmware,
                    text: String.localizedStringWithFormat(NSLocalizedString("ModemFirmware", comment: ""), NSLocalizedString("NotObtained", comment: ""))
                )
            }
        } catch {
            return InfoItem(
                id: CommonItemID.modemFirmware,
                text: String.localizedStringWithFormat(NSLocalizedString("ModemFirmware", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取IMEI 1
    func getIMEI1() -> InfoItem {
        
        // 双重获取渠道 先从CoreTelehony获取，如果获取不到再去MGDevice获取
        let IMEI1 = coreTelephonyController.getDeviceIMEI1() ?? deviceInfoController.getIMEI1()
        
        let value = IMEI1 ?? NSLocalizedString("NotObtained", comment: "")
        
        return InfoItem(
            id: CommonItemID.IMEI1,
            text: String.localizedStringWithFormat(NSLocalizedString("IMEI1", comment: ""), value),
            detailText: IMEI1, // 放到detail里面方便来复制
            isConfidential: IMEI1 != nil,
            copyable: IMEI1 != nil
        )
    }
    
    /// 获取IMEI 2
    /// 不一定存在 比如老款设备XS之前的设备，还有CH/A的 XS、SE 2、SE 3、12 mini、13 mini，还有蜂窝版iPad
    func getIMEI2() -> InfoItem? {
        
        let IMEI2 = coreTelephonyController.getDeviceIMEI2() ?? deviceInfoController.getIMEI2()
        
        if let IMEI2 = IMEI2 {
            return InfoItem(
                id: CommonItemID.IMEI2,
                text: String.localizedStringWithFormat(NSLocalizedString("IMEI2", comment: ""), IMEI2),
                detailText: IMEI2, // 放到detail里面方便来复制
                isConfidential: true,
                copyable: true
            )
        } else {
            return nil
        }
    }
    
    /// 获取MEID
    /// 不一定存在 iPhone 14系列开始就不再支持CDMA了，所以没有，其次是iPad这些还有两网老机型
    func getMEID() -> InfoItem? {
        let MEID = coreTelephonyController.getDeviceMEID() ?? deviceInfoController.getMEID()
        
        if let MEID = MEID {
            return InfoItem(
                id: CommonItemID.MEID,
                text: String.localizedStringWithFormat(NSLocalizedString("MEID", comment: ""), MEID),
                detailText: MEID, // 放到detail里面方便来复制
                isConfidential: true,
                copyable: true
            )
        } else {
            return nil
        }
    }
    
    /// 获取EID
    /// 不支持eSIM的设备没有
    /// 拆掉eSIM芯片的的设备没有EID
    /// 已更换为没有EID的设备不显示EID这一行，不然有些奇怪
    func getEID() -> InfoItem? {
        let EID = coreTelephonyController.getDeviceEID() ?? deviceInfoController.getEID()
        
        if let EID = EID {
            return InfoItem(
                id: CommonItemID.EID,
                text: String.localizedStringWithFormat(NSLocalizedString("EID", comment: ""), EID),
                detailText: EID, // 放到detail里面方便来复制
                isConfidential: true,
                copyable: true
            )
        } else {
//            return InfoItem(
//                id: CommonItemID.EID,
//                text: String.localizedStringWithFormat(NSLocalizedString("EID", comment: ""), NSLocalizedString("NotObtained", comment: ""))
//            )
            return nil
        }
    }
    
    /// 获取设备是否开启iCloud Private Relay iCloud专用代理
    private func getDeviceEnablediCloudPrivateRelay() -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                if let descriptor = coreTelephonyController.getServiceDescriptor(slotID: 1) { // 直接拿卡槽1的描述 这样处理是防止模拟器闪退
                    return InfoItem(
                        id: CommonItemID.privateRelay,
                        text: String.localizedStringWithFormat(NSLocalizedString("PrivateRelayStatus", comment: ""), try coreTelephonyController.getSlotPrivacyProxyState(descriptor: descriptor).privateRelayEnabled.boolValue ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
                    )
                }
                
            } catch {
                return InfoItem(
                    id: CommonItemID.privateRelay,
                    text: String.localizedStringWithFormat(NSLocalizedString("PrivateRelayStatus", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
            
        }
        return nil
    }
    
    /// 获取当前首选卡槽的网络类型
    func getDataPreferenceSlotRadioAccessTechnology() -> CoreTelephonyEnumMapper.RadioGeneration {
        do {
            let dataPrefContext = try coreTelephonyController.getDataPreferredContext()
            return getSlotRadioAccessTechnologyGeneration(context: dataPrefContext)
        } catch {
            return .unknown
        }
    }
    
    /// 获取设备支持的5G SA频率范围
    func getDevicePublicNrFrequencyRange() -> InfoItem? {
        if #available(iOS 15.0, *) {
            if getDataPreferenceSlotRadioAccessTechnology() == ._5G { // 只有5G才显示
                let range = coreTelephonyNetworkInfoController.getDeviceNrFrequencyRange()
                let rangeText: String
                
                switch range {
                case "CTNrFrequencyRangeSub6": rangeText = NSLocalizedString("NRSub6", comment: "")
                case "CTNrFrequencyRangeMmWave": rangeText = NSLocalizedString("NRMmWave", comment: "")
                case "CTNrFrequencyRangeSub6AndMmWave": rangeText = NSLocalizedString("NRSub6AndMmWave", comment: "")
                case "CTNrFrequencyRangeUnknown": rangeText = NSLocalizedString("Unknown", comment: "未知")
                default: return nil
                }
                return InfoItem(
                    id: CoreTelephonyItemID.NrFrequencyRange,
                    text: String.localizedStringWithFormat(NSLocalizedString("NrFrequencyRange", comment: ""), rangeText),
                    hintText: NSLocalizedString("NrFrequencyRangeHint", comment: "")
                )
            }
        }
        
        return nil
    }
    
    /// 获取设备是否开启蜂窝数据用量统计数据
    func getDeviceMobileDataUsageCollectionEnabled() -> InfoItem? {
        if #available(iOS 17.0, *) {
            do {
                let enabled = try coreTelephonyController.getDeviceMobileDataUsageCollectionEnabled()
                return InfoItem(
                    id: CoreTelephonyItemID.mobileDataUsageCollection,
                    text: String.localizedStringWithFormat(NSLocalizedString("MobileDataUsageCollectionStatistics", comment: ""), enabled ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.mobileDataUsageCollection,
                    text: String.localizedStringWithFormat(NSLocalizedString("MobileDataUsageCollectionStatistics", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取设备是否支持切换2G网络
    func getDevice2GSwitchEnabled() -> InfoItem? {
        if #available(iOS 17.0, *) {
            do {
                let enabled = try coreTelephonyController.getDevice2GSwitchEnabled()
                return InfoItem(
                    id: CoreTelephonyItemID.allow2GSwitch,
                    text: String.localizedStringWithFormat(NSLocalizedString("Allow2GSwitch", comment: ""), enabled ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.allow2GSwitch,
                    text: String.localizedStringWithFormat(NSLocalizedString("Allow2GSwitch", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 用户是否允许使用2G网络
    func getDevice2GUserPreference() -> InfoItem? {
        if #available(iOS 17.0, *) {
            do {
                let enabled = try coreTelephonyController.getDevice2GUserPreference()
                return InfoItem(
                    id: CoreTelephonyItemID.userEnabled2G,
                    text: String.localizedStringWithFormat(NSLocalizedString("Use2GNetwork", comment: ""), enabled ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.userEnabled2G,
                    text: String.localizedStringWithFormat(NSLocalizedString("Use2GNetwork", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
            
        }
        return nil
    }
    
    /// 获取设备是否支持专用承载
    /// 不知道什么意思
    func getDeviceSupportedDedicatedBearer() -> InfoItem {
        if #available(iOS 15.0, *) {
            return InfoItem(
                id: CoreTelephonyItemID.supportedDedicatedBearer,
                text: String.localizedStringWithFormat(NSLocalizedString("DedicatedBearer", comment: ""), coreTelephonyController.getDeviceDedicatedBearerSupported() ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: "")),
                hintText: !AppCapability.hasCommCenterSPI() ? NSLocalizedString("DataInaccurate", comment: "") : nil // 无权限时数据不一定准确
            )
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.supportedDedicatedBearer,
                text: String.localizedStringWithFormat(NSLocalizedString("DedicatedBearer", comment: ""), NSLocalizedString("NotSupported", comment: "")),
            )
        }
    }
    
    /// 获取设备的卡NAT 保活时间 单位s
    func getDeviceNATTKeepAliveOverCell() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let keepAliveInterval = try coreTelephonyController.getDeviceNATTKeepAliveOverCell()
                return InfoItem(
                    id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                    text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), String.localizedStringWithFormat(NSLocalizedString("TimeSeconds", comment: ""), keepAliveInterval)),
                    hintText: NSLocalizedString("NATKeepAliveIntervalHint", comment: "")
                )
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                        text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else if error.code == 35 { // 无SIM卡 / 未启用SIM卡
                    return InfoItem(
                        id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                        text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                    )
                } else if error.code == 19 { // 模拟器/无蜂窝网络模块设备 不支持
                    return InfoItem(
                        id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                        text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), NSLocalizedString("DeviceNotSupported", comment: ""))
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                        text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取设备当前是否允许开启个人热点
    func getDeviceHotspotAvailable() -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let tetheringStatusInfo = try coreTelephonyController.getDeviceTetheringStatusInfo()
                if let carrierEnabled = tetheringStatusInfo.carrierEnabled { // 这里必须要判断是否为nil 否则运营商不允许使用热点的情况下会导致闪退
                    if let userAuthenticated = tetheringStatusInfo.userAuthenticated {
                        let availableText: String
                        if !carrierEnabled.boolValue {
                            availableText = NSLocalizedString("CarrierRestricted", comment: "")
                        } else if !userAuthenticated.boolValue {
                            availableText = NSLocalizedString("HotspotNotAuthenticated", comment: "")
                        } else {
                            availableText = NSLocalizedString("Allowed", comment: "")
                        }
                        return InfoItem(
                            id: CoreTelephonyItemID.hotspotAvailability,
                            text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), availableText)
                        )
                    } else { // 有卡但是运营商不允许
                        // 判断是否无SIM卡
                        if getEnableSIMCount() == 0 {
                            return InfoItem(
                                id: CoreTelephonyItemID.hotspotAvailability,
                                text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                            )
                        }
                        return InfoItem(
                            id: CoreTelephonyItemID.hotspotAvailability,
                            text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("CarrierRestricted", comment: ""))
                        )
                    }
                } else { // 无SIM卡 / 未启用SIM卡
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                    )
                }
                
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else if error.code == 35 { // 基带服务重启中
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("Checking", comment: "")) // 使用获取中占位
                    )
                } else if error.code == 19 { // 模拟器/无蜂窝网络模块设备
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")) // 设备不支持
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotAvailability,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotAvailability", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取用户是否开启个人热点
    func getDeviceHotspotEnabled() -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let tetheringStatusInfo = try coreTelephonyController.getDeviceTetheringStatusInfo()
                if let _ = tetheringStatusInfo.carrierEnabled {
                    if let enabled = tetheringStatusInfo.asserted { // 这里必须要判断是否为nil 否则运营商不允许使用热点的情况下会导致闪退
                        return InfoItem(
                            id: CoreTelephonyItemID.hotspotEnabled,
                            text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), enabled.boolValue ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
                        )
                    } else { // 运营商不允许
                        // 判断是否无SIM卡
                        if getEnableSIMCount() == 0 {
                            return InfoItem(
                                id: CoreTelephonyItemID.hotspotEnabled,
                                text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                            )
                        }
                        return InfoItem(
                            id: CoreTelephonyItemID.hotspotEnabled,
                            text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("CarrierRestricted", comment: ""))
                        )
                    }
                } else { // 无SIM卡 / 未启用SIM卡
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotEnabled,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                    )
                }
                
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotEnabled,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else if error.code == 35 { // 基带服务重启中
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotEnabled,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("Checking", comment: "")) // 使用获取中占位
                    )
                } else if error.code == 19 { // 模拟器/无蜂窝网络模块设备
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotEnabled,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")) // 设备不支持
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID.hotspotEnabled,
                        text: String.localizedStringWithFormat(NSLocalizedString("PersonalHotspotEnabled", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
                
            }
            
        }
        return nil
    }
    
    /// 获取设备允许的紧急呼叫号码列表
    func getDeviceEmergencyTextNumbers() -> InfoItem? {
        if #available(iOS 16.0, *) {
            do {
                let numbers = try coreTelephonyController.getDeviceAllEmergencyTextNumbers()
                let numbersText = numbers.isEmpty
                ? NSLocalizedString("Empty", comment: "") // 空白列表
                : numbers.joined(separator: ", ") // 非空列表 添加断开的符号,
                return InfoItem(
                    id: CoreTelephonyItemID.emergencyTextNumbers,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyTextNumbers", comment: ""), numbersText),
                    isConfidential: false
                )
            } catch { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.emergencyTextNumbers,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyTextNumbers", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
            
        } else {
            return nil
        }
    }
    
    /// 获取设备是否需要显示eSIM旅行提示
    func getDeviceShouldShowEmbeddedSIMTravelTips() -> InfoItem? {
        if #available(iOS 17.0, *) {
            do {
                let result = try coreTelephonyController.getDeviceShouldShowEmbeddedSIMTravelTip()
                return InfoItem(
                    id: CoreTelephonyItemID.shouldShowEmbeddedSIMTravelTips,
                    text: String.localizedStringWithFormat(NSLocalizedString("ShouldShowEmbeddedSIMTravelTips", comment: ""), result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.shouldShowEmbeddedSIMTravelTips,
                    text: String.localizedStringWithFormat(NSLocalizedString("ShouldShowEmbeddedSIMTravelTips", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取设备是否需要显示加载设置eSIM界面
    func getDeviceNeedToLaunchSetUpEmbeddedSIM() -> InfoItem? {
        if #available(iOS 16.0, *) {
            do {
                let result = try coreTelephonyController.getDeviceNeedToLaunchSetUpEmbeddedSIM()
                return InfoItem(
                    id: CoreTelephonyItemID.needToLaunchSetUpEmbeddedSIM,
                    text: String.localizedStringWithFormat(NSLocalizedString("NeedToLaunchSetUpEmbeddedSIM", comment: ""), result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.needToLaunchSetUpEmbeddedSIM,
                    text: String.localizedStringWithFormat(NSLocalizedString("ShouldShowEmbeddedSIMTravelTips", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取设备是否正在使用内置eSIM服务
    func getDeviceUsingBootstrapDataService() -> InfoItem? {
        if #available(iOS 16.0, *) {
            if coreTelephonyController.getDeviceSupportsEmbeddedSIM() { // 设备必须支持eSIM才有意义
                do {
                    let result = try coreTelephonyController.getDeviceUsingBootstrapDataService()
                    return InfoItem(
                        id: CoreTelephonyItemID.bootstrapDataService,
                        text: String.localizedStringWithFormat(NSLocalizedString("UsingEmbeddedSIMDownloadService", comment: ""), result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                        hintText: NSLocalizedString("UsingEmbeddedSIMDownloadServiceHint", comment: ""),
                        isConfidential: false
                    )
                } catch let error as NSError {
                    return InfoItem(
                        id: CoreTelephonyItemID.bootstrapDataService,
                        text: String.localizedStringWithFormat(NSLocalizedString("UsingEmbeddedSIMDownloadService", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                        hintText: NSLocalizedString("UsingEmbeddedSIMDownloadServiceHint", comment: ""),
                        isConfidential: false
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取设备是否支持Hydra
    func getDeviceSupportsHydra() -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let supports = try coreTelephonyController.getDeviceSupportsHydra()
                return InfoItem(
                    id: CoreTelephonyItemID.supportsHydra,
                    text: String.localizedStringWithFormat(NSLocalizedString("SupportsHydra", comment: ""), supports ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 1 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.supportsHydra,
                        text: String.localizedStringWithFormat(NSLocalizedString("SupportsHydra", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyItemID.supportsHydra,
                        text: String.localizedStringWithFormat(NSLocalizedString("SupportsHydra", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取SIM卡槽状态
    /// 返回文本
    /// Apple SIM仍然判断为 EmbeddedSIM 已进行详细判断
    func getSlotSIMType(context: CTXPCServiceSubscriptionContext) -> String {
        do {
            let SIMType = try coreTelephonyController.getSlotSIMType(context: context)
            let SIMTypeText: String
            switch SIMType {
            case 0:
                if AppCapability.hasCommCenterSPI() {
                    SIMTypeText = NSLocalizedString("Checking", comment: "") // 有SPI权限但是基带服务正在重启，使用获取中占位
                } else { // 无权限
                    SIMTypeText = NSLocalizedString("NoPermission", comment: "")
                }
            case 1: SIMTypeText = NSLocalizedString("PhysicalSIM", comment: "")
            case 2:
                if deviceTypeBaseBand == .pad { // 判断下 Apple SIM
                    if cellularPlanController.getPlanIsAppleSIM(ICCID: try? coreTelephonyController.getSlotICCID(context: context)) { // Apple SIM
                        SIMTypeText = "Apple SIM"
                    } else { // eSIM
                        SIMTypeText = NSLocalizedString("EmbeddedSIM", comment: "")
                    }
                } else { // eSIM
                    SIMTypeText = NSLocalizedString("EmbeddedSIM", comment: "")
                }
            default: SIMTypeText = NSLocalizedString("Unknown", comment: "未知")
            }
            return SIMTypeText
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 { // 无权限
                return NSLocalizedString("NoPermission", comment: "")
            } else { // 未知错误
                return String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)")
            }
            
        }
    }
    
    /// 获取SIM卡类型
    func getSlotSIMTypeInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        return InfoItem(
            id: CommonItemID.SIMType,
            text: String.localizedStringWithFormat(NSLocalizedString("SIMType", comment: ""), getSlotSIMType(context: context)),
            isConfidential: false
        )
    }
    
    /// 获取卡槽标签
    func getSlotLabel(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if (try? coreTelephonyController.getSlotShortLabelText(context: context)) == nil { // 通过这个方法排除iPad或者纯单卡槽的机器
            return nil
        }
        do {
            let label = try coreTelephonyController.getSlotLabelText(context: context)
            //            if label.hasPrefix("USER_LABEL") { // 过滤掉系统内置的标签占位，相当于没设置标签，但是可能会出现误伤
            //                return nil
            //            }
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), label),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), NSLocalizedString("NotSet", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽发行卡的运营商名称
    /// iOS 16.4+如果无权限返回 --
    func getSlotCarrierName(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let carrierName = try coreTelephonyController.getSlotCarrierName(context: context) {
                return InfoItem(
                    id: CommonItemID.carrierName,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), carrierName.isEmpty ? NSLocalizedString("UnknownCarrier", comment: "") : carrierName),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CommonItemID.carrierName,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                    isConfidential: false
                )
            }
        } catch {
            return InfoItem(
                id: CommonItemID.carrierName,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), NSLocalizedString("NoSIM", comment: "")),
                isConfidential: false
            )
        }
        
    }
    
    /// 获取卡槽当前网络运营商名称
    func getSlotOperatorName(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 16.0, *) {
            do {
                let operatorName = try coreTelephonyController.getSlotOperatorName(context: context)
                return InfoItem(
                    id: CommonItemID.operatorName,
                    text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), operatorName),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CommonItemID.operatorName,
                    text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽当前连接的网络名称
    func getSlotLocalizedOperatorName(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let operatorName = try coreTelephonyController.getSlotLocalizedOperatorName(context: context)
            return InfoItem(
                id: CommonItemID.operatorName,
                text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), operatorName.isEmpty ? NSLocalizedString("NoService", comment: "") : operatorName), // 这里如果是获取到空字符串就是无服务
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CommonItemID.operatorName,
                text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽连接的网络的英文名称
    func getSlotOperatorEnglishName(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let operatorName = try coreTelephonyController.getSlotLocalizedOperatorName(context: context)
                let EnglishName = try coreTelephonyController.getSlotEnglishCarrierName(operatorName: operatorName)
                return InfoItem(
                    id: CommonItemID.operatorName,
                    text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), EnglishName.isEmpty ? NSLocalizedString("NoService", comment: "") : EnglishName),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CommonItemID.operatorName,
                    text: String.localizedStringWithFormat(NSLocalizedString("OperatorName", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡的电话号码
    func getSlotPhoneNumber(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do { // 有时候  coreTelephonyController.getSlotPhoneNumber 获取不到手机号，先用完整版context直接拿，如果拿不到再去用API获取
                if let phoneNumber = context.phoneNumber {
                    return InfoItem(
                        id: CommonItemID.phoneNumber,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), phoneNumber.isEmpty ? NSLocalizedString("NotSet", comment: "") : phoneNumber),
                        isConfidential: !phoneNumber.isEmpty
                    )
                    
                } else {
                    let phoneNumber = try coreTelephonyController.getSlotPhoneNumber(context: context)
                    return InfoItem(
                        id: CommonItemID.phoneNumber,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), phoneNumber.isEmpty ? NSLocalizedString("NotSet", comment: "") : phoneNumber),
                        isConfidential: !phoneNumber.isEmpty
                    )
                }
                
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CommonItemID.phoneNumber,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                        isConfidential: false
                    )
                } else {
                    return InfoItem(
                        id: CommonItemID.phoneNumber,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                        isConfidential: false
                    )
                }
            }
        } else { // 兼容下iOS 12
            if let phoneNumber = context.phoneNumber {
                return InfoItem(
                    id: CommonItemID.phoneNumber,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), phoneNumber.isEmpty ? NSLocalizedString("NotSet", comment: "") : phoneNumber),
                    isConfidential: !phoneNumber.isEmpty
                )
            } else {
                return InfoItem(
                    id: CommonItemID.phoneNumber,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), NSLocalizedString("NotSet", comment: "")),
                    isConfidential: false
                )
            }
        }
        
    }
    
    /// 获取卡槽的卡是否允许编辑电话号码
    func getSlotPhoneNumberEditable(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let editable = try coreTelephonyController.getSlotPhoneNumberEditable(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.phoneNumberEditable,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberEditable", comment: ""), editable ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")),
                    isConfidential: false
                )
            } catch let error as NSError {
                if error.code == 2 { // 当前卡槽没有卡
                    return InfoItem(
                        id: CoreTelephonyItemID.phoneNumberEditable,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberEditable", comment: ""), NSLocalizedString("NoSIM", comment: "")),
                        isConfidential: false
                    )
                } else if error.code == 13 {
                    return InfoItem(
                        id: CoreTelephonyItemID.phoneNumberEditable,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberEditable", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                        isConfidential: false
                    )
                } else { // 其他错误
                    return InfoItem(
                        id: CoreTelephonyItemID.phoneNumberEditable,
                        text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberEditable", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                        isConfidential: false
                    )
                }
                
            }
        } else {
            return nil
        }
        
    }
    
    /// 获取卡槽中的SIM卡的ICCID
    private func getSlotICCID(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let ICCID = try coreTelephonyController.getSlotICCID(context: context) {
                return InfoItem(
                    id: CommonItemID.ICCID,
                    text: String.localizedStringWithFormat(NSLocalizedString("ICCID", comment: ""), ICCID.isEmpty ? NSLocalizedString("None", comment: "") : ICCID),
                    isConfidential: true
                )
            } else {
                return InfoItem(
                    id: CommonItemID.ICCID,
                    text: String.localizedStringWithFormat(NSLocalizedString("ICCID", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    isConfidential: true
                )
            }
            
        } catch {
            return InfoItem(
                id: CommonItemID.ICCID,
                text: String.localizedStringWithFormat(NSLocalizedString("ICCID", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: true
            )
        }
    }
    
    /// 获取卡槽中的SIM卡正在使用的IMEI
    private func getSlotUseIMEI(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let IMEI = try coreTelephonyController.getSlotUseIMEI(context: context)
            return InfoItem(
                id: CommonItemID.useIMEI,
                text: String.localizedStringWithFormat(NSLocalizedString("UseIMEI", comment: ""), IMEI),
                isConfidential: true
            )
        } catch {
            return InfoItem(
                id: CommonItemID.useIMEI,
                text: String.localizedStringWithFormat(NSLocalizedString("UseIMEI", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
        
    }
    
    /// 获取卡槽中的SIM卡的TAC
    private func getSlotUseTypeAllocationCode(context: CTXPCServiceSubscriptionContext, descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let TAC = try coreTelephonyController.getSlotUseTypeAllocationCode(descriptor: descriptor)
                return InfoItem(
                    id: CommonItemID.useTypeAllocationCode,
                    text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), TAC),
                    hintText: NSLocalizedString("DeviceTypeAllocationCodeHint", comment: ""),
                    isConfidential: true
                )
            } catch let error as NSError {
                do {
                    if error.code == 13 { // 无SPI权限
                        let TAC = try coreTelephonyController.getSlotUseTypeAllocationCode(context: context)
                        return InfoItem(
                            id: CommonItemID.useTypeAllocationCode,
                            text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), TAC),
                            hintText: NSLocalizedString("DeviceTypeAllocationCodeHint", comment: ""),
                            isConfidential: true
                        )
                    } else {
                        return InfoItem(
                            id: CommonItemID.useTypeAllocationCode,
                            text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                        )
                    }
                } catch {
                    return InfoItem(
                        id: CommonItemID.useTypeAllocationCode,
                        text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                }
            }
        } else {
            do {
                let TAC = try coreTelephonyController.getSlotUseTypeAllocationCode(context: context)
                return InfoItem(
                    id: CommonItemID.useTypeAllocationCode,
                    text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), TAC),
                    hintText: NSLocalizedString("DeviceTypeAllocationCodeHint", comment: ""),
                    isConfidential: true
                )
            } catch {
                return InfoItem(
                    id: CommonItemID.useTypeAllocationCode,
                    text: String.localizedStringWithFormat(NSLocalizedString("DeviceTypeAllocationCode", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        
    }
    
    
    
    /// 获取卡槽中的SIM卡IMSI
    private func getSlotIMSI(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let IMSI = try coreTelephonyController.getSlotIMSI(context: context)
            return InfoItem(
                id: CommonItemID.IMSI,
                text: String.localizedStringWithFormat(NSLocalizedString("IMSI", comment: ""), IMSI.isEmpty ? NSLocalizedString("None", comment: "") : IMSI),
                isConfidential: true,
                copyable: false
            )
        } catch let error as NSError {
            if error.code == 2 { // 无SIM卡
                return InfoItem(
                    id: CommonItemID.IMSI,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSI", comment: ""), NSLocalizedString("NoSIM", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 1 || error.code == 13 { // 无权限
                return InfoItem(
                    id: CommonItemID.IMSI,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSI", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else { // 其他错误
                return InfoItem(
                    id: CommonItemID.IMSI,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSI", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    isConfidential: false
                )
            }
            
        }
        
    }
    
    /// 获取卡槽中的SIM卡的GID 1
    private func getSlotGID1(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let GID1 = try coreTelephonyController.getSlotGID1(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("GID1", comment: ""), GID1.isEmpty ? NSLocalizedString("None", comment: "") : GID1),
                detailText: GID1,
                isConfidential: false,
                copyable: true
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("GID1", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽中的SIM卡的GID 2
    private func getSlotGID2(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let GID2 = try coreTelephonyController.getSlotGID2(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("GID2", comment: ""), GID2.isEmpty ? NSLocalizedString("None", comment: "") : GID2),
                detailText: GID2,
                isConfidential: false,
                copyable: true
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("GID2", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 判断当前卡槽是否有卡
    func getSlotEnableSIM(context: CTXPCServiceSubscriptionContext) -> Bool {
        guard let raw = try? coreTelephonyController.getSlotSIMStatus(context: context) else {
            return false
        }
        
        switch CoreTelephonyEnumMapper.mapSIMStatus(raw) {
        case .ready,
                .inserted,
                .pinLocked,
                .pukLocked,
                .corporateLocked,
                .networkLocked,
                .operatorLocked,
                .operatorSubsetLocked,
                .serviceProviderLocked:
            return true
        case .notInserted,
                .notReady,
                .memoryFailure,
                .permanentlyLocked:
            return false
        case .unknown:
            return false
        }
    }
    
    /// 获取卡槽中的SIM卡是否工作良好
    func getSlotsSIMGood(fullyContext: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            if fullyContext.label != nil { // 通过判断label是否为nil来确定context是否是完整版的context
                return InfoItem(
                    id: CoreTelephonyItemID.SIMGood,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMHealth", comment: ""), fullyContext.isSimGood ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽中的SIM卡是否已插入
    func getSlotsSIMPresent(fullyContext: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if fullyContext.label != nil { // 通过判断label是否为nil来确定context是否是完整版的context
            return InfoItem(
                id: CoreTelephonyItemID.SIMPresent,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMPresent", comment: ""), fullyContext.isSimPresent ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        }
        return nil
    }
    
    /// 获取SIM卡状态
    func getSlotSIMStatus(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let SIMStatus = try coreTelephonyController.getSlotSIMStatus(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.SIMStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMStatus", comment: ""), localizedSIMStatusText(status: CoreTelephonyEnumMapper.mapSIMStatus(SIMStatus))),
                isConfidential: false
            )
        } catch {
            let text: String
            if SettingsUtils.instance.getShowInactiveSIMSlotsData() {
                text = NSLocalizedString("NoPermission", comment: "")
            } else {
                text = NSLocalizedString("NoPermission", comment: "").appending(" ").appending(String.localizedStringWithFormat(NSLocalizedString("EnableSettingsHint", comment: ""), NSLocalizedString("ShowInactiveSIMSlotsData", comment: "")))
            }
            return InfoItem(
                id: CoreTelephonyItemID.SIMStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMStatus", comment: ""), text),
                isConfidential: false
            )
        }
    }
    
    /// 判断设备是无SIM卡还是无eSIM卡还是未启用卡
    /// 1. 是否是iOS 14.0以下设备
    /// 1. 判断是否为纯eSIM设备
    /// 2. 判断蜂窝数据卡数量
    /// 3. 进行分析
    func getSlotNotInsertedSIMStatus(context: CTXPCServiceSubscriptionContext) -> CoreTelephonyEnumMapper.NotInsertedSIMStatus {
        if #available(iOS 14.0, *) {
            let cellularPlanCount = cellularPlanController.getCellularPlanCount()
            do {
                let eSIMOnly = try coreTelephonyController.getDeviceIsEmbeddedSIMOnlyDevice()
                if eSIMOnly { // 纯eSIM机型
                    if cellularPlanCount == 0 { // 无eSIM
                        return .noEmbeddedSIM
                    } else { // 未启用蜂窝数据卡
                        return .noEnableSIM
                    }
                }
            } catch {
                //
            }
        } else {
            return .unknown
        }
        
        return .unknown
    }
    
    /// 获取SIM卡状态的描述文本
    func localizedSIMStatusText(status: CoreTelephonyEnumMapper.SIMStatus) -> String {
        switch status {
            
        case .ready:
            return NSLocalizedString("SIMStatusReady", comment: "SIM ready")
        case .notInserted:
            // TODO 判断下是无SIM还是未启用SIM卡
            return NSLocalizedString("SIMStatusNotInserted", comment: "SIM not inserted")
        case .inserted:
            return NSLocalizedString("SIMStatusInserted", comment: "SIM inserted but not ready")
        case .notReady:
            return NSLocalizedString("SIMStatusNotReady", comment: "SIM not ready")
        case .pinLocked:
            return NSLocalizedString("SIMStatusPINLocked", comment: "SIM PIN locked")
        case .pukLocked:
            return NSLocalizedString("SIMStatusPUKLocked", comment: "SIM PUK locked")
        case .permanentlyLocked:
            return NSLocalizedString("SIMStatusPermanentlyLocked", comment: "SIM permanently locked")
        case .corporateLocked:
            return NSLocalizedString("SIMStatusCorporateLocked", comment: "SIM corporate locked")
        case .networkLocked:
            return NSLocalizedString("SIMStatusNetworkLocked", comment: "SIM network locked")
        case .operatorLocked:
            return NSLocalizedString("SIMStatusOperatorLocked", comment: "SIM operator locked")
        case .operatorSubsetLocked:
            return NSLocalizedString("SIMStatusOperatorSubsetLocked", comment: "SIM operator subset locked")
        case .serviceProviderLocked:
            return NSLocalizedString("SIMStatusServiceProviderLocked", comment: "SIM service provider locked")
        case .memoryFailure:
            return NSLocalizedString("SIMStatusMemoryFailure", comment: "SIM memory failure")
        case .unknown(let raw):
            return raw ?? NSLocalizedString("Unknown", comment: "未知")
            
        }
    }
    
    /// 获取SIM卡注册状态
    func getSlotRegistrationStatus(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let RegistrationStatus = try coreTelephonyController.getSlotRegistrationStatus(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.registrationStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("RegistrationStatus", comment: ""), localizedRegistrationStatusText(status: CoreTelephonyEnumMapper.mapRegistrationStatus(RegistrationStatus))),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.registrationStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("RegistrationStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    func localizedRegistrationStatusText(status: CoreTelephonyEnumMapper.RegistrationStatus) -> String {
        switch status {
            
        case .registeredHome:
            return NSLocalizedString("RegistrationRegisteredHome", comment: "已注册（本地网络）")
        case .registeredRoaming:
            return NSLocalizedString("RegistrationRegisteredRoaming", comment: "已注册（漫游网络）")
        case .notRegistered:
            return NSLocalizedString("RegistrationNotRegistered", comment: "未注册")
        case .searching:
            return NSLocalizedString("RegistrationSearching", comment: "搜索网络中")
        case .denied:
            return NSLocalizedString("RegistrationDenied", comment: "网络拒绝注册")
        case .emergencyOnly:
            return NSLocalizedString("RegistrationEmergencyOnly", comment: "仅限紧急呼叫")
        case .modemRestart:
            return NSLocalizedString("Checking", comment: "") // 基带服务重启中
        case .unknown(let raw):
            return raw ?? NSLocalizedString("Unknown", comment: "未知")
            
        }
    }
    
    /// 获取卡槽中的SIM卡所在的位置
    func getSlotSIMLocation(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let SIMLocation = try coreTelephonyController.getSlotSIMLocation(context: context)
                let SIMLocationText: String
                switch SIMLocation {
                case 0: SIMLocationText = NSLocalizedString("Checking", comment: "") // 基带服务重启中 使用获取中占位
                case 1: SIMLocationText = NSLocalizedString("LocationFront", comment: "")
                case 2: SIMLocationText = NSLocalizedString("LocationBack", comment: "")
                case 3:
                    if deviceTypeBaseBand == .pad { // 判断下 Apple SIM
                        if cellularPlanController.getPlanIsAppleSIM(ICCID: try? coreTelephonyController.getSlotICCID(context: context)) { // Apple SIM
                            SIMLocationText = "Apple SIM " + NSLocalizedString("Chip", comment: "")
                        } else { // eSIM
                            SIMLocationText = NSLocalizedString("LocationESIM", comment: "")
                        }
                    } else { // eSIM
                        SIMLocationText = NSLocalizedString("LocationESIM", comment: "")
                    }
                default: SIMLocationText = String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), String(SIMLocation))
                }
                return InfoItem(
                    id: CoreTelephonyItemID.SIMLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMLocation", comment: ""), SIMLocationText),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.SIMLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMLocation", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取当前卡槽的卡是否为默认数据卡
    func getSlotIsPreferredData(fullyContext: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if let result = fullyContext.userDataPreferred {
            return InfoItem(
                id: CommonItemID.preferredDataSlot,
                text: String.localizedStringWithFormat(NSLocalizedString("ActiveDataPlan", comment: ""), result.boolValue ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        }
        return nil
    }
    
    /// 获取当前卡槽的卡是否为默认语音
    func getSlotIsDefaultVoice(fullyContext: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if let result = fullyContext.userDefaultVoice {
            return InfoItem(
                id: CommonItemID.preferredDataSlot,
                text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), result.boolValue ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        }
        return nil
    }
    
    // 是否使用本地网络策略，大部分情况下理解成是否在漫游就好了
    func getSlotUseHomeNetworkPolicy(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let inHome = try coreTelephonyController.getSlotIsInHomeCountryNetworkPolicy(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.useHomeNetworkPolicy,
                text: String.localizedStringWithFormat(NSLocalizedString("UseHomeNetworkPolicy", comment: ""), inHome ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                hintText: NSLocalizedString("UseHomeNetworkPolicyHint", comment: ""),
                isConfidential: false
            )
        } catch { // 无权限时
            do { // 使用替代方案 为无权限设备做兼容
                return InfoItem(
                    id: CoreTelephonyItemID.useHomeNetworkPolicy,
                    text: String.localizedStringWithFormat(NSLocalizedString("UseHomeNetworkPolicy", comment: ""), try coreTelephonyController.getSlotIsInHomeCountryNetwork(context: context) ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                    hintText: NSLocalizedString("UseHomeNetworkPolicyHint", comment: ""),
                    isConfidential: false
                )
                
            } catch { // 仍然没获取到
                return InfoItem(
                    id: CoreTelephonyItemID.useHomeNetworkPolicy,
                    text: String.localizedStringWithFormat(NSLocalizedString("UseHomeNetworkPolicy", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("UseHomeNetworkPolicyHint", comment: ""),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取移动网络标识（PLMN）
    func getSlotPLMNInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let PLMN = try coreTelephonyController.getSlotPLMN(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.PLMN,
                    text: String.localizedStringWithFormat(NSLocalizedString("PLMN", comment: ""), PLMN.isEmpty ? NSLocalizedString("NotObtained", comment: "") : PLMN),
                    hintText: NSLocalizedString("PLMNHint", comment: ""),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.PLMN,
                    text: String.localizedStringWithFormat(NSLocalizedString("PLMN", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PLMNHint", comment: ""),
                    isConfidential: false
                )
            }
        } else { // 手动兼容下iOS 12
            do {
                let MCC = try coreTelephonyController.getSlotServingMCC(context: context)
                let MNC = try coreTelephonyController.getSlotServingMNC(context: context)
                let PLMN = MCC + MNC // 手动拼接
                return InfoItem(
                    id: CoreTelephonyItemID.PLMN,
                    text: String.localizedStringWithFormat(NSLocalizedString("PLMN", comment: ""), PLMN.isEmpty ? NSLocalizedString("NotObtained", comment: "") : PLMN),
                    hintText: NSLocalizedString("PLMNHint", comment: ""),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.PLMN,
                    text: String.localizedStringWithFormat(NSLocalizedString("PLMN", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PLMNHint", comment: ""),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽连接的移动网络国家代码
    func getSlotServingMCCInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let MCC = try coreTelephonyController.getSlotServingMCC(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.servingMCC,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingMCC", comment: ""), MCC == "65535" ? NSLocalizedString("NotObtained", comment: "") : MCC),
                hintText: NSLocalizedString("MCCHint", comment: ""),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.servingMCC,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingMCC", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("MCCHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽最后一次连接的移动网络国家代码
    func getSlotLastRegisteredNetworkMCCInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let MCC = try coreTelephonyController.getSlotLastKnownMCC(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.lastKnownMCC,
                    text: String.localizedStringWithFormat(NSLocalizedString("LastRegisteredNetworkMCC", comment: ""), MCC == "65535" || MCC.isEmpty ? NSLocalizedString("NotObtained", comment: "") : MCC),
                    hintText: NSLocalizedString("MCCHint", comment: ""),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.lastKnownMCC,
                    text: String.localizedStringWithFormat(NSLocalizedString("LastRegisteredNetworkMCC", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("MCCHint", comment: ""),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
        
    }
    
    /// 获取当前卡槽的SIM卡的MCC
    func getSlotSIMCardMCCInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let MCC = try coreTelephonyController.getSlotSIMCardMCC(context: context)
            // MCC 不能为空或者65535
            return InfoItem(
                id: CoreTelephonyItemID.simCardMCC,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMCardMCC", comment: ""), MCC == "65535" || MCC.isEmpty ? NSLocalizedString("NotObtained", comment: "") : MCC),
                hintText: NSLocalizedString("MCCHint", comment: ""),
                isConfidential: MCC == "65535" || MCC.isEmpty
            )
        } catch let error as NSError {
            if error.code == 22 {
                return InfoItem(
                    id: CoreTelephonyItemID.simCardMCC,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMCardMCC", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("MCCHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.simCardMCC,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMCardMCC", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    hintText: NSLocalizedString("MCCHint", comment: ""),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽连接的移动网络运营商代码
    func getSlotServingMNCInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let MNC = try coreTelephonyController.getSlotServingMNC(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.servingMNC,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingMNC", comment: ""), MNC == "65535" ? NSLocalizedString("NotObtained", comment: "") : MNC),
                hintText: NSLocalizedString("MNCHint", comment: ""),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.servingMNC,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingMNC", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("MNCHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽连接的移动网络运营商所属区域代码
    func getSlotLastRegisteredNetworkMNCCountryCodeInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let MNCCountryCode = try coreTelephonyController.getSlotLastKnownMNCCountryCode(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.lastKnownMNCCountryCode,
                text: String.localizedStringWithFormat(NSLocalizedString("LastRegisteredNetworkMNCCountryCode", comment: ""), MNCCountryCode == "65535" ? NSLocalizedString("NotObtained", comment: "") : MNCCountryCode),
                hintText: NSLocalizedString("MCCHint", comment: ""),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.lastKnownMNCCountryCode,
                text: String.localizedStringWithFormat(NSLocalizedString("LastRegisteredNetworkMNCCountryCode", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("MCCHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽SIM卡的移动网络运营商代码
    func getSlotSIMCardMNCInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let MNC = try coreTelephonyController.getSlotSIMCardMNC(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.simCardMNC,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMCardMNC", comment: ""), MNC == "65535" || MNC.isEmpty ? NSLocalizedString("NotObtained", comment: "") : MNC),
                hintText: NSLocalizedString("MNCHint", comment: ""),
                isConfidential: MNC == "65535" || MNC.isEmpty
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.simCardMNC,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMCardMNC", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("MNCHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取当前连接的网络类型2G 3G 4G 5G
    /// 获取 RadioGeneration 枚举
    func getSlotRadioAccessTechnologyGeneration(context: CTXPCServiceSubscriptionContext) -> CoreTelephonyEnumMapper.RadioGeneration {
        do {
            let radioAccessTechnology = try coreTelephonyController.getSlotRadioAccessTechnology(context: context)
            return CoreTelephonyEnumMapper.mapRegistrationRadioAccessTechnology(radioAccessTechnology).generation
        } catch {
            return .unknown
        }
    }
    
    /// 获取当前连接的网络类型/网络制式
    /// 获取 RadioGeneration 枚举
    func getSlotRadioAccessTechnology(context: CTXPCServiceSubscriptionContext) -> CoreTelephonyEnumMapper.RadioAccessTechnology {
        do {
            let radioAccessTechnology = try coreTelephonyController.getSlotRadioAccessTechnology(context: context)
            return CoreTelephonyEnumMapper.mapRegistrationRadioAccessTechnology(radioAccessTechnology)
        } catch {
            return .NO_SERVICE
        }
    }
    
    /// 获取卡槽的首选网络类型的枚举
    func getSlotSelectRate(context: CTXPCServiceSubscriptionContext) -> CoreTelephonyEnumMapper.RadioGeneration {
        do {
            return CoreTelephonyEnumMapper.mapSelectRate(rate: try coreTelephonyController.getSlotSelectRate(context: context))
        } catch {
            return .noPermission
        }
    }
    
    /// 返回选择网络的类型的文本
    func getRateText(radioGeneration: CoreTelephonyEnumMapper.RadioGeneration, indicator4GText: String) -> String {
        switch radioGeneration {
            
        case ._2G:
            return "2G"
        case ._3G:
            return "3G"
        case ._4G:
            if SettingsUtils.instance.getForceShowLTEAs4G() { // 允许用户强制覆盖LTE为4G
                return "4G"
            } else {
                return indicator4GText
            }
        case ._5G:
            return "5G"
        case .noService:
            return NSLocalizedString("NoService", comment: "")
        case .unknown:
            return NSLocalizedString("Unknown", comment: "未知")
        case .noPermission:
            return NSLocalizedString("NoPermission", comment: "")
        }
    }
    
    /// 获取当前卡槽选择的网络类型/网络制式
    func getSlotSelectRateInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        return InfoItem(
            id: CoreTelephonyItemID.selectRate,
            text: String.localizedStringWithFormat(NSLocalizedString("SelectNetworkType", comment: ""), getRateText(radioGeneration: getSlotSelectRate(context: context), indicator4GText: coreTelephonyController.getSlot4GIndicatorText(context: context)))
        )
    }
    
    /// 获取当前卡槽可选择的网络类型
    func getSlotSupportRatesInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        
        do {
            let supportRates = try coreTelephonyController.getSlotSupportRates(context: context)
            if !supportRates.isEmpty {
                let indicator4GText = coreTelephonyController.getSlot4GIndicatorText(context: context)
                
                var texts: [String] = []
                for rate in supportRates {
                    texts.append(getRateText(radioGeneration: CoreTelephonyEnumMapper.mapSelectRate(rate: rate), indicator4GText: indicator4GText))
                }
                
                let supportRatesText = texts.joined(separator: ", ")
                
                return InfoItem(
                    id: CoreTelephonyItemID.supportRates,
                    text: String.localizedStringWithFormat(NSLocalizedString("SupportNetworkTypes", comment: ""), supportRatesText)
                )
            } else {
                return nil
            }
        } catch {
            return nil
        }
        
    }
    
    /// 获取当前连接的网络类型/网络制式
    /// 获取 InfoItem 数据
    func getSlotRadioAccessTechnologyInfo(slotID: Int, context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let radioAccessTechnology = try coreTelephonyController.getSlotRadioAccessTechnology(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.radioAccessTechnology,
                text: String.localizedStringWithFormat(NSLocalizedString("RadioAccessTechnology", comment: ""), CoreTelephonyEnumMapper.mapRegistrationRadioAccessTechnology(radioAccessTechnology).displayDetailName),
                isConfidential: false
            )
        } catch { // 无权限时就用公开方法获取
            return InfoItem(
                id: CoreTelephonyItemID.radioAccessTechnology,
                text: String.localizedStringWithFormat(NSLocalizedString("RadioAccessTechnology", comment: ""), coreTelephonyNetworkInfoController.getSlotRadioAccessTechnologyEnum(slotID: slotID).displayDetailName),
                isConfidential: false
            )
        }
        
    }
    
    /// 获取卡槽信号强度
    func getSlotSignalStrengthInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let signalStrength = try coreTelephonyController.getSlotSignalStrengthInfo(context: context) {
                
                if getSlotRadioAccessTechnology(context: context) == .NO_SERVICE { // 判断下是否是无服务状态
                    return InfoItem(
                        id: CoreTelephonyItemID.signalStrength,
                        text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), NSLocalizedString("NoService", comment: "")),
                        isConfidential: false
                    )
                } else { // 显示信号格
                    let signalStrengthText = "\(signalStrength.displayBars!) / \(signalStrength.maxDisplayBars!)"
                    return InfoItem(
                        id: CoreTelephonyItemID.signalStrength,
                        text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), signalStrengthText),
                        isConfidential: false
                    )
                }
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.signalStrength,
                    text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    isConfidential: false
                )
            }
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.signalStrength,
                text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的卡是否连接到5G SA网络
    func getSlotNRConnected(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let connected = try coreTelephonyController.getSlotNRConnected(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.NRConnected,
                    text: String.localizedStringWithFormat(NSLocalizedString("NRConnected", comment: ""), connected ? NSLocalizedString("Connected", comment: "") : NSLocalizedString("NotConnected", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 35 { // 基带服务重启中
                    return InfoItem(
                        id: CoreTelephonyItemID.NRConnected,
                        text: String.localizedStringWithFormat(NSLocalizedString("NRConnected", comment: ""), NSLocalizedString("Checking", comment: "")) // 使用获取中占位
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID.NRConnected,
                        text: String.localizedStringWithFormat(NSLocalizedString("NRConnected", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡是否连接到5GA网络
    /// 5GA = 5G-Advanced
    func getSlot5GAdvancedConnected(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        // 手动限制到iOS 15.0+ 低版本系统的设备不支持5GA
        // 理论上可以限制到更高的系统版本显示，暂时没确定高通的基带是哪个型号支持的5GA
        // TODO 需要更多数据
        if #available(iOS 15.0, *) {
            do {
                let dataStatus = try coreTelephonyController.getSlotDataStatus(context: context)
                // 判断是否连接到5GA
                let result =  InfoItem(
                    id: CoreTelephonyItemID._5GAdvancedConnected,
                    text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedConnected", comment: ""),
                                                           dataStatus.indicatorOverride == 19 ? // 19 = 5GA
                                                           NSLocalizedString("Connected", comment: "") :
                                                            NSLocalizedString("NotConnected", comment: ""))
                )
                if #unavailable(iOS 18.4) { // 低于iOS 18.4 显示提示文本
                    result.hintText = NSLocalizedString("5GAdvancedConnectedHint", comment: "")
                }
                return result
            } catch let error as NSError {
                if error.code == 35 { // 基带服务重启中
                    return InfoItem(
                        id: CoreTelephonyItemID._5GAdvancedConnected,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedConnected", comment: ""), NSLocalizedString("Checking", comment: "")) // 使用获取中占位
                    )
                } else { // 未知错误
                    return InfoItem(
                        id: CoreTelephonyItemID._5GAdvancedConnected,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedConnected", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取IMS注册状态
    func getSlotIMSRegistrationStatus(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let IMSRegistrationStatus = try coreTelephonyController.getSlotIMSRegistrationStatus(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.IMSRegistrationStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSRegistrationStatus", comment: ""),
                                                           IMSRegistrationStatus.isRegisteredForVoice ? NSLocalizedString("Registered", comment: "") : NSLocalizedString("NotRegistered", comment: ""),
                                                           IMSRegistrationStatus.isRegisteredForSMS ? NSLocalizedString("Registered", comment: "") : NSLocalizedString("NotRegistered", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.IMSRegistrationStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSRegistrationStatus", comment: ""),
                                                           NSLocalizedString("Unknown", comment: "未知"),
                                                           NSLocalizedString("Unknown", comment: "未知")),
                    isConfidential: false
                )
            }
        } catch {
            do { // 备用方案 给无权限机器准备的
                return InfoItem(
                    id: CoreTelephonyItemID.IMSRegistrationStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSRegistrationBasicStatus", comment: ""),
                                                           try getSlotIMSRegistrationBasicStatus(context: context) ? NSLocalizedString("Registered", comment: "") : NSLocalizedString("NotRegistered", comment: "")),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.IMSRegistrationStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("IMSRegistrationStatus", comment: ""),
                                                           NSLocalizedString("NoPermission", comment: ""),
                                                           NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取IMS注册状态的基础版
    /// 主要是为了无权限设备准备的
    func getSlotIMSRegistrationBasicStatus(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        let connections = try coreTelephonyController.getSlotActiveConnections(context: context)
        return connections.contains("kCTDataConnectionServiceTypeIMS")
    }
    
    /// 获取卡槽的卡已连接的服务
    func getSlotActiveConnections(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let activeServices = try coreTelephonyController.getSlotActiveConnections(context: context)
            if !activeServices.isEmpty {
                return InfoItem(
                    id: CoreTelephonyItemID.activeConnections,
                    text: String.localizedStringWithFormat(NSLocalizedString("ActiveCellularServices", comment: ""), CoreTelephonyEnumMapper.mapDataConnectionServiceTypes(activeServices).joined(separator: "\n"))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.activeConnections,
                    text: String.localizedStringWithFormat(NSLocalizedString("ActiveCellularServices", comment: ""), NSLocalizedString("Empty", comment: ""))
                )
            }
        } catch let error as NSError {
            return InfoItem(
                id: CoreTelephonyItemID.activeConnections,
                text: String.localizedStringWithFormat(NSLocalizedString("ActiveCellularServices", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription))
            )
        }
    }
    
    /// 获取卡槽是否支持VoLTE
    func getSlotSupportedVoLTE(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let supportedVoLTE = try coreTelephonyController.getSlotCallCapabilities(context: context).isVoLTECallingAvailable
            return InfoItem(
                id: CoreTelephonyItemID.supportedVoLTE,
                text: String.localizedStringWithFormat(NSLocalizedString("SupportedVoLTE", comment: ""), supportedVoLTE ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.supportedVoLTE,
                text: String.localizedStringWithFormat(NSLocalizedString("SupportedVoLTE", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取卡槽的卡运营商是否允许编辑热点的APN
    func getSlotTetheringEditingSupported(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            return InfoItem(
                id: CoreTelephonyItemID.tetheringSettingsEditable,
                text: String.localizedStringWithFormat(NSLocalizedString("TetheringSettingsEditable", comment: ""), try coreTelephonyController.getSlotTetheringEditingSupported(context: context) ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: ""))
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.tetheringSettingsEditable,
                    text: String.localizedStringWithFormat(NSLocalizedString("TetheringSettingsEditable", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else if error.code == 35 { // 基带服务重启中
                return InfoItem(
                    id: CoreTelephonyItemID.tetheringSettingsEditable,
                    text: String.localizedStringWithFormat(NSLocalizedString("TetheringSettingsEditable", comment: ""), NSLocalizedString("Checking", comment: "")) // 使用获取中占位
                )
            } else { // 未知错误
                return InfoItem(
                    id: CoreTelephonyItemID.tetheringSettingsEditable,
                    text: String.localizedStringWithFormat(NSLocalizedString("TetheringSettingsEditable", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                )
            }
            
        }
    }
    
    /// 获取卡槽的卡用户是否允许附加APN
    func getSlotAllowedAttachAPNSetting(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let allowed = try coreTelephonyController.getSlotAllowedAttachAPNSetting(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.attachAPNSetting,
                text: String.localizedStringWithFormat(NSLocalizedString("AllowCellularDataAPNEditing", comment: ""), allowed ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: ""))
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.attachAPNSetting,
                    text: String.localizedStringWithFormat(NSLocalizedString("AllowCellularDataAPNEditing", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.attachAPNSetting,
                    text: String.localizedStringWithFormat(NSLocalizedString("AllowCellularDataAPNEditing", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                )
            }
            
        }
    }
    
    /// 获取卡槽的卡运营商是否禁止使用VoLTE
    func getSlotCarrierDisableVoLTE(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let disable = try coreTelephonyController.getSlotForceDisableVoLTE(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.carrierDisableVoLTE,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierDisableVoLTE", comment: ""), disable ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierDisableVoLTE,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierDisableVoLTE", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽是否支持Wi-Fi Calling
    func getSlotSupportedWiFiCalling(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let supportedWifiCalling = try coreTelephonyController.getSlotCallCapabilities(context: context).isWifiCallingAvailable
            return InfoItem(
                id: CoreTelephonyItemID.supportedVoLTE,
                text: String.localizedStringWithFormat(NSLocalizedString("SupportedWifiCalling", comment: ""), supportedWifiCalling ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.supportedVoLTE,
                text: String.localizedStringWithFormat(NSLocalizedString("SupportedWifiCalling", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取连接基站的ID
    func getSlotServingCellID(descriptor: CTServiceDescriptor) -> InfoItem {
        do {
            if let cellID = try coreTelephonyController.getSlotServingCellID(descriptor: descriptor) {
                return InfoItem(
                    id: CoreTelephonyItemID.cellId,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellID", comment: ""), cellID != "0" ? cellID : NSLocalizedString("NoService", comment: "")),
                    hintText: NSLocalizedString("ServingCellIDHint", comment: ""),
                    isConfidential: cellID != "0"
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.cellId,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellID", comment: ""), NSLocalizedString("Unknown", comment: "")),
                    hintText: NSLocalizedString("ServingCellIDHint", comment: ""),
                    isConfidential: false
                )
            }
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.cellId,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingCellID", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("ServingCellIDHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽当前基带数据中连接网络的类型
    /// 辅助方法
    func getSlotBandRadioAccessTechnology(cellInfo: CTCellInfo) -> CoreTelephonyEnumMapper.RadioAccessTechnology {
        if let rat = coreTelephonyController.getSlotBandRadioAccessTechnology(cellInfo: cellInfo) {
            return CoreTelephonyEnumMapper.mapCellMonitorRAT(rat)
        } else {
            return .UNKNOWN(raw: nil)
        }
    }
    
    /// 获取卡槽当前连接的基站频段
    func getSlotServingBand(context: CTXPCServiceSubscriptionContext, cellInfo: CTCellInfo) -> InfoItem? {
        if let bandInfo = coreTelephonyController.getSlotServingBand(cellInfo: cellInfo) {
            switch getSlotBandRadioAccessTechnology(cellInfo: cellInfo).generation {
            case ._5G:
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("NetworkCellBand", comment: ""), "5G", "n\(String(bandInfo))")
                )
            case ._4G:
                let LTEDisplay = getSlot4GNetworkDisplay(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("NetworkCellBand", comment: ""), LTEDisplay, "B\(String(bandInfo))")
                )
            case ._3G, ._2G: // 3G/2G网络不适用此item
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellBand", comment: ""), NSLocalizedString("NotApplicable", comment: ""))
                )
            case .noService:
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellBand", comment: ""), NSLocalizedString("NoService", comment: ""))
                )
            case .unknown:
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellBand", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
                )
            default:
                return InfoItem(
                    id: CoreTelephonyItemID.band,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingCellBand", comment: ""), String(bandInfo))
                )
                
            }
            
        }
        return nil
    }
    
    /// 获取当前卡槽的卡连接网络的频宽
    /// 单位 MHz
    /// 5G SA状态下的数据不准确
    /// *需要改进*
    func getSlotServingBandwidth(context: CTXPCServiceSubscriptionContext, cellInfo: CTCellInfo) -> InfoItem {
        
        if let bandwidth = coreTelephonyController.getSlotServingBandwidth(cellInfo: cellInfo) {
            switch getSlotBandRadioAccessTechnology(cellInfo: cellInfo).generation {
            case ._5G:
                return InfoItem(
                    id: CoreTelephonyItemID.bandwidth,
                    text: String.localizedStringWithFormat(NSLocalizedString("NetworkBandwidth", comment: ""), "5G",  String.localizedStringWithFormat(NSLocalizedString("MHz&PRB", comment: ""), String(bandwidth / 5), String(bandwidth))),
                    hintText: NSLocalizedString("DataInaccurate", comment: "")
                )
                
            case ._4G:
                let LTEDisplay = getSlot4GNetworkDisplay(context: context)
                if let bandwidthMHz = CoreTelephonyEnumMapper.LTEBandwidthMHz(PRB: bandwidth) {
                    return InfoItem(
                        id: CoreTelephonyItemID.bandwidth,
                        text: String.localizedStringWithFormat(NSLocalizedString("NetworkBandwidth", comment: ""), LTEDisplay,  String.localizedStringWithFormat(NSLocalizedString("MHz&PRB", comment: ""), UIUtils.formatDouble(bandwidthMHz), String(bandwidth))),
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyItemID.bandwidth,
                        text: String.localizedStringWithFormat(NSLocalizedString("NetworkBandwidth", comment: ""), LTEDisplay, String(bandwidth))
                    )
                    
                }
                
            case .noService:
                return InfoItem(
                    id: CoreTelephonyItemID.bandwidth,
                    text: String.localizedStringWithFormat(NSLocalizedString("Bandwidth", comment: ""), NSLocalizedString("NoService", comment: ""))
                )
            case .unknown:
                return InfoItem(
                    id: CoreTelephonyItemID.bandwidth,
                    text: String.localizedStringWithFormat(NSLocalizedString("Bandwidth", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
                )
            default: // 3G/2G
                return InfoItem(
                    id: CoreTelephonyItemID.bandwidth,
                    text: String.localizedStringWithFormat(NSLocalizedString("Bandwidth", comment: ""), "\(bandwidth) PRB/NRB")
                )
                
            }
            
            
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.bandwidth,
                text: String.localizedStringWithFormat(NSLocalizedString("Bandwidth", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
            )
        }
    }
    
    /// 获取卡槽连接的网络是否支持5G动态频宽
    func getSlotServingBWPSupport(cellInfo: CTCellInfo, experimentalFeatures: Bool) -> InfoItem? {
        if let supports = coreTelephonyController.getSlotServingBWPSupport(cellInfo: cellInfo) {
            if experimentalFeatures {
                let BWPSupportsText: String
                switch supports {
                case 0: BWPSupportsText = NSLocalizedString("NotSupported", comment: "")
                case 1: BWPSupportsText = String.localizedStringWithFormat(NSLocalizedString("BWPSupports", comment: ""), NSLocalizedString("Downlink", comment: ""))
                case 2: BWPSupportsText = String.localizedStringWithFormat(NSLocalizedString("BWPSupports", comment: ""), NSLocalizedString("Uplink", comment: ""))
                case 3: BWPSupportsText = String.localizedStringWithFormat(NSLocalizedString("BWPSupports", comment: ""), NSLocalizedString("DownlinkAndUplink", comment: ""))
                default: BWPSupportsText = String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), String(supports))
                }
                return InfoItem(
                    id: CoreTelephonyItemID.BWPSupport,
                    text: String.localizedStringWithFormat(NSLocalizedString("NRBWPSupport", comment: ""), BWPSupportsText),
                    hintText: NSLocalizedString("NRBWPSupportExperimentalHint", comment: "")
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.BWPSupport,
                    text: String.localizedStringWithFormat(NSLocalizedString("NRBWPSupport", comment: ""), supports != 0 ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: "")),
                    hintText: NSLocalizedString("NRBWPSupportHint", comment: "")
                )
            }
            
        }
        return nil
    }
    
    /// 获取卡槽NR子载波间隔
    func getSlotNRSubcarrierSpacing(cellInfo: CTCellInfo) -> InfoItem? {
        if let NRSubcarrierSpacing = coreTelephonyController.getSlotNRSubcarrierSpacing(cellInfo: cellInfo) {
            let NRSubcarrierSpacingResult: Int
            switch NRSubcarrierSpacing {
            case 0: NRSubcarrierSpacingResult = 15
            case 1: NRSubcarrierSpacingResult = 30
            case 2: NRSubcarrierSpacingResult = 60
            case 3: NRSubcarrierSpacingResult = 120
            case 4: NRSubcarrierSpacingResult = 240
            case 5: NRSubcarrierSpacingResult = 480
            case 6: NRSubcarrierSpacingResult = 960
            default:
                return nil
            }
            return InfoItem(
                id: CoreTelephonyItemID.NRSubcarrierSpacing,
                text: String.localizedStringWithFormat(NSLocalizedString("NRSubcarrierSpacing", comment: ""), NRSubcarrierSpacingResult),
                hintText: NSLocalizedString("NRSubcarrierSpacingHint", comment: "")
            )
        }
        return nil
    }
    
    /// 获取卡槽的卡允许的最大发射功率
    func getSlotMaximumTransmitPowerLimit(cellInfo: CTCellInfo) -> InfoItem {
        if let PMax = coreTelephonyController.getSlotPMax(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.PMax,
                text: String.localizedStringWithFormat(NSLocalizedString("MaximumTransmitPowerLimit", comment: ""), String(PMax)),
                hintText: NSLocalizedString("MaximumTransmitPowerLimitHint", comment: "")
            )
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.PMax,
                text: String.localizedStringWithFormat(NSLocalizedString("MaximumTransmitPowerLimit", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                hintText: NSLocalizedString("MaximumTransmitPowerLimitHint", comment: "")
            )
        }
    }
    
    /// 获取卡槽的GSCN
    func getSlotGSCN(cellInfo: CTCellInfo) -> InfoItem? {
        if let GSCN = coreTelephonyController.getSlotGSCN(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.GSCN,
                text: String.localizedStringWithFormat(NSLocalizedString("GlobalSynchronizationChannelNumber", comment: ""), GSCN),
                hintText: NSLocalizedString("GlobalSynchronizationChannelNumberHint", comment: ""),
                isConfidential: true
            )
        }
        return nil
    }
    
    /// 获取卡槽NRARFCN
    func getSlotNRARFCN(cellInfo: CTCellInfo) -> InfoItem? {
        if let NRARFCN = coreTelephonyController.getSlotNRARFCN(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.NRARFCN,
                text: String.localizedStringWithFormat(NSLocalizedString("NRAbsoluteRadioFrequencyChannelNumber", comment: ""), NRARFCN),
                hintText: NSLocalizedString("NRAbsoluteRadioFrequencyChannelNumberHint", comment: ""),
                isConfidential: true
            )
        }
        return nil
    }
    
    /// 获取卡槽的信道编号
    /// 需要区分不同网络类型
    func getSlotUARFCN(context: CTXPCServiceSubscriptionContext, cellInfo: CTCellInfo) -> InfoItem? {
        
        if let UARFCN = coreTelephonyController.getSlotUARFCN(cellInfo: cellInfo) {
            switch getSlotRadioAccessTechnology(context: context).generation {
            case ._4G: // EARFCN DL
                return InfoItem(
                    id: CoreTelephonyItemID.UARFCN,
                    text: String.localizedStringWithFormat(NSLocalizedString("ChannelNumber", comment: ""), UARFCN),
                    hintText: NSLocalizedString("ChannelNumberHint", comment: ""),
                    isConfidential: true
                )
            case ._3G: // UMTS/WCMDA扰码
                return InfoItem(
                    id: CoreTelephonyItemID.SCN,
                    text: String.localizedStringWithFormat(NSLocalizedString("ScramblingCode", comment: ""), UARFCN),
                    hintText: NSLocalizedString("ScramblingCodeHint", comment: ""),
                    isConfidential: true
                )
            default:
                return nil
            }
            
        }
        return nil
    }
    
    /// 获取卡槽物理小区ID
    func getSlotPhysicalCellID(cellInfo: CTCellInfo) -> InfoItem? {
        if let physicalCellID = coreTelephonyController.getSlotPhysicalCellID(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.physicalCellID,
                text: String.localizedStringWithFormat(NSLocalizedString("PhysicalCellID", comment: ""), physicalCellID),
                hintText: NSLocalizedString("PhysicalCellIDHint", comment: ""),
                isConfidential: true
            )
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的卡连接基站的TAC
    func getSlotServingTrackingAreaCode(cellInfo: CTCellInfo) -> InfoItem? {
        if let TAC = coreTelephonyController.getSlotServingTrackingAreaCode(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.servingTAC,
                text: String.localizedStringWithFormat(NSLocalizedString("ServingTrackingAreaCode", comment: ""), TAC),
                hintText: NSLocalizedString("ServingTrackingAreaCodeHint", comment: ""),
                isConfidential: true
            )
        }
        return nil
    }
    
    /// 同步获取当前卡槽的卡连接基站LAC
    func getSlotServingLocationAreaCode(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let servingLAC = try coreTelephonyController.getSlotServingLocationAreaCode(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.servingLAC,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), servingLAC != 0 ? servingLAC.stringValue : NSLocalizedString("NoService", comment: "")), // LAC = 0 为无服务
                    hintText: NSLocalizedString("ServingLocationAreaCodeHint", comment: ""),
                    isConfidential: servingLAC != 0,
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.servingLAC,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    hintText: NSLocalizedString("ServingLocationAreaCodeHint", comment: "")
                )
            }
            
        } catch let error as NSError {
            if error.code == 13 { // 错误代码13 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.servingLAC,
                    text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return InfoItem(
            id: CoreTelephonyItemID.servingLAC,
            text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
        )
    }
    
    /// 异步获取当前卡槽的卡连接基站LAC
    func getSlotServingLocationAreaCode(context: CTXPCServiceSubscriptionContext, onUpdate: @escaping (InfoItem) -> Void) -> InfoItem {
        
        let placeholder = InfoItem(
            id: CoreTelephonyItemID.servingLAC,
            text: String.localizedStringWithFormat(
                NSLocalizedString("ServingLocationAreaCode", comment: ""),
                NSLocalizedString("Fetching", comment: "")
            ),
            hintText: NSLocalizedString("AllowInstallEmbeddedSIMHint", comment: "")
        )
        
        coreTelephonyController.getSlotServingLocationAreaCode(context: context)  { LAC, error in
            DispatchQueue.main.async {
                if let servingLAC = LAC { // 拿到数据
                    // 新数据
                    let updated =  InfoItem(
                        id: CoreTelephonyItemID.servingLAC,
                        text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), String(servingLAC)),
                        hintText: NSLocalizedString("ServingLocationAreaCodeHint", comment: ""),
                        isConfidential: true,
                    )
                    // 更新item
                    onUpdate(updated)
                } else if case let error as NSError = error { // 捕获异常
                    if error.code == 13 {
                        let error =  InfoItem(
                            id: CoreTelephonyItemID.servingLAC,
                            text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                        )
                        // 更新item
                        onUpdate(error)
                    } else {
                        let unknownError = InfoItem(
                            id: CoreTelephonyItemID.servingLAC,
                            text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                        )
                        // 更新item
                        onUpdate(unknownError)
                    }
                    
                } else {
                    let unknown = InfoItem(
                        id: CoreTelephonyItemID.servingLAC,
                        text: String.localizedStringWithFormat(NSLocalizedString("ServingLocationAreaCode", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
                    )
                    // 更新item
                    onUpdate(unknown)
                }
            }
            
        }
        
        return placeholder
    }
    
    /// 获取卡槽的信号RSRP值
    /// 4G/5G网络的信号指标
    func getSlotRSRP(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            if let RSRP = coreTelephonyController.getSlotRSRP(descriptor: descriptor) {
                return InfoItem(
                    id: CoreTelephonyItemID.RSRP,
                    text: String.localizedStringWithFormat(NSLocalizedString("RSRP", comment: ""), RSRP),
                    hintText: NSLocalizedString("RSRPHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// 低版本获取RSRP的方法
    func getSlotRSRP(cellInfo: CTCellInfo) -> InfoItem? {
        if let RSRP = coreTelephonyController.getSlotRSRP(cellInfo: cellInfo) {
            return InfoItem(
                id: CoreTelephonyItemID.RSRP,
                text: String.localizedStringWithFormat(NSLocalizedString("RSRP", comment: ""), RSRP),
                hintText: NSLocalizedString("RSRPHint", comment: ""),
                isConfidential: false
            )
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的信号SNR值
    /// 4G/5G网络的信号指标
    func getSlotSNR(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            if let SNR = coreTelephonyController.getSlotSNR(descriptor: descriptor) {
                return InfoItem(
                    id: CoreTelephonyItemID.SNR,
                    text: String.localizedStringWithFormat(NSLocalizedString("SNR", comment: ""), SNR),
                    hintText: NSLocalizedString("SNRHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的信号RSCP值
    /// 3G网络的信号指标
    func getSlotRSCP(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            if let RSRP = coreTelephonyController.getSlotRSCP(descriptor: descriptor) {
                return InfoItem(
                    id: CoreTelephonyItemID.RSCP,
                    text: String.localizedStringWithFormat(NSLocalizedString("RSCP", comment: ""), RSRP),
                    hintText: NSLocalizedString("RSCPHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的信号ECN0值
    /// 3G网络的信号指标
    func getSlotECN0(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            if let ECN0 = coreTelephonyController.getSlotECN0(descriptor: descriptor) {
                return InfoItem(
                    id: CoreTelephonyItemID.ECN0,
                    text: String.localizedStringWithFormat(NSLocalizedString("ECN0", comment: ""), ECN0),
                    hintText: NSLocalizedString("ECN0Hint", comment: ""),
                    isConfidential: false
                )
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽选网模式
    func getSlotNetworkSelectionMode(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let networkSelectionMode = try coreTelephonyController.getSlotNetworkSelectionMode(context: context)
            let networkSelectionModeText: String
            switch networkSelectionMode {
            case 0: networkSelectionModeText = NSLocalizedString("NoService", comment: "")
            case 1: networkSelectionModeText = NSLocalizedString("Automatic", comment: "")
            case 2: networkSelectionModeText = NSLocalizedString("Manual", comment: "")
            case 3: networkSelectionModeText = NSLocalizedString("Disabled", comment: "")
            default: networkSelectionModeText = String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), String(networkSelectionMode))
            }
            return InfoItem(
                id: CoreTelephonyItemID.networkSelectionMode,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionMode", comment: ""), networkSelectionModeText),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.networkSelectionMode,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionMode", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取当前卡槽用户是否可以手动选择网络
    func getSlotNetworkSelectionMenuAvailable(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let showMenu = try coreTelephonyController.getSlotNetworkSelectionMenuAvailable(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.networkSelectionMenuAvailable,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionMenuAvailable", comment: ""), showMenu ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.networkSelectionMenuAvailable,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionMenuAvailable", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取当前卡槽用户是否启用数据漫游
    func  getSlotEnableDataRoaming(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.4, *) {
            do {
                let enable = try coreTelephonyController.getSlotEnableDataRoaming(descriptor: descriptor)
                return InfoItem(
                    id: CoreTelephonyItemID.dataRoaming,
                    text: String.localizedStringWithFormat(NSLocalizedString("DataRoaming", comment: ""), enable ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: "")),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.dataRoaming,
                    text: String.localizedStringWithFormat(NSLocalizedString("DataRoaming", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽是否是低数据模式
    /// 需要iOS 13.0+
    func getSlotLowDataMode(descriptor: CTServiceDescriptor) -> InfoItem? {
        let text: String
        do {
            let lowDataMode: Bool?
            
            if #available(iOS 14.0, *) {
                lowDataMode = try coreTelephonyController.getSlotEnabledLowDataMode(descriptor: descriptor)
            } else if #available(iOS 13.0, *) {
                lowDataMode = try coreTelephonyController.getSlotEnabledSaveDataMode(descriptor: descriptor)
            } else {
                return nil
            }
            
            if let enabled = lowDataMode {
                text = enabled ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")
            } else {
                text = NSLocalizedString("Unknown", comment: "未知")
            }
            
        } catch {
            text = NSLocalizedString("NoPermission", comment: "")
        }
        
        return InfoItem(
            id: CoreTelephonyItemID.lowDataMode,
            text: String.localizedStringWithFormat(NSLocalizedString("LowDataMode", comment: ""), text),
            isConfidential: false
        )
    }
    
    /// 获取当前卡槽的卡是否为高成本网络
    func getSlotInterfaceCostExpensive(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let expensive = try coreTelephonyController.getSlotInterfaceCostExpensive(descriptor: descriptor)
                return InfoItem(
                    id: CommonItemID.interfaceCostExpensive,
                    text: String.localizedStringWithFormat(NSLocalizedString("InterfaceCostExpensive", comment: ""), expensive ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CommonItemID.interfaceCostExpensive,
                        text: String.localizedStringWithFormat(NSLocalizedString("InterfaceCostExpensive", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else {
                    return InfoItem(
                        id: CommonItemID.interfaceCostExpensive,
                        text: String.localizedStringWithFormat(NSLocalizedString("InterfaceCostExpensive", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡拨号通话前显示提醒
    func getSlotShouldShowUserWarningWhenDialingCall(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let result = try coreTelephonyController.getSlotShouldShowUserWarningWhenDialingCall(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.dialingCallAlert,
                text: String.localizedStringWithFormat(NSLocalizedString("ShowWarningBeforeDialing", comment: ""), result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))
            )
        } catch let error as NSError {
            if error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyItemID.dialingCallAlert,
                    text: String.localizedStringWithFormat(NSLocalizedString("ShowWarningBeforeDialing", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.dialingCallAlert,
                    text: String.localizedStringWithFormat(NSLocalizedString("ShowWarningBeforeDialing", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                )
            }
        }
    }
    
    /// 获取当前卡槽的NR状态
    /// 包括是否允许使用5G SA和5G NSA
    /// 无低版本系统兼容方案，低版本系统无设备支持5G
    @available(iOS 14.0, *)
    func getSlotNRStatus(descriptor: CTServiceDescriptor) throws -> CTNRStatus? {
        let NRStatus: CTNRStatus
        if #available(iOS 17.0, *) { // iOS 17的新方法
            NRStatus = try coreTelephonyController.getSlotNRStatus(descriptor: descriptor)
        } else { // iOS 14开始的方法
            NRStatus = try coreTelephonyController.getSlotNRDisableStatus(descriptor: descriptor)
        }
        return NRStatus
    }
    
    /// 获取当前卡槽是否支持5G
    func getSlotSupports5G(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            if !AppCapability.hasCommCenterSPI() { // iOS 14的设备无权限状态下调用getSlotSupports5G会导致app闪退
                return InfoItem(
                    id: CoreTelephonyItemID.supports5G,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5G", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
            do {
                let supports = try coreTelephonyController.getSlotSupports5G(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.supports5G,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5G", comment: ""), supports ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.supports5G,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5G", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取当前卡槽是否支持5G SA
    /// 通过兼容方法支持非首选卡槽
    func getSlotSupports5GSA(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                if let NRStatus = try getSlotNRStatus(descriptor: descriptor) {
                    // reason = 4 当前非首选卡槽
                    // reason = 5 当前非首选卡槽+不支持
                    if NRStatus.saDisabledReasonMask == 4 || NRStatus.saDisabledReasonMask == 5 {
                        return getSlotSupports5GStandalone(descriptor: descriptor) // 使用替代方案
                    }
                    return InfoItem(
                        id: CoreTelephonyItemID.supports5GSA,
                        text: String.localizedStringWithFormat(NSLocalizedString("Supports5GSA", comment: ""), NRStatus.isSADisabled ? NSLocalizedString("NotSupported", comment: "") : NSLocalizedString("Supported", comment: ""))
                    )
                } else {
                    return nil
                }
                
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.supports5GSA,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5GSA", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽在任意状态下是否支持5G SA
    func getSlotSupports5GStandalone(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let supports = try coreTelephonyController.getSlotSupports5GStandalone(descriptor: descriptor)
                return InfoItem(
                    id: CoreTelephonyItemID.supports5GSA,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5GSA", comment: ""), supports ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
                )
            } catch let error as NSError {
                if error.code == 45 { // 不支持5G SA
                    return InfoItem(
                        id: CoreTelephonyItemID.supports5GSA,
                        text: String.localizedStringWithFormat(NSLocalizedString("Supports5GSA", comment: ""),  NSLocalizedString("NotSupported", comment: ""))
                    )
                } else if error.code == 1 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyItemID.supports5GSA,
                        text: String.localizedStringWithFormat(NSLocalizedString("Supports5GSA", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取当前卡槽是否支持5G NSA
    /// 只有首选卡槽支持
    func getSlotSupports5GNSA(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                if let NRStatus = try getSlotNRStatus(descriptor: descriptor) {
                    // reason = 4 当前非首选卡槽
                    // reason = 5 当前非首选卡槽+不支持
                    if NRStatus.nsaDisabledReasonMask == 4 || NRStatus.nsaDisabledReasonMask == 5 {
                        return nil
                    }
                    return InfoItem(
                        id: CoreTelephonyItemID.supports5GNSA,
                        text: String.localizedStringWithFormat(NSLocalizedString("Supports5GNSA", comment: ""), NRStatus.isNSADisabled ? NSLocalizedString("NotSupported", comment: "") : NSLocalizedString("Supported", comment: ""))
                    )
                } else {
                    return nil
                }
                
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.supports5GNSA,
                    text: String.localizedStringWithFormat(NSLocalizedString("Supports5GNSA", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取当前卡槽是否支持自动5G
    func getSlotSupportsHighDataMode(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            if AppCapability.hasCommCenterSPI() { // 因为查询API在无权限时不抛异常，因此只能手动判断了
                do {
                    let supports = try coreTelephonyController.getSlotSupportsHighDataMode(descriptor: descriptor)
                    return InfoItem(
                        id: CoreTelephonyItemID.supportsHighDataMode,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAuto", comment: ""), supports ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: ""))
                    )
                } catch {
                    return InfoItem(
                        id: CoreTelephonyItemID.supportsHighDataMode,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAuto", comment: ""), NSLocalizedString("Unknown", comment: "未知"))
                    )
                }
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.supportsHighDataMode,
                    text: String.localizedStringWithFormat(NSLocalizedString("5GAuto", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽是否开启自动5G
    func getSlotEnabled5GAuto(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let enabled = try coreTelephonyController.getSlotEnable5GAutoMode(descriptor: descriptor)
                return InfoItem(
                    id: CoreTelephonyItemID._5GAuto,
                    text: String.localizedStringWithFormat(NSLocalizedString("5GAuto", comment: ""), enabled ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID._5GAuto,
                    text: String.localizedStringWithFormat(NSLocalizedString("5GAuto", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        
        return nil
    }
    
    /// 获取当前卡槽是否开启 限制IP地址跟踪
    func getSlotLimitIPTrackingEnabled(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {return InfoItem(
                id: CoreTelephonyItemID.limitIPTracking,
                text: String.localizedStringWithFormat(NSLocalizedString("LimitIPTrackingStatus", comment: ""), try coreTelephonyController.getSlotPrivacyProxyState(descriptor: descriptor).limitIPTrackingEnabled.boolValue ? NSLocalizedString("TurnOn", comment: "") : NSLocalizedString("TurnOff", comment: ""))
            )} catch {
                return InfoItem(
                    id: CoreTelephonyItemID.limitIPTracking,
                    text: String.localizedStringWithFormat(NSLocalizedString("LimitIPTrackingStatus", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取被网络拒绝的原因代码
    /// 需要细化
    func getSlotNetworkRejectCause(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        do {
            let rejectCauseCode = try coreTelephonyController.getSlotRejectCauseCode(context: context)
            if rejectCauseCode == -1 { // -1 是正常
                return nil
            }
            return InfoItem(
                id: CoreTelephonyItemID.rejectCauseCode,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkRejectCause", comment: ""), String(describing: rejectCauseCode)),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.rejectCauseCode,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkRejectCause", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽运营商配置文件(IPCC)版本号
    func getSlotCarrierBundleVersion(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let carrierBundleVersion = try coreTelephonyController.getSlotCarrierBundleVersion(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), carrierBundleVersion),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    isConfidential: false
                )
            }
        } catch let error as NSError {
            if error.code == 0 { // 无SIM卡
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), NSLocalizedString("NoSIM", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 19 { // 模拟器/不支持蜂窝网络的设备不支持
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleVersion,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
        
    }
    
    /// 获取卡槽运营商配置文件所在目录
    func getSlotCarrierBundleLocation(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let carrierBundlePath = try coreTelephonyController.getSlotCarrierBundleLocation(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleLocation", comment: ""), carrierBundlePath),
                    detailText: carrierBundlePath, // 放到detail里面方便来复制
                    isConfidential: false,
                    copyable: true
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleLocation", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    isConfidential: false
                )
            }
        } catch let error as NSError {
            if error.code == 13 || error.code == 22 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleLocation", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleLocation,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleLocation", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取卡槽SIM卡中联系人数量
    func getSlotSIMPhonebookCount(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                return InfoItem(
                    id: CoreTelephonyItemID.SIMPhoneBookCount,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMPhonebookCount", comment: ""), try coreTelephonyController.getSlotPhonebookEntryCount(context: context)),
                    hintText: NSLocalizedString("SIMPhonebookHint", comment: ""),
                    isConfidential: false,
                )
            } catch { // 处理无权限的异常 直接返回nil
                return nil
            }
            
        } else {
            return nil
        }
    }
    
    // 获取卡槽用户归属区域 (ISO)列表
    func getSlotMobileSubscriberHomeCountryList(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let regionList = try coreTelephonyController.getSlotMobileSubscriberHomeCountryList(context: context)
            
            let valueText: String
            if regionList.isEmpty {
                valueText = NSLocalizedString("Empty", comment: "")
            } else {
                valueText = regionList.joined(separator: ", ")
            }
            
            return InfoItem(
                id: CoreTelephonyItemID.SIMHomeRegionList,
                text: String.localizedStringWithFormat(NSLocalizedString("SubscriberHomeRegions", comment: ""), valueText),
                isConfidential: false
            )
            
        } catch let error as NSError {
            if error.code == 0 { // 未启用/无SIM卡的卡槽
                return InfoItem(
                    id: CoreTelephonyItemID.SIMHomeRegionList,
                    text: String.localizedStringWithFormat(NSLocalizedString("SubscriberHomeRegions", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 1 || error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.SIMHomeRegionList,
                    text: String.localizedStringWithFormat(NSLocalizedString("SubscriberHomeRegions", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.SIMHomeRegionList,
                    text: String.localizedStringWithFormat(NSLocalizedString("SubscriberHomeRegions", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽的卡设定的允许的紧急呼叫号码列表
    func getSlotEmergencyTextNumbers(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let numbers = try coreTelephonyController.getSlotEmergencyTextNumbers(context: context)
                let numbersText = numbers.isEmpty
                ? NSLocalizedString("Empty", comment: "") // 空白列表
                : numbers.joined(separator: ", ") // 非空列表 添加断开的符号,
                return InfoItem(
                    id: CoreTelephonyItemID.emergencyTextNumbers,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyTextNumbers", comment: ""), numbersText),
                    isConfidential: false
                )
            } catch { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.emergencyTextNumbers,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyTextNumbers", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
            
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的卡短信状态是否就绪
    func getSlotSMSReadyState(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let SMSReadyState = try coreTelephonyController.getSlotSMSReadyState(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.SMSReadyState,
                text: String.localizedStringWithFormat(NSLocalizedString("SMSReady", comment: ""), SMSReadyState ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.SMSReadyState,
                text: String.localizedStringWithFormat(NSLocalizedString("SMSReady", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽短信中心号码
    func getSlotSMSCenterNumber(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let SMSCenterNumber = try coreTelephonyController.getSlotSMSCAddress(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.SMSCAddress,
                text: String.localizedStringWithFormat(NSLocalizedString("SMSCenterNumber", comment: ""), SMSCenterNumber.isEmpty ? NSLocalizedString("NotSet", comment: "") : SMSCenterNumber),
                detailText: SMSCenterNumber,
                isConfidential: false,
                copyable: !SMSCenterNumber.isEmpty
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.SMSCAddress,
                text: String.localizedStringWithFormat(NSLocalizedString("SMSCenterNumber", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取SIM卡是否允许使用PIN锁定
    /// iOS 14以下系统不支持
    func getSlotAllowSIMLockWithPIN(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            if let allowLockWinPin = coreTelephonyController.getSlotShouldAllowSimLock(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.allowSIMLockWithPIN,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMAllowsPINLock", comment: ""), allowLockWinPin == 1 ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")),
                    isConfidential: false
                )
            } else { // 处理证书安装无权限的问题
                return InfoItem(
                    id: CoreTelephonyItemID.allowSIMLockWithPIN,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMAllowsPINLock", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
            
        } else {
            return nil
        }
    }
    
    /// 获取卡槽中SIM卡是否被PIN锁住/已锁定
    func getSlotSIMLockedWithPIN(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let locked = try coreTelephonyController.getSlotSIMLockedWithPIN(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.SIMLockedWithPIN,
                text: String.localizedStringWithFormat(NSLocalizedString("SIMLockedWithPIN", comment: ""), locked ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyItemID.SIMLockedWithPIN,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMLockedWithPIN", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 6 { // 基带服务重启中
                return InfoItem(
                    id: CoreTelephonyItemID.SIMLockedWithPIN,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMLockedWithPIN", comment: ""), NSLocalizedString("Checking", comment: "")), // 使用获取中占位
                    isConfidential: false
                )
            } else { // 未知错误
                return InfoItem(
                    id: CoreTelephonyItemID.SIMLockedWithPIN,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMLockedWithPIN", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽中SIM卡剩余可尝试PIN次数
    func getSlotRemainingPINAttemptCount(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let count = try coreTelephonyController.getSlotRemainingPINAttemptCount(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.remainingPINAttemptCount,
                text: String.localizedStringWithFormat(NSLocalizedString("RemainingPINAttemptCount", comment: ""), String(count)),
                hintText: NSLocalizedString("PINAttemptHint", comment: ""),
                isConfidential: false
            )
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyItemID.remainingPINAttemptCount,
                    text: String.localizedStringWithFormat(NSLocalizedString("RemainingPINAttemptCount", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PINAttemptHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.remainingPINAttemptCount,
                    text: String.localizedStringWithFormat(NSLocalizedString("RemainingPINAttemptCount", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    hintText: NSLocalizedString("PINAttemptHint", comment: ""),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取卡槽中SIM卡剩余可尝试PUK次数
    func getSlotRemainingPUKAttemptCount(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let count = try coreTelephonyController.getSlotRemainingPUKAttemptCount(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.remainingPUKAttemptCount,
                text: String.localizedStringWithFormat(NSLocalizedString("RemainingPUKAttemptCount", comment: ""), String(count)),
                hintText: NSLocalizedString("PUKAttemptHint", comment: ""),
                isConfidential: false
            )
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyItemID.remainingPUKAttemptCount,
                    text: String.localizedStringWithFormat(NSLocalizedString("RemainingPUKAttemptCount", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PUKAttemptHint", comment: ""),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.remainingPUKAttemptCount,
                    text: String.localizedStringWithFormat(NSLocalizedString("RemainingPUKAttemptCount", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    hintText: NSLocalizedString("PUKAttemptHint", comment: ""),
                    isConfidential: false
                )
            }
        }
        
    }
    
    /// 获取卡槽的APN列表
    func getSlotAPNConfigList(slotID: Int) throws -> [CellularAPN] {
        
        guard let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) else {
            throw NSError(domain: "NSPOSIXErrorDomain", code: 13)
        }
        
        let apns = try coreTelephonyController.getSlotAPNs(context: context)
        
        return apns.map { item in
            let rawDict = item.reduce(into: [String: Any]()) { result, pair in
                if let key = pair.key as? String {
                    result[key] = pair.value
                }
            }
            return CellularAPN(
                apn: item["apn"] as? String,
                username: item["username"] as? String,
                password: item["password"] as? String,
                
                typeMask: item["type-mask"] as? Int,
                technologyMask: item["TechnologyMask"] as? Int,
                allowedProtocolMask: item["AllowedProtocolMask"] as? Int,
                roamingProtocolMask: item["AllowedProtocolMaskInRoaming"] as? Int,
                
                alwaysOn: item["AlwaysOnPDU"] as? Int,
                inactivityTimer: item["InactivityTimer"] as? Int,
                useNetworkMTU: item["UseNetworkMTU"] as? Int,
                
                xlat464: item["enableXLAT464"] as? Int,
                support5GSaHandover: item["Support5GSaHandOver"] as? Int,
                supportSwitchOver: item["SupportSwitchOver"] as? Int,
                
                pcoContainerId: item["PcoContainerId"],
                
                raw: rawDict
            )
        }
    }
    
    /// 获取当前卡槽的运营商预置书签的入口
    func getSlotAPNConfigEntry() -> InfoItem {
        return InfoItem(
            id: ActionItemID.APNConfig,
            text: NSLocalizedString("APNSettings", comment: "")
        )
    }
    
    /// 获取卡槽的APN列表
    func getSlotAPNConfig(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let APNs = try coreTelephonyController.getSlotAPNs(context: context)
            
            if APNs.isEmpty {
                return InfoItem(
                    id: CommonItemID.APN,
                    text: String.localizedStringWithFormat(NSLocalizedString("APNSettingsList", comment: ""), NSLocalizedString("None", comment: ""))
                )
            }
            
            var result: [String] = []
            
            for (index, item) in APNs.enumerated() {
                
                var lines: [String] = []
                
                lines.append("APN \(index + 1)")
                
                if let apn = item["apn"] as? String, !apn.isEmpty {
                    lines.append("APN: \(apn)")
                }
                
                if let username = item["username"] as? String, !username.isEmpty {
                    lines.append("Username: \(username)")
                }
                
                if let password = item["password"] as? String, !password.isEmpty {
                    lines.append("Password: \(password)")
                }
                
                if let typeMask = item["type-mask"] {
                    lines.append("Type Mask: \(typeMask)")
                }
                
                if let techMask = item["TechnologyMask"] {
                    lines.append("Technology Mask: \(techMask)")
                }
                
                if let protocolMask = item["AllowedProtocolMask"] {
                    lines.append("Protocol Mask: \(protocolMask)")
                }
                
                if let roamingProtocolMask = item["AllowedProtocolMaskInRoaming"] {
                    lines.append("Roaming Protocol Mask: \(roamingProtocolMask)")
                }
                
                if let alwaysOn = item["AlwaysOnPDU"] {
                    lines.append("Always On: \(alwaysOn)")
                }
                
                if let inactivity = item["InactivityTimer"] {
                    lines.append("Inactivity Timer: \(inactivity)")
                }
                
                if let mtu = item["UseNetworkMTU"] {
                    lines.append("Use Network MTU: \(mtu)")
                }
                
                if let xlat = item["enableXLAT464"] {
                    lines.append("XLAT464: \(xlat)")
                }
                
                if let handover = item["Support5GSaHandOver"] {
                    lines.append("5G SA Handover: \(handover)")
                }
                
                if let switchover = item["SupportSwitchOver"] {
                    lines.append("Switch Over: \(switchover)")
                }
                
                if let pco = item["PcoContainerId"] {
                    lines.append("PCO Container ID: \(pco)")
                }
                
                if lines.count == 1 {
                    lines.append(String(describing: item))
                }
                
                result.append(lines.joined(separator: "\n"))
            }
            
            let APNConfigText = result.joined(separator: "\n\n")
            
            return InfoItem(
                id: CommonItemID.APN,
                text: String.localizedStringWithFormat(NSLocalizedString("APNSettingsList", comment: ""), APNConfigText)
            )
            
        } catch {
            return InfoItem(
                id: CommonItemID.APN,
                text: String.localizedStringWithFormat(NSLocalizedString("APNSettingsList", comment: ""), NSLocalizedString("NotObtained", comment: ""))
            )
        }
    }
    
    /// 获取卡槽连接的网络运营商允许的最大多方通话人数
    func getSlotOperatorMultiPartyCallCountMaximum(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            return InfoItem(
                id: CoreTelephonyItemID.maximumConferenceCall,
                text: String.localizedStringWithFormat(NSLocalizedString("MaximumConferenceCallParticipants", comment: ""), String(try coreTelephonyController.getSlotOperatorMultiPartyCallCountMaximum(context: context)))
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.maximumConferenceCall,
                text: String.localizedStringWithFormat(NSLocalizedString("MaximumConferenceCallParticipants", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
    }
    
    /// 获取当前卡槽的运营商预置书签的入口
    func getSlotCarrierBookmarksEntry() -> InfoItem {
        return InfoItem(
            id: ActionItemID.carrierBookmark,
            text: NSLocalizedString("CarrierBookmarks", comment: "")
        )
    }
    
    /// 获取当前卡槽的运营商预置书签
    /// 容易闪退 改为二级界面展示
    func getSlotCarrierBookmarks(context: CTXPCServiceSubscriptionContext, onUpdate: @escaping (InfoItem) -> Void) -> InfoItem {
        
        // 1. 先给 UI 一个占位，避免卡顿
        let placeholder = InfoItem(
            id: CoreTelephonyItemID.carrierBookmarks,
            text: String.localizedStringWithFormat(
                NSLocalizedString("CarrierBookmarksList", comment: ""),
                NSLocalizedString("Checking", comment: "")
            )
        )
        
        // 2. 异步查询
        coreTelephonyController.getSlotCarrierBookmarks(context: context, completion: { list, error in
            // 最终展示的文本对象
            var displayText = ""
            // 拼接文本
            if let list = list, !list.isEmpty {
                displayText = list.compactMap { dict in
                    let title = dict["Title"] as? String ?? ""
                    let url = dict["URL"] as? String ?? ""
                    return "\(title)\n\(url)"
                }
                .joined(separator: "\n")
            } else {
                displayText = NSLocalizedString("None", comment: "")
            }
            
            let updated = InfoItem(
                id: CoreTelephonyItemID.carrierBookmarks,
                text: String.localizedStringWithFormat(
                    NSLocalizedString("CarrierBookmarksList", comment: ""),
                    displayText
                ),
                hintText: NSLocalizedString("CarrierBookmarksHint", comment: "")
            )
            // 更新item
            onUpdate(updated)
        })
        
        return placeholder
    }
    
    /// 获取当前卡槽的运营商预置书签
    /// 异步获取 CarrierBookmark 数组，用于二级界面
    func fetchSlotCarrierBookmarks(slotID: Int, completion: @escaping ([CarrierBookmark]?, Error?) -> Void) {
        
        guard let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) else {
            completion(nil, NSError(domain: "NSPOSIXErrorDomain", code: 13))
            return
        }
        
        coreTelephonyController.getSlotCarrierBookmarks(context: context) { list, error in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let list = list, !list.isEmpty else {
                completion([], nil)
                return
            }
            
            let bookmarks: [CarrierBookmark] = list.compactMap { dict in
                guard let title = dict["Title"] as? String,
                      let url = dict["URL"] as? String else {
                    return nil
                }
                
                return CarrierBookmark(
                    title: title,
                    URL: url
                )
            }
            
            completion(bookmarks, nil)
        }
    }
    
    /// 当前卡槽的卡是否时私有网络的SIM卡
    func getSlotSIMIsPrivateNetwork(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 16.0, *) {
            do {
                let result = try coreTelephonyController.getSlotSIMIsPrivateNetwork(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.SIMIsPrivateNetwork,
                    text: String.localizedStringWithFormat(NSLocalizedString("PrivateNetworkSIM", comment: ""), result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                    hintText: NSLocalizedString("PrivateNetworkSIMHint", comment: "")
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.SIMIsPrivateNetwork,
                    text: String.localizedStringWithFormat(NSLocalizedString("PrivateNetworkSIM", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡号码注册能力(PNR)
    func getSlotPNRSupported(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let supported = try coreTelephonyController.getSlotPNRSupported(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.PNRSupported,
                text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), supported ? NSLocalizedString("Supported", comment: "") : NSLocalizedString("NotSupported", comment: "")),
                hintText: NSLocalizedString("PhoneNumberRegistrationCapabilityHint", comment: "")
            )
        } catch let error as NSError {
            if error.code == 22 { // iPad 不支持
                return InfoItem(
                    id: CoreTelephonyItemID.PNRSupported,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")),
                    hintText: NSLocalizedString("PhoneNumberRegistrationCapabilityHint", comment: "")
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.PNRSupported,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PhoneNumberRegistrationCapabilityHint", comment: "")
                )
            }
        }
    }
    
    /// 获取卡槽的卡的认证状态
    /// TODO iOS 13设备报告 4097 错误 但是过了一段时间消失了
    func getSlotPhoneNumberCredentialValid(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let valid = try coreTelephonyController.getSlotPhoneNumberCredentialValid(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.phoneNumberCredential,
                text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberCredentialStatus", comment: ""), valid ? NSLocalizedString("Valid", comment: "") : NSLocalizedString("Invalid", comment: "")),
                hintText: NSLocalizedString("PhoneNumberCredentialStatusHint", comment: "")
            )
        } catch let error as NSError {
            if error.code == 35 { // 无SIM卡
                return InfoItem(
                    id: CoreTelephonyItemID.phoneNumberCredential,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberCredentialStatus", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: "")),
                    hintText: NSLocalizedString("PhoneNumberCredentialStatusHint", comment: "")
                )
            } else if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.phoneNumberCredential,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberCredentialStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    hintText: NSLocalizedString("PhoneNumberCredentialStatusHint", comment: "")
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.phoneNumberCredential,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberCredentialStatus", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code, error.localizedDescription)),
                    hintText: NSLocalizedString("PhoneNumberCredentialStatusHint", comment: "")
                )
            }
        }
    }
    
    /// 获取卡槽的卡NAT 保活时间 单位s
    func getSlotNATTKeepAliveOverCell(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let keepAliveInterval = try coreTelephonyController.getSlotNATTKeepAliveOverCell(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), String.localizedStringWithFormat(NSLocalizedString("TimeSeconds", comment: ""), keepAliveInterval)),
                hintText: NSLocalizedString("NATKeepAliveIntervalHint", comment: "")
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                    text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else if error.code == 35 { // 无SIM卡 / 未启用SIM卡
                return InfoItem(
                    id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                    text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), NSLocalizedString("SIMStatusNotInserted", comment: ""))
                )
            } else { // 未知错误
                return InfoItem(
                    id: CoreTelephonyItemID.NATTKeepAliveOverCell,
                    text: String.localizedStringWithFormat(NSLocalizedString("NATKeepAliveInterval", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                )
            }
        }
    }
    
    /// 获取卡槽在4G网络显示LTE还是4G
    /// 辅助方法
    func getSlot4GNetworkDisplay(context: CTXPCServiceSubscriptionContext) -> String {
        if SettingsUtils.instance.getForceShowLTEAs4G() {
            return "4G"
        } else {
            return coreTelephonyController.getSlot4GIndicatorText(context: context)
        }
    }
    
    /// 获取当前卡槽的卡运营商配置文件显示4G还是LTE
    func getSlot4GNetworkIndicator(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        return InfoItem(
            id: CommonItemID._4GNetworkIndicator,
            text: String.localizedStringWithFormat(NSLocalizedString("4GNetworkIndicator", comment: ""), coreTelephonyController.getSlot4GIndicatorText(context: context)),
            isConfidential: false
        )
    }
    
    /// 获取卡槽5GA的显示方法
    /// 5GA = 5G-Advanced
    func getSlotNRMMWaveIndicatorText(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                
                if AppCapability.hasCommCenterSPI() { // 无权限时可以直接查询
                    if try !coreTelephonyController.getSlotSupports5G(context: context) { // 卡/设备不支持5G就不显示了
                        return nil
                    }
                }
                if let NRMMWaveIndicatorText = try coreTelephonyController.getSlot5GNRMMWaveIndicatorText(context: context) {
                    return InfoItem(
                        id: CommonItemID.NRMMWaveIndicator,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedNetworkIndicator", comment: ""), NRMMWaveIndicatorText),
                        isConfidential: false
                    )
                } else {
                    return InfoItem(
                        id: CommonItemID.NRMMWaveIndicator,
                        text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedNetworkIndicator", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                        isConfidential: false
                    )
                }
            } catch {
                return InfoItem(
                    id: CommonItemID.NRMMWaveIndicator,
                    text: String.localizedStringWithFormat(NSLocalizedString("5GAdvancedNetworkIndicator", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                    isConfidential: false
                )
            }
            
        }
        return nil
    }
    
    /// 获取卡槽的卡运营商配置文件支持的SIM卡
    func getSlotCarrierBundleSupportedSIMs(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let list = try coreTelephonyController.getSlotCarrierBundleSupportsSIMList(context: context)
            let SIMListText = list.isEmpty
            ? NSLocalizedString("Empty", comment: "") // 空白列表
            : list.joined(separator: "\n") // 非空列表 添加换行符
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleSupportsSIMs,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsSIM", comment: ""), SIMListText),
                detailText: SIMListText,
                hintText: NSLocalizedString("CarrierBundleSupportsSIMHint", comment: ""),
                isConfidential: false,
                copyable: true
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleSupportsSIMs,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsSIM", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                hintText: NSLocalizedString("CarrierBundleSupportsSIMHint", comment: ""),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽是否显示5G开关
    func getSlotCarrierBundleShow5GSwitch(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            let show3G = coreTelephonyController.getSlotCarrierBundleShow5GSwitch(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleShow5GSwitcher,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), "5G", show3G ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        }
        return nil
    }
    
    /// 获取卡槽是否显示5G SA开关
    func getSlotCarrierBundleShow5GStandaloneSwitch(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            let show3G = coreTelephonyController.getSlotCarrierBundleShow5GStandaloneSwitch(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleShow5GStandaloneSwitcher,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), "5G SA", show3G ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        }
        return nil
    }
    
    /// 获取卡槽是否显示4G/LTE开关
    func getSlotCarrierBundleShow4GSwitch(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let show4G = try coreTelephonyController.getSlotCarrierBundleShow4GSwitch(context: context) {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleShow4GSwitcher,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), getSlot4GNetworkDisplay(context: context), show4G ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleShow4GSwitcher,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), getSlot4GNetworkDisplay(context: context), NSLocalizedString("Unknown", comment: "未知")),
                    isConfidential: false
                )
            }
        } catch let error as NSError {
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleShow4GSwitcher,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), getSlot4GNetworkDisplay(context: context), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)")),
                isConfidential: false
            )
        }
        
    }
    
    /// 获取卡槽是否显示3G开关
    func getSlotCarrierBundleShow3GSwitch(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        do {
            let show3G = try coreTelephonyController.getSlotCarrierBundleShow3GSwitch(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleShow4GSwitcher,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), "3G", show3G ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } catch let error as NSError {
            if error.code == 0 { // 未包含此字段 不显示
                return nil
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleShow4GSwitcher,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowNetworkSwitch", comment: ""), "3G", String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽是否显示VoLTE开关
    func getSlotCarrierBundleShowVoLTESwitch(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        do {
            let showVoLTE = try coreTelephonyController.getSlotCarrierBundleShowVoLTESwitch(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleShowVoLTESwitcher,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowVoLTESwitch", comment: ""), showVoLTE ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                hintText: NSLocalizedString("CarrierBundleShowVoLTESwitchHint", comment: ""),
                isConfidential: false
            )
        } catch let error as NSError {
            if error.code == 0 { // 不支持
                return nil
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleShowVoLTESwitcher,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleShowVoLTESwitch", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    hintText: NSLocalizedString("CarrierBundleShowVoLTESwitchHint", comment: ""),
                    isConfidential: false
                )
            }
        }
        
    }
    
    /// 获取卡槽的卡运营商配置文件更新前是否需要用户同意
    func getSlotCarrierBundleOTABeforeUserConfirm(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        do {
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundleOTABeforeUserConfirm,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleUpdateRequiresUserConfirmation", comment: ""), try coreTelephonyController.getSlotCarrierBundleOTABeforeUserConfirm(context: context) ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } catch let error as NSError{
            if error.code == 0 { // 不支持
                return nil
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundleOTABeforeUserConfirm,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleUpdateRequiresUserConfirmation", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
    }
    
    /// 获取卡槽的网络类型选择情况
    func getSlotRatSectionInfo(descriptor: CTServiceDescriptor, context: CTXPCServiceSubscriptionContext) -> [InfoItem] {
        
        do {
            let selectionType: String
            let preferredType: String
            
            if #available(iOS 14.0, *) {
                if let section = try coreTelephonyController.getSlotRatSelectionInfo(descriptor: descriptor) {
                    selectionType = section.selection
                    preferredType = section.preferred
                } else {
                    return []
                }
            } else {
                if AppCapability.hasCommCenterSPI() {
                    if let section = try coreTelephonyController.getSlotRatSelection(context: context) {
                        selectionType = section.selection
                        preferredType = section.preferred
                    } else {
                        return []
                    }
                } else { // iOS 12 iOS 13在无权限情况下调用非常卡 所以直接不去调用了
                    selectionType = ""
                    preferredType = ""
                }
            }
            return [
                InfoItem(
                    id: CoreTelephonyItemID.selectionNetworkType,
                    text: String.localizedStringWithFormat(NSLocalizedString("SelectNetworkType", comment: ""), selectionType.isEmpty ? NSLocalizedString("NoPermission", comment: "") : CoreTelephonyEnumMapper.mapRATSelection(selectionType))
                ),
                InfoItem(
                    id: CoreTelephonyItemID.preferredNetworkType,
                    text: String.localizedStringWithFormat(NSLocalizedString("PreferredNetworkType", comment: ""), preferredType.isEmpty ? NSLocalizedString("NoPermission", comment: "") : CoreTelephonyEnumMapper.mapRATSelection(preferredType))
                )]
        } catch {
            return [
                InfoItem(
                    id: CoreTelephonyItemID.selectionNetworkType,
                    text: String.localizedStringWithFormat(NSLocalizedString("SelectNetworkType", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                ),
                InfoItem(
                    id: CoreTelephonyItemID.preferredNetworkType,
                    text: String.localizedStringWithFormat(NSLocalizedString("PreferredNetworkType", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )]
        }
    }
    
    /// 获取卡槽标签的数据模型 原始数据
    func getSlotLabelRAWData(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let label = try coreTelephonyController.getSlotLabel(context: context)
            return InfoItem(
                id: CoreTelephonyItemID.slotLabel,
                text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), label)
            )
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyItemID.slotLabel,
                    text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else if error.code == 22 { // 无SIM卡
                return InfoItem(
                    id: CoreTelephonyItemID.slotLabel,
                    text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), NSLocalizedString("NoSIM", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.slotLabel,
                    text: String.localizedStringWithFormat(NSLocalizedString("Label", comment: ""), String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), "\(error.code) \(error.localizedDescription)"))
                )
            }
        }
    }
    
    /// 获取卡槽的蜂窝数据状态 原始数据
    func getSlotDataStatus(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let dataStatus = try coreTelephonyController.getSlotDataStatus(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.dataStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), dataStatus),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.dataStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的蜂窝数据状态 基本数据 原始数据
    func getSlotDataStatusBasic(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 15.4, *) {
            do {
                let dataStatus = try coreTelephonyController.getDataStatusBasic(context: context)
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataStatusBasic,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), dataStatus),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataStatusBasic,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的数据模式 原始数据
    func getSlotDataModeRAW(context: CTXPCServiceSubscriptionContext, descriptor: CTServiceDescriptor) -> InfoItem {
        do {
            let dataMode: Int
            if #available(iOS 18.0, *) { // iOS 18开始使用兼容方法
                dataMode = Int(try coreTelephonyController.getSlotDataStatus(context: context).dataMode)
            } else {
                dataMode = try coreTelephonyController.getSlotDataMode(descriptor: descriptor)
            }
            return InfoItem(
                id: CoreTelephonyRAWItemID.dataMode,
                text: String.localizedStringWithFormat(NSLocalizedString("DataMode", comment: ""), String(dataMode))
            )
        } catch let error as NSError {
            return InfoItem(
                id: CoreTelephonyRAWItemID.dataMode,
                text: String.localizedStringWithFormat(NSLocalizedString("DataMode", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
            )
        }
    }
    
    // 获取卡槽的信号强度 原始数据
    func getSlotSignalStrengthMeasurements(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                if let signalStrengthMeasurements = try coreTelephonyController.getSlotSignalStrengthMeasurements(descriptor: descriptor) {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.signalStrengthMeasurements,
                        text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), signalStrengthMeasurements),
                        isConfidential: false
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.signalStrengthMeasurements,
                        text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                        isConfidential: false
                    )
                }
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.signalStrengthMeasurements,
                    text: String.localizedStringWithFormat(NSLocalizedString("SignalStrength", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡网络选择的信息 原始数据
    func getSlotNetworkSelectionInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let networkSelectionInfo = try coreTelephonyController.getSlotNetworkSelectionInfo(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.networkSelectionInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionInfo", comment: ""), networkSelectionInfo),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.networkSelectionInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("NetworkSelectionInfo", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的卡的注册状态 原始数据
    func getSlotRegistrationDisplayStatus(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let registrationStatus = try coreTelephonyController.getSlotRegistrationDisplayStatus(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.registrationStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("RegistrationStatus", comment: ""), registrationStatus),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.registrationStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("RegistrationStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的SIM卡硬件信息 原始数据
    func getSlotSimHardwareInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let SIMHardwareInfo: CTSimHardwareInfo = try coreTelephonyController.getSlotSimHardwareInfo(context: context)
                return InfoItem(
                    id: CoreTelephonyRAWItemID.SIMHardwareInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMHardwareInfo", comment: ""), SIMHardwareInfo),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.SIMHardwareInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("SIMHardwareInfo", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取设备信息 原始数据
    /// 两个卡槽获取的数据不一样
    func getSlotMobileEquipmentInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let deviceInfo = try coreTelephonyController.getSlotMobileEquipmentInfo(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.deviceInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("DeviceInfoWithText", comment: ""), deviceInfo),
                isConfidential: true
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.deviceInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("DeviceInfoWithText", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    // 获取当前卡槽的系统能力 原始数据
    func getSlotSystemCapabilities(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let systemCapabilities = try coreTelephonyController.getSlotSystemCapabilities(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.systemCapabilities,
                text: String.localizedStringWithFormat(NSLocalizedString("SystemCapabilities", comment: ""), String(describing: systemCapabilities)),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.systemCapabilities,
                text: String.localizedStringWithFormat(NSLocalizedString("SystemCapabilities", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的GSMA UI Control Setting
    /// 不知道做什么的
    func getSlotGSMAUIControlSetting(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.GSMAUIControlSetting,
                    text: "GSMA UI Control Setting: \(String(describing: try coreTelephonyController.getSlotGSMAUIControlSetting(context: context)))",
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.GSMAUIControlSetting,
                    text: "GSMA UI Control Setting: \(NSLocalizedString("NoPermission", comment: ""))",
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取卡槽的网络小区小区信息
    func getSlotCellInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            if let cellInfo = try coreTelephonyController.getSlotCellInfo(context: context) {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.cellInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellInfo", comment: ""), cellInfo),
                    detailText: String(describing: cellInfo),
                    isConfidential: true,
                    copyable: true
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.cellInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellInfo", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                    isConfidential: false
                )
            }
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.cellInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("CellInfo", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取卡槽的卡5G NR禁用状态 原始数据
    func getSlotNRStatusInfo(descriptor: CTServiceDescriptor) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                if let NRStatus = try getSlotNRStatus(descriptor: descriptor) {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.NRStatus,
                        text: String.localizedStringWithFormat(NSLocalizedString("NRStatus", comment: ""), NRStatus),
                        isConfidential: false
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.NRStatus,
                        text: String.localizedStringWithFormat(NSLocalizedString("NRStatus", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                        isConfidential: false
                    )
                }
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.NRStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("NRStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的基带信息
    func getSlotBandInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                // 获取原始数据
                let bandInfoRAWData = try coreTelephonyController.getSlotBandInfo(context: context)
                // 转换为BandInfo类
                let bandInfo = BandInfo.convert(from: bandInfoRAWData)
                // 转换为可读文本
                let activeBandsText: String = BandInfo.format(bandInfo.active)
                let supportedBandsText: String = BandInfo.format(bandInfo.supported)
                
                return InfoItem(
                    id: CoreTelephonyItemID.bandInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("BandInfo", comment: ""),
                                                           activeBandsText.isEmpty ? NSLocalizedString("None", comment: "") : activeBandsText,
                                                           supportedBandsText.isEmpty ? NSLocalizedString("None", comment: "") : supportedBandsText),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.bandInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("BandInfo", comment: ""),
                                                           NSLocalizedString("NoPermission", comment: ""),
                                                           NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 获取卡槽的卡的频段信息 原始数据
    func getSlotBandRAWInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem? {
        if #available(iOS 14.0, *) {
            do {
                let bandInfo = try coreTelephonyController.getSlotBandInfo(context: context)
                return InfoItem(
                    id: CoreTelephonyItemID.bandInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("BandInformation", comment: ""), bandInfo),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyItemID.bandInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("BandInformation", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
            
        }
        return nil
    }
    
    /// 获取卡的PNR状态 原始数据
    func getSlotPNRInfo(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let PNRInfo = try coreTelephonyController.getSlotPNRContextInfo(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.PNRInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), PNRInfo),
                isConfidential: true
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyRAWItemID.PNRInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else if error.code == 35 { // 无SIM卡
                return InfoItem(
                    id: CoreTelephonyRAWItemID.PNRInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), NSLocalizedString("NoSIM", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.PNRInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumberRegistrationCapability", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取卡槽已连接的服务 原始数据
    func getSlotActiveConnectionsRAW(context: CTXPCServiceSubscriptionContext) -> InfoItem {
        do {
            let connections = try coreTelephonyController.getSlotActiveConnections(context: context)
            return InfoItem(
                id: CoreTelephonyRAWItemID.activeConnections,
                text: String.localizedStringWithFormat(NSLocalizedString("ActiveCellularServices", comment: ""), connections),
                isConfidential: false
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyRAWItemID.activeConnections,
                text: String.localizedStringWithFormat(NSLocalizedString("ActiveCellularServices", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取设备基本信息 原始数据
    func getDeviceInfoList() -> InfoItem {
        do {
            let deviceInfo = try coreTelephonyController.getDeviceInfoList()
            return InfoItem(
                id: CoreTelephonyRAWItemID.deviceInfo,
                text: String.localizedStringWithFormat(NSLocalizedString("DeviceInfoWithText", comment: ""), deviceInfo),
                isConfidential: true
            )
        } catch let error as NSError {
            if error.code == 1 || error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyRAWItemID.deviceInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("DeviceInfoWithText", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.deviceInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("DeviceInfoWithText", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
        }
        
    }
    
    /// 获取设备蜂窝网络数据状态 原始数据
    func getDeviceDataStatus() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let dataStatus = try coreTelephonyController.getDeviceDataStatus()
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), dataStatus),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularDataStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        }
        return nil
    }
    
    /// 蜂窝网络连接信息 原始数据
    func getDeviceInternetConnectionState() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                if let internetConnectionState = try coreTelephonyController.getDeviceInternetConnectionState() {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.internetConnection,
                        text: String.localizedStringWithFormat(NSLocalizedString("InternetConnectionState", comment: ""), internetConnectionState)
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.internetConnection,
                        text: String.localizedStringWithFormat(NSLocalizedString("InternetConnectionState", comment: ""),  NSLocalizedString("Unknown", comment: "未知"))
                    )
                }
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.internetConnection,
                    text: String.localizedStringWithFormat(NSLocalizedString("InternetConnectionState", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            }
        }
        return nil
    }
    
    /// 获取设备的数据载体 原始数据
    /// 最低兼容iOS 14
    func getDeviceDataBearerRAW() -> InfoItem? {
        do {
            let dataBearer: Int
            if #available(iOS 18.0, *) { // iOS 18及以上用兼容方案
                dataBearer = Int(try coreTelephonyController.getDeviceDataStatus().dataBearerTechnology)
            } else if #available(iOS 15.0, *) { // iOS 15 ～ iOS 17 用短暂的API
                dataBearer = try coreTelephonyController.getDeviceDataBearer()
            } else if #available(iOS 14.0, *) { // 低版本仍然用兼容方案
                dataBearer = Int(try coreTelephonyController.getDeviceDataStatus().dataBearerTechnology)
            } else { // iOS 12 iOS 13不支持
                return nil
            }
            return InfoItem(
                id: CoreTelephonyRAWItemID.dataBearer,
                text: String.localizedStringWithFormat(NSLocalizedString("DataBearer", comment: ""), String(dataBearer))
            )
        } catch let error as NSError {
            if error.code == 13 {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataBearer,
                    text: String.localizedStringWithFormat(NSLocalizedString("DataBearer", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.dataBearer,
                    text: String.localizedStringWithFormat(NSLocalizedString("DataBearer", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                )
            }
        }
    }
    
    /// 设备紧急模式信息 原始数据
    func getDeviceEmergencyModeInfo() -> InfoItem? {
        if #available(iOS 13.0, *) {
            do {
                let emergencyModeInfo = try coreTelephonyController.getDeviceEmergencyModeInfo()
                return InfoItem(
                    id: CoreTelephonyRAWItemID.emergencyModeInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyModeInfo", comment: ""), emergencyModeInfo),
                    isConfidential: false
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.emergencyModeInfo,
                    text: String.localizedStringWithFormat(NSLocalizedString("EmergencyModeInfo", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取设备共享网络信息 原始数据
    func getDeviceTetheringStatusInfo() -> InfoItem? {
        if #available(iOS 15.0, *) {
            do {
                let tetheringStatus = try coreTelephonyController.getDeviceTetheringStatusInfo()
                return InfoItem(
                    id: CoreTelephonyRAWItemID.tetheringStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("TetheringStatus", comment: ""), tetheringStatus),
                    isConfidential: true
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.tetheringStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("TetheringStatus", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: false
                )
            }
        } else {
            return nil
        }
    }
    
    /// 获取设备已保存的SIM卡记录(ICCID) 原始数据
    private func getDeviceSavedICCIDList() -> InfoItem {
        do {
            let ICCIDList = try coreTelephonyController.getDeviceSavedICCIDLists()
            return InfoItem(
                id: CoreTelephonyRAWItemID.tetheringStatus,
                text: String.localizedStringWithFormat(NSLocalizedString("SavedSIMRecord", comment: ""), ICCIDList),
                isConfidential: true
            )
        } catch let error as NSError {
            if error.code == 13 { // 无权限
                return InfoItem(
                    id: CoreTelephonyRAWItemID.tetheringStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("SavedSIMRecord", comment: ""), NSLocalizedString("NoPermission", comment: "")),
                    isConfidential: true
                )
            } else if error.code == 4099 { // 模拟器
                return InfoItem(
                    id: CoreTelephonyRAWItemID.tetheringStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("SavedSIMRecord", comment: ""), NSLocalizedString("DeviceNotSupported", comment: "")),
                    isConfidential: true
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.tetheringStatus,
                    text: String.localizedStringWithFormat(NSLocalizedString("SavedSIMRecord", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription)),
                    isConfidential: false
                )
            }
            
        }
    }
    
    /// 获取蜂窝用量工作区 原始数据
    func getDeviceCellularUsageWorkspaceInfo() -> InfoItem? {
        if #available(iOS 17.0, *) {
            do {
                let info = try coreTelephonyController.getDeviceCellularUsageWorkspaceInfo()
                return InfoItem(
                    id: CoreTelephonyRAWItemID.cellularUsageWorkspace,
                    text: String.localizedStringWithFormat(NSLocalizedString("CellularUsageWorkspaceInfo", comment: ""), info),
                    detailText: String(describing: info),
                    copyable: true
                )
            } catch let error as NSError {
                if error.code == 13 { // 无权限
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.cellularUsageWorkspace,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularUsageWorkspaceInfo", comment: ""), NSLocalizedString("NoPermission", comment: ""))
                    )
                } else {
                    return InfoItem(
                        id: CoreTelephonyRAWItemID.cellularUsageWorkspace,
                        text: String.localizedStringWithFormat(NSLocalizedString("CellularUsageWorkspaceInfo", comment: ""), String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))
                    )
                }
            }
        }
        return nil
    }
    
    /// 获取Packet Context数量 原始数据
    /// 不知道做什么的
    func getDevicePacketContextCount() -> InfoItem {
        do {
            let count = try coreTelephonyController.getDevicePacketContextCount()
            return InfoItem(
                id: CommonItemID.test,
                text: "Packet Context Count: \(String(count))"
            )
        } catch let error as NSError {
            if error.code == 4099 { // 模拟器不支持
                return InfoItem(
                    id: CommonItemID.test,
                    text: "Packet Context Count: \(NSLocalizedString("DeviceNotSupported", comment: ""))"
                )
            } else {
                return InfoItem(
                    id: CommonItemID.test,
                    text: "Packet Context Count: \(String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""), error.code ,error.localizedDescription))"
                )
            }
        }
    }
    
    
    /// 是否显示品牌通话信息
    /// 不知道做什么的
    func getDeviceShouldShowBrandedCallingInfo() -> InfoItem? {
        if #available(iOS 16.0, *) {
            do {
                let result = try coreTelephonyController.getDeviceShouldShowBrandedCallingInfo()
                return InfoItem(
                    id: CoreTelephonyRAWItemID.brandedCallingInfo,
                    text: "Should Show Branded Calling Info: \(result ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: ""))"
                )
            } catch {
                return InfoItem(
                    id: CoreTelephonyRAWItemID.brandedCallingInfo,
                    text: "Should Show Branded Calling Info: \(NSLocalizedString("NoPermission", comment: ""))"
                )
            }
        }
        
        return nil
    }
    
    /// 获取设备基本信息 系统版本号
    func getDeviceBaseInfoGroup() -> InfoItemGroup {
        return InfoItemGroup(id: CellularDataItemGroupID.deviceBaseInfo, items: [getDeviceBasicInfo()])
    }
    
    /// 获取设备基础信息组
    func getDeviceBaseCellularInfoGroup(inGroups: Bool) -> [InfoItemGroup] {
        // 获取是否显示实验性功能
        let experimentalFeatures = SettingsUtils.instance.getEnableExperimentalFeatures()
        var deviceInfoGroup: [InfoItemGroup] = []
        let deviceBaseInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceCellularInfo)
        deviceInfoGroup.append(deviceBaseInfoGroup)
        if !inGroups {
            deviceBaseInfoGroup.titleText = NSLocalizedString("DeviceInfo", comment: "")
        }
        deviceBaseInfoGroup.addItem(getDeviceSupportsCellular())
        if coreTelephonyController.getDeviceSupportsCellular() {  // 只有设备支持蜂窝网络才加载这些数据，否则没啥意义
            deviceBaseInfoGroup.addItemIfPresent(getDeviceCarrierLockState())
            deviceBaseInfoGroup.addItem(getDeviceSupports5G())
            deviceBaseInfoGroup.addItem(getDualSimCapability())
            deviceBaseInfoGroup.addItem(getSupportsEmbeddedSIM())
//            deviceBaseInfoGroup.addItem(getAllowInstallEmbeddedSIM())
            // 异步获取是否允许安装eSIM
            let eSIMInstallItem = getAllowInstallEmbeddedSIMItem { updated in
                // 更新数据
                deviceBaseInfoGroup.updateItem(updated)
                // 发送通知
                NotificationCenter.default.post(
                    name: CellularDataController.cellularDataItemUpdatedNotificationName,
                    object: nil
                )
            }
            deviceBaseInfoGroup.addItem(eSIMInstallItem)
            deviceBaseInfoGroup.addItem(getEmbeddedSIMOnlyDevice())
            deviceBaseInfoGroup.addItemIfPresent(getDeviceHotspotAvailable())
            deviceBaseInfoGroup.addItem(getDeviceCellularPlanTransferable())
            deviceBaseInfoGroup.addItemIfPresent(getEmbeddedSIMHealth())
            
            let cellularStatusGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceCellularInfo)
            cellularStatusGroup.titleText = NSLocalizedString("CellularStatus", comment: "")
            cellularStatusGroup.addItem(getSIMTrayStatus())
            cellularStatusGroup.addItem(getDeviceIsAnySIMReadyInfo())
            cellularStatusGroup.addItem(getDeviceCellularDataEnabled())
            cellularStatusGroup.addItemIfPresent(getInternetConnectionAvailability())
            cellularStatusGroup.addItemIfPresent(getPreferredDataSelectRateInfo())
            cellularStatusGroup.addItemIfPresent(getPreferredDataSlotInfo())
            cellularStatusGroup.addItemIfPresent(getDefaultVoiceSlotInfo())
            cellularStatusGroup.addItem(getDeviceEnableDataRoaming())
            cellularStatusGroup.addItemIfPresent(getDeviceDynamicDataSimSwitchState())
            cellularStatusGroup.addItem(getDeviceDynamicDataSimSwitchOnCallState())
            cellularStatusGroup.addItemIfPresent(getDeviceEnablediCloudPrivateRelay())
            cellularStatusGroup.addItemIfPresent(getDeviceMobileDataUsageCollectionEnabled())
            cellularStatusGroup.addItemIfPresent(getDeviceHotspotEnabled())
            cellularStatusGroup.addItemIfPresent(getDevice2GSwitchEnabled())
            cellularStatusGroup.addItemIfPresent(getDevice2GUserPreference())
            if experimentalFeatures {
                cellularStatusGroup.addItemIfPresent(getDeviceFactoryDebugEnabled()) // 工厂测试模式
                cellularStatusGroup.addItemIfPresent(getDeviceReleaseCandidateFlag()) // RC标记
                cellularStatusGroup.addItemIfPresent(getDeviceNeedToLaunchSetUpEmbeddedSIM()) // 需要显示设置eSIM界面
                cellularStatusGroup.addItemIfPresent(getDeviceShouldShowEmbeddedSIMTravelTips()) // 显示eSIM旅行提示
                cellularStatusGroup.addItemIfPresent(getDeviceUsingBootstrapDataService()) // 正在使用eSIM下载服务
                cellularStatusGroup.addItemIfPresent(getDeviceNATTKeepAliveOverCell()) // NATT最大时间
                cellularStatusGroup.addItemIfPresent(getDeviceSupportedDedicatedBearer()) // 是否支持专用承载
                cellularStatusGroup.addItemIfPresent(getDevicePublicNrFrequencyRange()) // NR频率范围
                cellularStatusGroup.addItemIfPresent(getDeviceEmergencyTextNumbers()) // 紧急呼叫允许的列表
            }
            
            // 基带硬件标识分组
            let modemIdentifiersGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceCellularInfo)
            modemIdentifiersGroup.titleText = NSLocalizedString("ModemIdentifiers", comment: "")
            
            modemIdentifiersGroup.addItem(getDeviceLogicBoardID(showFull: true))
            modemIdentifiersGroup.addItem(getDeviceModemFirmwareVersion())
            modemIdentifiersGroup.addItem(getBasebandUniqueID())
            modemIdentifiersGroup.addItem(getIMEI1())
            modemIdentifiersGroup.addItemIfPresent(getIMEI2())
            modemIdentifiersGroup.addItemIfPresent(getMEID())
            modemIdentifiersGroup.addItemIfPresent(getEID())
            
            // 整合数据
            deviceInfoGroup.append(cellularStatusGroup)
            deviceInfoGroup.append(modemIdentifiersGroup)
            
            if experimentalFeatures {
                let underlyingDataGroup = InfoItemGroup(id: deviceBaseInfoGroup.id)
                underlyingDataGroup.addItem(InfoItem(id: ActionItemID.underlyingData, text: NSLocalizedString("UnderlyingData", comment: "")))
                
                deviceInfoGroup.append(underlyingDataGroup)
            }
        }
        
        return deviceInfoGroup
    }
    
    /// 获取设备基本信息组的原始数据组
    func getDeviceBaseCellularUnderlyingInfoGroup() -> InfoItemGroup {
        let deviceBaseUnderlyingInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceCellularInfo)
        deviceBaseUnderlyingInfoGroup.addItem(getDeviceInfoList()) // 设备信息
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceSupportsHydra()) // 设备是否支持Hydra
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceInternetConnectionState()) // 蜂窝网络连接信息
        deviceBaseUnderlyingInfoGroup.addItem(getDevicePacketContextCount()) // 获取设备Packet Context数量 具体不知道做什么的
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceDataStatus()) // 蜂窝网络数据状态
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceDataBearerRAW()) // 蜂窝网络数据载体
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceTetheringStatusInfo()) // 网络共享信息
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceEmergencyModeInfo()) // 紧急模式信息
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceCellularUsageWorkspaceInfo()) // 蜂窝用量工作区信息
        deviceBaseUnderlyingInfoGroup.addItem(getDeviceSavedICCIDList()) // 已保存的SIM卡记录(ICCID)
        deviceBaseUnderlyingInfoGroup.addItemIfPresent(getDeviceShouldShowBrandedCallingInfo()) // 显示品牌信息
        
        return deviceBaseUnderlyingInfoGroup
    }
    
    /// 获取卡槽信息组
    func getSlotInfoGroup(slotID: Int, inGroups: Bool) -> [InfoItemGroup]? {
        // 先获取完全的context，如果没获取到就获取不全的context 主要给无权限机器获取不全的信息
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID),
           let descriptor = coreTelephonyController.getServiceDescriptor(slotID: slotID) {
            var slotGroup: [InfoItemGroup] = []
            let groupID = slotID == 1 ? CellularDataItemGroupID.slot1BaseInfo : CellularDataItemGroupID.slot2BaseInfo
            
            // 获取是否显示实验性功能
            let experimentalFeatures = SettingsUtils.instance.getEnableExperimentalFeatures()
            
            // 有启用的卡或用户强制启用显示的时候再显示详细信息
            if getSlotEnableSIM(context: context) || SettingsUtils.instance.getShowInactiveSIMSlotsData() {
                
                // 基本信息分组
                let slotBasicInfoGroup = InfoItemGroup(id: groupID)
                slotBasicInfoGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("Basic", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotBasicInfoGroup.addItemIfPresent(getSlotLabel(context: context))
                slotBasicInfoGroup.addItem(getSlotCarrierName(context: context))
                slotBasicInfoGroup.addItem(getSlotLocalizedOperatorName(context: context))
                slotBasicInfoGroup.addItemIfPresent(getSlotOperatorEnglishName(context: context))
                slotBasicInfoGroup.addItemIfPresent(getSlotPhoneNumber(context: context))
                if experimentalFeatures {
                    slotBasicInfoGroup.addItemIfPresent(getSlotPhoneNumberEditable(context: context))
                }
                slotBasicInfoGroup.addItem(getSlotUseIMEI(context: context))
                slotBasicInfoGroup.addItemIfPresent(getSlotUseTypeAllocationCode(context: context, descriptor: descriptor))
                slotBasicInfoGroup.addItem(getSlotIMSI(context: context))
                slotBasicInfoGroup.addItem(getSlotICCID(context: context))
                slotBasicInfoGroup.addItem(getSlotGID1(context: context))
                slotBasicInfoGroup.addItem(getSlotGID2(context: context))
                
                // SIM卡分组
                let slotSIMInfoGroup = InfoItemGroup(id: groupID)
                slotSIMInfoGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("SIM", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotSIMInfoGroup.addItem(getSlotSIMTypeInfo(context: context))
                slotSIMInfoGroup.addItem(getSlotSIMStatus(context: context))
                slotSIMInfoGroup.addItemIfPresent(getSlotSIMLocation(context: context))
                slotSIMInfoGroup.addItemIfPresent(getSlotsSIMPresent(fullyContext: context))
                slotSIMInfoGroup.addItemIfPresent(getSlotsSIMGood(fullyContext: context))
                if experimentalFeatures {
                    slotSIMInfoGroup.addItemIfPresent(getSlotSIMIsPrivateNetwork(context: context)) // 私有网络SIM
                }
                slotSIMInfoGroup.addItem(getSlotSIMCardMCCInfo(context: context))
                slotSIMInfoGroup.addItem(getSlotSIMCardMNCInfo(context: context))
                slotSIMInfoGroup.addItem(getSlotMobileSubscriberHomeCountryList(context: context))
                slotSIMInfoGroup.addItem(getSlotSIMLockedWithPIN(context: context))
                slotSIMInfoGroup.addItemIfPresent(getSlotAllowSIMLockWithPIN(context: context))
                slotSIMInfoGroup.addItem(getSlotRemainingPINAttemptCount(context: context))
                slotSIMInfoGroup.addItem(getSlotRemainingPUKAttemptCount(context: context))
                slotSIMInfoGroup.addItem(getSlotSMSCenterNumber(context: context))
                slotSIMInfoGroup.addItemIfPresent(getSlotSIMPhonebookCount(context: context))
                
                // 网络分组
                let slotNetworkInfoGroup = InfoItemGroup(id: groupID)
                slotNetworkInfoGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("Network", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotNetworkInfoGroup.addItem(getSlotRegistrationStatus(context: context))
                slotNetworkInfoGroup.addItem(getSlotSignalStrengthInfo(context: context))
                slotNetworkInfoGroup.addItem(getSlotRadioAccessTechnologyInfo(slotID: slotID, context: context))
                slotNetworkInfoGroup.addItemIfPresent(getSlotNRConnected(context: context))
                slotNetworkInfoGroup.addItemIfPresent(getSlot5GAdvancedConnected(context: context))
                slotNetworkInfoGroup.addItem(getSlotSelectRateInfo(context: context))
                slotNetworkInfoGroup.addItemIfPresent(getSlotSupportRatesInfo(context: context))
                if experimentalFeatures {
                    slotNetworkInfoGroup.addItems(getSlotRatSectionInfo(descriptor: descriptor, context: context))
                }
                slotNetworkInfoGroup.addItem(getSlotUseHomeNetworkPolicy(context: context))
                slotNetworkInfoGroup.addItemIfPresent(getSlotPLMNInfo(context: context))
                slotNetworkInfoGroup.addItem(getSlotServingMCCInfo(context: context))
                slotNetworkInfoGroup.addItemIfPresent(getSlotLastRegisteredNetworkMCCInfo(context: context))
//                if experimentalFeatures {
//                    slotNetworkInfoGroup.addItem(getSlotLastRegisteredNetworkMNCCountryCodeInfo(context: context)) // TODO 鸡肋数据
//                }
                slotNetworkInfoGroup.addItem(getSlotServingMNCInfo(context: context))
                slotNetworkInfoGroup.addItem(getSlotIMSRegistrationStatus(context: context))
                slotNetworkInfoGroup.addItem(getSlotActiveConnections(context: context))
                slotNetworkInfoGroup.addItem(getSlotSMSReadyState(context: context))
                slotNetworkInfoGroup.addItem(getSlotAPNConfigEntry())
                
                // 射频分组
                let slotRadioInfo = InfoItemGroup(id: groupID)
                slotRadioInfo.titleText = setSlotGroupTitle(title: NSLocalizedString("Radio", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotRadioInfo.addItem(getSlotServingCellID(descriptor: descriptor))
                slotRadioInfo.addItemIfPresent(getSlotRSRP(descriptor: descriptor))
                slotRadioInfo.addItemIfPresent(getSlotSNR(descriptor: descriptor))
                slotRadioInfo.addItemIfPresent(getSlotRSCP(descriptor: descriptor))
                slotRadioInfo.addItemIfPresent(getSlotECN0(descriptor: descriptor))
                
                if let cellInfo = try? coreTelephonyController.getSlotCellInfo(context: context) {
                    slotRadioInfo.addItemIfPresent(getSlotRSRP(cellInfo: cellInfo)) // 低版本系统获取RSRP的方法
                    slotRadioInfo.addItemIfPresent(getSlotServingBand(context: context, cellInfo: cellInfo))
                    slotRadioInfo.addItem(getSlotServingBandwidth(context: context, cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotServingBWPSupport(cellInfo: cellInfo, experimentalFeatures: experimentalFeatures))
                    slotRadioInfo.addItemIfPresent(getSlotNRSubcarrierSpacing(cellInfo: cellInfo))
                    slotRadioInfo.addItem(getSlotMaximumTransmitPowerLimit(cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotGSCN(cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotNRARFCN(cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotUARFCN(context: context, cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotPhysicalCellID(cellInfo: cellInfo))
                    slotRadioInfo.addItemIfPresent(getSlotServingTrackingAreaCode(cellInfo: cellInfo))
                }
                slotRadioInfo.addItem(getSlotServingLocationAreaCode(context: context))
                
                // 蜂窝能力分组
                let slotCapabilityGroup = InfoItemGroup(id: groupID)
                slotCapabilityGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("Capability", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotCapabilityGroup.addItemIfPresent(getSlotSupports5G(context: context))
                slotCapabilityGroup.addItemIfPresent(getSlotSupports5GSA(descriptor: descriptor))
                slotCapabilityGroup.addItemIfPresent(getSlotSupports5GNSA(descriptor: descriptor))
                slotCapabilityGroup.addItemIfPresent(getSlotSupportsHighDataMode(descriptor: descriptor))
                slotCapabilityGroup.addItem(getSlotSupportedVoLTE(context: context))
                slotCapabilityGroup.addItem(getSlotSupportedWiFiCalling(context: context))
                if experimentalFeatures {
                    slotCapabilityGroup.addItemIfPresent(getSlotBandInfo(context: context)) // 频段信息
                    slotCapabilityGroup.addItem(getSlotPNRSupported(context: context)) // 号码注册能力PNR
                }
                slotCapabilityGroup.addItem(getSlotOperatorMultiPartyCallCountMaximum(context: context))
                
                // 蜂窝配置分组
                let slotConfigGroup = InfoItemGroup(id: groupID)
                slotConfigGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("CellularConfiguration", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotConfigGroup.addItemIfPresent(getSlotIsPreferredData(fullyContext: context))
                slotConfigGroup.addItemIfPresent(getSlotIsDefaultVoice(fullyContext: context))
                slotConfigGroup.addItemIfPresent(getSlotEnabled5GAuto(descriptor: descriptor))
                slotConfigGroup.addItem(getSlotNetworkSelectionMode(context: context))
                slotConfigGroup.addItem(getSlotNetworkSelectionMenuAvailable(context: context))
                slotConfigGroup.addItemIfPresent(getSlotEnableDataRoaming(descriptor: descriptor))
                slotConfigGroup.addItemIfPresent(getSlotLowDataMode(descriptor: descriptor))
                slotConfigGroup.addItemIfPresent(getSlotLimitIPTrackingEnabled(descriptor: descriptor))
                if experimentalFeatures {
                    slotConfigGroup.addItemIfPresent(getSlotInterfaceCostExpensive(descriptor: descriptor)) // 高成本网络
                    slotConfigGroup.addItemIfPresent(getSlotShouldShowUserWarningWhenDialingCall(context: context)) // 拨号前需要提示
                    slotConfigGroup.addItem(getSlotPhoneNumberCredentialValid(context: context)) // 号码认证状态
                }
                
                // 运营商配置文件分组
                let slotCarrierBundleInfoGroup = InfoItemGroup(id: groupID)
                slotCarrierBundleInfoGroup.titleText = setSlotGroupTitle(title: NSLocalizedString("CarrierBundle", comment: ""), slotID: slotID, inGroups: inGroups)
                
                slotCarrierBundleInfoGroup.addItem(getSlot4GNetworkIndicator(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotNRMMWaveIndicatorText(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotCarrierBundleVersion(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotCarrierBundleLocation(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotTetheringEditingSupported(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotAllowedAttachAPNSetting(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierBundleShow5GSwitch(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierBundleShow5GStandaloneSwitch(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotCarrierBundleShow4GSwitch(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierBundleShow3GSwitch(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierBundleShowVoLTESwitch(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierDisableVoLTE(context: context))
                slotCarrierBundleInfoGroup.addItem(getSlotCarrierBundleSupportedSIMs(context: context))
                slotCarrierBundleInfoGroup.addItemIfPresent(getSlotEmergencyTextNumbers(context: context))
                if experimentalFeatures {
                    slotCarrierBundleInfoGroup.addItemIfPresent(getSlotCarrierBundleOTABeforeUserConfirm(context: context)) // 运营商配置文件更新前是否需要用户同意
                    slotCarrierBundleInfoGroup.addItem(getSlotNATTKeepAliveOverCell(context: context)) // NAT最大保持时间
                }
                slotCarrierBundleInfoGroup.addItem(getSlotCarrierBookmarksEntry())
                
                // 整合数据
                slotGroup.append(slotBasicInfoGroup)
                slotGroup.append(slotSIMInfoGroup)
                slotGroup.append(slotNetworkInfoGroup)
                slotGroup.append(slotRadioInfo)
                slotGroup.append(slotCapabilityGroup)
                slotGroup.append(slotConfigGroup)
                slotGroup.append(slotCarrierBundleInfoGroup)
                
            } else { // 没有卡的时候就显示没卡就行了
                let slotInfoGroup = InfoItemGroup(id: groupID)
                slotInfoGroup.addItem(getSlotSIMStatus(context: context))
                if !inGroups { // 堆叠显示的时候显示组标题
                    slotInfoGroup.titleText = String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), slotID)
                }
                slotGroup.append(slotInfoGroup)
            }
            
            if experimentalFeatures {
                // 增加原始数据分组
                let underlyingDataGroup = InfoItemGroup(id: groupID)
                underlyingDataGroup.addItem(InfoItem(id: ActionItemID.underlyingData, text: NSLocalizedString("UnderlyingData", comment: "")))
                
                slotGroup.append(underlyingDataGroup)
            }
            
            return slotGroup
        }
        return nil
    }
    
    /// 设置卡槽分组标题
    private func setSlotGroupTitle(title: String, slotID: Int, inGroups: Bool) -> String {
        if inGroups {
            return title
        } else {
            return String.localizedStringWithFormat(
                NSLocalizedString("SlotNumberPrefixFormat", comment: ""), slotID, title)
        }
    }
    
    /// 获取卡槽信息组的原始数据组
    func getSlotUnderlyingInfoGroup(slotID: Int) -> InfoItemGroup? {
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID),
           let descriptor = coreTelephonyController.getServiceDescriptor(slotID: slotID) {
            let slotUnderlyingInfoGroup = InfoItemGroup(id: slotID == 1 ? CellularDataItemGroupID.slot1BaseInfo : CellularDataItemGroupID.slot2BaseInfo)
            slotUnderlyingInfoGroup.titleText = String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), slotID)
            
            slotUnderlyingInfoGroup.addItem(getSlotLabelRAWData(context: context)) // 卡标签 原始数据
            slotUnderlyingInfoGroup.addItem(getSlotDataStatus(context: context)) // 蜂窝数据状态 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotDataStatusBasic(context: context)) // 蜂窝数据状态 基本数据 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotSimHardwareInfo(context: context)) // SIM卡硬件信息
            slotUnderlyingInfoGroup.addItem(getSlotActiveConnectionsRAW(context: context)) // 获取卡槽已连接的服务 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotSignalStrengthMeasurements(descriptor: descriptor)) // 信号测量
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotDataModeRAW(context: context, descriptor: descriptor)) // 数据模式
            slotUnderlyingInfoGroup.addItem(getSlotCellInfo(context: context)) // 网络小区信息
            slotUnderlyingInfoGroup.addItem(getSlotNetworkSelectionInfo(context: context)) // 网络选择的信息 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotNetworkRejectCause(context: context)) // 被网络拒绝的原因
            slotUnderlyingInfoGroup.addItem(getSlotRegistrationDisplayStatus(context: context)) // 卡注册状态
            slotUnderlyingInfoGroup.addItem(getSlotMobileEquipmentInfo(context: context)) // 获取设备信息 原始数据
            slotUnderlyingInfoGroup.addItem(getSlotSystemCapabilities(context: context)) // 获取当前卡槽的系统能力 原始数据
            slotUnderlyingInfoGroup.addItem(getSlotPNRInfo(context: context)) // 获取卡的PNR状态 原始数据
//            slotUnderlyingInfoGroup.addItemIfPresent(getSlotBandInfoRAW(context: context)) // 获取设备频段信息 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotNRStatusInfo(descriptor: descriptor)) // 卡槽的卡5G NR禁用状态 原始数据
            slotUnderlyingInfoGroup.addItemIfPresent(getSlotGSMAUIControlSetting(context: context)) // GSMA UI Control Setting
            
            return slotUnderlyingInfoGroup
        }
        return nil
    }
    
    /// 获取蜂窝数据页面的信息聚合
    func getCellularDataGroups(inGroups: Bool) -> [InfoItemGroup] {
        
        var cellularDataGroups = [getDeviceBaseInfoGroup()] + getDeviceBaseCellularInfoGroup(inGroups: inGroups)
        if let slot1Group = getSlotInfoGroup(slotID: 1, inGroups: inGroups) {
            cellularDataGroups = cellularDataGroups + slot1Group
        }
        if IMEICount > 1 { // IMEI有两个的再去获取卡槽2的数据，不然就是瞎浪费时间
            if let slot2Group = getSlotInfoGroup(slotID: 2, inGroups: inGroups) {
                cellularDataGroups = cellularDataGroups + slot2Group
            }
        }
        return cellularDataGroups
    }
    
    /// 获取蜂窝数据卡的标签
    func getCellularPlanLabelName(plan: CTCellularPlanItem) -> InfoItem? {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad显示的标签有问题，直接不显示这一条了
            return nil
        }
        if let label = plan.label { // 必须判断非nil iOS 14设备上 未知运营商的卡如果不判断会导致闪退 iOS 14返回的是nil
            return InfoItem(
                id: CellularPlanItemID.label,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanLabel", comment: ""), label),
                isConfidential: false
            )
        } else {
            return InfoItem(
                id: CellularPlanItemID.label,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanLabel", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                isConfidential: false
            )
        }
    }
    
    /// 获取蜂窝数据卡的名称
    func getCellularPlanName(plan: CTCellularPlanItem) -> InfoItem {
        if let name =  plan.name { // 必须判断非nil iOS 14设备上 未知运营商的卡如果不判断会导致闪退 iOS 14返回的是nil
            return InfoItem(
                id: CellularPlanItemID.name,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanName", comment: ""), name.isEmpty ? NSLocalizedString("UnknownCarrier", comment: "") : plan.name),
                isConfidential: false
            )
        } else {
            return InfoItem(
                id: CellularPlanItemID.name,
                text: String.localizedStringWithFormat(NSLocalizedString("CellularPlanName", comment: ""), NSLocalizedString("UnknownCarrier", comment: "")),
                isConfidential: false
            )
        }
        
    }
    
    /// 获取蜂窝数据卡的运营商名称
    func getCellularPlanCarrierName(plan: CTCellularPlanItem) -> InfoItem {
        if let carrierName = plan.carrierName { // 必须判断非nil iOS 14设备上 未知运营商的卡如果不判断会导致闪退 iOS 14返回的是nil
            return InfoItem(
                id: CellularPlanItemID.carrierName,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), carrierName.isEmpty ? NSLocalizedString("UnknownCarrier", comment: "") : plan.carrierName),
                isConfidential: false
            )
        } else {
            return InfoItem(
                id: CellularPlanItemID.carrierName,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), NSLocalizedString("UnknownCarrier", comment: "")),
                isConfidential: false
            )
        }
    }
    
    /// 获取蜂窝数据卡的UUID
    func getCellularPlanUUID(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.uuid,
            text: String.localizedStringWithFormat(NSLocalizedString("UUID", comment: ""), plan.uuid),
            isConfidential: true
        )
    }
    
    /// 获取蜂窝数据卡的ICCID
    func getCellularPlanICCID(plan: CTCellularPlanItem) -> InfoItem {
        if let ICCID = plan.iccid {
            return InfoItem(
                id: CommonItemID.ICCID,
                text: String.localizedStringWithFormat(NSLocalizedString("ICCID", comment: ""), ICCID),
                isConfidential: true
            )
        } else {
            return InfoItem(
                id: CommonItemID.ICCID,
                text: String.localizedStringWithFormat(NSLocalizedString("ICCID", comment: ""), NSLocalizedString("NotObtained", comment: "")),
                isConfidential: true
            )
        }
    }
    
    /// 获取蜂窝数据卡的SIM卡类型
    func getCellularPlanSIMType(plan: CTCellularPlanItem) -> InfoItem {
        let SIMType = plan.type
        let SIMTypeText: String
        switch SIMType {
        case 0: SIMTypeText = NSLocalizedString("PhysicalSIM", comment: "")
        case 2: SIMTypeText = NSLocalizedString("EmbeddedSIM", comment: "")
        case 3: SIMTypeText = "Apple SIM"
        default: SIMTypeText = NSLocalizedString("Unknown", comment: "未知")
        }
        
        return InfoItem(
            id: CommonItemID.SIMType,
            text: String.localizedStringWithFormat(NSLocalizedString("SIMType", comment: ""), SIMTypeText),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡的电话号码
    func getCellularPlanPhoneNumber(plan: CTCellularPlanItem) -> InfoItem {
        if let phoneNumber = plan.phoneNumber {
            return InfoItem(
                id: CommonItemID.phoneNumber,
                text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), phoneNumber.isEmpty ? NSLocalizedString("NotSet", comment: "") : phoneNumber),
                isConfidential: true
            )
        } else {
            return InfoItem(
                id: CommonItemID.phoneNumber,
                text: String.localizedStringWithFormat(NSLocalizedString("PhoneNumber", comment: ""), NSLocalizedString("Unknown", comment: "未知")),
                isConfidential: true
            )
        }
    }
    
    /// 获取蜂窝数据卡是否启用
    func getCellularPlanEnabled(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.enabled,
            text: String.localizedStringWithFormat(NSLocalizedString("isEnabledPlan", comment: ""), plan.isSelected ? NSLocalizedString("Enabled", comment: "") : NSLocalizedString("Disabled", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否可被选择
    func getCellularPlanSelectable(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.selectable,
            text: String.localizedStringWithFormat(NSLocalizedString("SelectablePlan", comment: ""), plan.isSelectable ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否可以被禁用
    func getCellularPlanCanDisable(plan: CTCellularPlanItem) -> InfoItem {
        // 默认是可以禁用的，plan.plan为nil也是可以允许关闭的
        let canDisablePlan: Bool
        if let planInfo = plan.plan {
            canDisablePlan = !planInfo.isDeleteNotAllowed
        } else {
            // 实体SIM卡允许关闭，但是需要考虑下双卡槽机器，只放一张卡的情况
            canDisablePlan = true
        }
        return InfoItem(
            id: CellularPlanItemID.canDisablePlan,
            text: String.localizedStringWithFormat(NSLocalizedString("CanDisablePlan", comment: ""), canDisablePlan ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: ""))
        )
    }
    
    /// 获取蜂窝数据卡是否允许被删除
    /// 实体SIM卡不允许删除蜂窝数据套餐
    /// eSIM看plan情况，一般都是允许删除的
    func getCellularPlanCanDelete(plan: CTCellularPlanItem) -> InfoItem {
        // 默认是不能删除的，plan.plan为nil不允许删除
        let canDeletePlan: Bool
        if let planInfo = plan.plan {
            canDeletePlan = !planInfo.isDeleteNotAllowed
        } else {
            // 实体 SIM 不允许删除
            canDeletePlan = false
        }
        return InfoItem(
            id: CellularPlanItemID.canDeletePlan,
            text: String.localizedStringWithFormat(NSLocalizedString("CanDeletePlan", comment: ""), canDeletePlan ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: ""))
        )
    }
    
    /// 获取蜂窝数据卡是否是默认语音号码
    func getCellularPlanDefaultVoice(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.defaultVoice,
            text: String.localizedStringWithFormat(NSLocalizedString("DefaultVoice", comment: ""), plan.isDefaultVoice ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否是默认语音号码
    func getCellularPlanSimStateValid(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.simStateValid,
            text: String.localizedStringWithFormat(NSLocalizedString("SimStateValid", comment: ""), plan.isSimStateValid ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否是默认数据卡
    func getCellularPlanActiveDataPlan(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.activeDataPlan,
            text: String.localizedStringWithFormat(NSLocalizedString("ActiveDataPlan", comment: ""), plan.isActiveDataPlan ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否正在安装
    func getCellularPlanInstalling(plan: CTCellularPlanItem) -> InfoItem {
        return InfoItem(
            id: CellularPlanItemID.installing,
            text: String.localizedStringWithFormat(NSLocalizedString("isInstallingPlan", comment: ""), plan.isInstalling ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
            isConfidential: false
        )
    }
    
    /// 获取蜂窝数据卡是否可转移
    /// 最低支持iOS 15.0
    func getCellularPlanTransferred(plan: CTCellularPlanItem) -> InfoItem? {
        if #available(iOS 15.0, *) {
            return InfoItem(
                id: CellularPlanItemID.transferred,
                text: String.localizedStringWithFormat(NSLocalizedString("isTransferredPlan", comment: ""), plan.isTransferred ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } else {
            return nil
        }
    }
    
    /// 获取蜂窝数据卡是否支持将物理SIM卡转换为eSIM
    /// 最低支持iOS 15.0
    func getCellularPlanTransferToeSIMSupported(plan: CTCellularPlanItem) -> InfoItem? {
        if #available(iOS 15.0, *) {
            return InfoItem(
                id: CellularPlanItemID.transferToeSIMSupported,
                text: String.localizedStringWithFormat(NSLocalizedString("TransferToeSIMSupported", comment: ""), plan.isLocalTransferToeSIMSupported ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } else {
            return nil
        }
    }
    
    /// 获取蜂窝数据卡是否正在检查蜂窝连接状态
    /// 最低支持iOS 16.0
    func getCellularPlanCheckingCellularConnectivity(plan: CTCellularPlanItem) -> InfoItem? {
        if #available(iOS 16.0, *) {
            return InfoItem(
                id: CellularPlanItemID.checkingCellularConnectivity,
                text: String.localizedStringWithFormat(NSLocalizedString("CheckingCellularConnectivity", comment: ""), plan.isCheckingCellularConnectivity ? NSLocalizedString("Yes", comment: "") : NSLocalizedString("No", comment: "")),
                isConfidential: false
            )
        } else {
            return nil
        }
    }
    
    /// 获取蜂窝数据卡的基础信息
    func getCellularPlanBasicInfoGroup(plan: CTCellularPlanItem) -> InfoItemGroup {
        let planBasicGroup = InfoItemGroup(id: CellularDataItemGroupID.cellularPlanBaseInfo)
        planBasicGroup.addItemIfPresent(getCellularPlanLabelName(plan: plan))
        planBasicGroup.addItem(getCellularPlanName(plan: plan))
        planBasicGroup.addItem(getCellularPlanCarrierName(plan: plan))
        planBasicGroup.addItem(getCellularPlanUUID(plan: plan))
        planBasicGroup.addItem(getCellularPlanICCID(plan: plan))
        planBasicGroup.addItem(getCellularPlanSIMType(plan: plan))
        planBasicGroup.addItem(getCellularPlanPhoneNumber(plan: plan))
        return planBasicGroup
    }
    
    func getCellularPlanStatusInfoGroup(plan: CTCellularPlanItem) -> InfoItemGroup {
        let planStatusGroup = InfoItemGroup(id: CellularDataItemGroupID.cellularPlanStatusInfo)
#if DEBUG
        planStatusGroup.footerText = String(describing: plan) // 蜂窝数据卡的原始数据
#endif
        planStatusGroup.addItem(getCellularPlanEnabled(plan: plan))
        planStatusGroup.addItem(getCellularPlanSelectable(plan: plan))
        planStatusGroup.addItem(getCellularPlanCanDisable(plan: plan))
        planStatusGroup.addItem(getCellularPlanCanDelete(plan: plan))
        planStatusGroup.addItem(getCellularPlanSimStateValid(plan: plan))
        planStatusGroup.addItem(getCellularPlanDefaultVoice(plan: plan))
        planStatusGroup.addItem(getCellularPlanActiveDataPlan(plan: plan))
        planStatusGroup.addItem(getCellularPlanInstalling(plan: plan))
        planStatusGroup.addItemIfPresent(getCellularPlanCheckingCellularConnectivity(plan: plan))
        planStatusGroup.addItemIfPresent(getCellularPlanTransferred(plan: plan))
        planStatusGroup.addItemIfPresent(getCellularPlanTransferToeSIMSupported(plan: plan))
        // TODO isSelectedOverride
        // TODO isBackedByCellularPlan
        return planStatusGroup
    }
    
    /// 获取蜂窝数据卡的信息聚合
    func getCellularPlanInfoGroups(plan: CTCellularPlanItem) -> [InfoItemGroup] {
        let planControlGroup = InfoItemGroup(id: CellularDataItemGroupID.cellularPlanControl)
        if plan.isSelected { // 判断当前蜂窝数据卡是否启用
            planControlGroup.addItem(InfoItem(id: ActionItemID.turnOffCellularPlan, text: NSLocalizedString("TurnOffThisLine", comment: "")))
        } else {
            planControlGroup.addItem(InfoItem(id: ActionItemID.turnOnCellularPlan, text: NSLocalizedString("TurnOnThisLine", comment: "")))
        }
        return [getCellularPlanBasicInfoGroup(plan: plan), getCellularPlanStatusInfoGroup(plan: plan), planControlGroup]
    }
    
    /// 获取设备是否允许使用开发者签名的IPCC
    /// 需要iOS 16.0+
    func getAllowDevSignedCarrierBundles() -> InfoItem? {
        if #available(iOS 16.0, *) {
            return InfoItem(
                id: CoreTelephonyItemID.allowDevSignedCarrierBundles,
                text: String.localizedStringWithFormat(NSLocalizedString("AllowInstallDevSignedCarrierBundles", comment: ""), coreTelephonyController.getAllowDevSignedCarrierBundles() ? NSLocalizedString("Allowed", comment: "") : NSLocalizedString("NotAllowed", comment: "")),
                isConfidential: false
            )
        } else {
            return nil
        }
    }
    
    /// 获取系统默认IPCC版本
    func getSystemDefaultIPCCVersion() -> InfoItem {
        do {
            let defaultIPCCVersion = try IPCCManagerController.getSystemDefaultIPCCVersion()
            return InfoItem(
                id: CoreTelephonyItemID.defaultIPCCVersion,
                text: String.localizedStringWithFormat(NSLocalizedString("SystemDefaultCarrierBundleVersion", comment: ""), defaultIPCCVersion)
            )
        } catch {
            return InfoItem(
                id: CoreTelephonyItemID.defaultIPCCVersion,
                text: String.localizedStringWithFormat(NSLocalizedString("SystemDefaultCarrierBundleVersion", comment: ""), NSLocalizedString("NotObtained", comment: ""))
            )
        }
    }
    
    // IPCC相关的基础信息组
    private func getIPCCBasicInfoGroup() -> InfoItemGroup {
        let basicInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceBaseInfo)
        basicInfoGroup.addItem(getDeviceBasicInfo())
        basicInfoGroup.addItem(getDeviceLogicBoardID(showFull: false)) // 裁剪掉最后的AP字母
        basicInfoGroup.addItemIfPresent(getDeviceCarrierLockState())
        basicInfoGroup.addItem(getSystemDefaultIPCCVersion())
        basicInfoGroup.addItemIfPresent(getAllowDevSignedCarrierBundles())
        basicInfoGroup.addItem(IPCCManagerController.getCarrierBundlePathWriteable())
        return basicInfoGroup
    }
    
    /// 获取IPCC管理的聚合
    func getIPCCManagerGroup() -> [InfoItemGroup] {
        var IPCCManagerGroup: [InfoItemGroup] = []
        // 第一组 系统版本
        IPCCManagerGroup.append(getIPCCBasicInfoGroup())
        
        // 第二组 安装IPCC及恢复IPCC
        let actionGroup = InfoItemGroup(id: CellularDataItemGroupID.installIPCC)
        actionGroup.addItem(InfoItem(id: ActionItemID.installIPCC, text: NSLocalizedString("InstallIPCC", comment: "")))
        if SettingsUtils.instance.getEnableExperimentalFeatures() { // 开启高级模式后显示刷新IPCC状态
            actionGroup.addItem(InfoItem(id: ActionItemID.refreshCarrierBundles, text: NSLocalizedString("RefreshCarrierBundles", comment: "")))
        }
        actionGroup.addItem(InfoItem(id: ActionItemID.restoreIPCCToSystem, text: NSLocalizedString("RestoreIPCCToSystem", comment: "")))
        IPCCManagerGroup.append(actionGroup)
        
        // 第三组/第四组 卡槽运营商信息
        for slotID in 1...max(getSlotCount(), 1) {
            if let context = coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
                let slotIPCCManagerGroup = InfoItemGroup(id: slotID == 1 ? CellularDataItemGroupID.slot1IPCCManager : CellularDataItemGroupID.slot2IPCCManager)
                // 设置卡槽编号
                slotIPCCManagerGroup.titleText = String.localizedStringWithFormat(NSLocalizedString("SlotNumber", comment: ""), slotID)
                // 放入数据
                slotIPCCManagerGroup.addItem(getSlotCarrierName(context: context))
                slotIPCCManagerGroup.addItem(getSlotCarrierBundleVersion(context: context))
                
                IPCCManagerGroup.append(slotIPCCManagerGroup)
            }
        }
        
        return IPCCManagerGroup
    }
    
    /// 获取IPCC兼容性的基础分组
    /// 结果的分组在IPCCManagerController里提供
    func getIPCCCompatibilityCheckBasicGroup() -> [InfoItemGroup] {
        var IPCCCompatibilityCheckGroup: [InfoItemGroup] = []
        
        // 第一组 系统版本
        IPCCCompatibilityCheckGroup.append(getIPCCBasicInfoGroup())
        
        // 第二组 选择检测的IPCC
        let actionGroup = InfoItemGroup(id: CellularDataItemGroupID.IPCCCompatibilityCheck)
        actionGroup.addItem(InfoItem(id: ActionItemID.selectIPCCFile, text: NSLocalizedString("SelectIPCCFile", comment: "")))
        IPCCCompatibilityCheckGroup.append(actionGroup)
        
        return IPCCCompatibilityCheckGroup
    }
    
    /// 获取基带激活信息组
    func getActivationTicketInfoGroup() -> [InfoItemGroup] {
        
        var activationTicketGroup: [InfoItemGroup] = []
        
        // 第一组系统信息
        let basicInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceBaseInfo)
        basicInfoGroup.addItem(getDeviceBasicInfo())
        basicInfoGroup.addItemIfPresent(getDeviceCarrierLockState())
        activationTicketGroup.append(basicInfoGroup)
        
        // 第二组基带激活信息
        let activationTicketInfo = InfoItemGroup(id: CellularDataItemGroupID.activationTicket, titleText: NSLocalizedString("BasebandActivationTicket", comment: ""))
        // 放一个占位 UI自己去处理
        activationTicketInfo.addItem(InfoItem(id: CoreTelephonyItemID.activationTicket, text: ""))
        
        activationTicketGroup.append(activationTicketInfo)
        
        // 第三组 第四组 操作组
        let actionGroup1 = InfoItemGroup(id: CellularDataItemGroupID.generalAction)
        actionGroup1.addItem(InfoItem(id: ActionItemID.copy, text: NSLocalizedString("CopyBasebandActivationTicket", comment: "")))
        
        let actionGroup2 = InfoItemGroup(id: CellularDataItemGroupID.generalAction)
        actionGroup2.addItem(InfoItem(id: ActionItemID.paste, text: NSLocalizedString("Paste", comment: "")))
        actionGroup2.addItem(InfoItem(id: ActionItemID.save, text: NSLocalizedString("Save", comment: "")))
        
        activationTicketGroup.append(actionGroup1)
        activationTicketGroup.append(actionGroup2)
        
        return activationTicketGroup
    }
    
    /// 获取设置网络模式的分组
    func getLockNetworkModeGroup(slotID: Int) -> [InfoItemGroup] {
        var lockNetworkModeGroup: [InfoItemGroup] = []
        
        // 第一组 设备基本信息
        let basicInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceBaseInfo)
        basicInfoGroup.addItem(getDeviceBasicInfo())
        lockNetworkModeGroup.append(basicInfoGroup)
        
        // 第二组 当前网络设定
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID),
           let descriptor = coreTelephonyController.getServiceDescriptor(slotID: slotID) {
            
            // 获取当前卡槽是否已经启用
            let slotEnabled = getSlotEnableSIM(context: context)
            
            let networkModeInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeInfo)
            if slotEnabled { // 已启用SIM卡的时候再放入数据
                networkModeInfoGroup.addItem(getSlotCarrierName(context: context))
                networkModeInfoGroup.addItem(getSlotLocalizedOperatorName(context: context))
                networkModeInfoGroup.addItem(getSlotSignalStrengthInfo(context: context))
                networkModeInfoGroup.addItem(getSlotRadioAccessTechnologyInfo(slotID: slotID, context: context))
                networkModeInfoGroup.addItems(getSlotRatSectionInfo(descriptor: descriptor, context: context))
            } else { // 无SIM卡/未启用SIM卡时直接显示无SIM卡/未启用SIM卡
                networkModeInfoGroup.addItem(getSlotSIMStatus(context: context))
            }
            
            lockNetworkModeGroup.append(networkModeInfoGroup)
            
            if slotEnabled { // 已启用SIM卡的时候再放入数据
                // 第三组 可选的设定
                let networkTypeGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeSelect)
                networkTypeGroup.titleText = NSLocalizedString("Setting", comment: "")
                networkTypeGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: NSLocalizedString("AutomaticSelectNetworkMode", comment: ""), detailText: "kCTRegistrationRATSelectionAutomatic"))
                networkTypeGroup.addItem(InfoItem(id: ActionItemID.selectNetworkModeUnknown, text: NSLocalizedString("UnknownNetworkMode", comment: "未知网络类型"), detailText: "kCTRegistrationRATSelectionUnknown"))
                networkTypeGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: NSLocalizedString("MultiNetworkMode", comment: ""), detailText: "kCTRegistrationRATSelectionDual"))
                
                lockNetworkModeGroup.append(networkTypeGroup)
                
                do {
                    if try coreTelephonyController.getDeviceSupports5G() { // 支持5G的设备再去放5G网络的选择，不然瞎捣乱呢
                        // 5G分组
                        let networkType5GGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeSelect)
                        networkType5GGroup.titleText = "5G"
                        networkType5GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "5G (SA+NSA)", detailText: "kCTRegistrationRATSelectionNR"))
                        networkType5GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "5G (SA)", detailText: "kCTRegistrationRATSelectionNRNonStandAlone"))
                        networkType5GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "5G (NSA)", detailText: "kCTRegistrationRATSelectionNRNonStandAlone"))
                        
                        lockNetworkModeGroup.append(networkType5GGroup)
                    }
                } catch {
                    //
                }
                
                // 4G分组
                let networkType4GGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeSelect)
                networkType4GGroup.titleText = "4G/LTE"
                networkType4GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "4G (LTE)", detailText: "kCTRegistrationRATSelectionNRNonStandAlone"))
                lockNetworkModeGroup.append(networkType4GGroup)
                
                // 判断设备是否支持CDMA
                let supportsCDMA: Bool = coreTelephonyController.getDeviceMEID() != nil
                
                // 3G分组
                let networkType3GGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeSelect)
                networkType3GGroup.titleText = "3G"
                networkType3GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "3G (UMTS/WCDMA)", detailText: "kCTRegistrationRATSelectionUMTS"))
                networkType3GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "3G (TD-SCDMA)", detailText: "kCTRegistrationRATSelectionTDSCDMA"))
                if supportsCDMA {
                    networkType3GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "3G (CDMA EV-DO)", detailText: "kCTRegistrationRATSelectionCDMA1xEVDO"))
                    networkType3GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "3G (CDMA Hybrid)", detailText: "kCTRegistrationRATSelectionCDMAHybrid"))
                }
                lockNetworkModeGroup.append(networkType3GGroup)
                
                // 2G分组
                let networkType2GGroup = InfoItemGroup(id: CellularDataItemGroupID.networkModeSelect)
                networkType2GGroup.titleText = "2G"
                networkType2GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "2G (GSM)", detailText: "kCTRegistrationRATSelectionGSM"))
                if supportsCDMA {
                    networkType2GGroup.addItem(InfoItem(id: ActionItemID.selectNetworkMode, text: "2G (CDMA 1x)", detailText: "kCTRegistrationRATSelectionCDMA1x"))
                }
                lockNetworkModeGroup.append(networkType2GGroup)
            }
            
        }
        
        return lockNetworkModeGroup
    }
    
    /// 设置卡槽网络模式
    func setSlotNetworkMode(slotID: Int, selection: String, preferred: String) throws -> Bool {
        
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
//           , let descriptor = coreTelephonyController.getServiceDescriptor(slotID: slotID) {
        
            
//            if #available(iOS 15.0, *) {
//                return try coreTelephonyController.setSlotRatSelection(descriptor: descriptor, selection: selection, preferred: preferred)
//            } else {
//                return try coreTelephonyController.setSlotRatSelection(context: context, selection: selection, preferred: preferred)
//            }
            
            return try coreTelephonyController.setSlotRatSelection(context: context, selection: selection, preferred: preferred)
        }
        
        
        
        return false
    }
    
    /// 获取设置网络频段的基本信息
    func getConfigureNetworkBandInfoGroup(slotID: Int) -> [InfoItemGroup] {
        
        var configureNetworkBandInfoGroup: [InfoItemGroup] = []
        
        // 第一组 设备基本信息
        let basicInfoGroup = InfoItemGroup(id: CellularDataItemGroupID.deviceBaseInfo)
        basicInfoGroup.addItem(getDeviceBasicInfo())
        configureNetworkBandInfoGroup.append(basicInfoGroup)
        
        // 第二组 当前卡的网络信息
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID),
           let descriptor = coreTelephonyController.getServiceDescriptor(slotID: slotID) {
            
            let networkStatusGroup = InfoItemGroup(id: CellularDataItemGroupID.networkBands)
            
            if getSlotEnableSIM(context: context) { // 已启用SIM卡的时候再放入数据
                networkStatusGroup.addItem(getSlotCarrierName(context: context))
                networkStatusGroup.addItem(getSlotLocalizedOperatorName(context: context))
                networkStatusGroup.addItem(getSlotSignalStrengthInfo(context: context))
                networkStatusGroup.addItem(getSlotRadioAccessTechnologyInfo(slotID: slotID, context: context))
                // 射频信息
                if let cellInfo = try? coreTelephonyController.getSlotCellInfo(context: context) {
                    networkStatusGroup.addItemIfPresent(getSlotServingBand(context: context, cellInfo: cellInfo))
                    networkStatusGroup.addItemIfPresent(getSlotRSRP(descriptor: descriptor))
                    networkStatusGroup.addItemIfPresent(getSlotSNR(descriptor: descriptor))
                }
            } else { // 无SIM卡/未启用SIM卡时直接显示无SIM卡/未启用SIM卡
                networkStatusGroup.addItem(getSlotSIMStatus(context: context))
            }
            
            configureNetworkBandInfoGroup.append(networkStatusGroup)
            
        }
        
        return configureNetworkBandInfoGroup
    }
    
    // 获取卡槽的卡的频段信息
    @available(iOS 14.0, *)
    func getSlotBandInfo(slotID: Int) throws -> CTBandInfo? {
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
            return try coreTelephonyController.getSlotBandInfo(context: context)
        }
        return nil
    }
    
    // 设置卡槽的卡的频段信息
    @available(iOS 14.0, *)
    func setSlotActiveBandInfo(slotID: Int, bandInfo: CTBandInfo) throws {
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
            try coreTelephonyController.setSlotActiveBandInfo(context: context, bandInfo: bandInfo)
        }
    }
    
    /// 恢复卡槽的卡的默认频段设置
    @available(iOS 14.0, *)
    func restoreSlotActiveBand(slotID: Int) -> Bool {
        if let context = coreTelephonyController.getServiceSubscriptionFullyContext(slotID: slotID) ?? coreTelephonyController.getServiceSubscriptionContext(slot: slotID) {
            
            do {
                let bandInfo = try coreTelephonyController.getSlotBandInfo(context: context)
                bandInfo.fActiveBands = bandInfo.fSupportedBands
                try coreTelephonyController.setSlotActiveBandInfo(context: context, bandInfo: bandInfo)
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
}
