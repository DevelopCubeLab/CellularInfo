import Foundation

// 每一个item的具体数据模型
class InfoItem {
    
    let id: Int                // id
    var text: String           // 文本
    var detailText: String?    // 副文本
    var hintText: String?      // 说明文本
    let isConfidential: Bool   // 是否是机密信息 比如IMEI这些
    let copyable: Bool         // 是否显示复制按钮
    
    init(id: Int, text: String, detailText: String? = nil, hintText: String? = nil, isConfidential: Bool = false, copyable: Bool = false) {
        self.id = id
        self.text = text
        self.detailText = detailText
        self.hintText = hintText
        self.isConfidential = isConfidential
        self.copyable = copyable
    }
}
