import Foundation
import UIKit

class ReferenceAndAcknowledgementsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var tableView = UITableView()
    
    private let tableCellList = [
        InfoItemGroup(id: 0, titleText: NSLocalizedString("OpenSourceComponents", comment: ""),
                     items: [
                        InfoItem(id: 1, text: "ZIP Foundation", hintText: "https://github.com/weichsel/ZIPFoundation"),
                        InfoItem(id: 2, text: "Windows XP icon", hintText: "https://github.com/marchmountain/-Windows-XP-High-Resolution-Icon-Pack"),
                        InfoItem(id: 3, text: "Windows 7 icon", hintText: "https://win7icons.visnalize.com/"),
                        InfoItem(id: 4, text: "Windows 10 & Windows 11 icon", hintText: "https://logos.fandom.com/wiki/Mobile_Plans"),
                     ]),
        InfoItemGroup(id: 1, titleText: NSLocalizedString("DevelopmentResources", comment: ""),
                      items: [
                        InfoItem(id: 1, text: "Limneos", detailText: NSLocalizedString("ProvideCoreTelephonyHeadFile", comment: ""), hintText: "https://developer.limneos.net/"),
                        InfoItem(id: 2, text: "OwnGoal Studio & 82flex", detailText: NSLocalizedString("ProvideCoreTelephonyHeadFile", comment: ""), hintText: "https://headers.82flex.com/"),
                        InfoItem(id: 3, text: "IPCCInstaller", detailText: "_CTServerConnectionInstallCarrierBundle", hintText: "https://github.com/Netskao"),
                      ]),
        InfoItemGroup(id: 2, titleText: NSLocalizedString("References", comment: ""),
                      items: [
                        InfoItem(id: 1,
                                 text: "3GPP TS 36.101 Release-17",
                                 detailText: "Transmission bandwidth configuration (NRB mapping), Table 5.6‑1, p.73", hintText: "https://www.etsi.org/deliver/etsi_ts/136100_136199/136101/17.06.00_60/ts_136101v170600p.pdf"),
                        InfoItem(id: 2,
                                 text: "ShareTechnote",
                                 detailText: NSLocalizedString("NRSubcarrierSpacingDataAndTechnicalDetails", comment: ""),
                                 hintText: "https://www.sharetechnote.com/html/5G/5G_Phy_Numerology.html"),
                        InfoItem(id: 3,
                                 text: "3GPP TS 38.300 Release-16",
                                 detailText: "NR overall description; BWP activation/deactivation mechanism, §10.6, p.96–97",
                                 hintText: "https://www.etsi.org/deliver/etsi_ts/138300_138399/138300/16.04.00_60/ts_138300v160400p.pdf"
                        ),
                        InfoItem(id: 4,
                                 text: "Keysight – Understanding 5G NR BWP",
                                 detailText: "Engineering interpretation of BWP, including UE capability, DL/UL separation, and dynamic bandwidth adaptation",
                                 hintText: "https://www.keysight.com/blogs/en/inds/2018/10/31/understanding-5g-new-radio-bandwidth-parts"
                        ),
                        InfoItem(id: 5,
                                 text: "Huawei BWP Overview",
                                 detailText: "Conceptual explanation of BWP, including multiple BWP configurations and dynamic switching behavior",
                                 hintText: "https://sg.o3community.huawei.com/sg/en/forum/1358950823329681409?blogId=668090880327827456"
                        )
                      ]),
        
        InfoItemGroup(id: 3, titleText: NSLocalizedString("Acknowledgements", comment: ""),
                      items: [
                        InfoItem(id: 9, text: "酷安@简单yi点点", detailText: NSLocalizedString("HelpTestAndProductImprovement", comment: ""), hintText: "http://www.coolapk.com/u/1137700"),
                        InfoItem(id: 10, text: "酷安@哥哥i", detailText: NSLocalizedString("HelpTest", comment: ""), hintText: "https://www.coolapk.com/u/504145"),
                      ], footerText: NSLocalizedString("ThanksBetaTestingMemberMessage", comment: ""))
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = NSLocalizedString("ReferenceAndAcknowledgements", comment: "")
        
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
    
    // MARK: - 设置每个分组的顶部标题
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableCellList[section].titleText
    }
    
    // MARK: - 设置每个分组的底部标题 可以为分组设置尾部文本，如果没有尾部可以返回 nil
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return tableCellList[section].footerText
    }
    
    // MARK: - 构造每个Cell
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        
        // 设置主标题
        cell.textLabel?.text = tableCellList[indexPath.section].items[indexPath.row].text
        cell.textLabel?.numberOfLines = 0 // 允许换行
        // 设置副标题
        cell.detailTextLabel?.text = tableCellList[indexPath.section].items[indexPath.row].detailText
        cell.detailTextLabel?.numberOfLines = 0 // 允许换行
        
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default // 启用选中效果
        
        return cell
        
    }
    
    // MARK: - Cell的点击事件
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        UIUtils.showAlertToUseDefaultBrowserOpenLink(URL: tableCellList[indexPath.section].items[indexPath.row].hintText, in: self)
        
    }
}
