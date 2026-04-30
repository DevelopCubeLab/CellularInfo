#if DEBUG

#import "DebugInterfaceViewController.h"

#import "../Head/CoreTelephonyClient.h"
#import "../Head/CTCellularPlanManager.h"
#import "../Head/CTTelephonyNetworkInfo.h"


#import <UIKit/UIKit.h>

// Notification for block callback debug
static NSString * const CTDebugBlockCallbackNotification = @"CTDebugBlockCallbackNotification";
static NSInteger CTDebugBlockArgCount = 2; // 默认2个参数

#pragma mark - Minimal dynamic invoker

@interface CTInvokeResult : NSObject
@property(nonatomic, copy) NSString *selectorString;
@property(nonatomic, copy) NSString *returnType;
@property(nonatomic, copy) NSString *signatureSummary;
@property(nonatomic, strong) id returnObject;               // object return
@property(nonatomic, strong) NSNumber *returnNumber;        // scalar return
@property(nonatomic, strong) NSError *error;                // NSError** out
@property(nonatomic, copy) NSString *log;                   // extra log
@property(nonatomic, assign) CFTimeInterval elapsedMs;
@end

@implementation CTInvokeResult
@end

@interface CTMethodRunner : NSObject
+ (CTInvokeResult *)invokeTarget:(id)target
                        selector:(NSString *)selString
                       arguments:(NSArray *)args
                   outErrorIndex:(NSInteger)outErrorIndex; // -1 means none
@end

@implementation CTMethodRunner

+ (NSString *)_typeString:(const char *)t {
    if (!t) return @"(null)";
    return [NSString stringWithUTF8String:t];
}

+ (NSString *)_prettyType:(const char *)t {
    if (!t) return @"(null)";
    // Basic, good-enough mapping for debugging
    switch (t[0]) {
        case 'v': return @"void";
        case '@': return @"id";
        case '#': return @"Class";
        case ':': return @"SEL";
        case 'B': return @"BOOL";
        case 'c': return @"char/BOOL";
        case 'i': return @"int";
        case 's': return @"short";
        case 'l': return @"long";
        case 'q': return @"long long";
        case 'C': return @"unsigned char";
        case 'I': return @"unsigned int";
        case 'S': return @"unsigned short";
        case 'L': return @"unsigned long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case '^': return @"pointer";
        default:  return [NSString stringWithFormat:@"%s", t];
    }
}

