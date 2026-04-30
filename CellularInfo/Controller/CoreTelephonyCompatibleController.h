#import <Foundation/Foundation.h>
//#import "CellularInfo-Swift.h"
#import "CTBandInfo.h"
#import "CTSimHardwareInfo.h"


// Forward declarations for private CoreTelephony classes (do not import their headers)
@class CTXPCServiceSubscriptionContext;
@class CTDataStatusBasic;

@interface CoreTelephonyCompatibleController : NSObject

+ (instancetype)instance;

- (CTDataStatusBasic *)getDataStatusBasic:(CTXPCServiceSubscriptionContext *)context API_AVAILABLE(ios(15.4));
- (CTBandInfo *)getSlotBandInfo:(CTXPCServiceSubscriptionContext *)context error:(NSError **)error API_AVAILABLE(ios(14.0));
@end
