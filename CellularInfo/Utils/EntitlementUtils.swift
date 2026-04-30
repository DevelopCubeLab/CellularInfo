import Foundation
import MachO

final class EntitlementUtils {
    
    private static var cachedEntitlements: [String: Any]?
    
    /// 获取当前 App Mach-O 中签名携带的 entitlements
    static func getEntitlements() -> [String: Any]? {
        if let cachedEntitlements {
            return cachedEntitlements
        }
        
        guard let path = Bundle.main.executablePath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let codeSignature = findCodeSignature(in: data),
              let entitlementBlob = extractEntitlementsBlob(from: data, codeSignatureOffset: codeSignature.offset),
              let entitlements = parseEntitlements(from: entitlementBlob) else {
            return nil
        }
        
        cachedEntitlements = entitlements
        return entitlements
    }
    
    /// 获取指定 entitlement 的原始值
    static func getValue(_ key: String) -> Any? {
        return getEntitlements()?[key]
    }
    
    /// 根据 keyHierarchy 获取嵌套 entitlement（忽略大小写）
    static func getValue(forKeyHierarchy keys: [String]) -> Any? {
        guard var current: Any = getEntitlements() else {
            return nil
        }
        
        for key in keys {
            if let dict = current as? [String: Any] {
                // 忽略大小写匹配 key
                if let matchedKey = dict.keys.first(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                    current = dict[matchedKey] as Any
                } else {
                    return nil
                }
            } else if let array = current as? [Any] {
                // 如果当前是数组，尝试匹配字符串（忽略大小写）
                if let matched = array.first(where: {
                    if let str = $0 as? String {
                        return str.caseInsensitiveCompare(key) == .orderedSame
                    }
                    return false
                }) {
                    return matched
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        return current
    }
    
    /// 判断 keyHierarchy 是否存在（支持 array contains，忽略大小写）
    static func exists(_ keyHierarchy: [String]) -> Bool {
        guard !keyHierarchy.isEmpty else {
            return false
        }
        
        // 单层 key
        if keyHierarchy.count == 1 {
            return getValue(forKeyHierarchy: keyHierarchy) != nil
        }
        
        // 多层：最后一层如果是 array.contains 语义
        let parentKeys = Array(keyHierarchy.dropLast())
        let lastKey = keyHierarchy.last!
        
        if let parent = getValue(forKeyHierarchy: parentKeys) {
            if let array = parent as? [String] {
                return array.contains {
                    $0.caseInsensitiveCompare(lastKey) == .orderedSame
                }
            }
            
            if let dict = parent as? [String: Any] {
                return dict.keys.contains {
                    $0.caseInsensitiveCompare(lastKey) == .orderedSame
                }
            }
        }
        
        return false
    }
    
    /// 判断 keyHierarchy 是否存在（如 ["com.xxx", "spi"]）
    static func has(_ keyHierarchy: [String]) -> Bool {
        return getValue(forKeyHierarchy: keyHierarchy) != nil
    }
    
    /// 检查 entitlement 是否存在某个字符串值
    static func has(_ key: String, value target: String) -> Bool {
        guard let value = getValue(key) else {
            return false
        }
        
        if let array = value as? [String] {
            return array.contains(target)
        }
        
        if let string = value as? String {
            return string == target
        }
        
        return false
    }
    
    /// 检查 entitlement 是否为 true
    static func has(_ key: String) -> Bool {
        guard let value = getValue(key) else {
            return false
        }
        
        if let boolValue = value as? Bool {
            return boolValue
        }
        
        return false
    }
    
    // MARK: - Mach-O Parsing
    private static func findCodeSignature(in data: Data) -> (offset: UInt32, size: UInt32)? {
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }
            
            // 先读取 magic，兼容 32/64 位 Mach-O
            let magic = baseAddress.assumingMemoryBound(to: UInt32.self).pointee
            
            let is64Bit: Bool
            let headerSize: Int
            
            switch magic {
            case MH_MAGIC_64, MH_CIGAM_64:
                is64Bit = true
                headerSize = MemoryLayout<mach_header_64>.size
            case MH_MAGIC, MH_CIGAM:
                is64Bit = false
                headerSize = MemoryLayout<mach_header>.size
            default:
                return nil
            }
            
            let ncmds: UInt32
            if is64Bit {
                ncmds = baseAddress.assumingMemoryBound(to: mach_header_64.self).pointee.ncmds
            } else {
                ncmds = baseAddress.assumingMemoryBound(to: mach_header.self).pointee.ncmds
            }
            
            var commandOffset = headerSize
            
            for _ in 0..<ncmds {
                let commandPointer = baseAddress.advanced(by: commandOffset).assumingMemoryBound(to: load_command.self)
                let command = commandPointer.pointee
                
                if command.cmd == LC_CODE_SIGNATURE {
                    let linkeditCommand = commandPointer.withMemoryRebound(to: linkedit_data_command.self, capacity: 1) {
                        $0.pointee
                    }
                    return (linkeditCommand.dataoff, linkeditCommand.datasize)
                }
                
                commandOffset += Int(command.cmdsize)
            }
            
            return nil
        }
    }
    
    private static func extractEntitlementsBlob(from data: Data, codeSignatureOffset: UInt32) -> Data? {
        let superBlobOffset = Int(codeSignatureOffset)
        
        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }
            
            func readUInt32(at offset: Int) -> UInt32 {
                let value = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt32.self).pointee
                return UInt32(bigEndian: value)
            }
            
            let magic = readUInt32(at: superBlobOffset)
            guard magic == 0xfade0cc0 else {
                return nil
            }
            
            let count = Int(readUInt32(at: superBlobOffset + 8))
            var indexOffset = superBlobOffset + 12
            
            for _ in 0..<count {
                let type = readUInt32(at: indexOffset)
                let blobOffset = Int(readUInt32(at: indexOffset + 4))
                
                // CSSLOT_ENTITLEMENTS = 0x00000005
                if type == 0x00000005 {
                    let entitlementBlobOffset = superBlobOffset + blobOffset
                    let blobMagic = readUInt32(at: entitlementBlobOffset)
                    guard blobMagic == 0xfade7171 else {
                        return nil
                    }
                    
                    let blobLength = Int(readUInt32(at: entitlementBlobOffset + 4))
                    return data.subdata(in: entitlementBlobOffset..<(entitlementBlobOffset + blobLength))
                }
                
                indexOffset += 8
            }
            
            return nil
        }
    }
    
    private static func parseEntitlements(from blob: Data) -> [String: Any]? {
        // Blob 头部 8 字节：[magic(4)][length(4)]，后面是 plist 数据
        let plistData = blob.dropFirst(8)
        
        return try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any]
    }
}
