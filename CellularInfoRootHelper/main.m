#include <stdio.h>
#include <sys/stat.h>
#import <sys/sysctl.h>
#include <pwd.h>
#import <Foundation/Foundation.h>

/// RootHelper主要工作
//1. 查询roothelper状态
//2. 查询ActivationTicket
//3. 写入ActivationTicket
//4. 读取设备有锁状态
//5. kill CommCenter
//6. 重启设备

/// 定义一个常量 存储下读取path的目录
static NSString * const activationPlistPath = @"/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist";

/// 定义函数
int status();
int getDeviceCarrierLockState();
int getBaseBandActivationTicket();
int setBaseBandActivationTicket(NSString *activationTicket);
int restartCommCenter();
void rebootDevice();
void enumerateProcesses(void (^block)(pid_t pid, NSString *execPath));

/// 主入口
int main(int argc, char *argv[], char *envp[]) {
    @autoreleasepool {
        // 确保进程运行在 root 权限
        setuid(0);
        setgid(0);
        
        if (getuid() != 0) {
            printf("uid=%d euid=%d\n", getuid(), geteuid());
            printf("ERROR: BatteryHealthHelper must be run as root.\n");
            return -3;
        }
        
        if (argc < 2) {
            printf("ERR: no command\n");
            return 1001;
        }

        NSString *cmd = [NSString stringWithUTF8String:argv[1]];

        if ([cmd isEqualToString:@"status"]) {
            return status();
        } else if ([cmd isEqualToString:@"carrierLock"]) {
            return getDeviceCarrierLockState();
        } else if ([cmd isEqualToString:@"getTicket"]) {
            return getBaseBandActivationTicket();
        } else if ([cmd isEqualToString:@"setTicket"]) {
            if (argc < 3) {
                printf("ERR: missing activation ticket\n");
                return 1;
            }
            NSString *ticket = [NSString stringWithUTF8String:argv[2]];
            return setBaseBandActivationTicket(ticket);
        } else if ([cmd isEqualToString:@"restartCommCenter"]) {
            return restartCommCenter();
        } else if ([cmd isEqualToString:@"reboot"]) {
            rebootDevice();
            return 0;
        } else {
            printf("ERR: unknown command\n");
            return 6;
        }
    }
}

/// 获取RootHelper状态
int status() {
    printf("OK");
    return 0;
}

/// 获取设备运营商锁状态 主要是给iOS 14以下设备准备的
/// 读取plist下面的 is_activation_policy_locked
/// value类型String
/// 返回值 1:kFalse
/// 返回值 2:kTrue
int getDeviceCarrierLockState() {
    @autoreleasepool {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:activationPlistPath];
        if (!dict) {
            printf("ERR: cannot read plist\n");
            return 1;
        }
        
        id value = dict[@"is_activation_policy_locked"];
        if (!value || ![value isKindOfClass:[NSString class]]) {
            printf("ERR: key not found or invalid type\n");
            return 2;
        }

        NSString *str = (NSString *)value;

        if ([str isEqualToString:@"2:kTrue"]) {
            printf("Locked\n");
            return 0;
        } else if ([str isEqualToString:@"1:kFalse"]) {
            printf("Unlock\n");
            return 0;
        } else {
            printf("ERR: unknown value %s\n", [str UTF8String]);
            return 3;
        }
    }
}

/// 获取设备基带激活票据
/// 主要是给ICCID解锁的设备备份ticket
/// 读取plist下的kPostponementTicket下面的ActivationTicket
/// 返回的应该是很长一段String
int getBaseBandActivationTicket() {
    @autoreleasepool {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:activationPlistPath];
        if (!dict) {
            printf("ERR: cannot read plist\n");
            return 2;
        }

        NSDictionary *postponement = dict[@"kPostponementTicket"];
        if (!postponement || ![postponement isKindOfClass:[NSDictionary class]]) {
            printf("ERR: kPostponementTicket not found\n");
            return 3;
        }

        id ticket = postponement[@"ActivationTicket"];
        if (!ticket) {
            printf("ERR: ActivationTicket not found\n");
            return 4;
        }

        if ([ticket isKindOfClass:[NSString class]]) {
            printf("%s\n", [(NSString *)ticket UTF8String]);
            return 0;
        }

        printf("ERR: ActivationTicket is not NSString\n");
        return 5;
    }
}

