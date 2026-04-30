#import <Foundation/Foundation.h>

@interface IPCCManagerController : NSObject

+ (BOOL)installIPCCAtURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NOTHROW;
+ (BOOL)refreshCarrierBundlesWithError:(NSError **)error NS_SWIFT_NOTHROW;
@end
