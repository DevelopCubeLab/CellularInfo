import Foundation

enum BandRadioAccessTechnology: Hashable {
    case LTE
    case NR
    case GSM
    case WCDMA
    case TD_SCDMA
    case CDMA
    case unknown(String) // 保留原始字符串
    
    /// 解析
    static func from(key: String) -> BandRadioAccessTechnology {
        if key.contains("LTE") {
            return .LTE
        }
        if key.contains("NR") {
            return .NR
        }
        if key.contains("GSM") {
            return .GSM
        }
        if key.contains("UTRAN") {
            return .WCDMA
        }
        if key.contains("TDSCDMA") {
            return .TD_SCDMA
        }
        if key.contains("CDMA") {
            return .CDMA
        }
        return .unknown(key) // 未知直接原样保留
    }
    
    // 输出
    var displayName: String {
        switch self {
        case .LTE: return "LTE"
        case .NR: return "5G"
        case .GSM: return "GSM"
        case .WCDMA: return "WCDMA"
        case .CDMA: return "CDMA"
        case .TD_SCDMA: return "TD-SCDMA"
        case .unknown(let raw): return raw // 原样输出
        }
    }
}

struct Band {
    let rat: BandRadioAccessTechnology
    let value: Int
    
    var displayName: String {
        switch rat {
        case .LTE:
            return "B\(value)"
        case .NR:
            return "n\(value)"
        default:
            return "\(value)"
        }
    }
}

struct BandInfoEntity {
    var active: [BandRadioAccessTechnology: [Band]] = [:]
    var supported: [BandRadioAccessTechnology: [Band]] = [:]
}

@available(iOS 14.0, *)
class BandInfo {
    
    // 转换函数
    static func convert(from bandInfo: CTBandInfo) -> BandInfoEntity {
        var model = BandInfoEntity()
        
        // 读取数据
        let activeDict = (bandInfo.fActiveBands as? [String: Any]) ?? [:]
        let supportedDict = (bandInfo.fSupportedBands as? [String: Any]) ?? [:]
        
        model.active = parseBands(activeDict)
        model.supported = parseBands(supportedDict)
        
        return model
    }
    
    // 转换数据
    private static func parseBands(_ dict: [String: Any]) -> [BandRadioAccessTechnology: [Band]] {
        var result: [BandRadioAccessTechnology: [Band]] = [:]
        
        for (key, rawValues) in dict {
            let rat = BandRadioAccessTechnology.from(key: key)
            let values = rawValues as? [NSNumber] ?? []
            let bands = values
                .map { Band(rat: rat, value: $0.intValue) }
                .sorted { $0.value < $1.value }
            result[rat] = bands
        }
        
        return result
    }
    
    static func format(_ dict: [BandRadioAccessTechnology: [Band]]) -> String {
        // 固定顺序（UI稳定，不用字典乱序）
        let order: [BandRadioAccessTechnology] = [
            .NR, .LTE, .WCDMA, .CDMA, .TD_SCDMA, .GSM
        ]
        var lines: [String] = []

        for rat in order {
            guard let bands = dict[rat], !bands.isEmpty else { continue }
            let bandStr = bands.map { $0.displayName }.joined(separator: ", ")
            lines.append("\(rat.displayName)：\(bandStr)")

        }
        // 未知类型兜底 原样输出
        for (rat, bands) in dict {
            if case .unknown = rat {
                guard !bands.isEmpty else { continue }
                let bandStr = bands.map { $0.displayName }.joined(separator: ", ")
                lines.append("\(rat.displayName)：\(bandStr)")
            }
        }
        return lines.joined(separator: "\n")

    }
    
    // 测试函数
    static func toString(_ model: BandInfoEntity) -> String {
        var result = ""
        
        result += "Active Bands\n"
        for (rat, bands) in model.active {
            let bandStr = bands.map { $0.displayName }.joined(separator: " ")
            result += "\(rat.displayName): \(bandStr)\n"
        }
        
        result += "\nSupported Bands\n"
        for (rat, bands) in model.supported {
            let bandStr = bands.map { $0.displayName }.joined(separator: " ")
            result += "\(rat.displayName): \(bandStr)\n"
        }
        
        return result
    }
}