/// 设置设备基带激活票据
/// 主要是给ICCID解锁的设备恢复之前的ticket
/// 写入plist下的kPostponementTicket下面的ActivationTicket
/// 返回的应该是很长一段String
int setBaseBandActivationTicket(NSString *activationTicket) {
    @autoreleasepool {
        if (!activationTicket || [activationTicket length] == 0) {
            printf("ERR: invalid input\n");
            return 1;
        }

        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:activationPlistPath];
        if (!dict) {
            printf("ERR: cannot read plist\n");
            return 2;
        }

        NSMutableDictionary *postponement = [dict[@"kPostponementTicket"] mutableCopy];
        if (!postponement || ![postponement isKindOfClass:[NSMutableDictionary class]]) {
            printf("ERR: kPostponementTicket not found or invalid\n");
            return 3;
        }

        // ActivationTicket 必须保持为 NSString 类型
        // 即使是 Base64 数据，也不能写成 NSData，否则系统会拒绝该值
        postponement[@"ActivationTicket"] = activationTicket;
        dict[@"kPostponementTicket"] = postponement;

        // 写回 plist
        BOOL success = [dict writeToFile:activationPlistPath atomically:YES];
        if (!success) {
            printf("ERR: write failed\n");
            return 4;
        }

        // 修复权限和所有权
        struct passwd *pw = getpwnam("_wireless");
        if (!pw) {
            printf("ERR: getpwnam failed\n");
            return 5;
        }

        if (chown([activationPlistPath UTF8String], pw->pw_uid, pw->pw_gid) != 0) {
            printf("ERR: chown failed\n");
            return 6;
        }

        if (chmod([activationPlistPath UTF8String], 0600) != 0) {
            printf("ERR: chmod failed\n");
            return 7;
        }

        printf("Saved\n");
        return 0;
    }
}

/// 结束CommCenter基带服务进程
/// 系统会自动重启它
int restartCommCenter() {
    __block int killed = 0;

    enumerateProcesses(^(pid_t pid, NSString *path) {
        if ([path.lastPathComponent isEqualToString:@"CommCenter"]) {
            if (kill(pid, SIGKILL) == 0) {
                killed = 1;
            }
        }
    });

    if (killed) {
        printf("Killed\n");
        return 0;
    } else {
        printf("ERR: CommCenter not found\n");
        return 1;
    }
}

/// 结束指定进程
void enumerateProcesses(void (^block)(pid_t pid, NSString *execPath)) {
    int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
    size_t size = 0;

    if (sysctl(mib, 3, NULL, &size, NULL, 0) != 0) return;

    struct kinfo_proc *procs = malloc(size);
    if (!procs) return;

    if (sysctl(mib, 3, procs, &size, NULL, 0) != 0) {
        free(procs);
        return;
    }

    int count = (int)(size / sizeof(struct kinfo_proc));
    for (int i = 0; i < count; i++) {
        pid_t pid = procs[i].kp_proc.p_pid;
        if (pid <= 0) continue;

        size_t argSize = 0;
        if (sysctl((int[]){CTL_KERN, KERN_PROCARGS2, pid}, 3, NULL, &argSize, NULL, 0) != 0)
            continue;

        if (argSize == 0 || argSize > 4096) continue;

        char *buffer = calloc(1, argSize);
        if (!buffer) continue;

        if (sysctl((int[]){CTL_KERN, KERN_PROCARGS2, pid}, 3, buffer, &argSize, NULL, 0) == 0) {
            char *exec = buffer + sizeof(int);
            if (exec && strlen(exec) > 0) {
                NSString *path = [NSString stringWithUTF8String:exec];
                if (path) {
                    block(pid, path);
                }
            }
        }

        free(buffer);
    }

    free(procs);
}

/// 重启设备
void rebootDevice() {
    reboot(0);
}
