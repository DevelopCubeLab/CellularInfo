import Foundation
import UIKit

/// IPCC文件兼容性检查结果
struct IPCCFileCompatibilityCheckResult {
    let carrierBundleInfo: CarrierBundleInfo
    let issues: Set<IPCCIssue>
}

/// IPCC文件兼容性问题集合
enum IPCCIssue: Hashable {
    case deviceNotSupported
    case belowSystemVersion
    case versionDowngrade
    case duplicateInstall
    case installPathLocked
}

// 安装结果枚举
enum IPCCInstallResult {
    case success(carrierName: String, version: String)                            // 成功（数量增加）
    case invalidBundle(carrierName: String, version: String)                      // 非法IPCC（数量减少）
    case failed                                                                   // 安装失败（无变化且未匹配）
    case upgradedFailed(carrierName: String, install: String, current: String)    // 升级
    case upgraded(carrierName: String, old: String, new: String)                  // 升级
    case downgraded(carrierName: String, old: String, new: String)                // 降级
    case sameVersion(carrierName: String, version: String)                        // 相同版本（重复）
    case pathLocked(lockedPath: [String])                                         // 安装失败 目录被锁定
    case permissionDenied                                                         // 无写入权限
}
