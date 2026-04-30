import Foundation
import UIKit
import ZIPFoundation

extension IPCCManagerController {

    /// 获取设备类型的字符串
    static func getDeviceTypeBasePath() -> String {
        let deviceType = CellularDataController.instance.getDeviceType() ?? UIDevice.current.userInterfaceIdiom
        if deviceType == .phone {
            return "iPhone"
        } else if deviceType == .pad {
            return "iPad"
        } else {
            return "iPhone"
        }
    }

    /// 获取系统默认IPCC版本号
    static func getSystemDefaultIPCCVersion() throws -> String {
        
        let fileManager = FileManager.default
        
        let deviceTypeBasePath = getDeviceTypeBasePath()
        
        // 文件路径 优先 Unknown 其次 US
        // iPhone和iPad目录不同
        let bundlePaths = [
            "/System/Library/CountryBundles/\(deviceTypeBasePath)/Unknown.bundle",
            "/System/Library/Carrier Bundles/\(deviceTypeBasePath)/Unknown.bundle", // iOS 18以下的主方法 无权限机器无法读取
            "/System/Library/CountryBundles/\(deviceTypeBasePath)/UnitedStates.bundle" // 兜底方案
        ]
        
        for bundlePath in bundlePaths {
            
            let plistPath = bundlePath + "/Info.plist"
            
            // 判断文件是否存在
            if !fileManager.fileExists(atPath: plistPath) {
                // 不存在就去找下一个目录
                continue
            }
            
            // 读取 plist
            if let dict = NSDictionary(contentsOfFile: plistPath),
               let version = dict["CFBundleVersion"] as? String { // 获取当前的IPCC默认版本
                return version
            }
        }
        
        // 没找到时抛异常
        throw CarrierBundleError.fileNotFound
    }

    /// 获取已经安装的IPCC
    static func getInstalledCarrierBundles() -> [CarrierBundleInfo] {
        
        let fileManager = FileManager.default
        
        // 根据设备类型选择目录
        let basePath = "/var/mobile/Library/Carrier Bundles/\(getDeviceTypeBasePath())"
        
        // 目录不存在直接返回空
        guard fileManager.fileExists(atPath: basePath) else {
            return []
        }
        
        var results: [CarrierBundleInfo] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        for url in contents {
            // 过滤：必须是目录 + 不是符号链接 + 后缀.bundle
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard resourceValues?.isDirectory == true,
                  resourceValues?.isSymbolicLink != true,
                  url.pathExtension == "bundle" else {
                continue
            }
            if let model = try? parseCarrierBundleInfo(from: url) {
                results.append(model)
            }
        }
        
        return results
    }

