# CellularInfo 蜂窝网络数据

<p align="center">
  <a href="https://github.com/DevelopCubeLab/CellularInfo/stargazers">
    <img src="https://img.shields.io/github/stars/DevelopCubeLab/CellularInfo?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/DevelopCubeLab/CellularInfo/issues">
    <img src="https://img.shields.io/github/issues/DevelopCubeLab/CellularInfo" alt="GitHub issues">
  </a>
</p>

[简体中文 ➡️](https://github.com/DevelopCubeLab/CellularInfo/blob/main/README_Zh.md)  

## Introduction

This app is a cellular network diagnostic and analysis tool for iOS, capable of querying over **160+** cellular network data points from CoreTelephony and underlying system frameworks.

The app provides detailed analysis of device information, SIM card information, carrier configurations (IPCC), radio access technologies (RAT), network status, and various low-level cellular parameters. By combining public system APIs with reverse-engineered private interfaces, the app is able to visualize data that is normally inaccessible on standard iOS devices.

The app also provides features such as IPCC management, IPCC compatibility checking, and network type configuration.

This project supports iOS **12.0 and later**, and is designed only for **iPhone and cellular-enabled iPad devices**.

Devices without cellular capability are not supported, including iPod Touch, Wi-Fi-only iPads, Xcode Simulators, and virtual machine environments (such as VPhone).

Jailbreak or TrollStore installation is required.  
Installing via a developer certificate provides access to only a limited subset of data.

This project will **not support** iOS versions below 12.0 because `CoreTelephonyClient` requires iOS 12.0+.

This tool is mainly intended for developers, security researchers, and advanced users who require deeper insight into iOS cellular network mechanisms.

To help protect your device data security, do not download installation packages for this project from unofficial sources, and do not share app data with others unless it is properly protected.

If you are interested in CoreTelephony, you can directly browse the organized source files below:

[`CoreTelephonyClient.h`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Head/CoreTelephonyClient.h)  
[`CoreTelephonyController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/CoreTelephonyController.swift)  
[`CellularDataController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/CellularDataController.swift)

These files include status descriptions, comments, and documented error cases.

Most comments in the source code are written in Chinese, but you can easily translate them using translation tools or LLMs.

Related IPCC installation implementation:

[`IPCCManagerController.m`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/IPCCManagerController.m)  
[`IPCCManagerController.swift`](https://github.com/DevelopCubeLab/CellularInfo/blob/main/CellularInfo/Controller/IPCCManagerController.swift)

> [!NOTE]
> Some professional cellular network terms and technical details in this app may not be fully accurate, as certain areas are still being researched and verified.  
> If you are a telecom or networking professional and notice any incorrect information in the app, please feel free to submit an issue. Corrections and improvements are always welcome.

> [!WARNING]
> Due to the extensive use of private APIs in this project, testing may not cover every iOS version completely.  
> If you encounter crashes, error codes, or unexpected behavior, please provide the crash log (`.ips` file) and submit an issue.

## Installation

| System Version | Installation Method | Notes |
|----------|------|------|
| iOS 17.3.1/iOS 18.7.2+/iOS 26.0.1+ devices without jailbreak support | Developer certificate sideloading ([limited data access](#10-Data accessible without extra entitlements)) | Can be installed using AltStore, SideStore, LiveContainer, LCSign, Esign, and other signing tools |
| iOS 17.0+ jailbreakable devices | Jailbreak(Dopamine/Realxin/palera1n) + TrollStore Lite | - |
| iOS 14.0 - iOS 16.6.1 and iOS 17.0 | Install using TrollStore | - |
| iOS 12.2 - iOS 13.x | Jailbreak installation | Requires separate RootHelper installation |
| iOS 12.0 - iOS 12.1.x | Jailbreak installation | Requires an IPA compatible with iOS 12.0 and separate RootHelper installation |
## How It Works
<img width="800" alt="How CellularInfo Works" src="https://github.com/user-attachments/assets/ff6a0a16-7445-42af-a15a-905b47d24635" />

## Data

### 1. The following features require iOS 17.0 or later.
>
* Device Enabled 2G Network Switch
* User Enabled 2G Network Preference
* Enabled Mobile Data Usage Collection Statistics
* Show eSIM Tips During Roaming
* NR Status (5G SA & 5G NSA) **(Compatibility extended to iOS 14.0+ using an alternative method)**
* Cellular Usage Workspace Info **(Underlying Data)**

### 2. The following features require iOS 16.4 or later.
>
* Device SIM Ready **(Compatibility extended to iOS 12.0+ using an alternative method)**

### 3. The following features require iOS 16.0 or later.
* Device Supports eSIM **(Compatibility extended to iOS 12.0+ using an alternative method)**
* eSIM Only Device [(Verified to be compatible with iOS 12.0 or later based on device support data)](https://support.apple.com/en-us/111850)
* Current Connected Operator Name **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Device eSIM Health
* Device Allowed Install Dev Signed IPCC (Carrier Budnle)
* Device Emergency Text Numbers
* Device Requires eSIM Setup
* Device Using eSIM download service
* Private Network SIM
* Should Show Branded Calling Info **(Underlying Data)**

### 4. The following features require iOS 15.4 or later.
>
* Device in Factory Debug Mode
* Baseband Release Candidate Flag
* Cellular Data Info **(Basic Info)** **(Displays full information using a fallback method, compatible with iOS 12.0 or later)**

### 5. The following features require iOS 15.0 or later.
>
* Device information in baseband
* Carrier English Name
* SIM Location
* Personal Hotspot Availability
* Personal Hotspot Enabled
* iCloud Private Relay Enabled Status
* Limit IP Tracking Enabled Status
* Device Supports Dedicated Bearer
* Device Supports Hydra
* SIM Hardware Information **(Underlying Data)**
* Tethering Status **(Underlying Data)**
* Data Bearer **(Underlying Data)** **(Compatibility extended to iOS 14.0+ using an alternative method)**
* Lock Network Mode **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Restore IPCC (Carrier Bundle) to System **(Compatibility extended to iOS 12.0+ using an alternative method)**

### 6. The following features require iOS 14.0 or later.
> [!WARNING]
**All data related to 5G networks**  
>
* Device Carrier Lock State **(Unsupported iPad Wi-Fi + Cellular Device)**
* Device Supports 5G **(Verified to be compatible with iOS 12.0 or later based on device support data)**
* 5G SA Connection Status **(Not a system limitation: 5G support requires compatible hardware (iPhone 12 and later) and iOS 14.0+)**
* 5G Auto Enabled Status
* SIM Suppotrs 5G
* SIM Suppotrs 5G SA
* SIM Suppotrs 5G NSA
* Show 5G Switcher **(Not a system limitation: 5G support requires compatible hardware (iPhone 12 and later) and iOS 14.0+)**
* Show 5G SA Switcher **(Not a system limitation: 5G support requires compatible hardware (iPhone 12 and later) and iOS 14.0+)**
* 5G-Advanced or 5G mmWave Network Indicator **(Not a system limitation: 5G support requires compatible hardware (iPhone 12 and later) and iOS 14.0+)**
* SIM Card Allows PIN Lock
* Carrier Disable VoLTE
* Low Data Mode Enabled Status **(Compatibility extended to iOS 13.0+ using an alternative method)**
* Expensive network
* Band Info
* Select Network Type **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Preferred Network Type **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Cellular Plan List **(Data retrieval fails on devices running iOS versions below 14.0)**
* Cellular Plan Details **(Data retrieval fails on devices running iOS versions below 14.0)**
* Enable or Disable Cellular Plan **(Data retrieval fails on devices running iOS versions below 14.0)**
* Configure Network Bands (Beta)

### 7. The following features require iOS 13.4 or later.
* Data Roaming **(Compatibility extended to iOS 12.0+ using an alternative method)**

### 8. The following features require iOS 13.0 or later.
>
* Cellular Data Connection Status
* Allow Mobile Data Switching
* Default Voice Slot **(Unsupported iPad Wi-Fi + Cellular Device)** **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Device Type Allocation Code (TAC) **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Cellular Plan Transfer Capability
* Phone Number **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Phone Number Editable
* Last Registered Network Mobile Country Code(MCC)
* RSRP (Reference Signal Received Power) **(Compatibility extended to iOS 12.0+ using an alternative method)**
* SNR (Signal-to-Noise Ratio)
* RSCP(Received Signal Code Power) 
* Ec/No(Energy per chip over Noise density)
* Use Home Network Policy **(Compatibility extended to iOS 12.0+ using an alternative method)**
* Low Data Mode Enabled Status
* NAT Keep-Alive Interval
* Emergency Text Numbers
* Emergency Mode Info
* Cellular Internet Connection State **(Underlying Data)**
* Signal Strength **(Underlying Data)**

### 9. The following features are *no longer supported* on iOS 18.0+
* NR Disable Status **(Supported on iOS 18.0+ via a new implementation)**
* 5G (NR) Frequency Range **(Supported on iOS 18.0+ via a new implementation)**
* Data Mode  **(Supported on iOS 18.0+ via a new implementation)**

### 10. Data accessible without extra entitlements
>
* Device Spuupots Cellular
* Device SIM Ready
* Cellular Data Enabled Status
* Cellular Data Connection Status
* Baseband Release Candidate Flag
* Requires eSIM Setup Status
* Show eSIM Tips During Roaming Status
* Carrier Name **(below iOS 16.4)**
* SIM Card Mobile Country Code(MCC) **(below iOS 16.4)**
* SIM Card Mobile Network Code(MNC) **(below iOS 16.4)**
* SIM Card Allows PIN Lock Status **(below iOS 18.0)**
* Radio Access Technology
* 5G SA(NR) Connection Status
* 5G-Advanced Connection Status
* Home Network Policy Status
* IMS Registration Status **(Basic Info)**
* Active Cellular Services
* 4G Network Indicator
* 5G-Advanced or 5G mmWave Network Indicator
* Show LTE Switcher
* Show VoLTE Switcher
* Carrier Bundle Supported SIMs
* Carrier Bookmarks **(if available)**
* Internet Connection State **(Underlying Data)**
* Cellular Data Status **(Underlying Data)**
* Active Cellular Services **(Underlying Data)**
* Data Bearer **(Underlying Data)**
* Data Mode **(Underlying Data)**
* Packet Context Count **(Underlying Data)**
* Should Show Branded Calling Info **(Underlying Data)**
* Device Supports Dedicated Bearer **(Data may not be reliable)**
* IPCC (Carrier Bundle) Compatibility Check **(Basic Info Check)**

### Data that requires the public-cellular-plan entitlement

* Device Supports eSIM
* Device Allows eSIM Installation

## Tested Devices

* iOS 12.1.2 iPhone SE 1 (2016)
* iOS 13.4.1 iPhone SE 1 (2016)
* iOS 14.4 iPhone 12 mini
* iOS 14.5 iPhone XR
* iOS 14.7 iPhone 12 mini
* iOS 15.0 iPhone 13 mini
* iPadOS 15.2 iPad Pro 10.5 (2017) Wi-Fi + Cellular **(with Apple SIM)**
* iOS 15.3 iPhone 13 mini
* iOS 15.4.1 iPhone 13 mini (x2)
* iOS 15.4.1 iPhone 13 Pro Max
* iPadOS 15.4.1 iPad mini 6 Wi-Fi + Cellular
* iOS 15.5 iPhone 11 **(carrier locked)**
* iOS 15.6 iPhone 13 mini
* iOS 15.6 iPhone SE 3 (2022)
* iOS 16.5 iPhone 13 Pro Max
* iOS 16.5 iPhone SE 3 (2022) **(carrier locked)**
* iOS 16.6 iPhone SE 3 (2022) **(carrier locked)**
* iOS 16.6 iPhone 13 Pro
* iOS 17.0 iPhone 13 mini
* iOS 18.7.9 iPad 7 (2019) Wi-Fi + Cellular **(jailbroken)**
* iOS 18.7 iPhone 16 Pro Max **(without entitlements)**
* iOS 18.7.1 iPhone 16 Pro Max **(without entitlements)**
* iOS 26.1 iPhone 17 Pro Max **(without entitlements)**
* iOS 26.1 iPhone 17 Pro **(without entitlements)**
* iOS 26.1 iPhone 17 Air **(without entitlements)**

**Beta Testing Group Devices**

* iOS 16.5 iPhone 14 Pro Max
* iOS 17.0 iPhone 15 Pro


## Build

``make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa``

## License Notice

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

To ensure user data security, you are required to comply with the GPL-3.0 license. Any modification, distribution, or derivative work must be released under the same license with complete source code.

## References

### Open Source Components

- **[ZIP Foundation](https://github.com/weichsel/ZIPFoundation)**

- **[Windows XP Icon Pack](https://github.com/marchmountain/-Windows-XP-High-Resolution-Icon-Pack)**

- **[Windows 7 Icons](https://win7icons.visnalize.com/)**

- **[Windows 10 & Windows 11 Icons](https://logos.fandom.com/wiki/Mobile_Plans)**

### Development Resources

- **[Limneos](https://developer.limneos.net/)**  
  Provides CoreTelephony headers

- **[OwnGoal Studio & 82flex](https://headers.82flex.com/)**  
  Provides CoreTelephony headers and cross-version comparisons

- **[IPCCInstaller](https://github.com/Netskao)**  
  Reference implementation of `_CTServerConnectionInstallCarrierBundle`

### Technical References

- **[3GPP TS 36.101 (Release 17)](https://www.etsi.org/deliver/etsi_ts/136100_136199/136101/17.06.00_60/ts_136101v170600p.pdf)**  
  Transmission bandwidth configuration (NRB mapping), Table 5.6-1, p.73

- **[ShareTechnote](https://www.sharetechnote.com/html/5G/5G_Phy_Numerology.html)**  
  NR subcarrier spacing and related technical details

- **[3GPP TS 38.300 (Release 16)](https://www.etsi.org/deliver/etsi_ts/138300_138399/138300/16.04.00_60/ts_138300v160400p.pdf)**  
  NR overall description; BWP activation/deactivation mechanism (§10.6)

- **[Keysight – Understanding 5G NR BWP](https://www.keysight.com/blogs/en/inds/2018/10/31/understanding-5g-new-radio-bandwidth-parts)**  
  Engineering interpretation of Bandwidth Parts (BWP)

- **[Huawei BWP Overview](https://sg.o3community.huawei.com/sg/en/forum/1358950823329681409?blogId=668090880327827456)**  
  Conceptual explanation of BWP and dynamic switching behavior
  
## Acknowledgements

- **[酷安@简单yi点点](http://www.coolapk.com/u/1137700)**  

  Helped with testing and product improvement

- **[酷安@哥哥i](https://www.coolapk.com/u/504145)**  

  Helped with testing
