#import <Foundation/Foundation.h>

@interface RootHelperController : NSObject

- (void) Respring;

@end

int spawnRoot(NSString *path, NSArray *args, NSString **stdOut, NSString **stdErr);
int spanRoot(NSString* path, NSArray* args, pid_t* outPid);
void killall(NSString* processName, BOOL softly);
int killallWithResult(NSString* processName, BOOL softly);
