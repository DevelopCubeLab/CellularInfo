import Foundation
import UIKit

/// 公开的蜂窝网络框架
/// @See https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo
class CoreTelephonyNetworkInfoController {
    
    // 单例实例
    static let instance = CoreTelephonyNetworkInfoController()
    
    // CTTelephonyNetworkInfo 的实例
    private let coreTelephonyNetworkInfo: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
    
    /// 私有构造方法
    private init() {
        //
    }
    
    /// 获取卡槽的 CTServiceDescriptor 实例列表
    /// 无需额外权利
    /// 无权限设备仍能正确返回数据
    /// 模拟器返回nil
    func getSlotDescriptors() -> [CTServiceDescriptor] {
        if let descriptors = coreTelephonyNetworkInfo.descriptors {
            return descriptors.descriptors
        }
        return []
    }
    
    /// 无需额外权利的方法获取卡槽数量
    /// 无权限设备可以获取正确的数据
    /// 模拟器返回0 因为没有基带模块
    func getDeviceSlotCount() -> Int {
        return getSlotDescriptors().count
    }
    /// 获取设备卡槽的网络类型
    /// 官方文档 @See https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology
    /// 返回值 官方文档 @See https://developer.apple.com/documentation/coretelephony/radio-access-technology-constants
    func getRadioAccessTechnology() -> [String] {
        if let slots = coreTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology {
            // 按 key 排序（保证 slot 顺序稳定）
            let sortedKeys = slots.keys.sorted()
                
            // 按顺序取值
            return sortedKeys.compactMap { slots[$0] }
        } else {
            return []
        }
    }
    
    /// 公开方法获取卡槽连接的网络类型
    func getSlotRadioAccessTechnology(slotID: Int) -> String? {
        let list = getRadioAccessTechnology()
        let index = slotID - 1
        
        if index >= 0 && index < list.count {
            return list[index]
        } else {
            return nil
        }
    }
    
    /// 公开方法获取卡槽连接的网络类型的枚举
    func getSlotRadioAccessTechnologyEnum(slotID: Int) -> CoreTelephonyEnumMapper.RadioAccessTechnology {
        if let technology = getSlotRadioAccessTechnology(slotID: slotID) {
            return CoreTelephonyEnumMapper.mapCTRadioAccessTechnology(technology)
        } else {
            return CoreTelephonyEnumMapper.RadioAccessTechnology.NO_SERVICE
        }
    }
    
    /// 获取设备当前NR的频率范围
    /// 返回值 CTNrFrequencyRangeSub6          = Sub6
    /// 返回值 CTNrFrequencyRangeMmWave        = 毫米波
    /// 返回值 CTNrFrequencyRangeSub6AndMmWave = Sub 6+ 毫米波
    /// 返回值 CTNrFrequencyRangeUnknown       = 未知
    @available(iOS 15.0, *)
    func getDeviceNrFrequencyRange() -> String {
        
        // 初始化
        coreTelephonyNetworkInfo.tryInitNrFrequencyRange()
        
        // 触发查询
        if !coreTelephonyNetworkInfo.nrFrequencyRangeInitialized {
            coreTelephonyNetworkInfo.queryNrFrequencyRange()
        }
        
        // 读取数据
        if let range = coreTelephonyNetworkInfo.currentNrFrequencyRange() {
            return range
        }
        
        return "CTNrFrequencyRangeUnknown"
    }
}
