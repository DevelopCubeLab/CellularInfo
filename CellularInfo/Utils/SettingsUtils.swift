import Foundation
import UIKit

class SettingsUtils {
    
    // 单例实例
    static let instance = SettingsUtils()
    
    // 私有的 PlistManagerUtils 实例，用于管理特定的 plist 文件
    private let plistManager: PlistManagerUtils
    
    private enum SettingItem {
        
        case applicationLanguage
        case autoRefreshData
        case timedRefreshData
        case showScreenshotCaptureAlert
        case experimentalFeatures
        case showCellularDataInGroups
        case showInactiveSIMSlotsData
        case hideNoPermissionData
        case forceShowLTEAs4G
        case showInstallIPCCTips
        case enableCheckCarrierBundleCompatibility
        case copyActivationTicketTips
        case lockNetworkModeStatus
        case lockNetworkModeEntryTips
        case lockNetworkModeAlert
        
        var key: String {
            switch self {
            case .applicationLanguage: return "ApplicationLanguage"
            case .autoRefreshData: return "AutoRefreshData"
            case .timedRefreshData: return "TimedRefreshData"
            case .showScreenshotCaptureAlert: return "ShowScreenshotCaptureAlert"
            case .experimentalFeatures: return "ExperimentalFeatures"
            case .showCellularDataInGroups: return "ShowCellularDataInGroups"
            case .showInactiveSIMSlotsData: return "ShowInactiveSIMSlotsData"
            case .hideNoPermissionData: return "HideNoPermissionData"
            case .forceShowLTEAs4G: return "ForceShowLTEAs4G"
            case .showInstallIPCCTips: return "ShowInstallIPCCTips"
            case .enableCheckCarrierBundleCompatibility: return "EnableCheckCarrierBundleCompatibility"
            case .copyActivationTicketTips: return "CopyActivationTicketTips"
            case .lockNetworkModeStatus: return "LockNetworkModeStatus"
            case .lockNetworkModeEntryTips: return "LockNetworkModeEntryTips"
            case .lockNetworkModeAlert: return "LockNetworkModeAlert"
            }
        }
    }
    
    // 语言设置
    enum ApplicationLanguage: Int {
        case System = 0             // 跟随系统
        case English = 1            // English
        case SimplifiedChinese = 2  // 简体中文
        case Spanish = 3            // Spanish
    }
    
    private init() {
        // 初始化
        self.plistManager = PlistManagerUtils.instance(for: "CellularInfoSettings") // 这里需要单独的名称，解决iOS 14以下的沙盒问题
    }
    
    private func setDefaultSettings() {
        
        if self.plistManager.isPlistExist() {
            return
        }
        
    }
    
    /// 获取App语言设置
    func getApplicationLanguage() -> ApplicationLanguage {
        let value = plistManager.getInt(key: SettingItem.applicationLanguage.key, defaultValue: ApplicationLanguage.System.rawValue)
        return ApplicationLanguage(rawValue: value) ?? ApplicationLanguage.System
    }

    /// 设置App语言设置
    func setApplicationLanguage(value: ApplicationLanguage) {
        setApplicationLanguage(value: value.rawValue)
    }

    /// 设置App语言设置
    func setApplicationLanguage(value: Int) {
        plistManager.setInt(key: SettingItem.applicationLanguage.key, value: value)
        plistManager.apply()
    }
    
