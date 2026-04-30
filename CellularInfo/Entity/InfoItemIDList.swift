import Foundation
import UIKit

// 通用ID
enum CommonItemID {
    static let test = 0
    static let deviceBasicInfo = 100
    static let logicBoardID = 101
    static let modemFirmware = 102
    static let IMEI1 = 103
    static let IMEI2 = 104
    static let MEID = 105
    static let EID = 106
    static let phoneNumber = 107
    static let carrierName = 108
    static let operatorName = 109
    static let useIMEI = 110
    static let useTypeAllocationCode = 111
    static let ICCID = 112
    static let IMSI = 113
    static let SIMType = 114
    static let privateRelay = 115
    static let _4GNetworkIndicator = 116
    static let NRMMWaveIndicator = 117
    static let dataSIMNetworkType = 118
    static let preferredDataSlot = 119
    static let defaultVoiceSlot = 120
    static let interfaceCostExpensive = 121
    static let APN = 122
}

// CoreTelephony的ID
enum CoreTelephonyItemID {
    static let supportsCellular = 201
    static let supports5G = 202
    static let supports5GSA = 203
    static let supports5GNSA = 204
    static let carrierLock = 205
    static let SIMTrayStatus = 206
    static let anySIMReady = 207
    static let dualSimCapability = 208
    static let supportsEmbeddedSIM = 209
    static let allowInstallEmbeddedSIM = 210
    static let allowDevSignedCarrierBundles = 211
    static let embeddedSIMOnlyDevice = 212
    static let cellularDataEnabled = 213
    static let cellularDataConnectionAvailability = 214
    static let dynamicDataSimSwitch = 215
    static let dynamicDataSimSwitchOnCall = 216
    static let mobileDataUsageCollection = 217
    static let allow2GSwitch = 218
    static let userEnabled2G = 219
    static let factoryDebugMode = 220
    static let releaseCandidate = 221
    static let supportedDedicatedBearer = 222
    static let supportsHydra = 223
    static let cellularPlanTransferable = 224
    static let hotspotAvailability = 225
    static let hotspotEnabled = 226
    static let defaultIPCCVersion = 227
    static let NrFrequencyRange = 228
    static let shouldShowEmbeddedSIMTravelTips = 229
    static let needToLaunchSetUpEmbeddedSIM = 230
    static let bootstrapDataService = 231

    static let slotLabel = 301
    static let SIMStatus = 302
    static let SIMGood = 303
    static let SIMPresent = 304
    static let SIMLocation = 305
    static let allowSIMLockWithPIN = 306
    static let SIMLockedWithPIN = 307
    static let remainingPINAttemptCount = 308
    static let remainingPUKAttemptCount = 309
    static let registrationStatus = 310
    static let radioAccessTechnology = 311
    static let NRConnected = 312
    static let _5GAdvancedConnected = 313
    static let selectRate = 314
    static let supportRates = 315
    static let signalStrength = 316
    static let signalStrengthInfo = 317
    static let PLMN = 318
    static let cellId = 319
    static let band = 320
    static let bandwidth = 321
    static let bandInfo = 322
    static let BWPSupport = 323
    static let physicalCellID = 324
    static let servingTAC = 325
    static let servingLAC = 326
    static let servingMNC = 327
    static let simCardMNC = 328
    static let lastKnownMNCCountryCode = 329
    static let servingMCC = 330
    static let simCardMCC = 331
    static let lastKnownMCC = 332
    static let RSRP = 333
    static let RSCP = 334
    static let SNR = 335
    static let ECN0 = 336
    static let GSCN = 337
    static let NRARFCN = 338
    static let UARFCN = 339
    static let SCN = 340
    static let PMax = 341
    static let NRSubcarrierSpacing = 342
    static let IMSRegistrationStatus = 343
    static let activeConnections = 344
    static let networkSelectionMode = 345
    static let networkSelectionMenuAvailable = 346
    static let rejectCauseCode = 347
    static let dataRoaming = 348
    static let lowDataMode = 349
    static let limitIPTracking = 350
    static let supportsHighDataMode = 351
    static let _5GAuto = 352
    static let useHomeNetworkPolicy = 353
    static let carrierBundleVersion = 354
    static let carrierBundleLocation = 355
    static let SMSReadyState = 356
    static let SMSCAddress = 357
    static let supportedVoLTE = 358
    static let carrierDisableVoLTE = 359
    static let tetheringSettingsEditable = 360
    static let attachAPNSetting = 361
    static let supportedWifiCalling = 362
    static let emergencyTextNumbers = 363
    static let phoneNumberEditable = 364
    static let SIMPhoneBookCount = 365
    static let carrierBookmarks = 366
    static let maximumConferenceCall = 367
    static let SIMHomeRegionList = 368
    static let SIMIsPrivateNetwork = 369
    static let PNRSupported = 370
    static let phoneNumberCredential = 371
    static let NATTKeepAliveOverCell = 372
    static let dialingCallAlert = 373
    static let selectionNetworkType = 374
    static let preferredNetworkType = 375
    static let carrierBundleSupportsSIMs = 376
    static let carrierBundleSupportsDevices = 377
    static let carrierBundleShow5GSwitcher = 378
    static let carrierBundleShow5GStandaloneSwitcher = 379
    static let carrierBundleShow4GSwitcher = 380
    static let carrierBundleShow3GSwitcher = 381
    static let carrierBundleShowVoLTESwitcher = 382
    static let carrierBundleOTABeforeUserConfirm = 383
    static let carrierBundlePath = 384
    static let activationTicket = 385
}

