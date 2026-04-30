#ifndef MobileGestalt_h
#define MobileGestalt_h

#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// 核心查询函数
CFTypeRef MGCopyAnswer(CFStringRef key);
Boolean MGGetBoolAnswer(CFStringRef key);
int MGGetSInt32Answer(CFStringRef key);
CFStringRef MGCopyAnswerWithError(CFStringRef key, CFErrorRef *error);
CFDictionaryRef MGCopyMultipleAnswers(CFArrayRef keys);

#ifdef __cplusplus
}
#endif

#endif /* MobileGestalt_h */
