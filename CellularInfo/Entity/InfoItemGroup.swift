import Foundation

class InfoItemGroup {
    
    let id: Int                           // 组id
    var titleText: String?                // 顶部文本
    private(set) var items: [InfoItem]    // 这一组的内容
    var footerText: String?               // 底部文本
    
    init(id: Int) {
        self.id = id
        self.items = []
    }
    
    init(id: Int, items: [InfoItem]) {
        self.id = id
        self.items = items
    }
    
    init(id: Int, titleText: String) {
        self.id = id
        self.titleText = titleText
        self.items = []
    }
    
    init(id: Int, titleText: String, items: [InfoItem]) {
        self.id = id
        self.titleText = titleText
        self.items = items
    }
    
    init(id: Int, items: [InfoItem], footerText: String) {
        self.id = id
        self.items = items
        self.footerText = footerText
    }
    
    init(id: Int, titleText: String?, items: [InfoItem], footerText: String?) {
        self.id = id
        self.titleText = titleText
        self.items = items
        self.footerText = footerText
    }
    
    // 添加单个条目
    func addItem(_ item: InfoItem) {
        self.items.append(item)
    }

    // 添加不为nil的项目
    func addItemIfPresent(_ item: InfoItem?) {
        if let item = item {
            addItem(item)
        }
    }
    
    // 如果不存在相同ID才添加
    func addItemIfNotExists(_ item: InfoItem) {
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
        }
    }
    
    // 在index加入新条目
    func addItem(_ item: InfoItem, at index: Int) {
        if index >= 0 && index <= items.count {
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
    }
    
    // 在某个ID后插入新条目
    func addItem(_ item: InfoItem, afterID targetID: Int) {
        // 如果已存在相同ID则不插入
        if items.contains(where: { $0.id == item.id }) {
            return
        }

        if let index = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: index + 1)
        } else {
            items.append(item)
        }
    }
    
    // 在某个ID前插入新条目
    func addItem(_ item: InfoItem, beforeID targetID: Int) {
        // 如果已存在相同ID则不插入
        if items.contains(where: { $0.id == item.id }) {
            return
        }

        if let index = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
    }
    
    // 添加多个条目
    func addItems(_ newItems: [InfoItem]) {
        self.items.append(contentsOf: newItems)
    }
    
    // 更新item
    func updateItem(_ newItem: InfoItem) {
        if let index = items.firstIndex(where: { $0.id == newItem.id }) {
            items[index] = newItem
        }
    }

    // 删除指定ID的所有条目
    func removeItems(withID targetID: Int) {
        self.items.removeAll { $0.id == targetID }
    }

    // 清空所有条目
    func clearItems() {
        self.items.removeAll()
    }
    
    // 随机打乱条目顺序
    func shuffleItems() {
        items.shuffle()
    }
}
