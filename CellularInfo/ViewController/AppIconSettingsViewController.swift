import Foundation
import UIKit

class AppIconSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let settingsUtils = SettingsUtils.instance
    
    private var tableView = UITableView()
 
    private let tableCellList: [AppIconGroup] = [
        AppIconGroup(titleText: nil, icons: [
            AppIcon(id: 0, name: nil, displayName: NSLocalizedString("DefaultIcon", comment: ""), previewImageName: "AppIcon76x76@2x~ipad")
        ]),
        AppIconGroup(titleText: "Windows®", icons: [
            AppIcon(id: 1, name: "AppIconWinXP", displayName: "Windows XP", previewImageName: "AppIconWinXP76x76@2x~ipad"),
            AppIcon(id: 2, name: "AppIconWin7", displayName: "Windows 7", previewImageName: "AppIconWin776x76@2x~ipad"),
            AppIcon(id: 3, name: "AppIconWin10", displayName: "Windows 10", previewImageName: "AppIconWin1076x76@2x~ipad"),
            AppIcon(id: 4, name: "AppIconWin11", displayName: "Windows 11", previewImageName: "AppIconWin1176x76@2x~ipad"),
        ])
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("AppIconSettings", comment: "")
        
        // iOS 15 之后的版本使用新的UITableView样式
        if #available(iOS 15.0, *) {
            tableView = UITableView(frame: .zero, style: .insetGrouped)
        } else {
            tableView = UITableView(frame: .zero, style: .grouped)
        }

        // 设置表格视图的代理和数据源
        tableView.delegate = self
        tableView.dataSource = self
        
        // 注册表格单元格
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        // 将表格视图添加到主视图
        view.addSubview(tableView)

        // 设置表格视图的布局
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
    }
    
    // MARK: - 设置总分组数量
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableCellList.count
    }
    
    // MARK: - 设置每个分组的Cell数量
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableCellList[section].icons.count
    }
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableCellList[section].titleText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = tableCellList[indexPath.section].icons[indexPath.row].displayName
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        cell.selectionStyle = .default
        
        // 当前icon
        let icon = tableCellList[indexPath.section].icons[indexPath.row]
        
        // 获取选择的icon名称
        // iOS 26 无法获取更改后的icon名称
        let currentIcon = settingsUtils.getApplicationIconName()
        
        if let path = Bundle.main.path(forResource: icon.previewImageName, ofType: "png") {
            cell.imageView?.image = UIImage(contentsOfFile: path)
            cell.accessoryType = (currentIcon == icon.name) ? .checkmark : .none
        }
        
        // 调整图片大小更紧凑
        let size = CGSize(width: 55, height: 55)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        cell.imageView?.image?.draw(in: CGRect(origin: .zero, size: size))
        cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        // 圆角 iOS 图标宽度*0.223 就是圆角
        cell.imageView?.layer.cornerRadius = 12
        cell.imageView?.clipsToBounds = true
        // 添加边框以增强视觉区分
        if #available(iOS 13.0, *) {
            cell.imageView?.layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
        } else {
            cell.imageView?.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        }
        cell.imageView?.layer.borderWidth = 3.0 / UIScreen.main.scale // 给OLED屏幕优化下，这样可以对齐到像素
        
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 当前icon
        let icon = tableCellList[indexPath.section].icons[indexPath.row]
        
        // 切换功能在iOS 18无法生效 在低于iOS 18或者iOS 26可以生效
        settingsUtils.setApplicationIconName(iconName: icon.name) { error in
            if case let error as NSError = error { // 如果出现错误就显示错误提示
                if error.code == -54 { // iOS 18证书签名安装专属错误 必须Bundle ID和描述文件的匹配 否则无法切换icon
                    UIUtils.showAlert(message: NSLocalizedString("ChangeIconFailedMessage", comment: ""), in: self)
                }
                UIUtils.showAlert(message: String.localizedStringWithFormat(NSLocalizedString("ErrorWithCodeReason", comment: ""),  error.code, error.localizedDescription), in: self)
                return
            }
            
            // 刷新UI
            tableView.reloadData()
        }
        
        
        
    }
    
}
