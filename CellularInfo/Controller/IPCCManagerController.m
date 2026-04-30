@import Foundation;
#import "IPCCManagerController.h"
#import "CoreTelephonyClient.h"

/// 必须复制ipcc文件到下面的目录
/// 研究过程
/// 随便选择一个目录，或者直接不拷贝ipcc文件到指定目录，
/// 日志: kernel    Sandbox: CommCenterMobile(60551) deny(1) file-read-metadata /private/var/mobile/Media/Downloads/
/// CommCenterMobileHelper    Failed to move the directory /var/mobile/Media/Downloads/xxx.ipcc to /var/mobile/Library/Carrier Bundles/CarrierBundleStaging/. Error: -1
/// CommCenter    Failed to move file xxx.ipcc from /var/mobile/Media/Downloads/xxx.ipcc to /var/mobile/Library/Carrier Bundles/CarrierBundleStaging/
/// 将 CommCenterMobileHelper 使用ldid -e分析其权利列表
/// <key>com.apple.security.exception.files.absolute-path.read-write</key>
/// <array>
///     <string>/private/var/mobile/Media/PublicStaging/</string>
///     <string>/private/var/tmp/</string>
///     <string>/private/var/wireless/Library/</string>
/// </array>
/// 因此只能在这几个目录下进行操作
static NSString * const kIPCCPublicStagingDirectory = @"/private/var/tmp/";

@implementation IPCCManagerController

/// 安装IPCC的主要方法
+ (BOOL)installIPCCAtURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NOTHROW {
    if (url == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Empty URL"}];
        }
        return NO;
    }
    
    NSError *stageError = nil;
    NSURL *stagedURL = [self stageIPCCAtURL:url error:&stageError];
    if (stagedURL == nil) {
        if (error) {
            *error = stageError ?: [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                                       code:-2
                                                   userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Failed to stage IPCC file"}];
        }
        return NO;
    }
    
    CTServerConnectionRef conn = _CTServerConnectionCreate(kCFAllocatorDefault, NULL, NULL);
    NSLog(@"[Cellular Info]<Install IPCC> conn=%p url=%@", conn, stagedURL.path);
    
    if (!conn) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Create CTServerConnection failed"}];
        }
        return NO;
    }
    
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (__bridge CFStringRef)stagedURL.path,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
    
    long result = _CTServerConnectionInstallCarrierBundle(conn, fileURL);
    
    if (fileURL) {
        CFRelease(fileURL);
    }
    
    NSLog(@"[Cellular Info]<Install IPCC> install result=%ld", result);
    
    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                         code:(NSInteger)result
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Install carrier bundle request failed"}];
        }
        return NO;
    }
    
    return YES;
}

/// 恢复系统自带的运营商配置
+ (BOOL)refreshCarrierBundlesWithError:(NSError **)error NS_SWIFT_NOTHROW {
    CTServerConnectionRef conn = _CTServerConnectionCreate(kCFAllocatorDefault, NULL, NULL);
    NSLog(@"[Cellular Info]<Restore IPCC> conn=%p", conn);
    
    if (!conn) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Restore IPCC>"
                                         code:-100
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Restore IPCC> Create CTServerConnection failed"}];
        }
        return NO;
    }
    
    long result = _CTServerConnectionResetCarrierBundle(conn);
    NSLog(@"[Cellular Info]<Restore IPCC> reset result=%ld", result);
    
    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Restore IPCC>"
                                         code:(NSInteger)result
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Restore IPCC> Reset carrier bundle failed"}];
        }
        return NO;
    }
    
    return YES;
}

/// 将用户选择的IPCC复制到指定目录下
/// 用来让 CommCenterMobileHelper 可以访问
/// 必要的步骤 如果不复制的话 CommCenterMobileHelper 无法访问到IPCC文件 直接导致安装IPCC失败
+ (NSURL *)stageIPCCAtURL:(NSURL *)sourceURL error:(NSError **)error {
    if (sourceURL == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                         code:-10
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Empty source URL"}];
        }
        return nil;
    }
    
    NSString *sourcePath = sourceURL.path;
    if (sourcePath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                         code:-11
                                     userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Empty source path"}];
        }
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL granted = [sourceURL startAccessingSecurityScopedResource]; // 向系统获取文件访问的授权
    
    @try {
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:sourcePath isDirectory:&isDirectory] || isDirectory) {
            if (error) {
                *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                             code:-12
                                         userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> IPCC file does not exist"}];
            }
            return nil;
        }
        
        if (![[sourcePath.pathExtension lowercaseString] isEqualToString:@"ipcc"]) {
            if (error) {
                *error = [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                             code:-13
                                         userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Selected file is not an .ipcc file"}];
            }
            return nil;
        }
        
        NSError *directoryError = nil;
        if (![fileManager createDirectoryAtPath:kIPCCPublicStagingDirectory
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&directoryError]) {
            if (error) {
                *error = directoryError ?: [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                                               code:-14
                                                           userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Failed to create PublicStaging directory"}];
            }
            return nil;
        }
        
        NSString *stagedPath = [kIPCCPublicStagingDirectory stringByAppendingPathComponent:sourcePath.lastPathComponent];
        
        if ([fileManager fileExistsAtPath:stagedPath]) {
            NSError *removeError = nil;
            if (![fileManager removeItemAtPath:stagedPath error:&removeError]) {
                if (error) {
                    *error = removeError ?: [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                                                code:-15
                                                            userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Failed to remove existing staged IPCC"}];
                }
                return nil;
            }
        }
        
        NSError *copyError = nil;
        if (![fileManager copyItemAtPath:sourcePath toPath:stagedPath error:&copyError]) {
            if (error) {
                *error = copyError ?: [NSError errorWithDomain:@"[Cellular Info]<Install IPCC>"
                                                          code:-16
                                                      userInfo:@{NSLocalizedDescriptionKey: @"[Cellular Info]<Install IPCC> Failed to copy IPCC to tmp"}];
            }
            return nil;
        }
        
        return [NSURL fileURLWithPath:stagedPath isDirectory:NO];
        
    } @finally {
        if (granted) {
            [sourceURL stopAccessingSecurityScopedResource];
        }
    }
}

@end
