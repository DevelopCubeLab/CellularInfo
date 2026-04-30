import Foundation

class CarrierBundleInfo {
    
    /// 运营商名称
    let carrierName: String
    
    /// IPCC版本
    let version: String
    
    /// 运营商配置文件所在路径
    /// 为管理运营商配置文件准备
    let bundlePath: URL
    
    /// 运营商配置文件支持的SIM
    /// 为管理运营商配置文件准备
    let supportSIMs: [String]
    
    /// 运营商配置文件支持的主板ID
    let supportDevice: [String]
    
    init(carrierName: String, version: String, bundlePath: URL, supportSIMs: [String] = [], supportDevice: [String]) {
        self.carrierName = carrierName
        self.version = version
        self.bundlePath = bundlePath
        self.supportSIMs = supportSIMs
        self.supportDevice = supportDevice
    }
}
