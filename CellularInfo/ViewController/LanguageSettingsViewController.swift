import Foundation
import UIKit

class LanguageSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private let settingsUtils = SettingsUtils.instance
    
    private let tableCellList = [InfoItemGroup(id: 0, items: [
        InfoItem(id: 0, text: NSLocalizedString("UseSystemLanguage", comment: "")),
        InfoItem(id: 1, text: "English"),
        InfoItem(id: 2, text: "简体中文")
    ])]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("LanguageSettings", comment: "")
        
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
        return tableCellList[section].items.count
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
        cell.textLabel?.numberOfLines = 0 // 允许换行
        
        cell.selectionStyle = .default
        if indexPath.row == settingsUtils.getApplicationLanguage().rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
            
        return cell
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 取消之前的选择
        tableView.cellForRow(at: IndexPath(row: settingsUtils.getApplicationLanguage().rawValue, section: indexPath.section))?.accessoryType = .none
        // 保存选项
        settingsUtils.setApplicationLanguage(value: indexPath.row)
        // 设置当前的cell选中状态
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        
        // 刷新界面显示
        ApplicationLanguageController.loadLanguageFromSettings()
        reloadAppRootView()
        
    }
    
    func reloadAppRootView() {
        guard let window = UIApplication.shared.windows.first else { return }

        let tabBarController = MainUITabBarController()
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        // 在设置导航控制器中重新 push LanguageSettingsViewController
        if let settingsNav = tabBarController.viewControllers?[3] as? UINavigationController {
            
            // 切换到设置的tab
            tabBarController.selectedIndex = 3
            
            // 拿到设置的root view controller 这样切换后左上角的返回就不是 < 返回  变成 < 设置 着呀不会让用户觉得是App View重建了
            if let settingsVC = settingsNav.viewControllers.first {
                settingsVC.navigationItem.backButtonTitle =
                    NSLocalizedString("Settings", comment: "")
            }

            // 重新将界面语言的View Controller Push出来
            let languageVC = LanguageSettingsViewController()
//            languageVC.hidesBottomBarWhenPushed = true // 隐藏底部导航栏
            settingsNav.pushViewController(languageVC, animated: false) // 不需要动画
        }
        
    }
}