    /// 安装IPCC
    static func installIPCC(path: URL) throws -> Bool {
        var error: NSError? // 创建一个接收错误信息的对象
        let result = IPCCManagerController.installIPCC(at: path, error: &error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }

    /// IPCC文件兼容性检测
    static func IPCCFileCompatibilityCheck(path: URL) throws -> IPCCFileCompatibilityCheckResult {
        // 直接解析 IPCC 文件
        let carrierBundleInfo = try parseCarrierBundleInfoFromIPCCFile(at: path)
        let version = carrierBundleInfo.version
        let carrierName = carrierBundleInfo.carrierName
        // 创建一个问题合集
        var issues: Set<IPCCIssue> = []
        
        // 判断安装目录是否权限被锁定
        if !isCarrierBundleFullyWritable() {
            issues.insert(.installPathLocked)
        }
        
        // 解析支持的设备型号
        let supportedDevices = carrierBundleInfo.supportDevice
        
        // 获取设备主板型号
        let deviceBoard = SystemInfoUtils.getDeviceLogicBoardID() // 例如D16
        
        // 设备是否匹配
        let deviceMatched = supportedDevices.contains { model in
            deviceBoard.hasPrefix(model) || model.hasPrefix(deviceBoard)
        }
        
        if !deviceMatched {
            issues.insert(.deviceNotSupported)
        }
        
        // 判断是否低于系统默认版本
        var systemVersion: String?
        do {
            systemVersion = try IPCCManagerController.getSystemDefaultIPCCVersion()
            if let systemVersion = systemVersion {
                if version.compare(systemVersion, options: .numeric) == .orderedAscending {
                    issues.insert(.belowSystemVersion)
                }
            }
        } catch {
            // 忽略系统版本获取失败
        }

        // 判断是否降级、重复等
        let installed = IPCCManagerController.getInstalledCarrierBundles()
        for item in installed {
            if item.carrierName == carrierName {
                if item.version == version {
                    issues.insert(.duplicateInstall)
                }
                if !issues.contains(.belowSystemVersion) {
                    if version.compare(item.version, options: .numeric) == .orderedAscending {
                        issues.insert(.versionDowngrade)
                    }
                }
            }
        }

        // 返回结果集
        return IPCCFileCompatibilityCheckResult(
            carrierBundleInfo: carrierBundleInfo,
            issues: issues
        )
    }
    
    /// 从 .ipcc 文件解析 CarrierBundleInfo
    private static func parseCarrierBundleInfoFromIPCCFile(at path: URL) throws -> CarrierBundleInfo {
        let fileManager = FileManager.default
        let baseTmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CellularInfo", isDirectory: true)
        
        // 清理旧目录
        try? fileManager.removeItem(at: baseTmpDir)
        try fileManager.createDirectory(at: baseTmpDir, withIntermediateDirectories: true)
        
        // 无论成功失败都清理
        defer {
            try? fileManager.removeItem(at: baseTmpDir)
        }
        
        // 拷贝 IPCC 到临时目录
        let targetURL = baseTmpDir.appendingPathComponent(UUID().uuidString + ".ipcc")
        try? fileManager.removeItem(at: targetURL)
        try fileManager.copyItem(at: path, to: targetURL)
        
        // 解压
        let unzipDir = baseTmpDir.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: unzipDir, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: targetURL, to: unzipDir)
        
        // 找 Payload
        let payloadPath = unzipDir.appendingPathComponent("Payload")
        let searchRoot: URL = fileManager.fileExists(atPath: payloadPath.path) ? payloadPath : unzipDir
        
        let contents = try fileManager.contentsOfDirectory(at: searchRoot, includingPropertiesForKeys: nil)
        
        // 找 bundle
        guard let bundle = contents.first(where: { IPCCManagerController.isCarrierBundleDirectory($0) }) else {
            throw CarrierBundleError.invalidIPCCFile
        }
        
        return try parseCarrierBundleInfo(from: bundle)
    }
    
    /// 从 bundle 目录解析 CarrierBundleInfo（包含设备支持信息）
    private static func parseCarrierBundleInfo(from bundleURL: URL) throws -> CarrierBundleInfo {
        let fileManager = FileManager.default
        // 主要就是两个文件 info.plist 和 carrier.plist
        let infoPlist = bundleURL.appendingPathComponent("Info.plist").path
        let carrierPlist = bundleURL.appendingPathComponent("carrier.plist").path
        // 获取 info.plist 里面的基本信息
        guard let infoDict = NSDictionary(contentsOfFile: infoPlist) as? [String: Any],
              let version = infoDict["CFBundleVersion"] as? String else {
            throw CarrierBundleError.invalidIPCCFile
        }
        // 获取 carrier.plist 里面的运营商信息
        guard let carrierDict = NSDictionary(contentsOfFile: carrierPlist) as? [String: Any],
              let carrierName = carrierDict["CarrierName"] as? String else {
            throw CarrierBundleError.invalidIPCCFile
        }
        // 获取当前IPCC支持的SIM卡
        let supportedSIMs = carrierDict["SupportedSIMs"] as? [String] ?? []

        // 解析支持设备
        var supportedDevices: [String] = []

        // 寻找supported_devices.plist
        // 不一定有 有的官方提供的IPCC里面有这个文件
        let supportedDevicesPlist = bundleURL.appendingPathComponent("supported_devices.plist").path
        if let dict = NSDictionary(contentsOfFile: supportedDevicesPlist) as? [String: Any],
           let devices = dict["SupportedDevicesExactMatch"] as? [String] {
            supportedDevices.append(contentsOf: devices)
        }

        // 直接用overrides_xxx.plist的文件名进行拆分判断
        if let bundleFiles = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) {
            for file in bundleFiles {
                let name = file.lastPathComponent

                if name.hasPrefix("overrides_") && name.hasSuffix(".plist") {
                    let part = name
                        .replacingOccurrences(of: "overrides_", with: "")
                        .replacingOccurrences(of: ".plist", with: "")

                    let models = part.split(separator: "_").map { String($0) }
                    supportedDevices.append(contentsOf: models)
                }
            }
        }
        // 合并+去重复+排序
        let uniqueDevices = Array(Set(supportedDevices)).sorted {
            // 提取数字部分做数值排序
            let num1 = Int($0.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
            let num2 = Int($1.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) ?? 0
            return num1 < num2
        }
        // 返回数据实例
        return CarrierBundleInfo(
            carrierName: carrierName,
            version: version,
            bundlePath: bundleURL,
            supportSIMs: supportedSIMs,
            supportDevice: uniqueDevices
        )
    }
    

