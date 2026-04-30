import Foundation

class CoreTelephonyEnumMapper {
    
    enum NotInsertedSIMStatus: Int {
        case noSIM = 1          // 无SIM卡
        case noEmbeddedSIM = 2  // 无eSIM卡
        case noEnableSIM = 3    // 未启用SIM卡
        case unknown = 0        // 未知
    }
    
    // SIM卡槽状态枚举
    enum SIMTrayStatus {
        case absent
        case noSIM
        case withSIM
        case unknown
    }
    
    // 遍历SIM卡槽状态枚举
    static func mapSIMTrayStatus(_ raw: String?) -> SIMTrayStatus {
        switch raw {
        case "kCTSIMSupportSIMTrayAbsent":
            return .absent
        case "kCTSIMSupportSIMTrayInsertedNoSIM":
            return .noSIM
        case "kCTSIMSupportSIMTrayInsertedWithSIM":
            return .withSIM
        case "kCTSIMSupportSIMTrayStatusUnknown":
            return .unknown
        default:
            return.unknown
        }
    }
    
    // SIM卡状态的枚举
    enum SIMStatus {
        case ready
        case notInserted
        case inserted
        case notReady
        case pinLocked
        case pukLocked
        case permanentlyLocked
        case corporateLocked
        case networkLocked
        case operatorLocked
        case operatorSubsetLocked
        case serviceProviderLocked
        case memoryFailure
        case unknown(raw: String?)
        
        // SIM卡是否就绪
        var isReady: Bool {
            if case .ready = self {
                return true
            }
            return false
        }
    }
    
    // 遍历SIM卡状态枚举
    static func mapSIMStatus(_ raw: String?) -> SIMStatus {
        switch raw {
        case "kCTSIMSupportSIMStatusReady":
            return .ready

        case "kCTSIMSupportSIMStatusNotInserted":
            return .notInserted

        case "kCTSIMSupportSIMStatusInserted":
            return .inserted

        case "kCTSIMSupportSIMStatusNotReady":
            return .notReady

        case "kCTSIMSupportSIMStatusPINLocked":
            return .pinLocked

        case "kCTSIMSupportSIMStatusPUKLocked":
            return .pukLocked

        case "kCTSIMSupportSIMStatusPermanentlyLocked":
            return .permanentlyLocked

        case "kCTSIMSupportSIMStatusCorporateLocked":
            return .corporateLocked

        case "kCTSIMSupportSIMStatusNetworkLocked":
            return .networkLocked

        case "kCTSIMSupportSIMStatusOperatorLocked":
            return .operatorLocked

        case "kCTSIMSupportSIMStatusOperatorSubsetLocked":
            return .operatorSubsetLocked

        case "kCTSIMSupportSIMStatusServiceProviderLocked":
            return .serviceProviderLocked

        case "kCTSIMSupportSIMStatusMemoryFailure":
            return .memoryFailure

        default:
            return .unknown(raw: raw)
        }
        
    }
    
    // 注册状态枚举
    enum RegistrationStatus {
        case registeredHome          // 本地网络已注册
        case registeredRoaming       // 漫游已注册
        case notRegistered           // 未注册
        case searching               // 搜索中
        case denied                  // 被拒绝
        case emergencyOnly           // 仅紧急呼叫
        case modemRestart            // 基带服务重启中
        case unknown(raw: String?)
    }
    
    // 遍历注册状态枚举
    static func mapRegistrationStatus(_ raw: String?) -> RegistrationStatus {
        switch raw {

        case "kCTRegistrationStatusRegisteredHome":
            return .registeredHome

        case "kCTRegistrationStatusRegisteredRoaming":
            return .registeredRoaming

        case "kCTRegistrationStatusNotRegistered":
            return .notRegistered

        case "kCTRegistrationStatusSearching":
            return .searching

        case "kCTRegistrationStatusDenied":
            return .denied

        case "kCTRegistrationStatusEmergencyOnly":
            return .emergencyOnly

        case "kCTRegistrationStatusUnknown":
            return .modemRestart
            
        default:
            return .unknown(raw: raw)
        }
    }

    // 无线接入制式（RAT）枚举
    enum RadioAccessTechnology: Equatable {
        case GSM
        case GPRS
        case EDGE
        case UTRAN
        case HSDPA
        case HSUPA
        case HSPA
        case CDMA1X
        case EVDO
        case EVDORev0
        case EVDORevA
        case EVDORevB
        case EHRPD
        case LTE
        case NR
        case NRNSA
        case NO_SERVICE
        case UNKNOWN(raw: String?)
        