+ (CTInvokeResult *)invokeTarget:(id)target
                        selector:(NSString *)selString
                       arguments:(NSArray *)args
                   outErrorIndex:(NSInteger)outErrorIndex
{
    CTInvokeResult *res = [CTInvokeResult new];
    res.selectorString = selString ?: @"";

    if (!target || selString.length == 0) {
        res.log = @"Missing target or selector.";
        return res;
    }

    SEL sel = NSSelectorFromString(selString);
    if (![target respondsToSelector:sel]) {
        res.log = @"Target does not respond to selector.";
        return res;
    }

    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    if (!sig) {
        res.log = @"No method signature.";
        return res;
    }

    NSMutableString *summary = [NSMutableString string];
    const char *retT = sig.methodReturnType;
    [summary appendFormat:@"return: %s (%@)\n", retT, [self _prettyType:retT]];

    NSUInteger nArgs = sig.numberOfArguments;
    [summary appendFormat:@"args(%lu):\n", (unsigned long)(nArgs - 2)];
    for (NSUInteger i = 2; i < nArgs; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        [summary appendFormat:@"  [%lu] %s (%@)\n", (unsigned long)(i-2), t, [self _prettyType:t]];
    }
    res.signatureSummary = summary;
    res.returnType = [self _typeString:retT];

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = sel;

    // Prepare NSError** (common)
    __autoreleasing NSError *nsErr = nil;
    NSError *__autoreleasing *errPtr = &nsErr;

    NSUInteger expectedArgs = nArgs - 2;
    NSUInteger providedArgs = args.count;
    NSUInteger count = MIN(expectedArgs, providedArgs);

    for (NSUInteger i = 0; i < count; i++) {
        const char *argType = [sig getArgumentTypeAtIndex:i + 2];

        // ---- Block parameter support (@?) ----
        if (argType[0] == '@' && strlen(argType) > 1 && argType[1] == '?') {
            // Heuristic: infer BOOL-return style based on selector name
            id blockObj = nil;
            BOOL likelyBoolResult = NO;
            NSString *selString = NSStringFromSelector(inv.selector);
            NSString *selLower = [selString lowercaseString];
            if ([selLower containsString:@"is"] ||
                [selLower containsString:@"has"] ||
                [selLower containsString:@"supported"] ||
                [selLower containsString:@"enabled"] ||
                [selLower containsString:@"attached"]) {
                likelyBoolResult = YES;
            }

            if (CTDebugBlockArgCount == 0) {

                void (^block)(void) = ^{

                    NSString *msg = @"[block callback] (no args)";

                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:CTDebugBlockCallbackNotification
                                      object:msg];
                };

                blockObj = [block copy];
            }
            else if (CTDebugBlockArgCount == 1) {

                BOOL useBool = NO;

                NSString *selString = NSStringFromSelector(inv.selector);
                NSString *selLower = [selString lowercaseString];

                if ([selLower containsString:@"is"] ||
                    [selLower containsString:@"has"] ||
                    [selLower containsString:@"supported"] ||
                    [selLower containsString:@"enabled"] ||
                    [selLower containsString:@"attached"]) {
                    useBool = YES;
                }

                if (useBool) {

                    void (^block)(BOOL) = ^(BOOL a) {

                        NSString *msg = [NSString stringWithFormat:
                            @"[block callback] arg0=%@ (BOOL)",
                            a ? @"YES" : @"NO"];

                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:CTDebugBlockCallbackNotification
                                          object:msg];
                    };

                    blockObj = [block copy];

                } else {

                    void (^block)(id) = ^(id a) {

                        NSString *valStr = @"(nil)";

                        if ([a isKindOfClass:[NSNumber class]]) {
                            NSNumber *num = (NSNumber *)a;
                            valStr = [NSString stringWithFormat:@"%@ (NSNumber → %@)",
                                      num,
                                      num.boolValue ? @"YES" : @"NO"];
                        } else if (a) {
                            valStr = [NSString stringWithFormat:@"%@ (%@)",
                                      a,
                                      NSStringFromClass([a class])];
                        }

                        NSString *msg = [NSString stringWithFormat:
                            @"[block callback] arg0=%@",
                            valStr];

                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:CTDebugBlockCallbackNotification
                                          object:msg];
                    };

                    blockObj = [block copy];
                }
            }
            else if (CTDebugBlockArgCount == 2) {

                BOOL useBool = NO;

                NSString *selString = NSStringFromSelector(inv.selector);
                NSString *selLower = [selString lowercaseString];

                if ([selLower containsString:@"is"] ||
                    [selLower containsString:@"has"] ||
                    [selLower containsString:@"supported"] ||
                    [selLower containsString:@"enabled"] ||
                    [selLower containsString:@"attached"]) {
                    useBool = YES;
                }

                if (useBool) {

                    void (^block)(BOOL, NSError *) = ^(BOOL a, NSError *b) {

                        NSString *msg = [NSString stringWithFormat:
                            @"[block callback] arg0=%@ (BOOL) error=%@",
                            a ? @"YES" : @"NO",
                            b ?: @"(nil)"];

                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:CTDebugBlockCallbackNotification
                                          object:msg];
                    };

                    blockObj = [block copy];

                } else {

                    void (^block)(id, NSError *) = ^(id a, NSError *b) {

                        NSString *valStr = @"(nil)";

                        if ([a isKindOfClass:[NSNumber class]]) {
                            NSNumber *num = (NSNumber *)a;
                            valStr = [NSString stringWithFormat:@"%@ (NSNumber → %@)",
                                      num,
                                      num.boolValue ? @"YES" : @"NO"];
                        } else if (a) {
                            valStr = [NSString stringWithFormat:@"%@ (%@)",
                                      a,
                                      NSStringFromClass([a class])];
                        }

                        NSString *msg = [NSString stringWithFormat:
                            @"[block callback] arg0=%@ error=%@",
                            valStr,
                            b ?: @"(nil)"];

                        [[NSNotificationCenter defaultCenter]
                            postNotificationName:CTDebugBlockCallbackNotification
                                          object:msg];
                    };

                    blockObj = [block copy];
                }
            }
            else if (CTDebugBlockArgCount == 3) {

                void (^block)(id,id,id) = ^(id a,id b,id c) {

                    NSString *msg = [NSString stringWithFormat:
                        @"[block callback] arg0=%@ arg1=%@ arg2=%@",
                        a ?: @"(nil)",
                        b ?: @"(nil)",
                        c ?: @"(nil)"];

                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:CTDebugBlockCallbackNotification
                                      object:msg];
                };

                blockObj = [block copy];
            }
            else {

                void (^block)(id,id,id,id) = ^(id a,id b,id c,id d) {

                    NSString *msg = [NSString stringWithFormat:
                        @"[block callback] arg0=%@ arg1=%@ arg2=%@ arg3=%@",
                        a ?: @"(nil)",
                        b ?: @"(nil)",
                        c ?: @"(nil)",
                        d ?: @"(nil)"];

                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:CTDebugBlockCallbackNotification
                                      object:msg];
                };

                blockObj = [block copy];
            }

            [inv setArgument:&blockObj atIndex:(NSInteger)i + 2];
            continue;
        }
        // ---- End block support ----

        // Inject NSError** (explicit template or auto-detected)
        if ((outErrorIndex >= 0 && (NSInteger)i == outErrorIndex) ||
            (argType[0] == '^' && argType[1] == '@')) {
            [inv setArgument:&errPtr atIndex:(NSInteger)i + 2];
            continue;
        }

        id obj = args[i];

        // Object parameter
        if (argType[0] == '@') {
            id v = (obj == [NSNull null]) ? nil : obj;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }

        // Scalar helpers
        if (argType[0] == 'B' || argType[0] == 'c') {
            BOOL b = [obj respondsToSelector:@selector(boolValue)] ? [obj boolValue] : NO;
            [inv setArgument:&b atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'i') {
            int v = [obj respondsToSelector:@selector(intValue)] ? [obj intValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'q') {
            long long v = [obj respondsToSelector:@selector(longLongValue)] ? [obj longLongValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'Q') {
            unsigned long long v = [obj respondsToSelector:@selector(unsignedLongLongValue)] ? [obj unsignedLongLongValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'I') {
            unsigned int v = [obj respondsToSelector:@selector(unsignedIntValue)] ? [obj unsignedIntValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'f') {
            float v = [obj respondsToSelector:@selector(floatValue)] ? [obj floatValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }
        if (argType[0] == 'd') {
            double v = [obj respondsToSelector:@selector(doubleValue)] ? [obj doubleValue] : 0;
            [inv setArgument:&v atIndex:(NSInteger)i + 2];
            continue;
        }

        res.log = [NSString stringWithFormat:@"Unsupported arg type: %s at index %lu", argType, (unsigned long)i];
        return res;
    }

    CFTimeInterval t0 = CACurrentMediaTime();
    @try {
        [inv invoke];
    } @catch (NSException *ex) {
        res.log = [NSString stringWithFormat:@"Exception: %@ — %@", ex.name ?: @"(nil)", ex.reason ?: @"(nil)"];
        return res;
    }
    CFTimeInterval t1 = CACurrentMediaTime();
    res.elapsedMs = (t1 - t0) * 1000.0;

    res.error = nsErr;

    // Read return value
    if (retT[0] == 'v') {
        res.log = @"Return void.";
        return res;
    }

    if (retT[0] == '@') {
        __unsafe_unretained id returnObj = nil;
        [inv getReturnValue:&returnObj];
        res.returnObject = returnObj;
        return res;
    }

    if (retT[0] == 'B' || retT[0] == 'c') {
        BOOL b = NO;
        [inv getReturnValue:&b];
        res.returnNumber = @(b);
        return res;
    }
    if (retT[0] == 'i') {
        int v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }
    if (retT[0] == 'q') {
        long long v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }
    if (retT[0] == 'Q') {
        unsigned long long v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }
    if (retT[0] == 'I') {
        unsigned int v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }
    if (retT[0] == 'f') {
        float v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }
    if (retT[0] == 'd') {
        double v = 0;
        [inv getReturnValue:&v];
        res.returnNumber = @(v);
        return res;
    }

    // ---- Struct return support (e.g. {?=BB}) ----
    if (retT[0] == '{') {
        NSUInteger len = sig.methodReturnLength;
        if (len == 0) {
            res.log = @"Struct return but size is 0.";
            return res;
        }

        uint8_t buffer[64] = {0};
        NSUInteger copyLen = MIN(len, sizeof(buffer));
        [inv getReturnValue:buffer];

        NSMutableString *hex = [NSMutableString string];
        for (NSUInteger i = 0; i < copyLen; i++) {
            [hex appendFormat:@"%02X ", buffer[i]];
        }

        NSMutableString *detail = [NSMutableString stringWithFormat:
            @"Struct return (%s), %lu bytes: [%@]",
            retT,
            (unsigned long)len,
            hex];

        // Special-case decode for common pattern {?=BB}
        if (strcmp(retT, "{?=BB}") == 0 && len >= 2) {
            BOOL b0 = buffer[0];
            BOOL b1 = buffer[1];
            [detail appendFormat:@" → BOOLs: {%d, %d}", b0, b1];
        }

        res.log = detail;
        return res;
    }

    res.log = [NSString stringWithFormat:@"Unsupported return type: %s", retT];
    return res;
}

@end

#pragma mark - Debug UI

typedef NS_ENUM(NSInteger, CTArgTemplate) {
    CTArgTemplate_NoArgs = 0,
    CTArgTemplate_ErrorOnly = 1,
    CTArgTemplate_Context_Error = 2,
    CTArgTemplate_ContextOnly = 3,
    CTArgTemplate_ServiceDescriptor_Error = 4,
};

@interface DebugInterfaceViewController ()
@property(nonatomic, strong) CoreTelephonyClient *ctClient;
@property(nonatomic, strong) CTTelephonyNetworkInfo *networkInfo;

@property(nonatomic, strong) CTCellularPlanManager *planManager;
@property(nonatomic, strong) UISegmentedControl *frameworkControl;

@property(nonatomic, strong) UITextField *selectorField;
@property(nonatomic, strong) UISegmentedControl *templateControl;
@property(nonatomic, strong) UISegmentedControl *blockArgControl;
@property(nonatomic, strong) UIButton *runButton;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UITextView *outputView;
@end

@implementation DebugInterfaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"调试";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    // Directly create CoreTelephonyClient instance as requested.
    self.ctClient = [CoreTelephonyClient new];
    self.networkInfo = [CTTelephonyNetworkInfo new];
    if ([CTCellularPlanManager respondsToSelector:@selector(sharedManager)]) {
        self.planManager = [CTCellularPlanManager sharedManager];
    } else {
        self.planManager = [CTCellularPlanManager new];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBlockCallback:)
                                                 name:CTDebugBlockCallbackNotification
                                               object:nil];

    [self buildUI];
    [self appendLine:@"Ready. Paste selector (e.g. getSIMTrayStatusOrError) and tap Run." ];
}

// Block callback notification handler
- (void)onBlockCallback:(NSNotification *)note {
    NSString *msg = (NSString *)note.object;
    if (msg.length) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendLine:msg];
        });
    }
}

