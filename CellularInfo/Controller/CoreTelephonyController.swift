import Foundation
import UIKit
import CoreTelephony

//@objcMembers
class CoreTelephonyController : NSObject, CoreTelephonyClientDataDelegateInternal {
    
    // 单例实例
    @objc static let instance = CoreTelephonyController()
    
    // CoreTelephonyClient 实例
    private let coreTelephonyClient: CoreTelephonyClient = CoreTelephonyClient()
    // 创建CTServerConnection 实例
    private let connection: CTServerConnectionRef
    // MGDeviceInfoController 实例
    private let deviceInfoController = MGDeviceInfoController.instance
    // 设备是否支持蜂窝网络
    private lazy var deviceSupportsCellular: Bool = {
        return self.getDeviceSupportsCellular()
    }()
    
    // 闭包 让外界知道数据更新
    var onDataUpdated: (() -> Void)?
    
    private var refreshDataTimer: Timer?
    
    /// 私有构造函数
    private override init() {
        // 创建 CTServerConnection 连接
        self.connection = _CTServerConnectionCreate(kCFAllocatorDefault, nil, nil)
        super.init()
        // 设置delegate
        coreTelephonyClient.setDelegate(self)
    }
    
    @objc func getCoreTelephonyClient() -> CoreTelephonyClient {
        return coreTelephonyClient
    }
    
    @objc func getCTServerConnection() -> CTServerConnectionRef {
        return self.connection
    }
    
