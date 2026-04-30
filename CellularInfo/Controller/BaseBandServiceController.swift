import Foundation
import UIKit

class BaseBandServiceController {

    enum RootCommand {
        case carrierLock
        case getTicket
        case setTicket(String)
        case restartCommCenter
        case rebootDevice
        case status
        
        var arguments: [String] {
            switch self {
            case .status:
                return ["status"]
            case .carrierLock:
                return ["carrierLock"]
            case .getTicket:
                return ["getTicket"]
            case .setTicket(let ticket):
                return ["setTicket", ticket]
            case .restartCommCenter:
                return ["restartCommCenter"]
            case .rebootDevice:
                return ["reboot"]
            }
        }
    }
    
    @discardableResult
    private static func runRootCommand(_ command: RootCommand) throws -> String {
        let helperPath: String
        
        if #available(iOS 14.0, *) {
            // iOS 14+：使用App Bundle内的RootHelper
            guard let path = Bundle.main.path(forResource: "CellularInfoRootHelper", ofType: nil) else {
                throw NSError(domain: "RootHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "RootHelper not found"])
            }
            helperPath = path
        } else {
            // iOS 13及以下：使用系统路径
            helperPath = "/usr/local/bin/CellularInfoRootHelper"
            // 判断是否有RootHelper
            if !FileManager.default.fileExists(atPath: helperPath) {
                throw NSError(domain: "RootHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "RootHelper not found"])
            }
        }
        
        var out: NSString?
        var err: NSString?
        
        let code = spawnRoot(helperPath,
                             command.arguments,
                             &out,
                             &err)
        
        if code != 0 {
            let errorMessage = (err as String?) ?? "Unknown error"
            throw NSError(domain: "RootHelper", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        return (out as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 重启设备
    static func rebootDevice() throws {
        try runRootCommand(.rebootDevice)
    }
    
    /// 重启基带服务 CommCenter
    static func restartCommCenterService() throws -> Bool {
        let result = try runRootCommand(.restartCommCenter)
        return result.contains("Killed")
    }

    /// 获取设备是否有锁
    /// 主要为iOS 14以下设备准备的
    /// 原始值 Locked / Unlock
    /// 返回值 true  = 有锁
    /// 返回值 false = 无锁
    static func getDeviceCarrierLockState() throws -> Bool {
        let locked = try runRootCommand(.carrierLock)
        return locked.contains("Locked")
    }
    
    /// 获取设备基带激活信息
    /// 返回String
    /// 与设备IMEI等绑定，一机器一码 不能混用
    static func getBaseBandActivationTicket() throws -> String {
        return try runRootCommand(.getTicket)
    }
    
    /// 设置设备基带激活信息
    static func setBaseBandActivationTicket(ticket: String) throws -> Bool {
        // 拒绝空字符串和不符合要求的
        if ticket.isEmpty || !isLikelyActivationTicket(ticket) {
            return false
        }
        // 发送请求并获取结果
        let result = try runRootCommand(.setTicket(ticket))
        // 返回结果
        return result.contains("Saved")
    }
    
    static func isLikelyActivationTicket(_ text: String) -> Bool {
        
        // Step 1: 输入规范化
        // 去除换行符和首尾空白，处理从剪贴板粘贴时可能带来的格式问题
        let cleaned = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 2: 长度校验
        // 激活票据通常较长（数百到数千字符）
        // 过滤明显异常的输入（过短或过长）
        guard cleaned.count > 100 else { return false }
        guard cleaned.count < 5000 else { return false }
        
        // Step 3: Base64 字符集校验
        // 确保字符串仅包含 Base64 合法字符
        // 可过滤 URL、JSON、普通文本等无效输入
        let base64Regex = "^[A-Za-z0-9+/=]+$"
        guard cleaned.range(of: base64Regex, options: .regularExpression) != nil else {
            return false
        }
        
        // Step 4: Base64 解码校验
        // 合法的激活票据必须可以成功进行 Base64 解码
        // 如果解码失败，则基本可以判定为无效数据
        guard let data = Data(base64Encoded: cleaned) else {
            return false
        }
        
        // Step 5: 前缀特征判断（启发式规则）
        // 大多数激活票据为 ASN.1 / DER 编码，Base64 后通常以 "MIIB"、"MIIC" 等开头
        // 该规则为辅助判断，不作为强制条件，避免误伤有效数据
        let prefix = cleaned.prefix(4)
        let validPrefixes = ["MIIB", "MIIC", "MIID", "MIIE"]
        
        let hasValidPrefix = validPrefixes.contains { prefix.hasPrefix($0) }
        
        // 若匹配常见前缀，可直接认为是高可信的激活票据
        if hasValidPrefix {
            return true
        }
        
        // Step 6: 兜底判断
        // 若 Base64 解码成功且二进制数据长度合理，则认为是潜在有效数据
        return data.count > 100
    }
}