- (void)buildUI {
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UIStackView *selectorRow = [[UIStackView alloc] initWithFrame:CGRectZero];
    selectorRow.axis = UILayoutConstraintAxisHorizontal;
    selectorRow.spacing = 8;
    selectorRow.alignment = UIStackViewAlignmentFill;
    selectorRow.distribution = UIStackViewDistributionFill;
    [stack addArrangedSubview:selectorRow];

    self.selectorField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.selectorField.placeholder = @"selector (e.g. copyMobileEquipmentIdentifier:error:)";
    self.selectorField.borderStyle = UITextBorderStyleRoundedRect;
    self.selectorField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.selectorField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.selectorField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [selectorRow addArrangedSubview:self.selectorField];

    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [pasteBtn setTitle:@"Paste" forState:UIControlStateNormal];
    [pasteBtn addTarget:self action:@selector(onPaste) forControlEvents:UIControlEventTouchUpInside];
    // Keep it compact
    [pasteBtn.widthAnchor constraintEqualToConstant:70].active = YES;
    [selectorRow addArrangedSubview:pasteBtn];

    self.frameworkControl = [[UISegmentedControl alloc] initWithItems:@[
        @"CoreTelephony",
        @"CTTelephonyNetworkInfo",
        @"CellularPlan"
    ]];
    self.frameworkControl.selectedSegmentIndex = 0;
    [stack addArrangedSubview:self.frameworkControl];

    self.templateControl = [[UISegmentedControl alloc] initWithItems:@[
        @"NoArgs",
        @"Err",
        @"Ctx+Err",
        @"Ctx",
        @"SD+Err"
    ]];
    self.templateControl.selectedSegmentIndex = CTArgTemplate_Context_Error;
    [stack addArrangedSubview:self.templateControl];

    self.blockArgControl = [[UISegmentedControl alloc] initWithItems:@[
        @"Block1",
        @"Block2",
        @"Block3",
        @"Block4"
    ]];

    self.blockArgControl.selectedSegmentIndex = 1; // 默认2参数
    [self.blockArgControl addTarget:self
                             action:@selector(onBlockArgChanged:)
                   forControlEvents:UIControlEventValueChanged];

    [stack addArrangedSubview:self.blockArgControl];
    
    UIStackView *btnRow = [[UIStackView alloc] initWithFrame:CGRectZero];
    btnRow.axis = UILayoutConstraintAxisHorizontal;
    btnRow.spacing = 10;
    btnRow.distribution = UIStackViewDistributionFillEqually;
    [stack addArrangedSubview:btnRow];

    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.runButton setTitle:@"Run" forState:UIControlStateNormal];
    [self.runButton addTarget:self action:@selector(onRun) forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:self.runButton];

    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [self.clearButton addTarget:self action:@selector(onClear) forControlEvents:UIControlEventTouchUpInside];
    [btnRow addArrangedSubview:self.clearButton];

    self.outputView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.outputView.editable = NO;
    if (@available(iOS 13.0, *)) {
        self.outputView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        self.outputView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } else {
        self.outputView.font = [UIFont fontWithName:@"Menlo-Regular" size:12] ?: [UIFont systemFontOfSize:12];
        self.outputView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    }
    self.outputView.layer.cornerRadius = 10;
    self.outputView.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
    [stack addArrangedSubview:self.outputView];

    // Layout
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12],
        [stack.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-12],
        [self.outputView.heightAnchor constraintGreaterThanOrEqualToConstant:200]
    ]];
}

