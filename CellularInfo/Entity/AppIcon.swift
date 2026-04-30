import Foundation

/// App Icon数据对象
class AppIcon {
    
    // ID
    let id: Int
    // icon名称 对应Assets.xcassets里面的AppIcon名称 nil的话是默认icon
    let name: String?
    // 在UI显示的名称
    let displayName: String
    // 预览图的文件名称 一般用iPad的 会清晰很多
    let previewImageName: String
    
    init(id: Int, name: String?, displayName: String, previewImageName: String) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.previewImageName = previewImageName
    }
}

/// Icon的组
class AppIconGroup {
    var titleText: String?
    let icons: [AppIcon]
    var footerText: String?
    
    init(titleText: String? = nil, icons: [AppIcon], footerText: String? = nil) {
        self.titleText = titleText
        self.icons = icons
        self.footerText = footerText
    }
}
