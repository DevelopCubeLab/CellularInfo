import Foundation
import UIKit

class AppCapability {
    
    /// 检查当前的安装环境是否有SPI权利
    static func hasCommCenterSPI() -> Bool {
        return EntitlementUtils.exists(["com.apple.CommCenter.fine-grained" , "spi"])
    }
    
    /// 检查当前安装环境是否有重置IPCC的权利
    static func hasCommCenterPreferencesReset() -> Bool {
        return EntitlementUtils.exists(["com.apple.CommCenter.fine-grained" , "preferences-reset"])
    }
    
    /// 检查当前安装环境是否有允许检测安装eSIM权限
    static func hasCommCenterPublicCellularPlan() -> Bool {
        return EntitlementUtils.exists(["com.apple.CommCenter.fine-grained" , "public-cellular-plan"])
    }
    
    // 检查UnSandbox权限的方法
    static func checkCarrierBundleReadPermission() -> Bool {
        let path = "/var/mobile/Library/Carrier Bundles"
        let writeable = access(path, R_OK) == 0
        return writeable
    }
    
    // 检查UnSandbox权限的方法
    static func checkUnSandboxPermission() -> Bool {
        let path = "/var/mobile/Library/Preferences"
        let writeable = access(path, W_OK) == 0
        return writeable
    }
}
