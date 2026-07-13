#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 执行 block 并捕获 Objective-C 异常（Swift 无法捕获 NSException）。
/// 返回捕获到的异常，nil 表示正常完成。
NSException * _Nullable RexCatchException(void (NS_NOESCAPE ^block)(void));

NS_ASSUME_NONNULL_END