        // 适合UI展示的名称
        var displayName: String {
            switch self {
            case .GSM, .GPRS, .EDGE:
                return "2G"
            case .UTRAN, .HSDPA, .HSUPA, .HSPA, .CDMA1X, .EVDO, .EVDORev0, .EVDORevA, .EVDORevB, .EHRPD:
                return "3G"
            case .LTE:
                return "4G"
            case .NRNSA:
                return "5G (NSA)"
            case .NR:
                return "5G (SA)"
            case .NO_SERVICE:
                return "No Service"
            case .UNKNOWN(let raw):
                return raw ?? "Unknown"
            }
        }

        // 更详细的UI展示名称（包含制式族信息）
        var displayDetailName: String {
            switch self {
            case .GSM:
                return "2G (GSM)"
            case .GPRS:
                return "2G (GPRS)"
            case .EDGE:
                return "2G (EDGE)"
                
            case .UTRAN:
                return "3G (UMTS/WCDMA)"
            case .HSDPA:
                return "3G (HSDPA)"
            case .HSUPA:
                return "3G (HSUPA)"
            case .HSPA:
                return "3G (HSPA)"
            case .CDMA1X:
                return "2G (CDMA2000 1x)"
            case .EVDO:
                return "3G (CDMA2000 EV-DO)"
            case .EVDORev0:
                return "3G (EV-DO Rev.0)"
            case .EVDORevA:
                return "3G (EV-DO Rev.A)"
            case .EVDORevB:
                return "3G (EV-DO Rev.B)"
            case .EHRPD:
                return "3G (eHRPD)"
            case .LTE:
                return "4G (LTE)"
            case .NR:
                return "5G SA (NR)"
            case .NRNSA:
                return "5G NSA"
            case .NO_SERVICE:
                return NSLocalizedString("NoService", comment: "")
            case .UNKNOWN(let raw):
                return raw ?? NSLocalizedString("Unknown", comment: "未知")
            }
        }
        
        // 获取2G/3G/4G的判断
        var generation: RadioGeneration {
            switch self {
            case .GSM, .GPRS, .EDGE, .CDMA1X:
                return ._2G

            case .UTRAN, .HSDPA, .HSUPA, .HSPA, .EVDO, .EVDORev0, .EVDORevA, .EVDORevB, .EHRPD:
                return ._3G

            case .LTE:
                return ._4G

            case .NR, .NRNSA:
                return ._5G

            case .NO_SERVICE:
                return .noService

            case .UNKNOWN:
                return .unknown
            }
        }
    }
    
    enum RadioGeneration {
        case _2G
        case _3G
        case _4G
        case _5G
        case noService
        case unknown
        
        case noPermission  // 这个不是网络代际 为了标注无权限准备的
    }
    
    // 遍历用户设置的网络类型
    static func mapSelectRate(rate: Int64) -> RadioGeneration {
        switch rate {
        case 1: return ._2G
        case 2: return ._3G
        case 3: return ._4G
        case 4: return ._5G
        default: return .unknown
        }
    }

    /// 遍历无线接入制式字符串 → 枚举
    static func mapRegistrationRadioAccessTechnology(_ raw: String?) -> RadioAccessTechnology {
        guard let raw else { return .NO_SERVICE }
        
        switch raw {
        case "kCTRegistrationRadioAccessTechnologyGSM":
            return .GSM
        case "kCTRegistrationRadioAccessTechnologyGPRS":
            return .GPRS
        case "kCTRegistrationRadioAccessTechnologyEDGE":
            return .EDGE
        case "kCTRegistrationRadioAccessTechnologyUTRAN":
            return .UTRAN
        case "kCTRegistrationRadioAccessTechnologyHSDPA":
            return .HSDPA
        case "kCTRegistrationRadioAccessTechnologyHSUPA":
            return .HSUPA
        case "kCTRegistrationRadioAccessTechnologyHSPA":
            return .HSPA
        case "kCTRegistrationRadioAccessTechnologyCDMA1x":
            return .CDMA1X
        case "kCTRegistrationRadioAccessTechnologyCDMAEVDO":
            return .EVDO
        case "kCTRegistrationRadioAccessTechnologyEHRPD":
            return .EHRPD
        case "kCTRegistrationRadioAccessTechnologyLTE":
            return .LTE
        case "kCTRegistrationRadioAccessTechnologyNR":
            return .NR
        case "kCTRegistrationRadioAccessTechnologyUnknown":
            fallthrough
        default:
            return raw == "kCTRegistrationRadioAccessTechnologyUnknown"
                ? .NO_SERVICE
                : .UNKNOWN(raw: raw)
        }
    }
    
