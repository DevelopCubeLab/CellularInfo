import Foundation
import UIKit

class MGDeviceInfoController {
    
    // 单例对象
    static let instance = MGDeviceInfoController()
    
    /// 私有构造方法
    private init() {
        //
    }
    
    /// 查询 MobileGestalt key 通用入口
    private func queryMG(_ key: String) -> Any? {
        guard let u = MGCopyAnswer(key as CFString) else {
            NSLog("[MGDeviceInfoController] key=%@ → nil", key)
            return nil
        }
        return u.takeRetainedValue()
    }
    
    func queryMGString(_ key: String) -> String? {
        return queryMG(key) as? String
    }
    
    /// 获取 IMEI 1
    func getIMEI1() -> String? {
        return queryMGString("InternationalMobileEquipmentIdentity")
    }
    
    /// 获取 IMEI 2
    func getIMEI2() -> String? {
        return queryMGString("InternationalMobileEquipmentIdentity2")
    }
    
    /// 获取MEID
    func getMEID() -> String? {
        return queryMGString("MobileEquipmentIdentifier")
    }
    
    /// 获取 EID
    func getEID() -> String? {
        return queryMGString("MobileEquipmentInfoDisplayCSN")
    }
    
    /// 获取基带UID
    /// 基带芯片组的唯一标识符
    func getBasebandUniqueId() -> String? {
        return queryMGString("BasebandUniqueId")
    }
    
    /// 判断是否有IMEI
    func haveIMEI() -> Bool {
        if getIMEI1() == nil && getIMEI2() == nil {
            return false
        }
        return true
    }
    
    /// 获取IMEI的数量
    func getIMEICount() -> Int {
        var count = 0
        if getIMEI1() != nil {
            count += 1
        }
        if getIMEI2() != nil {
            count += 1
        }
        return count
    }
}
