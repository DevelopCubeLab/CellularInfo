# CellularInfo 蜂窝网络数据

<p align="center">
  <a href="https://github.com/DevelopCubeLab/CellularInfo/stargazers">
    <img src="https://img.shields.io/github/stars/DevelopCubeLab/CellularInfo?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/DevelopCubeLab/CellularInfo/issues">
    <img src="https://img.shields.io/github/issues/DevelopCubeLab/CellularInfo" alt="GitHub issues">
  </a>
</p>

[⬅️ English](https://github.com/DevelopCubeLab/CellularInfo)
 
## 项目介绍

本应用是一款面向iOS的蜂窝网络诊断与分析工具，可查询多达 **160+** 项来自CoreTelephony及系统底层的蜂窝网络数据。

应用提供对设备信息、SIM卡信息、运营商配置（IPCC）、网络制式（RAT）、网络状态以及多种底层蜂窝参数的详细解析。通过结合系统公开接口与逆向分析得到的私有接口，实现了对常规iOS设备难以获取的数据的可视化展示。并且提供了IPCC管理和兼容性检测以及设置网络类型的功能。

项目最低支持 iOS **12.0**，仅适用于 **iPhone 和蜂窝版 iPad**。  

不支持不具备蜂窝通信能力的设备，包括 iPod Touch、Wi-Fi 版 iPad、Xcode模拟器以及虚拟机环境（例如 VPhone）。  

需要越狱或TrollStore安装，开发者证书签名安装可获取少部分数据  
  
本项目不会支持iOS 12.0以下系统版本，因为`CoreTelephonyClient`需要iOS 12.0+

本工具主要面向开发者、安全研究人员以及对 iOS 蜂窝网络机制有深入需求的高级用户。为了保证您的设备数据安全，请勿在非官方来源下载此项目的安装包，app内的数据请勿在未受保护的情况下发送给他人。

如果您对CoreTelephony感兴趣，可以直接查看整理好的  [`CoreTelephonyClient.h`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Head/CoreTelephonyClient.h)
[`CoreTelephonyController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/CoreTelephonyController.swift)
[`CellularDataController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/CellularDataController.swift)  
包含了状态注释和出现错误的情况  

安装IPCC的相关内容  
[`IPCCManagerController.m`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/IPCCManagerController.m)
[`IPCCManagerController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/IPCCManagerController.swift)

> [!NOTE]
> 由于部分蜂窝网络相关的专业术语与技术细节仍在研究与验证中，应用内可能存在不准确或错误的信息。  
> 如果您是通信或网络相关领域的专业人士，并发现应用中的错误内容，欢迎提交 issue，我们会及时进行修正与改进。

> [!WARNING]
由于该项目内使用到的私有API过多，每个iOS版本测试不一定能覆盖全，如果出现闪退的情况，或错误代码等情况，请提供崩溃日志`ips`文件，提交issue

## 安装

| 系统版本 | 安装方法 | 备注 |
|----------|------|------|
| iOS 17.0+ 暂时无法越狱设备 | 开发者证书签名安装([数据受限](#10-无需额外权利可以查询的数据)) | 使用AltStore、SideStore、LiveContainer、LCSign、Esign等各类签名工具均可安装 | 
| iOS 17.0+ 可越狱设备(A10 / A11) | 越狱+TrollStore Lite安装 | - | 
| iOS 14.0 - iOS 16.6.1 和 iOS 17.0  | 使用TrollStore安装 | - | 
| iOS 12.2 - iOS 13.x | 越狱安装 | 需要单独安装RootHelper | 
| iOS 12.0 - iOS 12.1.x | 越狱安装 | 需要选择支持iOS 12.0的ipa文件安装，需要单独安装RootHelper | 

## 工作原理
<img width="800" alt="How CellularInfo Works" src="https://github.com/user-attachments/assets/40729eb6-c84b-4723-a948-0a69c21cc4ea" />

## 数据

### 1. 以下功能或数据需要 iOS 17.0+
>
* 设备是否支持2G开关
* 用户是否开启2G网络
* 设备是否开启蜂窝数据用量统计
* 需要显示eSIM漫游提示
* NR状态(5G SA和5G NSA) **(已使用备用方法兼容至iOS 14.0+)**
* 蜂窝数据用量工作区信息 **(原始数据)**

### 2. 以下功能或数据需要 iOS 16.4+
>
* 设备是否SIM卡已就绪 **(已使用备用方法兼容至iOS 12.0+)**

### 3. 以下功能或数据需要 iOS 16.0+
>
* 设备是否支持eSIM **(已使用备用方法兼容至iOS 12.0+)**
* 设备仅支持eSIM [(已使用设备支持情况兼容至iOS 12.0+)](https://support.apple.com/zh-cn/111850)
* 当前连接的网络名称 **(已使用备用方法兼容至iOS 12.0+)**
* 设备eSIM 健康状况
* 设备允许安装开发签名的IPCC (Carrier Bundle)
* 设备允许紧急呼叫号码列表
* 设备是否需要设置eSIM
* 设备正在使用eSIM下载服务
* 私有网络SIM卡
* Should Show Branded Calling Info **(原始数据)**

### 4. 以下功能或数据需要 iOS 15.4+
>
* 设备处于工厂调试模式
* 基带候选(RC)版本固件
* 蜂窝数据 **(基本信息)** **(备用方法显示完整信息兼容至iOS 12.0+)**

### 5. 以下功能或数据需要 iOS 15.0+
>
* 基带中的设备信息
* 运营商的英文名称
* SIM所在的位置
* 设备与运营商允许使用个人热点
* 是否开启个人热点
* iCloud专用代理启用状态
* 限制IP地址跟踪启用状态
* 设备是否支持专用承载
* 设备是否支持Hydra
* SIM硬件信息 **(原始数据)**
* 网络共享状态信息 **(原始数据)**
* 数据载体 **(原始数据)**  **(已使用备用方法兼容至iOS 14.0+)**
* 锁定网络类型 **(已使用备用方法兼容至iOS 12.0+)**
* 还原运营商配置文件为系统默认版本 **(已使用备用方法兼容至iOS 12.0+)**

### 6. 以下功能或数据需要 iOS 14.0+
> [!WARNING]
**所有与5G网络相关的数据**  
>
* 运营商锁状态 **(不支持蜂窝版iPad)**
* 设备是否支持5G **(已使用设备支持情况兼容至iOS 12.0+)**
* 5G SA连接状态 **(此项目限制 低版本系统设备不支持5G网络)**
* 自动5G开启状态
* SIM支持5G
* SIM支持5G SA
* SIM支持5G NSA
* 显示5G切换开关 **(此项目限制 低版本系统设备不支持5G网络)**
* 显示5G SA切换开关 **(此项目限制 低版本系统设备不支持5G网络)**
* 5GA网络标识 **(此项目限制 低版本系统设备不支持5G网络)**
* SIM卡允许使用PIN锁定
* 运营商禁止使用VoLTE
* 低数据模式状态 **(已使用备用方法兼容至iOS 13.0+)**
* 高成本网络
* 频段信息
* 选择的网络类型 **(已使用备用方法兼容至iOS 12.0+)**
* 首选网络类型 **(已使用备用方法兼容至iOS 12.0+)**
* 蜂窝数据卡列表 **(iOS 14以下设备读取数据失败)**
* 蜂窝数据卡详细信息 **(iOS 14以下设备读取数据失败)**
* 启用或关闭蜂窝数据卡 **(iOS 14以下设备读取数据失败)**

### 7. 以下功能或数据需要 iOS 13.4+
>
* 数据漫游 **(已使用备用方法兼容至iOS 12.0+)**

### 8. 以下功能或数据需要 iOS 13.0+
>
* 蜂窝网络连接状态
* 允许切换蜂窝数据
* 默认语音号码 **(不支持蜂窝版iPad)** **(已使用备用方法兼容至iOS 12.0+)**
* 转移蜂窝套餐卡
* 电话号码 **(已使用备用方法兼容至iOS 12.0+)**
* 允许编辑电话号码
* 设备型号代码(TAC) **(已使用备用方法兼容至iOS 12.0+)**
* 上次注册网络的移动国家代码(MCC)
* 参考信号接收功率(RSRP) **(已使用备用方法兼容至iOS 12.0+)**
* 信噪比(SNR)
* 接收信号码功率(RSCP)
* 码片能量与噪声比(Ec/No)
* 使用本地策略网络 **(已使用备用方法兼容至iOS 12.0+)**
* 低数据模式状态
* NAT保持时间
* 允许紧急呼叫号码列表
* 紧急模式信息
* 蜂窝网络连接状态 **(原始数据)**
* 信号强度 **(原始数据)**

### *其余数据均可在 iOS 12.0+ 的设备上正常读取*

### 9. 以下功能或数据在 iOS 18.0+ *不再支持*
* NR禁用状态 **(已使用新方法兼容至iOS 18.0+)**
* 5G(NR)频率范围 **(已使用新方法兼容至iOS 18.0+)**
* 数据模式 **(已使用新方法兼容至iOS 18.0+)**

### 10. 无需额外权利可以查询的数据
>
* 设备是否支持蜂窝网络
* 设备是否SIM卡已就绪**（iOS 16.4及以上版本）**
* 蜂窝网络开关状态
* 蜂窝网络连接状态
* 基带候选(RC)版本固件
* 需要设置eSIM状态
* 需要显示eSIM漫游提示
* 运营商名称**（iOS 16.4以下版本）**
* SIM卡的移动国家代码(MCC)**（iOS 16.4以下版本）**
* SIM卡的移动网络代码(MNC)**（iOS 16.4以下版本）**
* SIM卡允许使用PIN锁定**（iOS 18.0以下版本）**
* 网络制式
* 5G SA(NR) 连接状态
* 5GA 连接状态
* 使用本地策略网络
* IMS注册状态 **(基本信息)**
* 当前使用的蜂窝服务
* 4G网络标识
* 5GA网络标识
* 显示LTE切换选项
* 显示VoLTE切换选项
* 运营商配置支持的SIM
* 运营商书签
* 网络连接状态 **(原始数据)**
* 蜂窝数据状态 **(原始数据)**
* 当前使用的蜂窝服务 **(原始数据)**
* 数据载体 **(原始数据)**
* 数据模式 **(原始数据)**
* Packet Context Count **(原始数据)**
* Should Show Branded Calling Info **(原始数据)**
* 设备是否支持专用承载**(数据不可靠)**
* IPCC(运营商配置文件)兼容性检测 **(基本检测)**

### 11. 需要public-cellular-plan权利可以查询的数据
* 设备是否支持eSIM
* 设备是否允许安装eSIM

## 已测试设备
* iOS 12.1.2 iPhone SE 1 (2016)
* iOS 13.4.1 iPhone SE 1 (2016)
* iOS 14.4 iPhone 12 mini
* iOS 14.5 iPhone XR
* iOS 14.7 iPhone 12 mini
* iOS 15.0 iPhone 13 mini
* iPad OS 15.2 iPad Pro 10.5(2017) Wi-Fi + Cellular **(有Apple SIM)**
* iOS 15.3 iPhone 13 mini
* iOS 15.4.1 iPhone 13 mini (x2)
* iOS 15.4.1 iPhone 13 Pro Max
* iPad OS 15.4.1 iPad mini 6 Wi-Fi + Cellular
* iOS 15.5 iPhone 11 **(有运营商锁)**
* iOS 15.6 iPhone 13 mini
* iOS 15.6 iPhone SE 3 (2022)
* iOS 16.5 iPhone 13 Pro Max
* iOS 16.5 iPhone SE 3 (2022) **(有运营商锁)**
* iOS 16.6 iPhone SE 3 (2022) **(有运营商锁)**
* iOS 16.6 iPhone 13 Pro
* iOS 17.0 iPhone 13 mini
* iOS 17.2 iPad 7 (2019) Wi-Fi + Cellular **(越狱)**
* iOS 18.7 iPhone 16 Pro Max **(无权利)**
* iOS 18.7.1 iPhone 16 Pro Max **(无权利)**
* iOS 26.1 iPhone 17 Pro Max **(无权利)**
* iOS 26.1 iPhone 17 Pro **(无权利)**
* iOS 26.1 iPhone 17 Air **(无权利)**  
  
**内测组成员设备**  

* iOS 16.5 iPhone 14 Pro Max
* iOS 17.0 iPhone 15 Pro

## 构建

``make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa``

## 开源协议说明

本项目基于 GNU General Public License v3.0（GPL-3.0）开源。

为保障用户数据安全与透明性，任何对本项目的使用、修改或再分发行为，均必须遵守 GPL-3.0 协议，并在相同协议下开源完整源代码。

## 参考

### 开源组件

- **[ZIP Foundation](https://github.com/weichsel/ZIPFoundation)**

- **[Windows XP 图标包](https://github.com/marchmountain/-Windows-XP-High-Resolution-Icon-Pack)**

- **[Windows 7 图标](https://win7icons.visnalize.com/)**

- **[Windows 10 & Windows 11 图标](https://logos.fandom.com/wiki/Mobile_Plans)**

### 开发资源

- **[Limneos](https://developer.limneos.net/)**  

  提供CoreTelephony头文件

- **[OwnGoal Studio & 82flex](https://headers.82flex.com/)**  

  提供CoreTelephony头文件与不同版本对比

- **[IPCCInstaller](https://github.com/Netskao)**  

  `_CTServerConnectionInstallCarrierBundle` 


### 参考资料

- **[3GPP TS 36.101（Release 17）](https://www.etsi.org/deliver/etsi_ts/136100_136199/136101/17.06.00_60/ts_136101v170600p.pdf)**  

  传输带宽配置（NRB 映射），表 5.6-1，第 73 页

- **[ShareTechnote](https://www.sharetechnote.com/html/5G/5G_Phy_Numerology.html)**  

  NR 子载波间隔及相关技术细节

- **[3GPP TS 38.300（Release 16）](https://www.etsi.org/deliver/etsi_ts/138300_138399/138300/16.04.00_60/ts_138300v160400p.pdf)**  

  NR 总体描述；BWP 激活/去激活机制（§10.6）

- **[Keysight – 理解 5G NR BWP](https://www.keysight.com/blogs/en/inds/2018/10/31/understanding-5g-new-radio-bandwidth-parts)**  

  带宽部分（BWP）的工程解析

- **[Huawei BWP 概述](https://sg.o3community.huawei.com/sg/en/forum/1358950823329681409?blogId=668090880327827456)**  

  BWP 概念说明及动态切换机制

## 致谢
- **[酷安@简单yi点点](http://www.coolapk.com/u/1137700)**  

  参与测试并提供产品改进建议

- **[酷安@哥哥i](https://www.coolapk.com/u/504145)**  

  参与测试支持