    // 判断一个目录是否是有效的 Carrier Bundle（包含 Info.plist + carrier.plist）
    private static func isCarrierBundleDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        
        let infoPlist = url.appendingPathComponent("Info.plist").path
        let carrierPlist = url.appendingPathComponent("carrier.plist").path
        
        return fileManager.fileExists(atPath: infoPlist) &&
               fileManager.fileExists(atPath: carrierPlist)
    }
    
    /// 桥接已恶搞本类的OC方法，方便上层直接拿异常
    static func refreshCarrierBundles() throws -> Bool {
        if !AppCapability.hasCommCenterSPI() { // CommCenter会拦截无权限的情况，但是不会返回异常，需要自己判断下
            throw CarrierBundleError.permissionDenied
        }
        var error: NSError? // 创建一个接收错误信息的对象
        let result = self.refreshCarrierBundlesWithError(&error)
        if let error = error { // 判断是否有错误 有错误就抛异常给上层
            throw error
        }
        return result
    }

    /// 恢复IPCC为系统版本的方法
    /// 调用后成功无返回值
    /// 调用后失败会抛异常
    static func restoreCarrierBundleToSystem() throws {
        
        if #available(iOS 15.0, *) { // iOS 15+ 使用系统方案
            // 高版本系统直接走CoreTelephonyClient方案
            let success = CoreTelephonyController.instance.restoreCarrierBundle()
            if !success { // 没成功的话就进行判断
                // 判断是不是没有SPI权利
                if !AppCapability.hasCommCenterPreferencesReset() {
                    throw CarrierBundleError.permissionDenied // 抛异常
                } else if getInstalledCarrierBundles().isEmpty { // 判断是否是没有安装任何IPCC
                    throw CarrierBundleError.noCarrierBundleInstalled // 抛异常
                } else if !IPCCManagerController.getCarrierBundleLockStatus().result { // 判断安装目录被锁定
                    let paths = IPCCManagerController.getCarrierBundleLockStatus().path
                    throw CarrierBundleError.pathLocked(paths)
                } else {
                    // 未知错误就只能抛安装失败异常
                    throw CarrierBundleError.resetCarrierBundleFailed
                }
                
            }
        } else { // 低于iOS 15系统版本 使用旧方案
            // 先手动删除已经安装的IPCC
            if !IPCCManagerController.removeAllInstalledCarrierBundle() {
                throw CarrierBundleError.removeFailed
            }
            
            // 判断是否被锁定
            let (pathLockedResult, paths) = IPCCManagerController.getCarrierBundleLockStatus()
            if !pathLockedResult {
                throw CarrierBundleError.pathLocked(paths)
            }
            
            do {
                if try !refreshCarrierBundles() {
                    throw CarrierBundleError.resetCarrierBundleFailed
                }
            } catch let error as NSError {
                NSLog("[CellularInfo]<Restore IPCC> failed domain=%@ code=%ld desc=%@",
                      error.domain, error.code, error.localizedDescription)
                throw CarrierBundleError.underlying(error)
            }
        }
    }
    
    // 检查IPCC安装后的情况
    // installIPCC 刚安装的IPCC文件
    // beforeInstallList 安装之前的列表
    static func checkInstalledIPCCResult(url: URL, beforeInstallList: [CarrierBundleInfo]) -> IPCCInstallResult {
        
        // 1. 获取安装后IPCC的列表 判断两者数量
        // 2. 增加 -> 成功
        // 3. 减少 -> 失败 IPCC不合法
        // 4. 数量未增加
        // 4.1 列表里的与安装的都不相同 = 安装失败
        // 4.2 同一个IPCC 升级 / 降级
        // 4.3 尝试升级IPCC 但是失败了，系统不兼容
        
        // 解析刚安装的IPCC信息
        let installIPCC: CarrierBundleInfo
        do {
            installIPCC = try parseCarrierBundleInfoFromIPCCFile(at: url)
        } catch {
            return IPCCInstallResult.failed
        }
        
        // 首先判断是否有权限写入安装路径
        let (result, paths) = IPCCManagerController.getCarrierBundleLockStatus()
        if !result { // 被锁定
            if AppCapability.checkCarrierBundleReadPermission() {
                return IPCCInstallResult.pathLocked(lockedPath: paths)
            } else { // 无权限
                return IPCCInstallResult.permissionDenied
            }
            
        }
        
        // 1. 获取安装后IPCC的列表 判断两者数量
        let afterInstallList = IPCCManagerController.getInstalledCarrierBundles()
        
        let beforeCount = beforeInstallList.count
        let afterCount = afterInstallList.count
        
        // 2. 增加 -> 成功
        if afterCount > beforeCount {
            return IPCCInstallResult.success(carrierName: installIPCC.carrierName, version: installIPCC.version)
        }
        
        // 3. 减少 -> 失败 IPCC不合法
        if afterCount < beforeCount {
            return IPCCInstallResult.invalidBundle(carrierName: installIPCC.carrierName, version: installIPCC.version)
        }
        
        // 4. 数量未增加
        
        // 找到安装后的同运营商IPCC
        let afterMatched = afterInstallList.first {
            $0.carrierName == installIPCC.carrierName
        }
        
        // 找到安装前的同运营商IPCC
        let beforeMatched = beforeInstallList.first {
            $0.carrierName == installIPCC.carrierName
        }
        
        // 4.1 列表里的与安装的都不相同 = 安装失败
        guard let after = afterMatched else {
            return IPCCInstallResult.failed
        }

        // 尝试升级但版本未生效 → 判定为升级失败
        if let before = beforeMatched {
            let isAttemptUpgrade = installIPCC.version.compare(before.version, options: .numeric) == .orderedDescending
            let notApplied = after.version != installIPCC.version
            
            if isAttemptUpgrade && notApplied {
                return IPCCInstallResult.upgradedFailed(carrierName: installIPCC.carrierName, install: installIPCC.version, current: after.version)
            }
        }
        
        // 如果之前没有，现在有 → 也算成功（兜底）
        guard let before = beforeMatched else {
            return IPCCInstallResult.success(carrierName: installIPCC.carrierName, version: installIPCC.version)
        }
        
        // 4.2 同一个IPCC 升级 / 降级 / 相同版本
        if after.version == before.version {
            return IPCCInstallResult.sameVersion(carrierName: installIPCC.carrierName, version: installIPCC.version)
        }
        
        if after.version.compare(before.version, options: .numeric) == .orderedDescending {
            return IPCCInstallResult.upgraded(carrierName: installIPCC.carrierName, old: before.version, new: after.version)
        } else {
            return IPCCInstallResult.downgraded(carrierName: installIPCC.carrierName, old: before.version, new: after.version)
        }
    }

    /// 给低版本删除已安装IPCC的方法
    private static func removeAllInstalledCarrierBundle() -> Bool {
        
        let basePath = "/var/mobile/Library/Carrier Bundles/\(getDeviceTypeBasePath())"
        let overlayPath = "/var/mobile/Library/Carrier Bundles/Overlay"
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: basePath) {
            return true
        }
        
        // 删除Bundle目录
        if fileManager.fileExists(atPath: basePath) {
            do {
                try fileManager.removeItem(atPath: basePath)
                NSLog("[CellularInfo]<CarrierBundle> removed directory: \(basePath)")
            } catch {
                NSLog("[CellularInfo]<CarrierBundle> remove failed at basePath: \(error)")
                return false
            }
        }
        
        // 删除Overlay目录
        if fileManager.fileExists(atPath: overlayPath) {
            do {
                try fileManager.removeItem(atPath: overlayPath)
                NSLog("[CellularInfo]<CarrierBundle> removed overlay: \(overlayPath)")
            } catch {
                NSLog("[CellularInfo]<CarrierBundle> remove failed at overlay: \(error)")
                return false
            }
        }
        
        return true
    }
    
    /// 导出已安装的 Carrier Bundle 为 .ipcc 文件，并返回导出路径
    static func exportInstalledCarrierBundle(forCarrierBundleInfo: CarrierBundleInfo) throws -> URL {
        let fileManager = FileManager.default

        // 1. 拿到Bundle的Path
        let bundleURL = forCarrierBundleInfo.bundlePath

        // 2. 在tmp目录下新建 CellularInfo 目录
        let baseTmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CellularInfo", isDirectory: true)
        try? fileManager.removeItem(at: baseTmpDir)
        try fileManager.createDirectory(at: baseTmpDir, withIntermediateDirectories: true)

        // 确保最后清理临时目录
        defer {
            try? fileManager.removeItem(at: baseTmpDir)
        }

        // 3. 在 CellularInfo 下新建 Payload 目录
        let payloadDir = baseTmpDir.appendingPathComponent("Payload", isDirectory: true)
        try fileManager.createDirectory(at: payloadDir, withIntermediateDirectories: true)

        // 4. 把 Bundle 整个复制到 Payload 下
        let targetBundleURL = payloadDir.appendingPathComponent(bundleURL.lastPathComponent, isDirectory: true)
        try fileManager.copyItem(at: bundleURL, to: targetBundleURL)

        // 5. 压缩 Payload 目录
        // 拼接主板编号（可能多个）
        let devicePart = forCarrierBundleInfo.supportDevice.joined(separator: "_")
        let sanitizedName = sanitizeFileName("\(forCarrierBundleInfo.carrierName)_\(devicePart)_\(forCarrierBundleInfo.version)")
        let zipTempURL = baseTmpDir.appendingPathComponent(sanitizedName).appendingPathExtension("ipcc")

        // ZIPFoundation: 压缩整个 Payload 目录（需要压缩 Payload 这个目录本身）
        try fileManager.zipItem(at: payloadDir, to: zipTempURL)

        // 6/7. 复制到 Documents/IPCC 目录
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ipccDir = documentsDir.appendingPathComponent("IPCC", isDirectory: true)
        if !fileManager.fileExists(atPath: ipccDir.path) {
            try fileManager.createDirectory(at: ipccDir, withIntermediateDirectories: true)
        }

        let finalURL = ipccDir.appendingPathComponent(sanitizedName).appendingPathExtension("ipcc")
        try? fileManager.removeItem(at: finalURL)
        try fileManager.copyItem(at: zipTempURL, to: finalURL)

        // 8. 返回导出路径
        return finalURL
    }

    /// 简单文件名清理（移除非法字符）
    private static func sanitizeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|\n\r\t")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    /// 删除指定IPCC的方法
    static func deleteInstalledCarrierBundle(forCarrierBundleInfo: CarrierBundleInfo) throws {
        let basePath = "/private/var/mobile/Library/Carrier Bundles/\(getDeviceTypeBasePath())"
        let fileManager = FileManager.default
        
        // 安全校验：必须在指定目录下
        let bundlePath = forCarrierBundleInfo.bundlePath.path
        guard bundlePath.hasPrefix(basePath) else {
            NSLog("[CellularInfo]<CarrierBundle> invalid path: \(bundlePath)")
            throw CarrierBundleError.invalidPath
        }
        
        // 文件不存在直接抛异常
        guard fileManager.fileExists(atPath: bundlePath) else {
            NSLog("[CellularInfo]<CarrierBundle> path not exist: \(bundlePath)")
            throw CarrierBundleError.fileNotFound
        }
        
        // 判断是否被锁定
        let (pathLockedResult, paths) = IPCCManagerController.getCarrierBundleLockStatus()
        if !pathLockedResult {
            throw CarrierBundleError.pathLocked(paths)
        }
        
        do {
            try fileManager.removeItem(at: forCarrierBundleInfo.bundlePath)
            // 删除对应 SupportedSIMs 的软链接
            let baseURL = URL(fileURLWithPath: basePath)
            if let contents = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) {
                for item in contents {
                    let values = try? item.resourceValues(forKeys: [.isSymbolicLinkKey])
                    if values?.isSymbolicLink == true {
                        // 如果软链接名称在 SupportedSIMs 列表中，则删除
                        if forCarrierBundleInfo.supportSIMs.contains(item.lastPathComponent) {
                            try? fileManager.removeItem(at: item)
                            NSLog("[CellularInfo]<CarrierBundle> removed symlink: \(item.path)")
                        }
                    }
                }
            }
            NSLog("[CellularInfo]<CarrierBundle> removed bundle: \(bundlePath)")
            
            // 刷新IPCC状态
            do {
                if try !refreshCarrierBundles() {
                    throw CarrierBundleError.resetCarrierBundleFailed
                }
            } catch let error as NSError {
                NSLog("[CellularInfo]<CarrierBundle> failed domain=%@ code=%ld desc=%@",
                      error.domain, error.code, error.localizedDescription)
                throw CarrierBundleError.underlying(error)
            }
            
        } catch {
            NSLog("[CellularInfo]<CarrierBundle> remove failed: \(error)")
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 1 {
                throw CarrierBundleError.permissionDenied
            }
            throw CarrierBundleError.underlying(nsError)
        }
    }
    
    /// 获取Carrier Bundle目录下面的各种目录
    private static func getCarrierBundleRuntimePathList() -> [String] {
        let basePath = "/var/mobile/Library/Carrier Bundles" // 主目录
        let bundleLinksPath = "/var/mobile/Library/Carrier Bundles/BundleLinks" // 低版本iOS不在这里
        let carrierBundlePath = "/var/mobile/Library/Carrier Bundles/\(getDeviceTypeBasePath())" // IPCC安装目录
        let libraryPath = "/var/mobile/Library/Carrier Bundles/Library" // 低版本iOS不在这里
        let libraryPreferencesPath = "/var/mobile/Library/Carrier Bundles/Library/Preferences" // 低版本iOS不在这里
        let overlayPath = "/var/mobile/Library/Carrier Bundles/Overlay"
        
        return [basePath, bundleLinksPath, libraryPath, libraryPreferencesPath,carrierBundlePath, overlayPath]
    }
    
    /// 判断CarrierBundle目录是否全部可写（基于运行时路径列表）
    static func isCarrierBundleFullyWritable() -> Bool {
        return getCarrierBundleRuntimePathList()
            .filter {
                FileManager.default.fileExists(atPath: $0) // 仅保留存在的目录
            }
            .allSatisfy {
                FileUtils.isOwnerWritable($0) // 判断权限
            }
    }
    
    /// 获取CarrierBundle目录锁定状态（返回被锁定的路径列表）
    static func getCarrierBundleLockStatus() -> (result: Bool, path: [String]) {
        let existingPaths = getCarrierBundleRuntimePathList()
            .filter { FileManager.default.fileExists(atPath: $0) } // 仅保留存在的目录
        
        let lockedPaths = existingPaths.filter {
            !FileUtils.isOwnerWritable($0)
        }
        
        return (lockedPaths.isEmpty, lockedPaths)
    }

    /// 获取IPCC安装目录权限情况
    static func getCarrierBundlePathWriteable() -> InfoItem {
        if AppCapability.checkCarrierBundleReadPermission() { // 判断是否有权限
            let (result, paths) =  IPCCManagerController.getCarrierBundleLockStatus()
            if result {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundlePath,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleRuntimePathStatus", comment: ""), NSLocalizedString("ReadAndWrite", comment: ""))
                )
            } else {
                return InfoItem(
                    id: CoreTelephonyItemID.carrierBundlePath,
                    text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleRuntimePathStatus", comment: ""), String.localizedStringWithFormat(NSLocalizedString("RestrictedAndPath", comment: ""), paths.joined(separator: "\n"))),
                    detailText: paths.joined(separator: "\n"), // 放到detail里面方便来复制
                    copyable: true
                )
            }
        } else {
            return InfoItem(
                id: CoreTelephonyItemID.carrierBundlePath,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleRuntimePathStatus", comment: ""), NSLocalizedString("NoPermission", comment: ""))
            )
        }
        
    }
    
    /// 获取IPCC文件兼容性检测结果
    static func getIPCCCompatibilityCheckResult(path: URL) throws -> [InfoItemGroup] {
        let checkInfo = try IPCCFileCompatibilityCheck(path: path) // 直接调用检测函数
        
        // 第一组 IPCC文件基本信息
        let IPCCFileInfo = InfoItemGroup(id: CellularDataItemGroupID.IPCCFileInfo, titleText: NSLocalizedString("IPCCFileInfo", comment: ""), items: [
            InfoItem(
                id: CommonItemID.carrierName,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierName", comment: ""), checkInfo.carrierBundleInfo.carrierName)
            ),
            InfoItem(
                id: CoreTelephonyItemID.carrierBundleVersion,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleVersion", comment: ""), checkInfo.carrierBundleInfo.version)
            ),
            InfoItem(
                id: CoreTelephonyItemID.carrierBundleSupportsDevices,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsDevices", comment: ""), checkInfo.carrierBundleInfo.supportDevice.joined(separator: "\n")),
                detailText: checkInfo.carrierBundleInfo.supportDevice.joined(separator: "\n"),
                copyable: true
            ),
            InfoItem(
                id: CoreTelephonyItemID.carrierBundleSupportsSIMs,
                text: String.localizedStringWithFormat(NSLocalizedString("CarrierBundleSupportsSIM", comment: ""), checkInfo.carrierBundleInfo.supportSIMs.joined(separator: "\n")),
                detailText: checkInfo.carrierBundleInfo.supportSIMs.joined(separator: "\n"),
                copyable: true
            ),
        ])
        
        // 第二组 IPCC文件兼容性
        let compatibilityCheckResultGroup = InfoItemGroup(id: CellularDataItemGroupID.IPCCCompatibility, titleText: NSLocalizedString("CompatibilityCheckResult", comment: ""), items: [
            InfoItem(
                id: checkInfo.issues.contains(.deviceNotSupported) ? 0 : 1, // 因为不想给InfoItem加字段了，所以用ID来当状态
                text: NSLocalizedString("DeviceCompatibility", comment: ""),
                detailText: checkInfo.issues.contains(.deviceNotSupported) ? NSLocalizedString("Incompatible", comment: "") : NSLocalizedString("Compatible", comment: "")
            ),
            InfoItem(
                id: checkInfo.issues.contains(.belowSystemVersion) ? 0 : 1,
                text: NSLocalizedString("SystemCompatibility", comment: ""),
                detailText: checkInfo.issues.contains(.belowSystemVersion) ? NSLocalizedString("BelowSystemVersion", comment: "") : NSLocalizedString("Installable", comment: "")
            )
        ])
        
        // 判断是否有SPI权限
        if AppCapability.hasCommCenterSPI() {
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: checkInfo.issues.contains(.duplicateInstall) ? 0 : 1,
                text: NSLocalizedString("DuplicateInstallCheck", comment: ""),
                detailText: checkInfo.issues.contains(.duplicateInstall) ? NSLocalizedString("DuplicateInstall", comment: "") : NSLocalizedString("Installable", comment: "")
            ))
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: checkInfo.issues.contains(.versionDowngrade) ? 0 : 1,
                text: NSLocalizedString("VersionCompatibility", comment: ""),
                detailText: checkInfo.issues.contains(.versionDowngrade) ? NSLocalizedString("DowngradeInstall", comment: "") : NSLocalizedString("Installable", comment: "")
            ))
        } else {
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: -1,
                text: NSLocalizedString("DuplicateInstall", comment: ""),
                detailText: NSLocalizedString("NoPermission", comment: "")
            ))
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: -1,
                text: NSLocalizedString("VersionCompatibility", comment: ""),
                detailText: NSLocalizedString("NoPermission", comment: "")
            ))
            
        }
        
        // 判断安装目录是否可以有权限
        if AppCapability.checkCarrierBundleReadPermission() {
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: checkInfo.issues.contains(.installPathLocked) ? 0 : 1,
                text: NSLocalizedString("InstallPathAccess", comment: ""),
                detailText: checkInfo.issues.contains(.installPathLocked) ? NSLocalizedString("Restricted", comment: "") : NSLocalizedString("ReadAndWrite", comment: "")
            ))
        } else {
            compatibilityCheckResultGroup.addItem(InfoItem(
                id: -1,
                text: NSLocalizedString("InstallPathAccess", comment: ""),
                detailText: NSLocalizedString("NoPermission", comment: ""),
            ))
        }
        
        // 第三组 用户安装IPCC
        let installThisIPCCGroup = InfoItemGroup(id: CellularDataItemGroupID.installIPCC)
        
        let installSelectIPCCFile: InfoItem
        if AppCapability.hasCommCenterSPI() {
            if checkInfo.issues.isEmpty {
                installSelectIPCCFile = InfoItem(id: ActionItemID.installSelectIPCC, text: NSLocalizedString("InstallThisIPCC", comment: ""))
                installSelectIPCCFile.detailText = String.localizedStringWithFormat(
                    NSLocalizedString("ConfirmInstallIPCCMessage", comment: ""),
                    checkInfo.carrierBundleInfo.carrierName, // IPCC文件的运营商名称
                    checkInfo.carrierBundleInfo.version // IPCC文件的版本
                )
            } else {
                installSelectIPCCFile = InfoItem(id: ActionItemID.installSelectIPCCWithWarning, text: NSLocalizedString("InstallThisIPCC", comment: ""))
                installSelectIPCCFile.detailText = String.localizedStringWithFormat(
                    NSLocalizedString("ConfirmInstallIPCCWithWarningMessage", comment: ""),
                    checkInfo.carrierBundleInfo.carrierName, // IPCC文件的运营商名称
                    checkInfo.carrierBundleInfo.version // IPCC文件的版本
                )
            }
        } else {
            // 使用电脑刷入就行
            if checkInfo.issues.isEmpty {
                installSelectIPCCFile = InfoItem(
                    id: ActionItemID.installSelectIPCCUseComputer, text: NSLocalizedString("UseComputerInstallThisIPCC", comment: ""),
                    detailText: NSLocalizedString("UseComputerInstallThisIPCCMessage", comment: "")
                )
            } else {
                // 存在风险
                installSelectIPCCFile = InfoItem(
                    id: ActionItemID.installSelectIPCCUseComputerWithWarning, text: NSLocalizedString("UseComputerInstallThisIPCC", comment: ""),
                    detailText: NSLocalizedString("UseComputerInstallThisIPCCWithWarningMessage", comment: "")
                )
            }
            
        }
        
        installThisIPCCGroup.addItem(installSelectIPCCFile)
        
        return [IPCCFileInfo, compatibilityCheckResultGroup, installThisIPCCGroup]
    }
    
}