// CellularPlan的ID
enum CellularPlanItemID {
    static let name = 501
    static let label = 502
    static let carrierName = 503
    static let uuid = 504
    static let enabled = 505
    static let installing = 506
    static let selectable = 507
    static let defaultVoice = 508
    static let activeDataPlan = 509
    static let simStateValid = 510
    static let checkingCellularConnectivity = 511
    static let transferred = 512
    static let transferToeSIMSupported = 513
    static let canDisablePlan = 514
    static let canDeletePlan = 515
}

// CoreTelephony原始数据的ID
enum CoreTelephonyRAWItemID {
    static let deviceInfo = 701
    static let systemCapabilities = 702
    static let dataStatus = 703
    static let dataStatusBasic = 704
    static let NRStatus = 705
    static let dataMode = 706
    static let dataBearer = 707
    static let activeConnections = 708
    static let internetConnection = 709
    static let networkSelectionInfo = 710
    static let signalStrengthMeasurements = 711
    static let cellInfo = 712
    static let registrationStatus = 713
    static let PNRInfo = 714
    static let SIMHardwareInfo = 715
    static let ICCIDList = 716
    static let tetheringStatus = 717
    static let cellularUsageWorkspace = 718
    static let emergencyModeInfo = 719
    static let GSMAUIControlSetting = 720
    static let brandedCallingInfo = 721
}

// 设备信息的ID
enum MGDeviceInfoItemID {
    static let baseBandUniqueID = 805
}

// 信息组ID
enum CellularDataItemGroupID {
    static let generalAction = -2 // 操作组 纯占位
    static let deviceBaseInfo = -1
    static let deviceCellularInfo = 0  // ID不要改
    static let slot1BaseInfo = 1       // ID不要改
    static let slot2BaseInfo = 2       // ID不要改
    static let cellularPlanBaseInfo = 3
    static let cellularPlanStatusInfo = 4
    static let cellularPlanControl = 5
    static let installIPCC = 6
    static let slot1IPCCManager = 7
    static let slot2IPCCManager = 8
    static let IPCCCompatibilityCheck = 9
    static let IPCCFileInfo = 10
    static let IPCCCompatibility = 11
    static let activationTicket = 12
    static let setNetworkMode = 13
    static let networkModeInfo = 14
    static let networkModeSelect = 15
    static let maintenance = 16
}

// 操作item的ID
enum ActionItemID {
    static let copy = -7
    static let paste = -8
    static let save = -9
    static let underlyingData = -10
    static let carrierBookmark = -11
    static let APNConfig = -12
    static let turnOnCellularPlan = -13
    static let turnOffCellularPlan = -14
    static let IPCCManager = -15
    static let IPCCCompatibilityCheck = -16
    static let SettingNetworkMode = -17
    static let installIPCC = -18
    static let restoreIPCCToSystem = -19
    static let refreshCarrierBundles = -20
    static let refreshCellularConnection = -21
    static let installSelectIPCC = -22
    static let installSelectIPCCWithWarning = -23
    static let installSelectIPCCUseComputer = -24
    static let installSelectIPCCUseComputerWithWarning = -25
    static let selectIPCCFile = -26
    static let activationTicketManager = -27
    static let rebootCommCenterService = -28
    static let selectNetworkMode = -29
    static let selectNetworkModeUnknown = -30
}

// 设置组的ID
enum SettingsGroupID {
    static let languageSettings = 0
    static let generalSettings = 1
    static let displaySettings = 2
    static let aboutApplication = 3
    static let recommend = 4
}

// 设置项的ID
enum SettingsItemID {
    static let languageSettings = 10
    static let appIconSettings = 11
    static let autoRefreshData = 12
    static let timedRefreshData = 13
    static let screenshotCaptureAlert = 14
    static let experimentalFeatures = 15
    static let checkCarrierBundleCompatibility = 16
    static let resetAllWarnings = 17
    static let showCellularDataInGroups = 18
    static let showInactiveSIMSlotsData = 19
    static let hideNoPermissionData = 20
    static let forceShowLTEAs4G = 21
    static let versionCode = 22
    static let reference = 23
    static let githubLink = 24
    static let trollSIMSwitcher = 25
}
