import Foundation

/// 表示单个 APN（接入点）配置的数据模型
/// 数据来源于 CoreTelephony 私有接口，部分字段为推测含义
struct CellularAPN {
    
    /// 接入点名称（Access Point Name）
    /// 用于标识数据网络接入入口，例如：internet / ims / cmnet 等
    let apn: String?
    
    /// 用户名（PPP / PAP / CHAP 认证）
    /// 某些运营商需要，通常为空
    let username: String?
    
    /// 密码（PPP / PAP / CHAP 认证）
    /// 与用户名配合使用，通常为空
    let password: String?
    
    
    // MARK: - 网络能力与类型
    
    /// APN 类型掩码（Type Mask）
    /// Int 类型
    /// 表示该 APN 支持的业务类型，通常为位掩码
    /// 常见类型包括：
    /// - 1 = default：默认数据
    /// - 2 = supl: 辅助定位
    /// - 4 = mms：彩信
    /// - 8 = dun：热点共享
    /// - 131072 = ims：IMS（VoLTE / VoNR）
    /// - 262144 = sos: 紧急呼叫
    let typeMask: Int?
    
    /// 技术掩码（Technology Mask）
    /// 表示该 APN 支持的无线接入技术（RAT）
    /// 可能涉及 LTE / NR / 3G 等，具体含义未公开
    let technologyMask: Int?
    
    /// APN 协议（Allowed Protocol Mask）
    /// 指定数据连接使用的 IP 协议类型：
    /// - IPv4   = 1
    /// - IPv6   = 2
    /// - IPv4v6 = 3
    let allowedProtocolMask: Int?
    
    /// 漫游协议（Roaming Protocol Mask）
    /// 在漫游网络下使用的 IP 协议配置
    /// - IPv4   = 1
    /// - IPv6   = 2
    /// - IPv4v6 = 3
    let roamingProtocolMask: Int?
    
    
    // MARK: - 连接行为控制
    
    /// 是否保持常驻连接（Always On PDU）
    /// 常用于 IMS 或 5G SA 场景，保持数据承载持续激活
    let alwaysOn: Int?
    
    /// 空闲断开定时器（Inactivity Timer）
    /// 指定在无数据传输时，连接保持多久后断开
    let inactivityTimer: Int?
    
    /// 是否使用网络下发的 MTU（Use Network MTU）
    /// 控制终端是否采用运营商配置的最大传输单元
    /// 0 = 使用系统默认 MTU
    /// 1 = 使用运营商下发 MTU
    let useNetworkMTU: Int?
    
    
    // MARK: - 高级 / 5G 相关能力
    
    /// 是否启用 464XLAT（IPv4 over IPv6）
    /// 用于 IPv6-only 网络下兼容 IPv4 服务（NAT64 场景）
    /// 0 = 不开启
    /// 1 = 开启
    let xlat464: Int?
    
    /// 是否支持 5G SA 切换（Support 5G SA Handover）
    /// 表示在 5G 独立组网环境中的切换能力
    let support5GSaHandover: Int?
    
    /// 切换能力（Support Switch Over）
    /// 可能涉及多卡切换或数据承载切换，具体语义未公开
    let supportSwitchOver: Int?
    
    
    // MARK: - 底层协议参数
    
    /// PCO 容器 ID（Protocol Configuration Options）
    /// 属于 NAS 层配置参数（3GPP 标准），用于承载网络配置数据
    /// 通常不面向用户展示
    let pcoContainerId: Any?
    
    
    // MARK: - 原始数据
    
    /// 原始字典数据（来自 CoreTelephony）
    /// 用于调试或高级模式展示，避免信息丢失
    let raw: [String: Any]
    
    
    /// 将 typeMask 转换为可读文本（业务类型解析）
    static func getTypeMaskText(mask: Int?) -> String {
        guard let mask = mask else {
            return NSLocalizedString("Unknown", comment: "未知")
        }
        
        var result: [String] = []
        
        if mask & 1 != 0 {
            result.append(NSLocalizedString("MobileData", comment: ""))
        }
        if mask & 2 != 0 {
            result.append(NSLocalizedString("A-GPS", comment: ""))
        }
        if mask & 4 != 0 {
            result.append(NSLocalizedString("MMS", comment: ""))
        }
        if mask & 8 != 0 {
            result.append("dun")
        }
        if mask & 64 != 0 {
            result.append("hipri")
        }
        if mask & 131072 != 0 {
            result.append(NSLocalizedString("IMS", comment: ""))
        }
        if mask & 262144 != 0 {
            result.append(NSLocalizedString("SOS", comment: ""))
        }
        
        if result.isEmpty {
            return String(mask)
        }
        
        return result.joined(separator: ", ")
    }
    
    /// 通过协议掩码获取IP协议的文本
    static func getProtocolText(mask: Int?) -> String {
        switch mask {
        case 1: return "IPv4"
        case 2: return "IPv6"
        case 3: return "IPv4/IPv6"
        default: return NSLocalizedString("Unknown", comment: "未知")
        }
    }
    
    /// 获取允许网络协议的文本
    static func getTechnologyText(mask: Int?) -> String {
        guard let mask = mask else {
            return NSLocalizedString("Unknown", comment: "未知")
        }
        
        if mask == 0 {
            return NSLocalizedString("AnyNetworkType", comment: "")
        }
        var result: [String] = []
        
        if mask & 4 != 0 {
            result.append("3G")
        }
        if mask & 32 != 0 || mask & 64 != 0 {
            result.append("4G")
        }
        if mask & 128 != 0 {
            result.append("5G")
        }
        
        return result.joined(separator: " / ")
    }
}
