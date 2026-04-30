import Foundation
import UIKit

class CTCellularPlanController {
    
    // 单例对象
    static let instance = CTCellularPlanController()
    
    private let planManager: CTCellularPlanManager = CTCellularPlanManager.shared()
    
    private init() {
        //
    }
    
    /// 获取全部数据流量卡
    /// 返回 [CTCellularPlanItem] 数组
    /// 需要 cellular-plan 和 com.apple.private.security.no-sandbox 权利
    /// iOS 14.0以上才能获取
    /// iOS 14.0以下返回的是空的
    func getCellularPlans() -> [CTCellularPlanItem] {
        var plans: [CTCellularPlanItem] = []
        let sema = DispatchSemaphore(value: 0) // 创建一个信号量为 0 的锁
        
        planManager.planItems { items in
            plans = items ?? []
            sema.signal() // 继续线程
        }
        
        sema.wait() // 挂起线程
        
        return plans
        
    }
    
    /// 获取蜂窝数据卡的数量
    /// iOS 14以下无法获取正确数量
    func getCellularPlanCount() -> Int {
        return getCellularPlans().count
    }
    
    /// 获取全部蜂窝数据卡的详细情况
    func getCellularPlansStatus() -> CellularPlanStatus {
        return getCellularPlansStatus(plans: getCellularPlans())
    }
    
    /// 获取全部蜂窝数据卡的详细情况
    func getCellularPlansStatus(plans: [CTCellularPlanItem]) -> CellularPlanStatus {
        let count = plans.count
        var physicalSIMCount = 0
        var eSIMCount = 0
        var appleSIMCount = 0
        var enabledPlanCount = 0
        
        for plan in plans {
            // 统计启用状态
            // isSelected 表示当前启用
            if plan.isSelected {
                enabledPlanCount += 1
            }
            
            // SIM卡类型判断
            switch plan.type {
            case 0:
                physicalSIMCount += 1
            case 2:
                eSIMCount += 1
            case 3:
                appleSIMCount += 1
            default:
                break
            }
        }
        
        return CellularPlanStatus(
            count: count,
            physicalSIMCont: physicalSIMCount,
            eSIMCount: eSIMCount,
            appleSIMCount: appleSIMCount,
            enabledPlanCount: enabledPlanCount,
            plans: plans
        )
    }
    
    /// 通过UUID获取某个蜂窝数据卡
    func getCellularPlanBy(UUID: String) -> CTCellularPlanItem? {
        return getCellularPlans().first { $0.uuid == UUID }
    }
    
    /// 通过ICCID获取某个蜂窝数据卡
    func getCellularPlanBy(ICCID: String) -> CTCellularPlanItem? {
        return getCellularPlans().first { $0.iccid == ICCID }
    }
    
    /// 设置蜂窝套餐卡开启/关闭 同步方法
    func setCellularPlanItem(item: CTCellularPlanItem, enable: Bool) -> Bool {
        return planManager.didSelect(item, isEnable: enable) == 0
    }
    
    /// 设置蜂窝套餐卡开启/关闭 异步方法
    /// 蜂窝数据卡不支持关闭时抛异常 错误代码 43
    func setCellularPlanItem(item: CTCellularPlanItem, enable: Bool, completion: @escaping (Error?) -> Void) {
        planManager.didSelect(item, isEnable: enable) { success, error in
            completion(error)
        }
    }
    
    /// 判断当前蜂窝数据卡是否为Apple SIM
    /// 判断标准:
    /// 1. 必须是iPad
    /// 2. 系统版本低于iOS 18
    /// 3. type为3
    func getPlanIsAppleSIM(ICCID: String?) -> Bool {
        if let ICCID = ICCID {
            if CellularDataController.instance.getDeviceType() == .pad {
                if #unavailable(iOS 18.0) {
                    if let plan = getCellularPlanBy(ICCID: ICCID) {
                        return plan.type == 3
                    }
                }
            }
        }
        return false
    }
}