    static func mapRadioAccessTechnology(_ raw: String?) -> RadioAccessTechnology {
        guard let raw, !raw.isEmpty else { return .NO_SERVICE }
        
        if raw.contains("NR") { return .NR }
        if raw.contains("LTE") { return .LTE }

        if raw.contains("EHRPD") { return .EHRPD }
        if raw.contains("EVDO") { return .EVDO }
        if raw.contains("CDMA1x") || raw.contains("CDMA1X") { return .CDMA1X }

        if raw.contains("HSDPA") { return .HSDPA }
        if raw.contains("HSUPA") { return .HSUPA }
        if raw.contains("HSPA") { return .HSPA }

        if raw.contains("UTRAN") ||
           raw.contains("UMTS") ||
           raw.contains("WCDMA") {
            return .UTRAN
        }

        if raw.contains("EDGE") { return .EDGE }
        if raw.contains("GPRS") { return .GPRS }
        if raw.contains("GSM") { return .GSM }

        if raw.contains("Unknown") || raw.contains("UNKNOWN") {
            return .NO_SERVICE
        }

        return .UNKNOWN(raw: raw)
    }
    
    static func mapCTRadioAccessTechnology(_ raw: String?) -> RadioAccessTechnology {
        guard let raw else { return .NO_SERVICE }
        
        switch raw {
        case "CTRadioAccessTechnologyGPRS": return .GPRS
        case "CTRadioAccessTechnologyEdge": return .EDGE
        case "CTRadioAccessTechnologyWCDMA": return .UTRAN
        case "CTRadioAccessTechnologyHSDPA": return .HSDPA
        case "CTRadioAccessTechnologyHSUPA": return .HSUPA
        case "CTRadioAccessTechnologyCDMA1x": return .CDMA1X
        case "CTRadioAccessTechnologyCDMAEVDORev0": return .EVDORev0
        case "CTRadioAccessTechnologyCDMAEVDORevA": return .EVDORevA
        case "CTRadioAccessTechnologyCDMAEVDORevB": return .EVDORevB
        case "CTRadioAccessTechnologyeHRPD": return .EHRPD
        case "CTRadioAccessTechnologyLTE": return .LTE
        case "CTRadioAccessTechnologyNRNSA": return .NRNSA
        case "CTRadioAccessTechnologyNR": return .NR
        default:
            return .UNKNOWN(raw: raw)
        }
    }

    static func mapCellMonitorRAT(_ raw: String?) -> RadioAccessTechnology {
        guard let raw else {
            return .UNKNOWN(raw: nil)
        }

        switch raw {

        // 2G
        case "kCTCellMonitorRadioAccessTechnologyGSM":
            return .GSM

        // 3G
        case "kCTCellMonitorRadioAccessTechnologyUMTS",
             "kCTCellMonitorRadioAccessTechnologyUTRAN",
             "kCTCellMonitorRadioAccessTechnologyTDSCDMA":
            return .UTRAN

        case "kCTCellMonitorRadioAccessTechnologyCDMA1x":
            return .CDMA1X

        case "kCTCellMonitorRadioAccessTechnologyCDMAEVDO",
             "kCTCellMonitorRadioAccessTechnologyCDMAHybrid":
            return .EVDO

        // 4G
        case "kCTCellMonitorRadioAccessTechnologyLTE":
            return .LTE

        // 5G
        case "kCTCellMonitorRadioAccessTechnologyNR":
            return .NR

        // 无服务
        case "kCTCellMonitorRadioAccessTechnologyUnknown":
            return .NO_SERVICE

        // 未知
        default:
            return .UNKNOWN(raw: raw)
        }
    }
    
    // 换算4G LTE网络的NRB/PRB转换为MHz
    static func LTEBandwidthMHz(PRB: Int) -> Double? {
        switch PRB {
        case 6:
            return 1.4
        case 15:
            return 3
        case 25:
            return 5
        case 50:
            return 10
        case 75:
            return 15
        case 100:
            return 20
        default:
            return nil
        }
    }
    
    static func mapDataConnectionServiceTypes(_ keys: [String]) -> [String] {
        return keys.map { mapDataConnectionServiceType($0) }
    }
    
