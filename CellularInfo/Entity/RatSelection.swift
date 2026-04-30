import Foundation
import UIKit

/// 给低版本的兼容层
/// 系统头文件 CTRatSelection.h
/// 系统默认支持iOS 14.0+
class RatSelection {
    
    let selection: String
    
    let preferred: String
    
    init(selection: String, preferred: String) {
        self.selection = selection
        self.preferred = preferred
    }
}