- (void)onBlockArgChanged:(UISegmentedControl *)sender {
    CTDebugBlockArgCount = sender.selectedSegmentIndex + 1;

    [self appendLine:[NSString stringWithFormat:
        @"[config] block args = %ld",
        (long)CTDebugBlockArgCount]];
}

- (void)onClear {
    self.outputView.text = @"";
}

- (void)onPaste {
    NSString *s = [UIPasteboard generalPasteboard].string;
    if (s.length == 0) {
        [self appendLine:@"[!] Pasteboard empty."];
        return;
    }
    self.selectorField.text = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self appendLine:[NSString stringWithFormat:@"[paste] %@", self.selectorField.text]];
}

- (void)onRun {
    [self.view endEditing:YES];

    NSString *sel = self.selectorField.text ?: @"";
    sel = [sel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (sel.length == 0) {
        [self appendLine:@"[!] Empty selector."];
        return;
    }

    NSInteger tpl = self.templateControl.selectedSegmentIndex;

    id target = nil;

    if (self.frameworkControl.selectedSegmentIndex == 0) {
        target = self.ctClient;
    } else if (self.frameworkControl.selectedSegmentIndex == 1) {
        target = self.networkInfo;
    } else {
        target = self.planManager;
    }

    // Resolve a friendly input like "getLocalizedOperatorName" into a real selector.
    // We try different suffixes based on the chosen argument template.
    NSString *resolvedSel = sel;
    if ([resolvedSel rangeOfString:@":"].location == NSNotFound) {
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        switch (tpl) {
            case CTArgTemplate_NoArgs:
                [candidates addObject:sel];
                break;
            case CTArgTemplate_ErrorOnly:
                [candidates addObject:[sel stringByAppendingString:@":"]];
                [candidates addObject:[sel stringByAppendingString:@":error:"]];
                break;
            case CTArgTemplate_Context_Error:
                [candidates addObject:[sel stringByAppendingString:@":error:"]];
                [candidates addObject:[sel stringByAppendingString:@":"]];
                break;
            case CTArgTemplate_ContextOnly:
                [candidates addObject:[sel stringByAppendingString:@":"]];
                break;
            case CTArgTemplate_ServiceDescriptor_Error:
                [candidates addObject:[sel stringByAppendingString:@":error:"]];
                [candidates addObject:[sel stringByAppendingString:@":"]];
                break;
            default:
                [candidates addObject:sel];
                break;
        }

        // Pick the first one that exists on CoreTelephonyClient
        resolvedSel = nil;
        for (NSString *c in candidates) {
            SEL testSel = NSSelectorFromString(c);
            if ([target respondsToSelector:testSel]) {
                resolvedSel = c;
                break;
            }
        }
        if (!resolvedSel) {
            resolvedSel = sel; // fallback
        }
    }

    // Auto-acquire a preferred data subscription context or service descriptor when the selected template needs it.
    id contextObj = nil;
    id serviceDescriptorObj = nil;

    if (tpl == CTArgTemplate_Context_Error || tpl == CTArgTemplate_ContextOnly) {
        __autoreleasing NSError *ctxErr = nil;
        if ([self.ctClient respondsToSelector:@selector(getPreferredDataSubscriptionContextSync:)]) {
            contextObj = [self.ctClient getPreferredDataSubscriptionContextSync:(id *)&ctxErr];
        }
        if (ctxErr) {
            [self appendLine:[NSString stringWithFormat:@"[ctx] error: %@ (domain=%@ code=%ld)", ctxErr, ctxErr.domain, (long)ctxErr.code]];
        } else {
            [self appendLine:[NSString stringWithFormat:@"[ctx] %@", contextObj ?: @"(nil)"]];
        }
    }

    if (tpl == CTArgTemplate_ServiceDescriptor_Error) {
        __autoreleasing NSError *sdErr = nil;
        if ([self.ctClient respondsToSelector:@selector(getCurrentDataServiceDescriptorSync:)]) {
            serviceDescriptorObj = [self.ctClient getCurrentDataServiceDescriptorSync:(id *)&sdErr];
        }
        if (sdErr) {
            [self appendLine:[NSString stringWithFormat:@"[sd] error: %@ (domain=%@ code=%ld)", sdErr, sdErr.domain, (long)sdErr.code]];
        } else {
            [self appendLine:[NSString stringWithFormat:@"[sd] %@", serviceDescriptorObj ?: @"(nil)"]];
        }
    }

    sel = resolvedSel;

    NSArray *args = @[];
    NSInteger outErrIndex = -1;
    // Inspect real method signature to avoid mismatched template (e.g. block vs NSError**)
    SEL realSel = NSSelectorFromString(sel);
    NSMethodSignature *realSig = [target methodSignatureForSelector:realSel];

    BOOL secondArgIsBlock = NO;
    NSUInteger realArgCount = 0;
    if (realSig) {
        realArgCount = realSig.numberOfArguments - 2;
        if (realArgCount >= 2) {
            const char *arg1Type = [realSig getArgumentTypeAtIndex:3]; // second logical arg
            if (arg1Type && arg1Type[0] == '@' && strlen(arg1Type) > 1 && arg1Type[1] == '?') {
                secondArgIsBlock = YES;
            }
        }
    }

    switch (tpl) {
        case CTArgTemplate_NoArgs:
            args = @[];
            outErrIndex = -1;
            break;

        case CTArgTemplate_ErrorOnly:
            if (realArgCount == 1 && !secondArgIsBlock) {
                args = @[ [NSNull null] ];
                outErrIndex = 0;
            } else {
                args = @[];
                outErrIndex = -1;
            }
            break;

        case CTArgTemplate_Context_Error:
            if (realArgCount == 2 && secondArgIsBlock) {
                // fetchPhonebook:completion: style
                args = @[ (contextObj ?: [NSNull null]), [NSNull null] ];
                outErrIndex = -1; // no NSError**
            } else {
                args = @[ (contextObj ?: [NSNull null]), [NSNull null] ];
                outErrIndex = 1;
            }
            break;

        case CTArgTemplate_ContextOnly:
            args = @[ (contextObj ?: [NSNull null]) ];
            outErrIndex = -1;
            break;

        case CTArgTemplate_ServiceDescriptor_Error:
            if (realArgCount == 2 && secondArgIsBlock) {
                args = @[ (serviceDescriptorObj ?: [NSNull null]), [NSNull null] ];
                outErrIndex = -1;
            } else {
                args = @[ (serviceDescriptorObj ?: [NSNull null]), [NSNull null] ];
                outErrIndex = 1;
            }
            break;

        default:
            args = @[];
            outErrIndex = -1;
            break;
    }

    [self appendLine:@"\n====================" ];
    [self appendLine:[NSString stringWithFormat:@"Selector: %@", sel]];

    CTInvokeResult *r = [CTMethodRunner invokeTarget:target
                                            selector:sel
                                           arguments:args
                                       outErrorIndex:outErrIndex];

    if (r.signatureSummary.length) {
        [self appendLine:@"Signature:"];
        [self appendLine:r.signatureSummary];
    }

    if (r.returnObject) {
        [self appendLine:[NSString stringWithFormat:@"Return (obj): %@", r.returnObject]];
    } else if (r.returnNumber) {
        [self appendLine:[NSString stringWithFormat:@"Return (num): %@", r.returnNumber]];
    } else {
        [self appendLine:@"Return: (nil/void/unsupported)" ];
    }

    [self appendLine:[NSString stringWithFormat:@"Elapsed: %.3f ms", r.elapsedMs]];

    if (r.error) {
        [self appendLine:[NSString stringWithFormat:@"NSError**: %@ (domain=%@ code=%ld)", r.error, r.error.domain, (long)r.error.code]];
    } else {
        [self appendLine:@"NSError**: (nil)" ];
    }

    if (r.log.length) {
        [self appendLine:[NSString stringWithFormat:@"Log: %@", r.log]];
    }
}

- (void)appendLine:(NSString *)line {
    if (!line) return;
    NSString *cur = self.outputView.text ?: @"";
    NSString *next = cur.length ? [cur stringByAppendingFormat:@"\n%@", line] : line;
    self.outputView.text = next;

    // Auto-scroll to bottom
    NSRange range = NSMakeRange(self.outputView.text.length, 0);
    [self.outputView scrollRangeToVisible:range];

    // Also NSLog for easy capture
    NSLog(@"[CTDebug] %@", line);
}

// Remove observer on dealloc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:CTDebugBlockCallbackNotification
                                                  object:nil];
}

@end

#endif