    static func mapDataConnectionServiceType(_ key: String) -> String {
        switch key {
            
        // 常用
        case "kCTDataConnectionServiceTypeInternet":
            return NSLocalizedString("MobileData", comment: "")
            
        case "kCTDataConnectionServiceTypeIMS":
            return "IMS (VoLTE / VoNR)"
            
        case "kCTDataConnectionServiceTypeWirelessModemTraffic":
            return NSLocalizedString("PersonalHotspot", comment: "")
            
        case "kCTDataConnectionServiceTypeMMS":
            return NSLocalizedString("MMS", comment: "")
            
        case "kCTDataConnectionServiceTypeUT":
            return NSLocalizedString("TelephonyServices", comment: "")
            
        case "kCTDataConnectionServiceTypeVVM":
            return NSLocalizedString("Voicemail", comment: "")
            
            
        // 可能出现
        case "kCTDataConnectionServiceTypeEntitlementTraffic":
            return NSLocalizedString("CarrierServices", comment: "")
            
        case "kCTDataConnectionServiceTypeInternetProbe":
            return NSLocalizedString("ConnectivityCheck", comment: "")
            
        case "kCTDataConnectionServiceTypeWirelessModemAuthentication":
            return NSLocalizedString("NetworkAccessAuthentication", comment: "")
            
        case "kCTDataConnectionServiceTypeAppleWirelessDiagnostics":
            return NSLocalizedString("Diagnostics", comment: "")
            
        case "kCTDataConnectionServiceTypeEmergencyLocation":
            return NSLocalizedString("EmergencyServices", comment: "")
            
        case "kCTDataConnectionServiceTypeOMADM":
            return NSLocalizedString("DeviceManagement", comment: "")
            
        case "kCTDataConnectionServiceTypeCellularDataPlanProvisioning", "kCTDataConnectionServiceTypeCellularDataPlanProvisioning2":
            return NSLocalizedString("DataPlanProvisioning", comment: "")
        
        /// 在iPhone 17 Pro Max LL/A 设备上 断开Wi-Fi连接 点击设置蜂窝号码
        /// 系统开始加载 观察控制中心的蜂窝网络 从1格信号变成1～4格 此时可以添加eSIM
        /// 也会有这个item出现
        case "kCTDataConnectionServiceTypeBootstrapProvisioning":
            return NSLocalizedString("eSIMProvisioningService", comment: "")
            
        case "kCTDataConnectionServiceTypeOTAActivation":
            return NSLocalizedString("OTAActivation", comment: "")
            
        case "kCTDataConnectionServiceTypeOTAInternet":
            return NSLocalizedString("OTAInternet", comment: "")
            
        case "kCTDataConnectionServiceTypeZeroRated":
            return NSLocalizedString("ZeroRatedData", comment: "")
            
        case "kCTDataConnectionServiceType3GFaceTimeTraffic":
            return "FaceTime (3G)"
            
        case "kCTDataConnectionServiceType3GFaceTimeAuthentication":
            return NSLocalizedString("FaceTimeAuthentication", comment: "")
            
            
        // 其他的不想做了，原路返回
        default:
            return key
        }
    }
    
    static func mapRATSelection(_ value: String?) -> String {
        guard let value = value else {
            return NSLocalizedString("Unknown", comment: "未知")
        }
        
        switch value {
            
            // MARK: - System
            
        case "kCTRegistrationRATSelectionAutomatic":
            return NSLocalizedString("Automatic", comment: "")
            
        case "kCTRegistrationRATSelectionUnknown":
            return NSLocalizedString("Unknown", comment: "未知")
            
        case "kCTRegistrationRATSelectionDual":
            return NSLocalizedString("MultiNetworkMode", comment: "")
            
            // MARK: - 5G
            
        case "kCTRegistrationRATSelectionNR":
            return "5G (SA+NSA)"
            
        case "kCTRegistrationRATSelectionNRNonStandAlone":
            return "5G (NSA)"
            
        case "kCTRegistrationRATSelectionNRStandAlone":
            return "5G (SA)"
            
            // MARK: - 4G
            
        case "kCTRegistrationRATSelectionLTE":
            return "4G (LTE)"
            
            // MARK: - 3G / 2G
            
        case "kCTRegistrationRATSelectionUMTS":
            return "3G (UMTS/WCDMA)"
            
        case "kCTRegistrationRATSelectionTDSCDMA":
            return "3G (TD-SCDMA)"
            
        case "kCTRegistrationRATSelectionGSM":
            return "2G (GSM)"
            
            // MARK: - CDMA (Legacy)
            
        case "kCTRegistrationRATSelectionCDMA1x":
            return "CDMA 1x"
            
        case "kCTRegistrationRATSelectionCDMA1xEVDO":
            return "CDMA EV-DO"
            
        case "kCTRegistrationRATSelectionCDMAHybrid":
            return "CDMA Hybrid"
            
            // MARK: - Internal / Unknown LTE variants
            
        case "kCTRegistrationRATSelection12":
            return "LTE (Internal 12)"
            
        case "kCTRegistrationRATSelection13":
            return "LTE (Internal 13)"
            
        case "kCTRegistrationRATSelection14":
            return "LTE (Internal 14)"
            
        default:
            return String.localizedStringWithFormat(NSLocalizedString("UnknownWithError", comment: ""), value)
        }
    }
}
