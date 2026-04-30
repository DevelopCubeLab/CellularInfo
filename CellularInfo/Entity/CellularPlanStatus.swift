import Foundation

class CellularPlanStatus {
    
    // 蜂窝数据卡总数
    let count: Int
    // 物理SIM卡总数
    let physicalSIMCont: Int
    // eSIM总数
    let eSIMCount: Int
    // Apple SIM总数
    let appleSIMCount: Int
    // 启用的蜂窝数据卡数量
    let enabledPlanCount: Int
    // 原始数据放进去
    let plans: [CTCellularPlanItem]
    
    init(count: Int, physicalSIMCont: Int, eSIMCount: Int, appleSIMCount: Int = 0, enabledPlanCount: Int, plans: [CTCellularPlanItem]) {
        self.count = count
        self.physicalSIMCont = physicalSIMCont
        self.eSIMCount = eSIMCount
        self.appleSIMCount = appleSIMCount
        self.enabledPlanCount = enabledPlanCount
        self.plans = plans
    }
}