    // 定时刷新数据
    func startRefreshDataTimer() {
        guard refreshDataTimer == nil else { // 防止重复创建
            return
        }
        
        DispatchQueue.main.async {
            // 设置一个2秒的定时器 定时发送数据更新的通知
            self.refreshDataTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                NSLog("[CellularInfo] Timer Refresh Data")
                self?.onDataUpdated?()
            }
        }
    }
    
    // 停止定时刷新数据
    func stopRefreshDataTimer() {
        refreshDataTimer?.invalidate()
        refreshDataTimer = nil
    }
    
    /// 数据状态变化（最核心：蜂窝数据整体状态）
    func dataStatus(_ arg1: Any, dataStatusInfo arg2: Any) {
        NSLog("[CellularInfo] dataStatus")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 更改蜂窝网络类型的回调
    func regDataModeChanged(_ client: Any?, dataMode: Int32) {
        NSLog("[CellularInfo] regDataModeChanged")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// RAT 选择变化（2G/3G/LTE/NR）
    func ratSelectionChanged(_ arg1: Any, selection arg2: Any) {
        NSLog("[CellularInfo] ratSelectionChanged")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 数据模式变化（2G/3G/LTE/NR切换）
    func regDataModeChanged(_ arg1: Any, dataMode arg2: Int32) {
        NSLog("[CellularInfo] regDataModeChanged")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 网络环境变化（5G / LTE 切换等）
    func servingNetworkChanged(_ arg1: Any) {
        NSLog("[CellularInfo] servingNetworkChanged")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 信号强度变化
    func signalStrengthChanged(_ arg1: Any, info arg2: Any) {
        NSLog("[CellularInfo] signalStrengthChanged")
        onDataUpdated?() // 发送闭包回调通知
    }

    /// 小区变化（切基站）
    func cellChanged(_ arg1: Any, cell arg2: Any) {
        NSLog("[CellularInfo] cellChanged")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 小区监控（NR ARFCN / 带宽 / PCI）
    func cellMonitorUpdate(_ arg1: Any, info arg2: Any) {
        NSLog("[CellularInfo] cellMonitorUpdate")
        onDataUpdated?() // 发送闭包回调通知
    }
    
    /// 设备是否支持蜂窝网络
    /// 最低需要iOS 15.0+
    /// 无权限设备可返回正确数据
    /// 模拟器返回false
    func getDeviceSupportsCellular() -> Bool {
        if #available(iOS 15.0, *) {
            return coreTelephonyClient.supportsCellular() // 这个API竟然需要iOS 15.0+ 离谱！
        } else if getDeviceSlotCount() > 0 {
            return true
        } else if deviceInfoController.haveIMEI() { // 备用方案，直接判断设备是否有IMEI
            return true
        } else { // 给iOS 15以下无权限机器做的兼容性方案
            if #available(iOS 13.0, *) {
                return (try? getDeviceDataStatus()) != nil
            } else { // iOS 12单独做个适配
                return CoreTelephonyNetworkInfoController.instance.getDeviceSlotCount() != 0
            }
        }
    }
    
    /// 获取设备的信息
    /// key    device-type
    /// value  iPhone
    /// value  iPad
    /// key    eid
    /// value  890xxxxxxxxxxxxxx
    @available(iOS 15.0, *)
    func getDeviceTypeInfo(timeout: TimeInterval = 3) -> [String: Any]? {
        
        let sema = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        
        coreTelephonyClient.getDeviceInfo { info, error in
            result = info as? [String: Any]
            sema.signal()
        }
        
        let waitResult = sema.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            return nil
        }
        
        return result
    }
    
    /// 通过基带获取设备类型
    /// 返回系统类型
    @available(iOS 15.0, *)
    func getDeviceType() -> UIUserInterfaceIdiom? {
        // 先尝试从基带获取
        if let info = getDeviceTypeInfo(), let type = info["device-type"] as? String {
            
            switch type {
            case "iPhone":
                return .phone
            case "iPad":
                return .pad
            default:
                break
            }
        }
        return nil
        // fallback 这个可以被伪造
//        return UIDevice.current.userInterfaceIdiom
    }
    
    /// 获取设备基本信息的列表
    /// 包括卡槽的基本IMEI信息
    /// 包括EID和MEID(老设备可选)
    /// 获取卡槽的设备信息用 getSlotMobileEquipmentInfo
    /// 无权限时抛异常 错误代码 1
    func getDeviceInfoList() throws -> CTMobileEquipmentInfoList {
        return try coreTelephonyClient.getMobileEquipmentInfo()
    }
    
    /// 获取设备的卡槽数量
    /// 用于判断设备有几个IMEI
    /// 返回卡槽数量
    func getDeviceSlotCount() -> Int {
        do {
            return try getDeviceInfoList().meInfoList.count
        } catch {
            return 0
        }
    }
    
    // 获取全部IMEI列表
    private func getDeviceIMEI(number: Int) -> String? {
        // 获取是否存在设备信息
        guard let list = try? getDeviceInfoList().meInfoList else {
            return nil
        }
        
        let index = number - 1
        // 判断获取的IMEI是否越界
        guard index >= 0 && index < list.count else {
            return nil
        }
        // 获取IMEI并且返回
        return list[index].imei
    }
    
    /// 获取设备的IMEI 1
    /// 支持蜂窝网络的机器+有权限会返回
    func getDeviceIMEI1() -> String? {
        return getDeviceIMEI(number: 1)
    }
    
    /// 获取设备的IMEI 2
    /// 部分设备无IMEI 2
    /// 比如老款设备XS之前的设备，还有CH/A的 XS、SE 2、SE 3、12 mini、13 mini，还有蜂窝版iPad
    func getDeviceIMEI2() -> String? {
        return getDeviceIMEI(number: 2)
    }
    
    /// 获取设备的EID
    /// 不支持eSIM的设备没有EID
    func getDeviceEID() -> String? {
        do {
            if let list = try getDeviceInfoList().meInfoList {
                for info in list {
                    if let EID = info.csn, !EID.isEmpty {
                        return EID
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// 获取设备的MEID
    /// 就是CDMA的那个
    /// iPhone 14系列开始没有这个MEID了 取消支持CDMA了
    func getDeviceMEID() -> String? {
        do {
            if let list = try getDeviceInfoList().meInfoList {
                for info in list {
                    if let MEID = info.meid, !MEID.isEmpty {
                        return MEID
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }
    
    /// 获取设备激活策略
    /// 需要carrier-settings权利
    /// 返回的是 是否有锁
    @available(iOS 14.0, *)
    func getDeviceActivationPolicyState() throws -> CTActivationPolicyState {
        return try coreTelephonyClient.getActivationPolicyState()
    }
    
    /// 获取设备是否有锁 基于本地的激活策略查询
    /// 这个接口应该是给 关于本机 提供支持的
    /// 返回值 CTActivationPolicyCarrierUnlocked    = 1 无锁
    /// 返回值 CTActivationPolicyCarrierLocked      = 2 无锁
    /// 返回值 CTActivationPolicyCarrierLockUnknown = 0 未知
    /// 未知 这个状态比如把激活文件删除了 或者QPE解锁把基带激活文件卡没了，但是没重启或者继续插卡会返回这个状态，重新激活就会返回其他状态了
    /// iPad 蜂窝版返回未知状态 iPad不支持这个查询
    /// 无权限/模拟器抛异常
    /// 暂无低版本替代方案
    @available(iOS 14.0, *)
    func getDeviceCarrierLockState() throws -> Int64 {
        return try getDeviceActivationPolicyState().carrierLock
    }
    
    /// 获取设备是否启用工厂模式
    /// 返回true/false
    /// 暂时不知道怎么开启工厂模式
    /// 经测试iOS 15.3.1设备无此方法 iOS 15.4.1设备有此方法 因此判断API支持的系统版本为iOS 15.4+
    /// 无权限/模拟器抛异常 错误代码 13
    @available(iOS 15.4, *)
    func getDeviceFactoryDebugEnabled() throws -> Bool {
        return try coreTelephonyClient.isFactoryDebugEnabled().boolValue
    }
    
    /// 获取基带是否是RC版固件
    @available(iOS 15.4, *)
    func getDeviceReleaseCandidateFlag() -> Bool {
        return coreTelephonyClient.getReleaseCandidateFlag().boolValue
    }
    
    /// 获取SIM卡槽状态
    /// 返回值  kCTSIMSupportSIMTrayAbsent           SIM卡托被拔出
    /// 返回值  kCTSIMSupportSIMTrayInsertedNoSIM    无SIM卡
    /// 返回值  kCTSIMSupportSIMTrayInsertedWithSIM  有SIM卡
    /// 返回值  kCTSIMSupportSIMTrayStatusUnknown    未知
    /// TODO 需要更多数据关于*无实体卡槽的数据*
    /// 无权限/模拟器抛异常 错误代码 1
    func getDeviceSIMTrayStatus() throws -> String {
        return try coreTelephonyClient.getSIMTrayStatusOrError()
    }
    
    /// 获取设备是否有SIM卡就绪
    /// 单卡或者双卡或者eSIM只要有一个就绪就是true
    /// 返回true或者false
    /// 经测试反馈iOS 16.3设备闪退，iOS 16.4.1设备不闪退，并且通过limneos网站内容进行相互判断
    /// 因此该API需要iOS 16.4+
    /// 低版本可使用getActiveContexts获取Context来判断
    /// 无权限可返回正常数据
    @available(iOS 16.4, *)
    func getDeviceIsAnySIMReady() throws -> Bool {
        return try coreTelephonyClient.isAnySimReady().boolValue
    }
    
    /// 是否是纯eSIM机型
    /// 返回true或者false
    /// 无权限/模拟器抛异常
    /// API本身仅支持iOS 16.0+
    func getDeviceIsEmbeddedSIMOnlyDevice() throws -> Bool {
        if #available(iOS 16.0, *) {
            return try coreTelephonyClient.isEmbeddedSIMOnlyConfig().boolValue
        } else { // 低于iOS 16.0的设备肯定不是纯eSIM机型，因为LL/A的iPhone 14系列出厂搭载的是iOS 16.0
            return false
        }
    }
    
    /// 双卡支持情况
    /// 单卡+esim机器            返回值 = 2
    /// 魔改双卡槽 eSIM拆除（14pm）返回值 = 2
    /// 双实体卡                 返回值 = 2
    /// 纯单卡                   返回值 = 3
    /// iPad蜂窝版               返回值 = 3
    /// 基带服务重启中            返回值 = 4
    /// 无权限                   返回值 = 0
    /// 无权限抛异常 错误代码 13
    /// 模拟器/无蜂窝网络模块设备 错误代码 19
    func getDeviceDualSimCapability() throws -> Int64 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getDualSimCapability(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备是否支持5G
    /// API本身仅支持iOS 14.0+
    /// iOS 14 以下绝对不支持5G iPhone 12全系列出厂搭载iOS14.0系统 因此通过次即可判断
    /// @See https://support.apple.com/zh-cn/111850
    /// @See https://support.apple.com/en-us/111850
    /// API本身判断是否支持智能数据模式
    /// 经过测试iOS 15的iPhone 11 返回false iOS 15的iPhone 13 mini/13 Pro Max返回true
    /// 返回true/false
    /// 无权限设备/模拟器返回false 并不会抛异常
    func getDeviceSupports5G() throws -> Bool {
        if #available(iOS 14.0, *) {
            var error: NSError? // 创建一个接收错误信息的对象
            let result = coreTelephonyClient.isSmartDataModeSupported(&error)
            if let error = error { // 判断是否有错误 有错误就抛异常给上层
                throw error
            }
            return result
        } else { // iOS 14 以下绝对不支持5G iPhone 12全系列出厂搭载iOS14.0系统
            return false
        }
    }
    
    /// 硬件是否支持eSIM
    /// 需要最低iOS 16.0 强行兼容到低版本
    /// 无权限设备返回false
    func getDeviceSupportsEmbeddedSIM() -> Bool {
        if #available(iOS 16.0, *) {
            let supports =  coreTelephonyClient.supportsEmbeddedSIM() // 这个API竟然需要iOS 16.0+ 更离谱！
            if supports {
                return supports
            } else {
                return CTCellularPlanProvisioning().supportsEmbeddedSIM // 公开方法获取 但是这个需要 public-cellular-plan 权利
            }
        } else {
            return deviceInfoController.getEID() != nil // 备用方案 查询设备是否有EID
        }
    }
    
    /// 检查eSIM健康状态
    /// TODO *需要更多返回值数据*
    /// checkEmbeddedSimHealthWithError的返回值 == nil 是设备不支持 会抛异常
    ///                                        != nil 需要看返回值
    ///                                        eSIM被拆除的设备返回 = 0
    ///                                        错误代码 19 设备不支持
    ///                                        错误代码 1 无权限
    /// 无低版本系统替代方案
    /// 因为可能设备不支持因此需要抛异常
    @available(iOS 16.0, *)
    func checkDeviceEmbeddedSIMHealth() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.checkEmbeddedSimHealthWithError(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        if let result = result {
            return result.boolValue
        } else {
            throw NSError(domain: "CoreTelephonyController", code: 19, userInfo: nil)
        }
    }
    
    /// 激活策略是否允许安装eSIM
    /// 同步方法 很卡 大概需要5秒，用异步方法替代
    @available(*, deprecated, message: "Use getDeviceAllowInstallEmbeddedSIM(_ completion: @escaping (Bool) -> Void) instead")
    func getDeviceAllowInstallEmbeddedSIM() -> Bool {
        let cellularPlanProvisioning = CTCellularPlanProvisioning()
        return cellularPlanProvisioning.supportsCellularPlan()
    }
    
    /// 激活策略是否允许安装 eSIM 异步方法
    /// 注意：回调一定在主线程
    /// 需要 public-cellular-plan 权利
    /// info.plist需要配置MCC和MNC
    /// @See https://stackoverflow.com/questions/73890332/ctcellularplanprovisioning-supportscellularplan-takes-too-long
    /// @See https://stackoverflow.com/questions/58630606/coretelephony-esim-functions-not-working-on-device
    func getDeviceAllowInstallEmbeddedSIM(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = CTCellularPlanProvisioning().supportsCellularPlan()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /// 获取设备是否允许转移蜂窝套餐
    /// 返回true/false 是否支持
    /// 设备不支持 错误代码 19
    /// 无权限抛异常 高版本错误代码 1 低版本错误代码 13
    /// 模拟器抛异常 错误 4099
    /// 无低版本替代方法
    @available(iOS 13.0, *)
    func getDeviceCellularPlanTransferable() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.isAnyPlanTransferable(fromThisDeviceOrError: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备蜂窝网络连接可用性的实例
    /// 返回 CTDataConnectionAvailabilityStatus 实例
    /// available = true   csiError =  0  蜂窝网络连接正常
    /// available = false  csiError = -1  蜂窝网络已关闭
    /// available = false  csiError = -2  未开启数据漫游
    /// available = false  csiError = -3  TODO 短暂出现
    /// available = false  csiError = -5  无网络(无服务/飞行模式/SIM卡不允许蜂窝数据)
    /// available = false  csiError =  1  正在切换蜂窝数据
    /// available = false  csiError = 24  正在切换蜂窝数据
    /// available = false  csiError = 94  手动选择网络中
    /// TODO *需要更多数据*
    /// 需要最低iOS 13.0
    /// 无权限时可返回正常数据
    /// 模拟器/无蜂窝网络模块设备抛异常 错误代码 19
    @available(iOS 13.0, *)
    func getDeviceInternetConnectionAvailability() throws -> CTDataConnectionAvailabilityStatus {
        return try coreTelephonyClient.getInternetConnectionAvailabilitySync()
    }
    
    /// 获取设备蜂窝连接状态
    /// 返回 CTDataConnectionStatus 实例
    /// 需要细化，分析QoS很有价值
    /// 无权限设备能返回数据
    @available(iOS 13.0, *)
    func getDeviceInternetConnectionState() throws -> CTDataConnectionStatus? {
        return try coreTelephonyClient.getInternetConnectionStateSync()
    }
    
    /// 获取设备的蜂窝网络状态的实例
    /// 与 getDataStatus 类似 getDataStatus这个需要传context获取某个卡槽的
    @available(iOS 13.0, *)
    func getDeviceDataStatus() throws -> CTDataStatus {
        return try coreTelephonyClient.getInternetDataStatusSync()
    }
    
    /// 获取是否开启 允许切换蜂窝数据
    /// 头文件Swift解析存在问题 需要 NS_SWIFT_NOTHROW 注解
    /// iOS 14 15 16 17.0 均正常运行
    /// iOS 13 iPhone SE1 经过测试抛出异常45 不支持
    /// 无权限时会抛异常
    @available(iOS 13.0, *)
    func getDeviceDynamicDataSimSwitchEnabled() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getSupportDynamicDataSimSwitchSync(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取是否开启 允许在通话时切换蜂窝数据
    /// 头文件Swift解析存在问题 需要 NS_SWIFT_NOTHROW 注解
    /// iOS 14 15 16 17.0 均正常运行
    /// iOS 13 iPhone SE1 经过测试抛出异常45 不支持
    /// iOS 12 iPhone SE1 经过测试正常返回
    /// 无权限时会抛异常
    func getDeviceDynamicDataSimSwitchOnCallEnabled() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getSupportDynamicDataSimSwitch(onBBCallSync: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取NR的频率范围
    /// TODO *需要更多数据*
    /// 5G SA  返回 4 = CTNrFrequencyRangeSub6
    /// 5G NSA 返回 0 = CTNrFrequencyRangeUnknown
    /// 4G     返回 0 = CTNrFrequencyRangeUnknown
    /// 具体使用CoreTelephonyNetworkInfoController.getDeviceNrFrequencyRange() 方法
    /// iOS 18.0移除了此方法
    /// @See https://headers.82flex.com/diff/17.0_21A329...18.6_22G86/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony/CoreTelephonyClient.h
    func getPublicNrFrequencyRange() throws -> UInt32 {
        if #available(iOS 18.0, *) {
            throw NSError(domain: "CoreTelephony", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not supported on iOS 18+"])
        }
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getPublicNrFrequencyRangeSync(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备是否支持2G开关
    /// 无低版本系统兼容方案
    /// 模拟器找不到get2GSwitchEnabledSync方法会闪退
    @available(iOS 17.0, *)
    func getDevice2GSwitchEnabled() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
#if targetEnvironment(simulator)
        let result = false // 模拟器直接返回false
#else
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.get2GSwitchEnabledSync(&error)
#endif
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备用户是否开启2G网络
    /// 无低版本系统兼容方案
    /// 模拟器找不到get2GUserPreferenceSync方法会闪退
    @available(iOS 17.0, *)
    func getDevice2GUserPreference() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        
#if targetEnvironment(simulator)
        let result = false // 模拟器直接返回false
#else
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.get2GUserPreferenceSync(&error)
#endif
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备是否开启蜂窝网络数据统计
    @available(iOS 17.0, *)
    func getDeviceMobileDataUsageCollectionEnabled() throws -> Bool {
        return try coreTelephonyClient.usageCollectionEnabledSync().boolValue
    }
    
    /// 获取蜂窝用量工作区的实例
    /// 返回 CTCellularUsageWorkspaceInfo 实例
    /// 无权限时抛异常 错误代码 13
    /// 无低版本兼容方法
    @available(iOS 17.0, *)
    func getDeviceCellularUsageWorkspaceInfo() throws -> CTCellularUsageWorkspaceInfo {
        return try coreTelephonyClient.getCellularUsageWorkspaceInfo()
    }
    
    /// 获取设备首选蜂窝数据卡是否开启数据漫游
    /// 无权限抛异常 错误代码 13
    func getDeviceEnableDataRoaming() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getInternationalDataAccessStatusSync(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备是否支持专用承载
    /// 最低要求iOS 15.0
    /// 无权限设备的数据可能不准确
    @available(iOS 15.0, *)
    func getDeviceDedicatedBearerSupported() -> Bool {
        return coreTelephonyClient.hasDedicatedBearerSupport()
    }
    
    /// 获取设备NAT Traversal 最大保持时间 单位秒
    /// 最低要求 iOS 13.0
    /// 获取卡槽的使用 getSlotNATTKeepAliveOverCell
    /// 无权限时会抛异常 错误代码 13
    /// 模拟器/无蜂窝网络模块设备 错误代码 19
    @available(iOS 13.0, *)
    func getDeviceNATTKeepAliveOverCell() throws -> UInt32 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getNATTKeepAliveOverCell(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备紧急状态的实例
    /// 无权限设备抛异常 错误代码 13
    @available(iOS 13.0, *)
    func getDeviceEmergencyModeInfo() throws -> CTEmergencyModeResult {
        return try coreTelephonyClient.copyEmergencyMode()
    }
    
    /// 获取设备是否需要显示eSIM旅行提示
    /// 无需额外权利
    @available(iOS 17.0, *)
    func getDeviceShouldShowEmbeddedSIMTravelTip() throws -> Bool {
        return try coreTelephonyClient.shouldShoweSIMTravelTip().boolValue
    }
    
    /// 获取设备是否需要显示加载设置eSIM界面
    /// 无需额外权利
    @available(iOS 16.0, *)
    func getDeviceNeedToLaunchSetUpEmbeddedSIM() throws -> Bool {
        return try coreTelephonyClient.needToLaunchSetUpeSIM().boolValue
    }
    
    /// 获取设备是否正在使用内置的eSIM来进行eSIM下载服务
    /// 测试设备：iPhone 17 Pro Max LL/A iOS 26.1 设备内无已安装eSIM 断开Wi-Fi直接点击 添加eSIM 即可触发
    /// 测试设备：iPad 7gen Wi-Fi+Cellular J/A iOS 17.2 设备内无已安装eSIM SIM卡槽拔掉SIM卡 断开Wi-Fi直接点击 添加eSIM 即可触发
    /// 无权限设备抛异常 错误代码 1
    @available(iOS 16.0, *)
    func getDeviceUsingBootstrapDataService() throws -> Bool {
        return try coreTelephonyClient.usingBootstrapDataService().boolValue
    }
    
    /// 请求系统启动内置eSIM下载eSIM下载服务
    /// 触发条件很苛刻
    /// 1. 需要设备需要支持eSIM
    /// 2. 需要设备内无SIM卡(如果有卡槽的设备)和eSIM
    /// 3. 断开网络连接 例如Wi-Fi
    /// 即可触发
    /// 否则会抛异常
    /// 需要额外权利 requestBootstrapDataService
    /// 测试设备：iPad 7gen Wi-Fi+Cellular J/A iOS 17.2 设备内无已安装eSIM SIM卡槽拔掉SIM卡 断开Wi-Fi直接点击 添加eSIM 即可触发
    /// iOS 26已移除此方法
    /// *未使用*
    @available(iOS 17.0, *)
    func requestBootstrapDataService() throws -> Bool {
        if #available(iOS 26.0, *) {
            throw NSError(domain: "CoreTelephony", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not supported on iOS 26+"])
        }
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.requestBootstrapDataService(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 请求系统释放内置eSIM的eSIM下载服务
    /// 无效返回值 是否释放都会返回true
    /// *未使用*
    @available(iOS 17.0, *)
    func releaseBootstrapDataService() throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.releaseBootstrapDataService(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备是否显示品牌呼叫信息
    /// 不知道做什么用的
    /// *需要更多数据*
    /// 无权限设备抛异常 错误代码 13
    @available(iOS 16.0, *)
    func getDeviceShouldShowBrandedCallingInfo() throws -> Bool {
        return try coreTelephonyClient.shouldShowBrandedCallingInfo().boolValue
    }
    
    /// 获取Packet Context数量
    /// 不知道做什么的
    /// 13 Pro Max和13 mini调用返回 6
    /// 无权限设备返回0
    /// 模拟器抛异常 错误代码 4099
    func getDevicePacketContextCount() throws -> UInt32 {
        var count: UInt32 = 0
        if let error = coreTelephonyClient.getPacketContextCount(&count) {
            throw error
        }
        return count
    }
    
    /// 获取设备存储的SIM卡ICCID列表
    /// 无权限设备抛异常 错误代码 13
    /// 模拟器抛异常 错误代码 4099
    func getDeviceSavedICCIDLists() throws -> [String] {
        return try coreTelephonyClient.listPersonalWallets()
    }
    
    /// 根据slot获取当前插槽的context
    /// 获取到的context内部信息不全
    /// 完整版的context列表: getSubscriptionInfoWithError, getActiveContexts
    /// 但是足够查询数据了
    func getServiceSubscriptionContext(slot: Int) -> CTXPCServiceSubscriptionContext? {
        return CTXPCServiceSubscriptionContext(slot: Int32(slot))
    }
    
    /// 根据slotID获取当前插槽的context
    /// 获取到的context是完整的context信息
    func getServiceSubscriptionFullyContext(slotID: Int) -> CTXPCServiceSubscriptionContext? {
        return getSubscriptionContexts().first { $0.slotID == slotID }
    }
    
    /// 获取CTXPCContexts实例
    func getActiveContextsInfo() throws -> CTXPCContexts {
        return try coreTelephonyClient.getActiveContexts()
    }
    
    /// 获取全部活跃的Context
    /// 获取到的CTXPCContextInfo Context是完整版
    /// 转换后的CTXPCServiceSubscriptionContext Context是非完整版
    func getActiveContexts() throws -> [CTXPCServiceSubscriptionContext] {
        if let subscriptions = try getActiveContextsInfo().subscriptions { // subscriptions可能为nil 需要判断
            var contextList: [CTXPCServiceSubscriptionContext] = []
            for subscription in subscriptions { // subscriptions的类型是CTXPCContextInfo 我们需要 CTXPCServiceSubscriptionContext
                contextList.append(CTXPCServiceSubscriptionContext.init(slot: Int32(subscription.slotID))) // 所以需要手动转换
            }
            return contextList
        } else {
            return []
        }
    }
    
    /// 获取全部完整的Context
    func getSubscriptionContexts() -> [CTXPCServiceSubscriptionContext] {
        do {
            return try coreTelephonyClient.getSubscriptionInfo().subscriptions
        } catch {
            return []
        }
    }
    
    /// 根据slot的uuid获取当前插槽的context
    func getServiceSubscriptionContext(uuid: UUID) -> CTXPCServiceSubscriptionContext? {
        return CTXPCServiceSubscriptionContext(uuid: uuid)
    }
    
    /// 获取当前首选卡槽的context
    /// 获取的context信息是全的
    func getDataPreferredContext() throws -> CTXPCServiceSubscriptionContext {
        return try coreTelephonyClient.getPreferredDataSubscriptionContextSync()
    }
    
    /// 获取当前首选语音卡槽的context
    /// 获取的context的信息不全
    /// iPad蜂窝版不支持 抛异常 错误代码 35
    /// 无权限设备错误代码 1
    /// iOS 12 使用getActiveContexts获取Context分析
    @available(iOS 13.0, *)
    func getUserDefaultVoiceSubscriptionContext() throws -> CTXPCServiceSubscriptionContext {
        return try coreTelephonyClient.getUserDefaultVoiceSubscriptionContext()
    }
    
    /// 获取当前首选卡槽的ID
    func getDataPreferredSlotID() throws -> Int64 {
        return try getDataPreferredContext().slotID
    }
    
    /// 通过 domain 获取 CTServiceDescriptorContainer 服务描述的实例
    /// domain 只能 = 1 获取到Container 其余参数返回nil
    /// 返回 CTServiceDescriptorContainer 实例
    /// 无权限/模拟器返回nil
    func getDescriptorsForDomain(domain: Int64) -> CTServiceDescriptorContainer? {
        return coreTelephonyClient.getDescriptorsForDomain(domain, error: nil)
    }
    
    /// 根据 slotID 获取对应的 CTServiceDescriptor
    /// domain 固定为 1（Cellular 域）
    /// slotID 通常为 1 / 2，对应 instance = 1 / 2
    /// 无匹配时返回 nil
    func getServiceDescriptor(slotID: Int) -> CTServiceDescriptor? {
        // 先获取到 CTServiceDescriptorContainer
        guard let container = getDescriptorsForDomain(domain: 1), let descriptors = container.descriptors else {
            return nil
        }
        
        // instance 通常与 slotID 对应（1 -> 1, 2 -> 2）
        for descriptor in descriptors {
            if descriptor.instance as! Int64 == slotID {
                return descriptor
            }
        }
        
        return nil
    }
    
    /// 获取当前 使用 的蜂窝数据的卡槽的服务描述
    /// 系统选中的
    /// 比如允许切换蜂窝数据打开后，系统会自动切换两张卡
    func getCurrentDataServiceDescriptor() -> CTServiceDescriptor? {
        return coreTelephonyClient.getCurrentDataServiceDescriptorSync(nil)
    }
    
    /// 获取当前 选中 的蜂窝数据的卡槽的服务描述
    /// 用户选中的
    /// 用户选中的未必是当前正在用的，比如开启了切换蜂窝数据
    func getPreferredDataServiceDescriptor() -> CTServiceDescriptor? {
        return coreTelephonyClient.getPreferredDataServiceDescriptorSync(nil)
    }
    
    /// 获取卡槽的蜂窝网络状态的实例
    /// 返回 CTDataStatus 实例
    /// 可以分析出5G SA还是5G NSA
    /// 与 getInternetDataStatusSync 获取的数据类似 这个获取的是设备联网的
    /// 无权限设备仍然可以访问，数据基本准确
    /// 基带服务崩溃/重启时抛异常 错误代码 35
    func getSlotDataStatus(context: CTXPCServiceSubscriptionContext) throws -> CTDataStatus {
        return try coreTelephonyClient.getDataStatus(context)
    }
    
    /// 获取蜂窝网络数据基本信息的实例
    /// 使用 -(CTDataStatus *)getDataStatus:(CTXPCServiceSubscriptionContext *)context error:(id*)error; 替代
    /// 返回 CTDataStatusBasic 实例
    /// iOS 15.4以下没有 CTDataStatusBasic 头文件
    /// 无权限设备仍然可以访问
    @available(iOS 15.4, *)
    func getDataStatusBasic(context: CTXPCServiceSubscriptionContext) throws -> CTDataStatusBasic {
        return try coreTelephonyClient.getDataStatusBasic(context)
    }
    
    /// 获取当前卡槽连接网络类型
    /// 直接拿到 CTDataStatus 里面的 dataMode 的数据
    /// 返回值  4 = 3G HSDPA
    /// 返回值 14 = 4G (LTE)
    /// 返回值 16 = 5G NSA (NRNSA)
    /// 返回值 17 = 5G SA (NR)
    /// 返回值 -1 = 未知
    /// TODO *需要更多数据*
    /// 返回的是数字编号
    /// 无权限时抛异常
    /// iOS 12的设备 抛异常 错误代码 22
    /// iOS 18.0移除了此方法
    /// @See https://headers.82flex.com/diff/17.0_21A329...18.6_22G86/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony/CoreTelephonyClient.h
    /// 使用iOS 18.7的iPhone 16 Pro Max测试闪退
    /// 高版本系统使用 getDataStatus 的 CTDataStatus 的 dataMode
    func getSlotDataMode(descriptor: CTServiceDescriptor) throws -> Int {
        if #available(iOS 18.0, *) {
            throw NSError(domain: "CoreTelephony", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not supported on iOS 18.0+"])
        }
        return try coreTelephonyClient.getDataMode(descriptor).intValue
    }
    
    /// 获取当前设备连接的网络类型指示
    /// 直接拿到 CTDataStatus 里面的 dataBearerTechnology 的数据
    /// 返回值 4 = 4G (LTE)
    /// 返回值 6 = 5G SA (NR)
    /// iOS 15.0开始支持
    /// iOS 18.0移除了此方法
    /// @See https://headers.82flex.com/diff/17.0_21A329...18.6_22G86/System/Library/Frameworks/CoreTelephony.framework/CoreTelephony/CoreTelephonyClient.h
    /// 使用iOS 18.7的iPhone 16 Pro Max测试闪退
    /// 高版本系统使用 getDataStatus 的 CTDataStatus 的 dataBearerTechnology
    /// 无权限设备抛异常 错误代码 13
    @available(iOS 15.0, *)
    func getDeviceDataBearer() throws -> Int {
        if #available(iOS 18.0, *) {
            throw NSError(domain: "CoreTelephony", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not supported on iOS 18+"])
        }
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getPublicDataBearerSync(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return Int(result)
    }
    
    /// 获取卡槽是否已经连接到5G SA
    /// 无权限设备返回的数据准确
    /// 基带服务崩溃/重启时抛异常 错误代码 35
    @available(iOS 14.0, *)
    func getSlotNRConnected(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try getSlotDataStatus(context: context).newRadioCoverage
    }
    
    /// 获取卡槽首选网络类型
    /// 返回值 1 = 2G
    /// 返回值 2 = 3G
    /// 返回值 3 = 4G
    /// 返回值 4 = 5G
    func getSlotSelectRate(context: CTXPCServiceSubscriptionContext) throws -> Int64 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getMaxDataRate(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前首选卡槽的首选网络类型
    /// 返回值 1 = 2G
    /// 返回值 2 = 3G
    /// 返回值 3 = 4G
    /// 返回值 4 = 5G
    func getDataPreferredSlotRate() throws -> Int64 {
        return try getSlotSelectRate(context: try getDataPreferredContext())
    }
    
    /// 获取卡槽支持并且可选择的网络类型
    /// 返回值 1 = 2G
    /// 返回值 2 = 3G
    /// 返回值 3 = 4G
    /// 返回值 4 = 5G
    func getSlotSupportRates(context: CTXPCServiceSubscriptionContext) throws -> [Int64] {
        return try coreTelephonyClient.getSupportedDataRates(context).rates as! [Int64]
    }
    
    /// 获取当前首选卡槽支持并且可选择的网络类型
    /// 返回值 1 = 2G
    /// 返回值 2 = 3G
    /// 返回值 3 = 4G
    /// 返回值 4 = 5G
    func getDataPreferredSlotSupportRates() throws -> [Int64] {
        return try getSlotSupportRates(context: try getDataPreferredContext())
    }
    
    /// 获取当前卡槽的卡标签实例
    /// 返回 CTSimLabel 实例
    /// 无SIM卡时抛异常 错误代码 22
    /// 无权限设备抛异常 错误代码 1
    func getSlotLabel(context: CTXPCServiceSubscriptionContext) throws -> CTSimLabel {
        return try coreTelephonyClient.getSimLabel(context)
    }
    
    /// 获取当前卡槽的卡标签
    /// 返回卡标签的文字
    /// 替代方法 getSubscriptionUserFacingName 需要iOS 15
    func getSlotLabelText(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyLabel(context)
    }
    
    /// 获取当前卡槽的卡标签
    /// 返回卡标签的文字
    /// 需要iOS 15.0+ 无需使用这个方法 copyLabel 兼容性更好
    /// *未使用*
    @available(iOS 15.0, *)
    func getSlotLabelFacingName(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.getSubscriptionUserFacingName(context)
    }
    
    /// 获取当前卡槽的卡标签的简写
    /// 例如 设置 UNICOM -> U; Verizon -> V; Telia -> T
    /// 不适用于无SIM卡或纯单卡设备或iPad蜂窝版设备
    /// 无卡/纯单卡设备/iPad蜂窝版 返回错误35
    func getSlotShortLabelText(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try coreTelephonyClient.getShortLabel(context)
    }
    
    /// 获取当前卡槽使用的Type Allocation Code
    /// 获取的内容是当前卡槽使用的IMEI前8位
    /// 需要 public-subscriber-info 权利
    /// 最低要求iOS 13.0
    /// 无权限抛异常 错误代码 13
    @available(iOS 13.0, *)
    func getSlotUseTypeAllocationCode(descriptor: CTServiceDescriptor) throws -> String {
        return try coreTelephonyClient.getTypeAllocationCode(descriptor)
    }
    
    /// 备用方法获取当前卡槽使用的TypeAllocationCode
    func getSlotUseTypeAllocationCode(context: CTXPCServiceSubscriptionContext) throws -> String {
        let useIMEI = try getSlotUseIMEI(context: context)
        return String(useIMEI.prefix(8))
    }
    
    /// 获取当前卡槽的电话号码信息
    /// 无权限时抛异常 错误代码 13
    /// 当前卡槽没有卡并且设备内就只有过一张卡的情况抛异常 错误代码 2
    @available(iOS 13.0, *)
    func getSlotPhoneNumberInfo(context: CTXPCServiceSubscriptionContext) throws -> CTPhoneNumberInfo {
        return try coreTelephonyClient.getPhoneNumber(context)
    }
    
    /// 获取当前卡槽的电话号码
    /// 低版本兼容方法 直接拿完整的 CTXPCServiceSubscriptionContext.phoneNumber 获取
    @available(iOS 13.0, *)
    func getSlotPhoneNumber(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try getSlotPhoneNumberInfo(context: context).displayPhoneNumber
    }
    
    /// 获取当前卡槽的电话号码是否允许编辑
    /// iPad蜂窝版会返回false
    /// 当前卡槽没有卡并且设备内就只有过一张卡的情况抛异常 错误代码 2
    @available(iOS 13.0, *)
    func getSlotPhoneNumberEditable(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try getSlotPhoneNumberInfo(context: context).isEditable
    }
    
    /// 获取当前卡槽的ICCID
    func getSlotICCID(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try coreTelephonyClient.copySIMIdentity(context)
    }
    
    /// 获取当前卡槽的IMSI
    /// 无权限抛异常 高版本系统错误代码 1 低版本系统错误代码 13
    /// 无SIM卡且只有一张卡抛异常 错误代码 2
    func getSlotIMSI(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyMobileSubscriberIdentity(context)
    }
    
    /// 获取卡槽的SIM卡的GID 1
    func getSlotGID1(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyGid1(context)
    }
    
    /// 获取卡槽的SIM卡的GID 2
    func getSlotGID2(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyGid2(context)
    }
    
    /// 获取当前的卡槽的SIM卡状态
    /// 具体key和含义在 CoreTelephonyEnumMapper.mapSIMStatus
    /// 无权限时抛异常 错误代码 1
    func getSlotSIMStatus(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.getSIMStatus(context)
    }
    
    /// 获取卡槽中的SIM卡类型
    /// 实体SIM卡 返回值 = 1
    /// Apple SIM 返回值 = 1
    /// eSIM 返回值 = 2
    /// 无权限 返回值 = 0 并且抛异常 错误代码 1
    /// iOS 14设备无权限抛异常 错误代码 13
    /// 基带服务重启时 返回值 = 0 不抛异常
    /// Apple SIM 官方文档 @See https://support.apple.com/en-us/104990
    /// iOS 18系统开始不再支持任何Apple SIM的iPad
    func getSlotSIMType(context: CTXPCServiceSubscriptionContext) throws -> Int64 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.isEsim(for: context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 判断卡槽中SIM卡是否允许使用PIN
    /// 允许   返回值 = 1
    /// 不允许 返回值 = 2
    /// 无权限 返回值 = nil
    /// iOS 18 以下无权限 返回正确数据
    /// iOS 15.4.1无权限测试可以返回正确数据
    /// iOS 16.5无权限测试可以返回正确数据
    /// iOS 17.0无权限测试可以返回正确数据
    /// iOS 18以上 无权限时抛异常 错误代码 1
    @available(iOS 14.0, *)
    func getSlotShouldAllowSimLock(context: CTXPCServiceSubscriptionContext) -> NSNumber? {
        return coreTelephonyClient.shouldAllowSimLock(for: context)
    }
    
    /// 获取卡槽中的SIM卡是否被PIN锁定
    /// 返回bool
    /// 无权限/模拟器抛异常 高版本系统错误代码 1 低版本系统错误代码 13
    /// 基带服务崩溃/重启时抛异常 错误代码 6 设备未配置
    func getSlotSIMLockedWithPIN(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try coreTelephonyClient.fetchSIMLockValue(context).boolValue
    }
    
    /// 获取卡槽中SIM卡允许尝试PIN的次数
    /// 返回值 0 - 3 次
    /// 剩余0次后卡会被PUK锁定
    /// 无权限/模拟器抛异常 错误代码 1
    func getSlotRemainingPINAttemptCount(context: CTXPCServiceSubscriptionContext) throws -> Int {
        return try coreTelephonyClient.getRemainingPINAttemptCount(context).intValue
    }
    
    /// 获取卡槽中SIM卡允许尝试PUK的次数
    /// 返回值 0 - 10 次
    /// 剩余0次后卡被彻底锁死，只能换卡
    /// 无权限/模拟器抛异常 高版本系统错误代码 1 低版本系统错误代码 13
    func getSlotRemainingPUKAttemptCount(context: CTXPCServiceSubscriptionContext) throws -> Int {
        return try coreTelephonyClient.getRemainingPUKAttemptCount(context).intValue
    }
    
    /// 获取原始网络运营商名称
    /// 完全可以使用 getSlotLocalizedOperatorName 替代
    /// 无权限/模拟器抛异常 高版本系统错误代码 1 低版本系统错误代码 13
    @available(iOS 16.0, *)
    func getSlotOperatorName(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.getOperatorName(context)
    }
    
    /// 获取本地化的网络运营商名称
    /// 无权限时抛异常 错误代码 1
    func getSlotLocalizedOperatorName(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.getLocalizedOperatorName(context)
    }
    
    /// 获取网络运营商英文名称
    /// 使用运营商/网络名词获取这个运营商/网络的英文名
    /// 无低版本替代方案
    /// 无权限抛异常
    /// TODO 可以做一个用户输入运营商名称 查询英文名的操作
    @available(iOS 15.0, *)
    func getSlotEnglishCarrierName(operatorName: String) throws -> String {
        return try coreTelephonyClient.getEnglishCarrierName(for: operatorName)
    }
    
    /// 获取卡槽的运营商名称
    /// 这个返回值是卡发行的运营商
    /// 与 getSlotOperatorName 获取的连接的网络的运营商名称无关，因为用户可以是在漫游
    /// iOS 16.4开始 无权限的设备会返回 --
    func getSlotCarrierName(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["CarrierName"]) as? String
    }
    
    /// 获取当前卡槽搜索网络运营商的结果
    /// 因为没有调用搜索过程，结果也是没有搜索到网络，虽然不是nil但是数据没有什么意义
    func getSlotNetworkSelectionInfo(context: CTXPCServiceSubscriptionContext) throws -> CTNetworkSelectionInfo {
        return try coreTelephonyClient.copyNetworkSelectionInfo(context)
    }
    
    /// 获取当前卡槽搜索网络模式
    /// 返回值                                  = 0 无SIM卡 / 无服务 / 飞行模式
    /// 返回值 CTNetworkSelectionModeAutomatic  = 1 自动选网
    /// 返回值 CTNetworkSelectionModeManual     = 2 手动选网
    /// 返回值 CTNetworkSelectionModeDisabled   = 3 禁用选网
    /// 无权限时返回nil
    func getSlotNetworkSelectionMode(context: CTXPCServiceSubscriptionContext) throws -> UInt64 {
        return try getSlotNetworkSelectionInfo(context: context).selectionMode
    }
    
    /// 获取当前卡槽是否支持手动选网
    /// 返回true/false
    func getSlotNetworkSelectionMenuAvailable(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try coreTelephonyClient.isNetworkSelectionMenuAvailable(context).boolValue
    }
    
    /// 获取当前卡槽是否启用数据漫游
    /// 返回true/false
    /// 无权限时返回false
    /// 头文件网站显示不包含iOS 13.1.3 可能是需要iOS 13.2或13.4 暂时限制到13.4
    /// TODO *需要更多数据*
    /// 有备用方案可以获取数据漫游开关
    @available(iOS 13.4, *)
    func getSlotEnableDataRoaming(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getInternationalDataAccessSync(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽是否设置低数据模式 iOS 14+
    /// 返回true/false
    /// 最低iOS 14.0 跟5G相关的都需要iOS 14.0+
    /// iOS13使用 saveDataMode 替代
    /// 无权限时返回false
    @available(iOS 14.0, *)
    func getSlotEnabledLowDataMode(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.lowDataMode(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽是否设置低数据模式 iOS 13+
    /// iOS 13的替代方法
    /// 低数据模式是iOS 13引入的新API，第三方app没办法调用，感觉没啥用，纯属鸡肋功能
    /// iOS 14.0+系统返回的结果与 lowDataMode 一致，不建议用这个方法，仅作为低版本系统的替代
    @available(iOS 13.0, *)
    func getSlotEnabledSaveDataMode(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.saveDataMode(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽的卡是否支持高数据模式(5G时允许使用更多数据)
    /// 无权限时不会抛异常但是返回false
    @available(iOS 14.0, *)
    func getSlotSupportsHighDataMode(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.isHighDataModeSupported(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽当前卡注册状态的实例
    /// 无权限的时候抛异常
    func getSlotRegistrationDisplayStatus(context: CTXPCServiceSubscriptionContext) throws -> CTRegistrationDisplayStatus {
        return try coreTelephonyClient.copyRegistrationDisplayStatus(context)
    }
    
    /// 获取卡槽当前卡注册状态
    /// 返回值 kCTRegistrationStatusRegisteredHome     = 本地网络注册
    /// 返回值 kCTRegistrationStatusRegisteredRoaming  = 漫游网络注册
    /// 返回值 kCTRegistrationStatusSearching          = 正在搜索
    /// 返回值 kCTRegistrationStatusDenied             = 被网络拒绝注册
    /// 返回值 kCTRegistrationStatusEmergencyOnly      = 仅限紧急呼叫
    /// 返回值 kCTRegistrationStatusUnknown            = 未知注册状态
    /// 无权限/模拟器返回nil 抛异常 错误代码1
    func getSlotRegistrationStatus(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyRegistrationStatus(context)
    }
    
    /// 获取卡槽当前卡被拒绝状态代码
    /// TODO *需要更多数据*
    /// -1  正常
    /// 7   /
    /// 10  有信号没网
    /// 11  没卡
    /// 14  插卡无服务
    /// 15  没卡
    /// 18  /
    /// 255
    /// TODO 还有些值不知道 包括每个值的具体含义也不知道
    /// 需要细化
    func getSlotRejectCauseCode(context: CTXPCServiceSubscriptionContext) throws -> NSNumber {
        return try coreTelephonyClient.getRejectCauseCode(context)
    }
    
    /// 获取当前卡槽注册的网络是否为本地网络策略
    /// 可以理解为是否正在漫游，但是也不完全一样，比如某些漫游卡运营商虽然在漫游但是还使用本地策略
    /// 原始函数返回值不是BOOL class-dump弄错了，应该是NSNumber
    /// 无权限/模拟器返抛异常
    /// 无权限替代方法 getDataStatus(context).inHomeCountry
    func getSlotIsInHomeCountryNetworkPolicy(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        if #available(iOS 13.0, *) {
            // 这个方法在iOS 13.0+才支持
            return try coreTelephonyClient.copyIs(inHomeCountry: context).boolValue
        }
        // 低版本替代方法
        return try getSlotRegistrationDisplayStatus(context: context).isInHomeCountry
    }
    
    /// 获取当前卡槽注册的网络是否为本地网络策略 备用方法
    /// 无需额外权利，适合无权限设备
    /// iOS 18系统可正常获取数据
    func getSlotIsInHomeCountryNetwork(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try getSlotDataStatus(context: context).inHomeCountry
    }
    
    /// 获取卡槽中的卡短信是否已经就绪
    /// 返回 true或者false
    /// 无权限/模拟器抛异常
    func getSlotSMSReadyState(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try coreTelephonyClient.getSmsReadyState(context).boolValue
    }
    
    /// 获取卡槽中的卡短信中心号码
    /// 返回值可以是 "" 所以还是需要额外判断下
    /// 无权限时返回nil
    func getSlotSMSCAddress(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.getSmscAddress(context)
    }
    
    /// 获取卡槽紧急呼叫号码列表
    /// 返回值 紧急号码的数组[String]
    /// 无权限时抛出异常
    /// 无低版本替代方法
    @available(iOS 13.0, *)
    func getSlotEmergencyTextNumbers(context: CTXPCServiceSubscriptionContext) throws -> [String] {
        if let numbers = try coreTelephonyClient.getEmergencyTextNumbers(context) as? [String] {
            return numbers
        }
        return []
    }
    
    /// 获取设备允许的紧急呼叫号码列表
    /// 无低版本系统替代方法
    @available(iOS 16.0, *)
    func getDeviceAllEmergencyTextNumbers() throws -> [String] {
//        return try coreTelephonyClient.getAllEmergencyNumbers().map { "\($0)" }
        return try coreTelephonyClient.getAllEmergencyNumbers()
    }
    
    /// 获取当前卡槽的APN配置
    /// 无权限设备抛异常 错误代码 13
    func getSlotAPNs(context: CTXPCServiceSubscriptionContext) throws -> [[AnyHashable: Any]] {
        return try coreTelephonyClient.getConfiguredApns(context)
    }
    
    /// 获取卡槽是否允许附加APN配置
    /// 无权限设备抛异常 错误代码 13
    func getSlotAllowedAttachAPNSetting(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.isAttachApnSettingAllowed(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前网络运营商允许的最大多方通话人数
    /// 返回数字 0～6 都有可能 取决于网络
    /// 无权限抛异常错误代码 13
    func getSlotOperatorMultiPartyCallCountMaximum(context: CTXPCServiceSubscriptionContext) throws -> Int {
        return try coreTelephonyClient.getOperatorMultiPartyCallCountMaximum(context).intValue
    }
    
    /// 获取信号格的实例
    /// 用 Context 获取
    /// 返回 CTSignalStrengthInfo 实例
    /// 返回数据和 getSlotPublicSignalStrength 是一样的
    func getSlotSignalStrengthInfo(context: CTXPCServiceSubscriptionContext) throws -> CTSignalStrengthInfo? {
        return try coreTelephonyClient.getSignalStrengthInfo(context)
    }
    
    /// 获取信号格的实例
    /// 用 Descriptor 获取
    /// 返回 CTSignalStrengthInfo 实例
    /// 返回数据和 getSlotSignalStrengthInfo 是一样的
    /// *未使用*
    func getSlotPublicSignalStrength(descriptor: CTServiceDescriptor) throws -> CTSignalStrengthInfo? {
        return try coreTelephonyClient.getPublicSignalStrength(descriptor)
    }
    
    /// 获取连接基站信息的实例
    /// 用 Descriptor 获取
    /// 返回 CTCellIdInfo 实例
    func getSlotCellIDInfo(descriptor: CTServiceDescriptor) throws -> CTCellIdInfo {
        return try coreTelephonyClient.copyPublicCellId(descriptor)
    }
    
    /// 获取连接基站的ID
    /// 用 Descriptor 获取
    /// 返回Cell ID
    /// Cell ID = 0 为无服务
    func getSlotServingCellID(descriptor: CTServiceDescriptor) throws -> String? {
        return try getSlotCellIDInfo(descriptor: descriptor).cellId.stringValue
    }
    
    /// 获取卡槽的基带信息
    /// 把系统的异步方法强行同步调用，debug测试返回时间仅需要0.142 ms所以不需要担心性能问题
    /// 返回的数据大部分是系统自带 FTMInternal-4 App的 Serving Cell Info
    /// 返回 CTCellInfo 实例
    func getSlotCellInfo(context: CTXPCServiceSubscriptionContext, timeout: TimeInterval = 3) throws -> CTCellInfo? {
        
        // 创建一个向量为0的锁
        let sema = DispatchSemaphore(value: 0)
        // 创建对象
        var resultInfo: CTCellInfo?
        var nsError: NSError?
        // 获取数据
        coreTelephonyClient.copyCellInfo(context) { info, error in
            resultInfo = info
            nsError = error as NSError?
            sema.signal()
        }
        // 解除线程占用
        _ = sema.wait(timeout: .now() + timeout)
        
        if let error = nsError {
            throw error
        }
        
        return resultInfo
    }
    
    /// 通过CTCellInfo的key获取value
    /// 已知key:
    /// kCTCellMonitorCellRadioAccessTechnology 当前连接的网络类型
    /// kCTCellMonitorBandInfo          频段
    /// kCTCellMonitorBandwidth         频宽
    /// kCTCellMonitorCellId            基站ID
    /// kCTCellMonitorMCC               SIM卡的移动国家代码(MCC)
    /// kCTCellMonitorMNC               SIM卡的移动网络代码(MNC)
    /// kCTCellMonitorGSCN              全局同步信号
    /// kCTCellMonitorCsgId             *专用基站ID 半无效数据*
    /// kCTCellMonitorNRARFCN           5G绝对无线信道编号
    /// kCTCellMonitorUARFCN            信道编号
    /// kCTCellMonitorPID               物理小区ID
    /// kCTCellMonitorPMax              最大发射功率上限
    /// kCTCellMonitorTAC               跟踪区码
    /// kCTCellMonitorSCS               子载波间隔
    /// kCTCellMonitorBWPSupport        5G动态频宽
    /// kCTCellMonitorThroughput        *无效数据*
    /// kCTCellMonitorSCN               3G UMTS/WCDMA 扰码
    /// kCTCellMonitorRSRP              低版本兼容方案 不为0时是低版本的数据
    /// kCTCellMonitorRSRQ              低版本兼容方案 不为0时是低版本的数据
    func getSlotCellInfo(cellInfo: CTCellInfo, key: String) -> Any? {
        
        guard let list = cellInfo.legacyInfo,
              !list.isEmpty
        else {
            return nil
        }
        
         // 优先找 Serving Cell
        if let serving = list.first(where: {
            ($0["kCTCellMonitorCellType"] as? String)
            == "kCTCellMonitorCellTypeServing"
        }) {
            return serving[key]
        }
        
        return list.first?[key]
    }
    
    /// 获取卡槽当前使用的网络类型
    /// kCTCellMonitorCellRadioAccessTechnology
    /// 辅助方法
    func getSlotBandRadioAccessTechnology(cellInfo: CTCellInfo) -> String? {
        return getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorCellRadioAccessTechnology") as? String
    }
    
    /// 获取卡槽的卡的MCC
    /// 备用方法 兼容iOS 12
    /// 高版本直接使用getSlotServingMCC(context: CTXPCServiceSubscriptionContext)
    func getSlotServingMCC(cellInfo: CTCellInfo) -> String? {
        if let MCC = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorMCC") as? NSNumber {
            return MCC.stringValue
        }
        return nil
    }
    
    /// 获取卡槽的卡的MNC
    /// 备用方法 兼容iOS 12
    /// 高版本直接使用getSlotServingMNC(context: CTXPCServiceSubscriptionContext)
    func getSlotServingMNC(cellInfo: CTCellInfo) -> String? {
        if let MNC = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorMNC") as? NSNumber {
            return MNC.stringValue
        }
        return nil
    }
    
    /// 获取卡槽当前使用的频段
    /// kCTCellMonitorBandInfo
    func getSlotServingBand(cellInfo: CTCellInfo) -> Int? {
        if let ServingBand = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorBandInfo") as? NSNumber {
            return ServingBand.intValue
        }
        return nil
    }
    
    /// 获取卡槽当前网络的频宽
    /// 原始数据单位 PRB/NRB
    /// 单位 MHz
    /// kCTCellMonitorBandwidth
    /// 数据暂时有问题 数据不准确 需要转换
    /// 5G SA  返回 100 FTM 20 MHz
    /// 4G LTE 返回 100 FTM 20 MHz
    /// 4G LTE 返回  75 FTM 15 MHz
    /// 4G LTE 返回  50 FTM 10 MHz
    /// LTE 对照关系（3GPP TS 36.101 Release-17 Page 73 Table 5.6-1）对照表
    /// NRB → Channel Bandwidth
    /// 6   → 1.4 MHz
    /// 15  → 3 MHz
    /// 25  → 5 MHz
    /// 50  → 10 MHz
    /// 75  → 15 MHz
    /// 100 → 20 MHz
    /// *需要更多数据*
    /// 参考文献 Page 73 @See https://www.etsi.org/deliver/etsi_ts/136100_136199/136101/17.06.00_60/ts_136101v170600p.pdf
    /// 参考文献 @See https://www.3gpp.org/technologies/101-carrier-aggregation-explained
    /// 参考文献 @See https://www.sciencedirect.com/topics/computer-science/physical-resource-block
    func getSlotServingBandwidth(cellInfo: CTCellInfo) -> Int? {
        if let bandwidth = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorBandwidth") as? NSNumber {
            return bandwidth.intValue
        }
        return nil
    }
    
    /// 获取卡槽连接的网络是否支持5G动态频宽
    /// 返回 1 3 0
    /// *需要更多数据*
    /// 参考文献 Page 96-97 @See https://www.etsi.org/deliver/etsi_ts/138300_138399/138300/16.04.00_60/ts_138300v160400p.pdf
    /// 参考文献 @See https://sg.o3community.huawei.com/sg/en/forum/1358950823329681409?blogId=668090880327827456
    /// 参考文献 @See https://www.keysight.com/blogs/en/inds/2018/10/31/understanding-5g-new-radio-bandwidth-parts
    func getSlotServingBWPSupport(cellInfo: CTCellInfo) -> Int? {
        if let BWPSupport = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorBWPSupport") as? NSNumber {
            return BWPSupport.intValue
        }
        return nil
    }
    
    /// 获取卡槽 NR子载波间隔
    /// 单位 kHz
    /// kCTCellMonitorSCS
    /// 返回值 0 =  15 kHz
    /// 返回值 1 =  30 kHz
    /// 返回值 2 =  60 kHz
    /// 返回值 3 = 120 kHz
    /// 返回值 4 = 240 kHz
    /// 返回值 5 = 480 kHz
    /// 返回值 6 = 960 kHz
    /// 参考文献 @See https://www.sharetechnote.com/html/5G/5G_Phy_Numerology.html
    func getSlotNRSubcarrierSpacing(cellInfo: CTCellInfo) -> Int? {
        if let subcarrierSpacing = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorSCS") as? NSNumber {
            return subcarrierSpacing.intValue
        }
        return nil
    }
    
    /// 获取最大发射功率上限
    /// kCTCellMonitorPMax
    /// 单位 dBm
    func getSlotPMax(cellInfo: CTCellInfo) -> Int? {
        if let max = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorPMax") as? NSNumber {
            if max != 0 { // 发射最大功率为0时不显示
                return max.intValue
            }
        }
        return nil
    }
    
    /// 获取卡槽 同步信道编号 (GSCN)
    /// Synchronization Channel Number (GSCN)
    /// kCTCellMonitorGSCN
    func getSlotGSCN(cellInfo: CTCellInfo) -> String? {
        if let GSCN = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorGSCN") as? NSNumber {
            return GSCN.stringValue
        }
        return nil
    }
    
    /// 获取卡槽 5G绝对无线信道编号
    /// NR Absolute Radio Frequency Channel Number(NRARFCN)
    /// kCTCellMonitorNRARFCN
    /// 系统4G显示 EARFCN DL
    /// *需要细化*
    func getSlotNRARFCN(cellInfo: CTCellInfo) -> String? {
        if let NRARFCN = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorNRARFCN") as? NSNumber {
            return NRARFCN.stringValue
        }
        return nil
    }
    
    /// 获取卡槽 信道编号
    /// Channel Number
    /// kCTCellMonitorUARFCN
    func getSlotUARFCN(cellInfo: CTCellInfo) -> String? {
        if let UARFCN = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorUARFCN") as? NSNumber {
            return UARFCN.stringValue
        }
        return nil
    }
    
    /// 获取卡槽 3G UMTS/WCDMA 扰码
    /// Scrambling Code (PSC)
    func getSlotSCN(cellInfo: CTCellInfo) -> String? {
        if let SCN = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorSCN") as? NSNumber {
            return SCN.stringValue
        }
        return nil
    }
    
    /// 获取卡槽 物理小区ID
    /// Physical Cell ID
    /// kCTCellMonitorPID
    func getSlotPhysicalCellID(cellInfo: CTCellInfo) -> Int? {
        if let physicalCellID = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorPID") as? NSNumber {
            return physicalCellID.intValue
        }
        return nil
    }
    
    /// 获取卡槽的RSRP值
    /// 旧版系统的兼容方法
    /// 信号单位 dBm
    /// 高版本直接用 getSlotRSRP(descriptor: CTServiceDescriptor)
    func getSlotRSRP(cellInfo: CTCellInfo) -> String? {
        if let RSRP = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorRSRP") as? NSNumber {
            if RSRP != 0 {
                return RSRP.stringValue
            }
        }
        return nil
    }
    
    /// 获取卡槽的RSRQ
    /// 低版本可以获取
    /// 高版本无法获取 需要别的方法
    /// *未使用*
    func getSlotRSRQ(cellInfo: CTCellInfo) -> String? {
        if let RSRQ = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorRSRQ") as? NSNumber {
            if RSRQ != 0 {
                return RSRQ.stringValue
            }
        }
        return nil
    }
    
    /// 获取卡槽的服务TAC 跟踪区码
    /// 主要是4G/5G网络中的区域代码
    /// kCTCellMonitorTAC
    func getSlotServingTrackingAreaCode(cellInfo: CTCellInfo) -> String? {
        if let code = getSlotCellInfo(cellInfo: cellInfo, key: "kCTCellMonitorTAC") as? NSNumber {
            return code.stringValue
        }
        return nil
    }
    
    /// 同步获取卡槽当前基站的LAC 位置区码
    /// 主要是2G和3G网络的指标时LAC，4G/5G时TAC
    /// 优先使用getSlotCellInfo里面的info解析TAC
    /// 把系统的异步方法强行同步调用，debug测试返回时间仅需要0.06 ms所以不需要担心性能问题
    /// LAC = 0 为无服务
    /// 无权限机器会抛异常 错误代码 13 无权限
    func getSlotServingLocationAreaCode(context: CTXPCServiceSubscriptionContext, timeout: TimeInterval = 3) throws -> NSNumber? {
        // 创建一个向量为0的锁
        let sema = DispatchSemaphore(value: 0)
        // 创建对象
        var LAC: NSNumber?
        var callbackError: Error?
        // 获取数据
        coreTelephonyClient.copyLocationAreaCode(context) { locationAreaCode, error in
            LAC = locationAreaCode
            callbackError = error
            sema.signal()
        }
        // 解除线程占用
        _ = sema.wait(timeout: .now() + timeout)
        // 如果存在异常就抛异常
        if let error = callbackError {
            throw error
        }
        
        return LAC
    }
    
    /// 异步获取卡槽当前基站的LAC 位置区码
    func getSlotServingLocationAreaCode(context: CTXPCServiceSubscriptionContext, completion: @escaping (String?, Error?) -> Void) {
        coreTelephonyClient.copyLocationAreaCode(context) { locationAreaCode, error in
            completion(locationAreaCode?.stringValue, error)
        }
    }
    
    /// 获取信号原始信息的实例
    /// 包含RSRP信息的 CTSignalStrengthMeasurements 实例
    /// 包含RSRP和SNR
    /// 返回值可以为nil
    @available(iOS 13.0, *)
    func getSlotSignalStrengthMeasurements(descriptor: CTServiceDescriptor) throws -> CTSignalStrengthMeasurements? {
        return try coreTelephonyClient.getSignalStrengthMeasurements(descriptor)
    }
    
    /// 获取卡槽的RSRP值
    /// 4G/5G的网络指标
    /// 信号单位 dBm
    /// 低版本兼容方案 getSlotCellInfo 里面的kCTCellMonitorRSRP
    @available(iOS 13.0, *)
    func getSlotRSRP(descriptor: CTServiceDescriptor) -> String? {
        return try? getSlotSignalStrengthMeasurements(descriptor: descriptor)?.rsrp?.stringValue
    }
    
    /// 获取卡槽的SNR值 信噪比
    /// 4G/5G的网络指标
    @available(iOS 13.0, *)
    func getSlotSNR(descriptor: CTServiceDescriptor) -> Double? {
        return try? getSlotSignalStrengthMeasurements(descriptor: descriptor)?.snr?.doubleValue
    }
    
    /// 获取卡槽的RSCP值
    /// 3G网络的指标
    @available(iOS 13.0, *)
    func getSlotRSCP(descriptor: CTServiceDescriptor) -> String? {
        return try? getSlotSignalStrengthMeasurements(descriptor: descriptor)?.rscp?.stringValue
    }
    
    /// 获取卡槽的ECN0值 信噪比
    /// 3G的网络指标
    @available(iOS 13.0, *)
    func getSlotECN0(descriptor: CTServiceDescriptor) -> String? {
        return try? getSlotSignalStrengthMeasurements(descriptor: descriptor)?.ecn0?.stringValue
    }
    
    /// 获取卡槽SIM卡的信息
    /// 返回 CTSimHardwareInfo 实例
    /// 无权限时抛异常 错误代码 1
    /// iOS 15以下系统版本没有CTSimHardwareInfo
    @available(iOS 15.0, *)
    func getSlotSimHardwareInfo(context: CTXPCServiceSubscriptionContext) throws -> CTSimHardwareInfo {
        return try coreTelephonyClient.getSimHardwareInfo(context)
    }
    
    /// 获取SIM卡所在的位置
    /// 返回值 CTSimLocationFront    1 = 正面
    /// 返回值 CTSimLocationBack     2 = 背面（只有双实体卡槽的设备才能出现）
    /// 返回值 CTSimLocationEmbedded 3 = eSIM / Apple SIM 芯片中 （Apple SIM 仍然返回这个）
    /// 返回值 CTSimLocationUnknown  0 = 基带服务重启中
    /// 无权限抛异常 错误代码 1
    @available(iOS 15.0, *)
    func getSlotSIMLocation(context: CTXPCServiceSubscriptionContext) throws -> Int64 {
        return try getSlotSimHardwareInfo(context: context).simLocation
    }
    
    /// 获取卡槽的设备基本信息
    /// 返回 CTMobileEquipmentInfo 实例
    /// 包含IMEI IMSI EID 等信息
    /// 双卡槽设备获取的数据是不一样的
    /// 获取设备的信息用 getDeviceInfoList
    /// 无权限时抛异常 错误代码1
    func getSlotMobileEquipmentInfo(context: CTXPCServiceSubscriptionContext) throws -> CTMobileEquipmentInfo {
        return try coreTelephonyClient.getMobileEquipmentInfo(for: context)
    }
    
    /// 获取当前卡槽使用的IMEI
    func getSlotUseIMEI(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try getSlotMobileEquipmentInfo(context: context).imei
    }
    
    /// 获取卡槽通话支持情况
    /// 包括VoLTE和Wi-Fi Calling支持情况
    /// 返回 CTCallCapabilities 实例
    /// 无权限抛异常 错误代码 13
    func getSlotCallCapabilities(context: CTXPCServiceSubscriptionContext) throws -> CTCallCapabilities {
        return try coreTelephonyClient.getCallCapabilities(context)
    }
    
    /// 获取卡槽是否强制禁用VoLTE
    /// 一般为false
    /// 无权限时抛异常
    @available(iOS 14.0, *)
    func getSlotForceDisableVoLTE(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.context(context, isMandatoryDisabledVoLTE: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽连接网络的PLMN
    /// 需要iOS 13.0+
    /// 正常获取返回值是 MCC + MNC
    /// 未获取到是 ""
    /// 无权限抛异常
    /// TODO 兼容下iOS 12
    @available(iOS 13.0, *)
    func getSlotPLMN(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyServingPlmn(context)
    }
    
    /// 获取当前卡槽连接网络的MCC 移动网络国家代码
    /// 未获取到的时候是65535
    /// 无权限抛异常
    func getSlotServingMCC(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyMobileCountryCode(context)
    }
    
    /// 获取当前卡槽连接网络的MNC 移动运营商标识符
    /// 未获取到的时候是65535
    /// 无权限抛异常
    func getSlotServingMNC(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyMobileNetworkCode(context)
    }
    
    /// 获取当前卡槽的卡最后一次获取到的MCC
    /// 无权限抛异常
    /// 无低版本兼容方法
    @available(iOS 13.0, *)
    func getSlotLastKnownMCC(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyLastKnownMobileCountryCode(context)
    }
    
    /// 获取当前卡槽的卡最后一次获取到的MNC所属的国家/地区代码
    /// 与 copyLastKnownMobileCountryCode 没区别
    /// 这个数据有问题 返回的是SIM卡归属的MCC
    /// 无权限抛异常
    func getSlotLastKnownMNCCountryCode(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyLastKnownMobileSubscriberCountryCode(context)
    }
    
    /// 获取当前卡槽SIM卡的MCC 移动网络国家代码
    /// 未获取到的时候是65535或者为空
    /// 无权限 错误代码 22 不会抛异常
    /// iOS 16.4+ 无权限返回Empty
    func getSlotSIMCardMCC(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyMobileSubscriberCountryCode(context)
    }
    
    /// 获取当前卡槽SIM卡的MNC 移动运营商标识符
    /// 未获取到的时候是65535或者为空
    /// 无权限 错误代码 22 不会抛异常
    /// iOS 16.4+ 无权限返回Empty
    func getSlotSIMCardMNC(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyMobileSubscriberNetworkCode(context)
    }
    
    /// 获取SIM卡发卡所属国家/地区的ISO列表信息
    /// 返回 [String]
    /// 未启用/无SIM卡的卡槽 抛异常 返回错误代码0
    /// 无权限抛异常 高版本错误代码 1 高版本错误代码 13
    func getSlotMobileSubscriberHomeCountryList(context: CTXPCServiceSubscriptionContext) throws -> [String] {
        return try coreTelephonyClient.getMobileSubscriberHomeCountryList(context)
    }
    
    /// 获取IMS注册状态
    /// 返回 CTIMSRegistrationStatus 的实例
    /// 可能为nil
    /// 无权限时抛异常 错误代码 1
    func getSlotIMSRegistrationStatus(context: CTXPCServiceSubscriptionContext) throws -> CTIMSRegistrationStatus? {
        return try coreTelephonyClient.getIMSRegistrationStatus(context)
    }
    
    /// 获取当前卡槽使用的无线技术
    /// 使用 context 获取
    /// 返回 String
    /// 与 getCurrentRat 获取的结果是一致的
    func getSlotRadioAccessTechnology(context: CTXPCServiceSubscriptionContext) throws -> String {
        return try coreTelephonyClient.copyRadioAccessTechnology(context)
    }
    
    /// 返回当前卡槽连接的网络类型
    /// 使用 descriptor 获取
    /// 返回的是 String
    /// 与 copyRadioAccessTechnology 获取的结果是一致的
    func getSlotCurrentRat(descriptor: CTServiceDescriptor) throws -> String {
        return try coreTelephonyClient.getCurrentRat(descriptor)
    }
    
    /// 获取当前卡槽的卡是否支持5G
    /// iOS 14无权限设备调用会导致闪退 需要额外判断保护
    /// 无权限时抛异常 错误代码 13
    @available(iOS 14.0, *)
    func getSlotSupports5G(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try coreTelephonyClient.getSupports5G(context).boolValue
    }
    
    /// 获取当前卡槽的卡是否支持5G SA
    /// 返回当前卡是否支持5G SA
    /// 无需当前卡为首选卡槽
    /// throws 但是有时候会返回不支持 需要处理异常
    /// 错误代码45是不支持
    /// 无权限抛异常 错误代码1
    @available(iOS 14.0, *)
    func getSlotSupports5GStandalone(descriptor: CTServiceDescriptor) throws -> Bool {
        return try coreTelephonyClient.getSupports5GStandalone(descriptor).boolValue
    }
    
    /// 获取NR状态
    /// 返回 CTNRStatus 实例
    /// 与 getNRDisableStatus 获取的数据是一样的
    /// 低版本替代方案 getNRDisableStatus
    @available(iOS 17.0, *)
    func getSlotNRStatus(descriptor: CTServiceDescriptor) throws -> CTNRStatus {
        return try coreTelephonyClient.getNRStatus(descriptor)
    }
    
    /// 获取NR状态
    /// 返回 CTNRStatus 实例
    /// 例如不支持5G的卡/IPCC saDisabled = true
    /// saDisabled  = true 不支持SA
    /// nsaDisabled = true 不支持NSA
    /// reason = 1 当前不支持
    /// reason = 4 当前非首选卡槽 disabled 状态无效
    /// reason = 5 当前非首选卡槽+不支持 disabled 状态无效
    /// 飞行模式下可以显示非首选卡槽的正确状态
    /// 与 getNRStatus 获取的数据是一样的
    /// 无低版本替代方案
    /// iOS 18.0移除了此方法
    /// 高版本使用getNRStatus
    @available(iOS 14.0, *)
    func getSlotNRDisableStatus(descriptor: CTServiceDescriptor) throws -> CTNRStatus {
        if #available(iOS 18.0, *) {
            throw NSError(domain: "CoreTelephony", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not supported on iOS 18+"])
        }
        return try coreTelephonyClient.getNRDisableStatus(descriptor)
    }
    
    /// 获取卡槽的卡是否开启自动5G
    /// 无权限时抛异常
    @available(iOS 14.0, *)
    func getSlotEnable5GAutoMode(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.smartDataMode(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽的卡是否支持PNR
    /// iPad蜂窝版抛异常 错误代码 22
    func getSlotPNRSupported(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.isPNRSupported(context, outError: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽PNR信息
    /// 包括IMSI PLMN 手机号 SIM卡已就绪情况
    /// 其他API可以获取
    /// 无SIM卡时抛异常 错误代码 35
    /// 无权限时抛异常 错误代码 13
    func getSlotPNRContextInfo(context: CTXPCServiceSubscriptionContext) throws -> CTPNRContextInfo {
        return try coreTelephonyClient.getPNRContext(context)
    }
    
    /// 获取卡槽的号码认证状态
    /// 运营商网络是否已完成该 SIM 卡的身份确认
    /// iOS 13的设备 抛异常 错误代码 4097 无法与帮助程序通信 iOS 12设备正常 iOS 14设备正常
    /// 无SIM卡时抛异常 错误代码 35
    /// 无权限时抛异常 错误代码 13
    func getSlotPhoneNumberCredentialValid(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.isPhoneNumberCredentialValid(context, outError: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取基带支持的频段等信息
    /// 返回 CTBandInfo 实例
    /// 无权限时抛异常
    /// iOS 14以下没有 CTBandInfo 头文件
    @available(iOS 14.0, *)
    func getSlotBandInfo(context: CTXPCServiceSubscriptionContext) throws -> CTBandInfo {
        return try coreTelephonyClient.getBandInfo(context)
    }
    
    /// 设置当前卡的频段信息
    @available(iOS 14.0, *)
    func setSlotActiveBandInfo(context: CTXPCServiceSubscriptionContext, bandInfo: CTBandInfo) throws {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        coreTelephonyClient.setActiveBandInfo(context, bands: bandInfo, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
    }
    
    /// 获取当前卡槽的SIM卡联系人数量
    /// 新版SIM卡和eSIM通常返回0
    /// 无权限时仍然返回0
    /// 手动抛异常解决无权限的判断问题
    func getSlotPhonebookEntryCount(context: CTXPCServiceSubscriptionContext) throws -> Int32 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getPhonebookEntryCount(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取系统能力
    /// 返回 key-value 的字典
    /// value 可能是Bool也可能是String
    /// 无权限时返回nil
    func getSlotSystemCapabilities(context: CTXPCServiceSubscriptionContext) throws -> [String: Any] {
        var error: NSError? // 创建一个接收错误信息的对象
        // 这个方法Swift无法识别这个方法抛异常，只能自己处理异常
        let result = coreTelephonyClient.context(context, getSystemCapabilities: &error) ?? [:]
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽是否设置 iCloud专用代理 和 限制IP地址跟踪
    /// 返回 CTPrivacyProxyState 结构体
    /// 返回值 CTPrivacyProxyState.privateRelayEnabled    = 用户是否开启 iCloud专用代理 不代表是否已经连接到专用代理
    /// 返回值 CTPrivacyProxyState.limitIPTrackingEnabled = 用户是否开启 限制IP地址跟踪
    /// 无权限/模拟器返回[false, false]
    /// 手动抛异常解决无权限的判断问题
    @available(iOS 15.0, *)
    func getSlotPrivacyProxyState(descriptor: CTServiceDescriptor) throws -> CTPrivacyProxyState {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getPrivacyProxyState(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽NAT Traversal 最大保持时间 单位秒
    /// 与 private_getNATTKeepAliveOverCell
    ///    getNATTKeepAliveOverCell
    ///    getNATTKeepAliveOverCellForPreferredDataContext
    ///    获取的数据是一样的
    /// 返回int 例如110
    /// 错误 35 设备暂不支持
    /// 无权限时会抛异常 错误代码 13
    /// 基带服务崩溃/重启时抛异常 错误代码 35
    func getSlotNATTKeepAliveOverCell(context: CTXPCServiceSubscriptionContext) throws -> UInt32 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getNATTKeepAliveOverCell(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取设备网络共享的信息
    /// 返回 CTTetheringStatus 实例
    /// 经过测试需要iOS 15.0+ limneos网站数据存在错误
    /// iOS 14.4的设备运行闪退
    /// 无权限时会抛异常 错误代码 13
    /// 基带服务崩溃/重启时抛异常 错误代码 35
    /// 模拟器/无蜂窝网络模块设备抛异常 错误代码 19
    @available(iOS 15.0, *)
    func getDeviceTetheringStatusInfo() throws -> CTTetheringStatus {
        return try coreTelephonyClient.getTetheringStatusSync()
    }
    
    /// 设置网络共享状态
    /// 返回nil
    /// *未使用*
    @available(iOS 14.0, *)
    func setTetheringActive(active: Bool) -> String {
        return String(describing: coreTelephonyClient.setTetheringActive(active))
    }
    
    /// 获取是否允许编辑网络共享信息
    /// 经过测试 如果当前运营商的卡不允许编辑APN 那么就会返回0 允许编辑返回1
    /// 无权限设备抛异常 错误代码 13
    /// 基带服务崩溃/重启时抛异常 错误代码 35
    func getSlotTetheringEditingSupported(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.isTetheringEditingSupported(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽的卡系统认为接口的费用是昂贵的 高成本网络
    /// 无低版本替代方案
    /// 无权限设备抛异常 错误代码 13
    @available(iOS 14.0, *)
    func getSlotInterfaceCostExpensive(descriptor: CTServiceDescriptor) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.interfaceCostExpensive(descriptor, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取卡槽的卡是否需要在通话时显示警告信息
    /// 不知道做什么用的
    /// 无权限设备抛异常 错误代码 13
    func getSlotShouldShowUserWarningWhenDialingCall(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.shouldShowUserWarningWhenDialingCall(on: context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽的运营商配置文件(IPCC)版本号
    /// 无SIM卡并且设备只有过一张卡时抛异常 错误代码 0
    /// 无权限时抛异常
    /// 模拟器抛异常 错误代码 19 设备不支持
    func getSlotCarrierBundleVersion(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try coreTelephonyClient.copyCarrierBundleVersion(context)
    }
    
    /// 获取当前卡槽的运营商配置文件(IPCC)所在位置
    /// 无权限设备抛异常 错误代码 22
    func getSlotCarrierBundleLocation(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try coreTelephonyClient.copyCarrierBundleLocation(context)
    }
    
    /// 获取当前卡槽的运营商配置文件(IPCC)中的value
    /// keyHierarchy = 需要获取的键的列表
    ///                一次只能查询一个key
    ///                如果是Array嵌套的key需要 ["OTASoftwareUpdate", "SoftwareUpdateOptInRequired"] 这种格式
    /// 返回 value 如果不存在或者一次查询了多个key会返回nil
    /// 注意错误的数据类型可能会导致基带服务(CommCenter)崩溃 第一次错误返回nil 第二次基带服务直接崩溃
    func getSlotCarrierBundleValue(context: CTXPCServiceSubscriptionContext, keyHierarchy: [String]) throws -> Any? {
        return try coreTelephonyClient.context(context, getCarrierBundleValue: keyHierarchy)
    }
    
    /// 用于查询Bundle的类型
    enum CarrierBundleType: Int64 {
        // 发卡运营商的Bundle
        case homeCarrier = 1
        // 连接网络的Bundle
        case servingCarrier = 2
        // 系统默认的Bundle
        case defaultBundle = 4
    }
    
    /// 获取当前卡槽的运营商配置文件(IPCC)中的value
    /// keyHierarchy = 需要获取的键的列表
    /// bundleType = 需要查询的Bundle类型
    func getSlotCarrierBundleValue(context: CTXPCServiceSubscriptionContext, keyHierarchy: [String], bundleType: CarrierBundleType) throws -> Any? {
        let bundle = CTBundle(bundleType: bundleType.rawValue)
        return try coreTelephonyClient.copyCarrierBundleValue(context, keyHierarchy: keyHierarchy, bundleType: bundle)
    }
    
    /// 运营商配置文件要求当前卡槽在4G LTE网络的显示的文本
    /// 返回 4G 或 LTE
    /// 无权限设备可返回正确数据
    /// 模拟器返回nil
    func getSlot4GIndicatorText(context: CTXPCServiceSubscriptionContext) -> String {
        return (try? getSlotCarrierBundleValue(context: context, keyHierarchy: ["DataIndicatorOverrideForLTE"]) as? String) ?? "nil"
    }
    
    /// 运营商配置文件要求当前卡槽在5G毫米波/5GA的状态下显示的文本
    /// 部分运营商需要IPCC >= 64.0.0 版本才能获取
    /// 手动限制最低iOS 14.0+
    @available(iOS 14.0, *)
    func getSlot5GNRMMWaveIndicatorText(context: CTXPCServiceSubscriptionContext) throws -> String? {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["DataIndicatorOverrideForNRMmwave"]) as? String
    }
    
    /// 运营商配置文件是否允许显示切换5G网络开关
    /// 手动限制最低iOS 14.0+
    @available(iOS 14.0, *)
    func getSlotCarrierBundleShow5GSwitch(context: CTXPCServiceSubscriptionContext) -> Bool {
        return (try? getSlotCarrierBundleValue(context: context, keyHierarchy: ["Show5GSwitch"]) as? Bool) ?? false
    }
    
    /// 运营商配置文件是否允许显示切换5G SA开关
    /// 手动限制最低iOS 14.0+
    @available(iOS 14.0, *)
    func getSlotCarrierBundleShow5GStandaloneSwitch(context: CTXPCServiceSubscriptionContext) -> Bool {
        return (try? getSlotCarrierBundleValue(context: context, keyHierarchy: ["Show5GStandaloneSwitch"]) as? Bool) ?? false
    }
    
    /// 运营商配置文件是否允许显示切换4G网络开关
    /// 正常返回的是true/false
    /// 有可能的结果是 Invalid
    func getSlotCarrierBundleShow4GSwitch(context: CTXPCServiceSubscriptionContext) throws -> Bool? {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["Show4GSwitch"]) as? Bool
    }
    
    /// 运营商配置文件是否允许显示切换3G网络开关
    /// 有两种字段来控制显示3G开关
    /// 未包含此字段时抛异常 错误代码 0 无法完成此操作
    func getSlotCarrierBundleShow3GSwitch(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        do {
            return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["Show3GSwitch"]) as? Bool ?? false
        } catch {
            return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["Show3GSwitchWith4G"]) as? Bool ?? false
        }
    }
    
    /// 运营商配置文件是否允许显示切换VoLTE开关
    func getSlotCarrierBundleShowVoLTESwitch(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["ShowVolteSwitch"]) as? Bool ?? false
    }
    
    /// 运营商配置文件是否在更新之前需要用户同意
    func getSlotCarrierBundleOTABeforeUserConfirm(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["OTASoftwareUpdate", "SoftwareUpdateOptInRequired"]) as? Bool ?? false
    }
    
    /// 运营商配置文件能兼容的SIM卡列表
    /// 包括 IMSI ICCID GID1 GID2 不一定都包含
    /// 无权限可返回正确的数据
    func getSlotCarrierBundleSupportsSIMList(context: CTXPCServiceSubscriptionContext) throws -> [String] {
        return try getSlotCarrierBundleValue(context: context, keyHierarchy: ["SupportedSIMs"]) as? [String] ?? []
    }
    
    /// 获取当前卡槽的运营商的书签（可以理解成他们的广告 doge）
    func getSlotCarrierBookmarks(context: CTXPCServiceSubscriptionContext,completion: @escaping ([[String: Any]]?, Error?) -> Void) {

        coreTelephonyClient.copyCarrierBookmarks(context) { data, error in
            guard error == nil else { // 判断是否有错误
                completion(nil, error)
                return
            }
            let list = data?["CarrierBookmarks"] as? [[String: Any]] // 获取数据
            completion(list, nil)
        }
    }
    
    /// 获取设备是否允许使用开发者签名的IPCC
    /// 返回false 我也不知道怎么让它返回true
    @available(iOS 16.0, *)
    func getAllowDevSignedCarrierBundles() -> Bool {
        return coreTelephonyClient.getAllowDevSignedCarrierBundlesFlag().boolValue
    }
    
    /// 获取当前卡槽的SIM卡是否为私有网络的SIM卡
    @available(iOS 16.0, *)
    func getSlotSIMIsPrivateNetwork(context: CTXPCServiceSubscriptionContext) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.isPrivateNetworkSIM(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// 获取当前卡槽激活的数据服务类型
    /// 返回[String]
    /// 已知key:
    /// kCTDataConnectionServiceTypeInternet                        → Mobile Data 蜂窝数据
    /// kCTDataConnectionServiceTypeUT                              → Telephony Services (UT) 电话服务 呼叫转移等
    /// kCTDataConnectionServiceTypeIMS                             → IMS (VoLTE/VoNR)
    /// kCTDataConnectionServiceTypeMMS                             → MMS 彩信
    /// kCTDataConnectionServiceTypeWirelessModemTraffic            → 个人热点
    /// kCTDataConnectionServiceTypeEntitlementTraffic              → Carrier Services
    /// kCTDataConnectionServiceTypeVVM                             → Voicemail (VVM)
    /// kCTDataConnectionServiceTypeWirelessModemAuthentication     → Modem Authentication
    /// kCTDataConnectionServiceTypeCellularDataPlanProvisioning    → Data Plan Provisioning
    /// kCTDataConnectionServiceTypeCellularDataPlanProvisioning2   → Data Plan Provisioning (Secondary)
    /// kCTDataConnectionServiceTypeAppleWirelessDiagnostics        → Diagnostics
    /// kCTDataConnectionServiceTypeDataTest                        → Network Test
    /// kCTDataConnectionServiceTypeOTAActivation                   → OTA Activation
    /// kCTDataConnectionServiceType3GFaceTimeTraffic               → FaceTime (3G)
    /// kCTDataConnectionServiceType3GFaceTimeAuthentication        → FaceTime Authentication
    /// kCTDataConnectionServiceTypeOMADM                           → Device Management (OMA-DM)
    /// kCTDataConnectionServiceTypeOTAInternet                     → OTA Internet
    /// kCTDataConnectionServiceTypeZeroRated                       → Zero-Rated Data
    /// kCTDataConnectionServiceTypeInternalDataProbe               → Internal Probe
    /// kCTDataConnectionServiceTypeEm                              → Engineering Mode
    /// kCTDataConnectionServiceTypeEmergencyLocation               → Emergency Services
    /// kCTDataConnectionServiceTypeBootstrapProvisioning           → Bootstrap Provisioning
    /// kCTDataConnectionServiceTypeBootstrapRoamingInternetBypass  → Roaming Bypass
    /// kCTDataConnectionServiceTypeCarrierSpace                    → Carrier Space
    /// kCTDataConnectionServiceTypeInternetProbe                   → Connectivity Check
    /// kCTDataConnectionServiceTypeThumborIMS                      → IMS Media
    /// kCTDataConnectionServiceTypeLLWirelessModemTraffic          → Low-Level Modem Traffic
    /// 无权限设备可返回正确数据
    func getSlotActiveConnections(context: CTXPCServiceSubscriptionContext) throws -> [String] {
        return try coreTelephonyClient.getActiveConnections(context)
    }
    
    /// 获取设备是否支持高级数据通道调度能力
    /// *需要更多数据*
    /// 无权限时抛异常 错误代码 1
    @available(iOS 15.0, *)
    func getDeviceSupportsHydra() throws -> Bool {
        return try coreTelephonyClient.supportsHydra().boolValue
    }
    
    /// 获取卡槽的网络类型选择的状态实例
    /// 低版本兼容方案：getRatSelection
    @available(iOS 14.0, *)
    func getSlotRatSelectionInfo(descriptor: CTServiceDescriptor) throws -> CTRatSelection? {
        return try coreTelephonyClient.getRatSelectionMask(descriptor)
    }
    
    /// 获取卡槽的网络类型选择的状态实例
    /// 低版本兼容方法
    /// iOS 14以上请使用getRatSelectionMask
    /// iOS 14以下 无权限调用很卡 有权限设备正常
    func getSlotRatSelection(context: CTXPCServiceSubscriptionContext, timeout: TimeInterval = 3) throws -> RatSelection? {
        
        let sema = DispatchSemaphore(value: 0)
        var result: RatSelection?
        
        coreTelephonyClient.getRatSelection(context) { currentSelection, preferredSelection, error in
            if let selection = currentSelection, let preferred = preferredSelection {
                result = RatSelection(selection: selection, preferred: preferred)
                sema.signal()
            }
            
        }
        
        let waitResult = sema.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            return nil
        }
        
        return result
        
    }
    
    /// 设置网络类型选择
    /// 可以锁定网络
    /// 低版本兼容方案：setRatSelection
    /// selection, preferred已知key:
    /// kCTRegistrationRATSelectionAutomatic
    /// kCTRegistrationRATSelectionDual
    /// kCTRegistrationRATSelectionUnknown
    ///
    /// kCTRegistrationRATSelectionNR
    /// kCTRegistrationRATSelectionNRNonStandAlone
    /// kCTRegistrationRATSelectionNRStandAlone
    ///
    /// kCTRegistrationRATSelectionLTE
    ///
    /// kCTRegistrationRATSelectionGSM
    /// kCTRegistrationRATSelectionUMTS
    /// kCTRegistrationRATSelectionTDSCDMA
    ///
    /// kCTRegistrationRATSelectionCDMA1x
    /// kCTRegistrationRATSelectionCDMA1xEVDO
    /// kCTRegistrationRATSelectionCDMAHybrid
    ///
    /// kCTRegistrationRATSelection12
    /// kCTRegistrationRATSelection13
    /// KCTRegistrationRATSelection14
    @available(iOS 15.0, *)
    func setSlotRatSelection(descriptor: CTServiceDescriptor, selection: String, preferred: String) throws -> Bool {
        if let error = coreTelephonyClient.setRatSelectionMask(descriptor, selection: selection, preferred: preferred) {
            if let nsError = error as? NSError {
                throw nsError
            } else {
                throw NSError(domain: "CoreTelephonyControllerError",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "\(error)"]
                )
            }
        } else {
            return true
        }
    }
    
    /// 设置网络类型选择
    /// 低版本兼容方案
    func setSlotRatSelection(context: CTXPCServiceSubscriptionContext, selection: String, preferred: String, timeout: TimeInterval = 3) throws -> Bool {
        
        let sema = DispatchSemaphore(value: 0)
        var finalError: Error?
        var result = false
        
        coreTelephonyClient.setRatSelection(context, selection: selection, preferred: preferred) { error in
            
            if let error = error {
                finalError = error
            } else {
                result = true
            }
            
            sema.signal()
        }
        
        // 等待
        let waitResult = sema.wait(timeout: .now() + timeout)
        
        // 等待超时抛异常
        if waitResult == .timedOut {
            throw CarrierBundleError.timeout
        }
        
        // 如果有错误就抛异常
        if let error = finalError {
            throw error
        }
        
        return result
    }
    
    /// 获取调制解调器固件版本
    func getDeviceModemFirmwareVersion() throws -> String? {
        
        var unmanaged: Unmanaged<CFString>?
        
        // 发送XPC指令查询基带版本号
        let result = _CTServerConnectionCopyFirmwareVersion(connection, &unmanaged)
        
        guard result == 0, let unmanaged else {
            throw CarrierBundleError.operationFailed
        }
        
        let version = unmanaged.takeRetainedValue() as String
        
        return version
    }
    
    /// 刷新蜂窝网络信号
    /// 无权限设备会被CommCenter抛弃请求
    func refreshCellularConnection() {
        // 设置原因
        let reason = "UserTriggeredReload" as CFString
        // 发送请求
        _CTServerConnectionResetModem(connection, reason)
    }
    
    /// 获取蜂窝数据是否开启
    /// 无需额外权利
    func getCellularDataEnabled() throws -> Bool {
        var enabled: UInt8 = 0
        let ret = _CTServerConnectionGetCellularDataIsEnabled(connection, &enabled)
        if ret != 0 {
            throw CoreTelephonyConnectionError.apiFailed(code: ret)
        }
        return (enabled != 0)
    }
    
    /// 设置蜂窝数据是否开启
    func setCellularDataEnabled(enable: Bool) throws {
        let raw: UInt8 = enable ? 1 : 0
        let ret = _CTServerConnectionSetCellularDataIsEnabled(connection, raw)
        if ret != 0 {
            throw CoreTelephonyConnectionError.apiFailed(code: ret)
        }
    }
    
    /// TODO 获取网络时间
    /// 获取数据无效
    /// 返回1
    func fetchNetworkTime(requestType: Int32 = 2) throws -> Int32 {
        var result: Int32 = 0
        let ret = _CTServerConnectionFetchTimeFromNetwork(connection, requestType, &result)
        if ret != 0 {
            throw CoreTelephonyConnectionError.apiFailed(code: ret)
        }
        return result
    }

    /// TODO 获取基带温度
    /// 返回0 数据无效
    func fetchTemperature(sensorType: Int32) throws -> (valid: Bool, value1: Int32, value2: Int32) {
        
        var valid: UInt8 = 0
        var value1: Int32 = 0
        var value2: Int32 = 0
        
        let ret = _CTServerConnectionGetTemperature(
            connection,
            sensorType,
            &valid,
            &value1,
            &value2
        )
        
        if ret != 0 {
            throw CoreTelephonyConnectionError.apiFailed(code: ret)
        }
        
        return (valid != 0, value1, value2)
    }
    
    /// 重置SIM卡状态
    /// 日志报错 #N no controller to send debug sim reset
    /// TODO 无效
    func resetSIMStatus() throws -> Bool {
        // 创建连接
        guard let conn = _CTServerConnectionCreate(kCFAllocatorDefault, nil, nil) else {
            throw CarrierBundleError.connectionFailed
        }
        
        // 调用底层API
        let result = _CTServerConnectionDebugResetSim(conn)
        
        // 判断返回值
        return result != 0
    }
    
    /// 重置IPCC为系统出厂版本
    /// 需要 preferences-reset 权利
    /// 返回是否成功
    /// iOS 15以下不支持，已改进通过删除Carrier Bundle目录的方法来实现
    @available(iOS 15.0, *)
    func restoreCarrierBundle() -> Bool {
        return coreTelephonyClient.restore(toSystemBundles: nil) // 参数是Int指针，不管成功还是失败都是返回0
    }
    
    /// TODO 暂时不知道做什么的
    /// 返回值 0
    /// 无权限设备抛异常 错误代码 13
    @available(iOS 15.0, *)
    func getSlotGSMAUIControlSetting(context: CTXPCServiceSubscriptionContext) throws -> UInt64 {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = coreTelephonyClient.getGSMAUIControlSetting(context, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }
    
    /// TODO 暂时不知道做什么的
    /// 不管参数是true还是false都返回nil
    @available(iOS 15.0, *)
    func loadGSMASettings(context: CTXPCServiceSubscriptionContext, state: Bool) -> String {
        return String(describing: coreTelephonyClient.loadGSMASettings(context, state: state))
    }
    
    /// TODO 暂时不知道做什么的
    /// 返回错误 Error Domain=NSPOSIXErrorDomain Code=45 "Operation not supported"
    func getSlotEncryptionStatus(descriptor: CTServiceDescriptor) -> String {
        return String(describing: coreTelephonyClient.getEncryptionStatus(descriptor, error: nil))
    }
    
    /// TODO 暂时不知道做什么的
    /// 需要额外权利 data-allowed
    @available(iOS 15.0, *)
    func getLocalPolicies(policies: [String]) throws -> Any? {
        return try coreTelephonyClient.getLocalPolicies(policies)
    }
    
    /// TODO 暂时不知道做什么的
    @available(iOS 13.0, *)
    func getSlotPseudoIdentity(context: CTXPCServiceSubscriptionContext) -> String? {
        return String(describing: coreTelephonyClient.context(context, getPseudoIdentityFor: "SubscriberIdentity", error: nil))
    }
    
    /// TODO 不知道有什么用
    /// 不管参数是true还是false都返回0
    @available(iOS 16.0, *)
    func fetchBasebandTicket(arg1: Bool) throws -> String {
        return String(describing: try coreTelephonyClient.fetchBasebandTicket(arg1))
    }
    
}
