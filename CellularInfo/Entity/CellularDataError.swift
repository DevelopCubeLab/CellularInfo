import Foundation
import UIKit


enum CarrierBundleError: Error {
    
    case permissionDenied               // 无权限
    case operationFailed                // 操作失败
    case pathLocked([String])           // 目录被锁定
    case invalidPath                    // 非法路径
    case fileNotFound                   // 找不到指定目录
    case removeFailed                   // 删除文件失败
    
    case connectionFailed               // 连接到CommCenter服务失败
    case timeout                        // 操作超时
    
    case invalidIPCCFile                // 非法的IPCC文件
    case stagingFailed                  // 复制到中间路径失败
    case installFailed                  // 安装失败
    case resetCarrierBundleFailed       // 重置IPCC失败
    case noCarrierBundleInstalled       // 没有安装IPCC
    
    case underlying(Error)              // 未知错误
    
}

extension CarrierBundleError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NSLocalizedString("PermissionDenied", comment: "")
        case .operationFailed:
            return NSLocalizedString("OperationFailed", comment: "")
        case .timeout:
            return NSLocalizedString("OperationTimeout", comment: "")
        case .invalidPath:
            return NSLocalizedString("InvalidPath", comment: "")
        case .fileNotFound:
            return NSLocalizedString("FileNotFound", comment: "")
        case .removeFailed:
            return NSLocalizedString("RemoveFailed", comment: "")
            
        case .connectionFailed:
            return NSLocalizedString("ConnectionFailed", comment: "")
            
        case .invalidIPCCFile:
            return NSLocalizedString("InvalidIPCCFile", comment: "")
        case .stagingFailed:
            return NSLocalizedString("IPCCStagingFailed", comment: "")
        case .installFailed:
            return NSLocalizedString("IPCCInstallFailed", comment: "")
        case .resetCarrierBundleFailed:
            return NSLocalizedString("ResetCarrierBundleFailed", comment: "")
        case .noCarrierBundleInstalled:
            return NSLocalizedString("NoIPCCInstalled", comment: "")
            
        case .pathLocked(let paths):
            return String.localizedStringWithFormat(NSLocalizedString("PathLocked", comment: ""), paths.joined(separator: "\n"))
        case .underlying(let error):
            return String(format: NSLocalizedString("UnderlyingSystemError", comment: ""), error.localizedDescription)
        }
    }
    
    var getNSError: NSError {
        switch self {
        case .underlying(let error):
            return error as NSError
        default:
            return NSError(
                domain: "com.developlab.CellularInfo",
                code: (self as? any RawRepresentable)?.rawValue as? Int ?? -1,
                userInfo: [
                    NSLocalizedDescriptionKey: self.localizedDescription
                ]
            )
        }
    }
    
    
}

enum CoreTelephonyConnectionError: Error {
    case connectionFailed
    case apiFailed(code: Int32)
}
