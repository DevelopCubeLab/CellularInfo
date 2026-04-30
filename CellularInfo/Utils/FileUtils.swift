import Foundation
import UIKit

class FileUtils {
    
    static func getFilePermissionOctal(_ path: String) -> String? {
        var fileStat = stat()
        
        // 调用 stat 获取文件信息
        guard stat(path, &fileStat) == 0 else {
            return nil
        }
        
        // 只取权限位（忽略文件类型位）
        let perm = fileStat.st_mode & 0o777
        
        // 格式化成 0755 这种字符串
        return String(format: "%04o", perm)
    }
    
    /// 判断文件/目录是否具有“所有者写入权限”（u+w）
    static func isOwnerWritable(_ path: String) -> Bool {
        var fileStat = stat()
        
        // 获取文件信息失败，默认认为不可写
        guard stat(path, &fileStat) == 0 else {
            return false
        }
        
        // S_IWUSR = 所有者写权限位
        return (fileStat.st_mode & S_IWUSR) != 0
    }
    
    static func isActivationPolicyLocked() -> String? {
        let path = "/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return("read plist failed")
        }
        
        let raw = dict["is_activation_policy_locked"]
        
        if let str = raw as? String {
            return str
        }
        
        if let num = raw as? NSNumber {
            // CFBoolean / NSNumber fallback
            return num.boolValue ? "kTrue" : "kFalse"
        }
        
        if let b = raw as? Bool {
            return b ? "kTrue" : "kFalse"
        }
        
        if let raw = raw {
            // 最关键：兜底 description（你看到的 1:kFalse 就是这么来的）
            return String(describing: raw)
        }
        
        return nil
    }
    
    /// 确保iCloud文件已经下载到本地
    /// 如果是iCloud占位文件，则触发系统下载并等待完成
    /// iCloud文件可能只是一个占位符，必须先下载到本地才能读取，否则解析/拷贝会失败
    static func ensureFileDownloaded(url: URL, completion: @escaping (Bool) -> Void) {
        do {
            let values = try url.resourceValues(forKeys: [
                .isUbiquitousItemKey,
                .ubiquitousItemDownloadingStatusKey
            ])
            
            // 如果是iCloud文件
            if values.isUbiquitousItem == true {
                // 如果还没有下载完成
                if values.ubiquitousItemDownloadingStatus != .current {
                    
                    // 主动触发下载
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    
                    // 简单轮询等待下载完成
                    DispatchQueue.global().async {
                        while true {
                            let newValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                            if newValues?.ubiquitousItemDownloadingStatus == .current {
                                DispatchQueue.main.async {
                                    completion(true)
                                }
                                break
                            }
                            Thread.sleep(forTimeInterval: 0.2)
                        }
                    }
                    return
                }
            }
            
            // 本地文件或已下载完成
            completion(true)
            
        } catch {
            completion(false)
        }
    }
}
