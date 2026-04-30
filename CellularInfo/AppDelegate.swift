import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        if #unavailable(iOS 12.0) {
            NSLog("[CellularInfo] Not Supported current iOS version")
            exit(0)
        }
        
        // 设置App语言（必须在加载 UI 之前）
        ApplicationLanguageController.loadLanguageFromSettings()
        
        // 检查设置
        SettingsUtils.instance.checkShowLockNetworkMode()
        
        // 加载root view
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = MainUITabBarController()
        window!.makeKeyAndVisible()
        return true
    }

    /// App从后台返回前台的调用方法
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 发送通知
        NotificationCenter.default.post(name: CellularDataController.cellularDataRefreshNotificationName, object: nil)
    }
    
    /// 分享ipcc文件到app以后的处理方法
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleIncomingIPCC(url: url)
        return true
    }
    
    private func handleIncomingIPCC(url: URL) {
        guard url.pathExtension.lowercased() == "ipcc" else { return }
        
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let tabBar = window.rootViewController as? MainUITabBarController else {
                return
            }
            
            // 切换tab到工具这个tab
            tabBar.selectedIndex = 2
            
            guard let nav = tabBar.selectedViewController as? UINavigationController else {
                    return
                }
                
            // 先判断是不是用户恰好在IPCC管理界面
            if let managerViewController = nav.topViewController as? IPCCManagerViewController {
                // 已经在这个页面 直接调用
                managerViewController.importIPCCFileFromOtherApplication(url: url)
                
            } else { // 不在就创建VC并且push打开
                let managerViewController = IPCCManagerViewController()
                nav.pushViewController(managerViewController, animated: true)
                // 等动画都加载完成再去刷IPCC
                DispatchQueue.main.async {
                    // 调用安装IPCC的方法 这样才能保证弹窗出现
                    managerViewController.receiveFileFromOtherApplication(url: url)
                }
            }
        }
    }

}