    /// 获取App icon
    func getApplicationIconName() -> String? {
        
        /// iOS 26如果证书签名安装 描述文件的Bundle ID和App实际运行Bundle ID不一致的话没办法读取App Icon
        /// 会一直返回nil 所以需要保存一下
        if #available(iOS 26.0, *) {
            let value = plistManager.getString(key: "ApplicationIconName", defaultValue: "")
            return value.isEmpty ? nil : value
        
        }
        return UIApplication.shared.alternateIconName
    }
    
    /// 设置App icon
    func setApplicationIconName(iconName: String?, completion: ((Error?) -> Void)? = nil) {
        // 设置icon
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                /// iOS 18设备如果证书签名安装 描述文件的Bundle ID和App实际运行Bundle ID不一致的话没办法切换App Icon
                /// 错误代码 -54
                completion?(error)
                return
            }
            // 只有成功后才记录状态
            // 因为iOS 26如果证书签名安装 描述文件的Bundle ID和App实际运行Bundle ID不一致的话没办法读取App Icon
            if #available(iOS 26.0, *) {
                if let iconName = iconName { // 设置备用图标
                    self.plistManager.setString(key: "ApplicationIconName", value: iconName)
                } else { // 设置默认图标 直接删除这个key
                    self.plistManager.remove(key: "ApplicationIconName")
                }
                self.plistManager.apply()
            }
            
            completion?(nil)
        }
    }
    
    /// 获取是否自动刷新数据
    func getAutoRefreshData() -> Bool {
        return plistManager.getBool(key: SettingItem.autoRefreshData.key, defaultValue: true)
    }
    
    func setAutoRefreshData(enable: Bool) {
        plistManager.setBool(key: SettingItem.autoRefreshData.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否定时刷新数据
    func getTimedRefreshData() -> Bool {
        return plistManager.getBool(key: SettingItem.timedRefreshData.key, defaultValue: true)
    }
    
    func setTimedRefreshData(enable: Bool) {
        plistManager.setBool(key: SettingItem.timedRefreshData.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否在截图或录屏后发出警告
    func getShowScreenshotCaptureAlert() -> Bool {
        return plistManager.getBool(key: SettingItem.showScreenshotCaptureAlert.key, defaultValue: true)
    }
    
    func setShowScreenshotCaptureAlert(enable: Bool) {
        plistManager.setBool(key: SettingItem.showScreenshotCaptureAlert.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否开启实验性功能
    func getEnableExperimentalFeatures() -> Bool {
        return plistManager.getBool(key: SettingItem.experimentalFeatures.key, defaultValue: false)
    }
    
    func setEnableExperimentalFeatures(enable: Bool) {
        plistManager.setBool(key: SettingItem.experimentalFeatures.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否分组显示蜂窝网络数据
    func getShowCellularDataInGroups() -> Bool {
        return plistManager.getBool(key: SettingItem.showCellularDataInGroups.key, defaultValue: true)
    }
    
    func setShowCellularDataInGroups(enable: Bool) {
        plistManager.setBool(key: SettingItem.showCellularDataInGroups.key, value: enable)
        plistManager.apply()
    }
    
    /// 显示显示未使用卡槽(未启用/无SIM卡)的数据
    func getShowInactiveSIMSlotsData() -> Bool {
        return plistManager.getBool(key: SettingItem.showInactiveSIMSlotsData.key, defaultValue: false)
    }
    
    func setShowInactiveSIMSlotsData(enable: Bool) {
        plistManager.setBool(key: SettingItem.showInactiveSIMSlotsData.key, value: enable)
        plistManager.apply()
    }
    
    /// 隐藏无权限数据
    /// 给证书签名和无权限设备准备的
    func getHideNoPermissionData() -> Bool {
        return plistManager.getBool(key: SettingItem.hideNoPermissionData.key, defaultValue: false)
    }
    
    func setHideNoPermissionData(enable: Bool) {
        plistManager.setBool(key: SettingItem.hideNoPermissionData.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否强行显示LTE为4G
    func getForceShowLTEAs4G() -> Bool {
        return plistManager.getBool(key: SettingItem.forceShowLTEAs4G.key, defaultValue: false)
    }
    
    func setForceShowLTEAs4G(enable: Bool) {
        plistManager.setBool(key: SettingItem.forceShowLTEAs4G.key, value: enable)
        plistManager.apply()
    }
    
    /// 显示安装IPCC前的提示
    func getShowInstallIPCCTips() -> Bool {
        return plistManager.getBool(key: SettingItem.showInstallIPCCTips.key, defaultValue: true)
    }
    
    func setShowInstallIPCCTips(enable: Bool) {
        plistManager.setBool(key: SettingItem.showInstallIPCCTips.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否在安装IPCC之前检查IPCC的兼容性
    func getEnableCheckCarrierBundleCompatibility() -> Bool {
        return plistManager.getBool(key: SettingItem.enableCheckCarrierBundleCompatibility.key, defaultValue: true)
    }
    
    func setEnableCheckCarrierBundleCompatibility(enable: Bool) {
        plistManager.setBool(key: SettingItem.enableCheckCarrierBundleCompatibility.key, value: enable)
        plistManager.apply()
    }
    
    /// 显示安装IPCC前的提示
    func getShowCopyActivationTicketTips() -> Bool {
        return plistManager.getBool(key: SettingItem.copyActivationTicketTips.key, defaultValue: true)
    }
    
    func setShowCopyActivationTicketTipsTips(enable: Bool) {
        plistManager.setBool(key: SettingItem.copyActivationTicketTips.key, value: enable)
        plistManager.apply()
    }
    
    /// 获取是否显示锁定网络类型
    func getShowLockNetworkMode() -> Bool {
        // 必须开启实验性功能
        return getEnableExperimentalFeatures() && (plistManager.getInt(key: SettingItem.lockNetworkModeStatus.key, defaultValue: 0) >= 3)
    }
    
    /// 设定锁定网络类型是否显示
    /// 必须开启实验性功能
    func setShowLockNetworkMode(status: Bool) {
        if status && getEnableExperimentalFeatures() {
            // 获取当前次数
            var value = plistManager.getInt(key: SettingItem.lockNetworkModeStatus.key, defaultValue: 0)
            if value < 8 { // 7次就是永久开启
                value = value + 1
                plistManager.setInt(key: SettingItem.lockNetworkModeStatus.key, value: value)
            }
            
        } else {
            plistManager.remove(key: SettingItem.lockNetworkModeStatus.key)
            plistManager.remove(key: SettingItem.lockNetworkModeEntryTips.key)
        }
        plistManager.apply()
    }
    
    /// 启动app时检查是否显示锁定网络类型
    func checkShowLockNetworkMode() {
        let value = plistManager.getInt(key: SettingItem.lockNetworkModeStatus.key, defaultValue: 0)
        if value < 7 || !getEnableExperimentalFeatures() { // 如果不是永久开启就直接清零 相当于临时开启 并且需要开启实验性功能
            plistManager.remove(key: SettingItem.lockNetworkModeStatus.key)
        }
        if value < 0 || value >= 9 { // 这肯定是用户瞎改的 惩罚下 清零 doge
            plistManager.remove(key: SettingItem.lockNetworkModeStatus.key)
        }
        plistManager.apply()
    }
    
    /// 获取进入设定网络类型界面提示显示的次数
    func getShowLockNetworkModeEntryTipsCount() -> Int {
        var count =  plistManager.getInt(key: SettingItem.lockNetworkModeEntryTips.key, defaultValue: 0)
        if count > -1 && count <= 20 {
            count = count + 1
            plistManager.setInt(key: SettingItem.lockNetworkModeEntryTips.key, value: count)
            plistManager.apply()
        }
        return count
    }
    
    /// 获取是否显示进入设定网络类型界面提示
    func getShowLockNetworkModeEntryTips() -> Bool {
        return getShowLockNetworkModeEntryTipsCount() != -1
    }
    
    /// 获取是否允许不再提示进入设置网络类型的提示弹窗
    func getAllowSetNotShowLockNetworkModeEntryTips() -> Bool {
        return getShowLockNetworkModeEntryTipsCount() >= 10
    }
    
    /// 设置不再显示进入设置网络类型的提示弹窗
    func setNotShowLockNetworkModeEntryTips() {
        if getAllowSetNotShowLockNetworkModeEntryTips() {
            plistManager.setInt(key: SettingItem.lockNetworkModeEntryTips.key, value: -1)
            plistManager.apply()
        }
    }
    
    /// 获取设定网络时是否弹出提示
    func getShowSetLockNetworkModeAlertCount() -> Int {
        var count =  plistManager.getInt(key: SettingItem.lockNetworkModeAlert.key, defaultValue: 0)
        if count > -1 && count <= 12 {
            count = count + 1
            plistManager.setInt(key: SettingItem.lockNetworkModeAlert.key, value: count)
            plistManager.apply()
        }
        return count
    }
    
    /// 获取是否显示设定网络时弹出提示
    func getShowSetLockNetworkModeAlert() -> Bool {
        return getShowSetLockNetworkModeAlertCount() != -1
    }
    
    /// 获取是否允许不再提示设定网络时弹出提示
    func getAllowSetNotShowLockNetworkModeAlert() -> Bool {
        return getShowSetLockNetworkModeAlertCount() >= 6
    }
    
    /// 设置不再显示设定网络时弹出的提示
    func setNotShowLockNetworkModeAlert() {
        if getAllowSetNotShowLockNetworkModeAlert() {
            plistManager.setInt(key: SettingItem.lockNetworkModeAlert.key, value: -1)
            plistManager.apply()
        }
    }
    
    /// 重设全部警告
    func resetAllWarning() {
        // 重新显示安装IPCC前的提示
        plistManager.remove(key: SettingItem.showInstallIPCCTips.key)
        plistManager.remove(key: SettingItem.copyActivationTicketTips.key)
        plistManager.remove(key: SettingItem.lockNetworkModeStatus.key)
        plistManager.remove(key: SettingItem.lockNetworkModeEntryTips.key)
        plistManager.remove(key: SettingItem.lockNetworkModeAlert.key)
        plistManager.apply()
    }
}
