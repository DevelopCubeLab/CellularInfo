#import "CoreTelephonyCompatibleController.h"
#import "CellularInfo-Swift.h"
#import <Foundation/Foundation.h>
#import "../Head/CoreTelephonyClient.h"

@implementation CoreTelephonyCompatibleController

+ (instancetype)instance {
    static CoreTelephonyCompatibleController *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CoreTelephonyCompatibleController alloc] init];
    });
    return instance;
}

- (CTDataStatusBasic *)getDataStatusBasic:(CTXPCServiceSubscriptionContext *)context API_AVAILABLE(ios(15.4)) {
    CoreTelephonyClient *client = [[CoreTelephonyController instance] getCoreTelephonyClient];
    return [client getDataStatusBasic:context error:nil];
}

- (CTBandInfo *)getSlotBandInfo:(CTXPCServiceSubscriptionContext *)context error:(NSError * _Nullable * _Nullable)error API_AVAILABLE(ios(14.0)) {
    CoreTelephonyClient *client = [[CoreTelephonyController instance] getCoreTelephonyClient];
    return [client getBandInfo:context error:error];
}

//- (NSString *)copyModemFirmwareVersion:(NSError **)error {
//
//    CTServerConnectionRef conn = _CTServerConnectionCreate(kCFAllocatorDefault, NULL, NULL);
//    if (!conn) {
//        if (error) {
//            *error = [NSError errorWithDomain:@"[Cellular Info]<Modem FW>"
//                                         code:-1
//                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create CTServerConnection"}];
//        }
//        return nil;
//    }
//
//    CFStringRef versionRef = NULL;
//
//    int result = _CTServerConnectionCopyFirmwareVersion(conn, &versionRef);
//
//    if (result != 0 || !versionRef) {
//        if (error) {
//            *error = [NSError errorWithDomain:@"[Cellular Info]<Modem FW>"
//                                         code:result
//                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to get modem firmware version"}];
//        }
//        return nil;
//    }
//
//    return (__bridge_transfer NSString *)versionRef;
//}

@end
