//
//  DylibManager.h
//  ReSignTool
//
//  Created by chiyz on 2020/11/4.
//  Copyright © 2020 Mac. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LogDelegate <NSObject>

/// 开始回调log信息
/// @param str log信息
- (void)starLogWith:(NSString *_Nonnull)str;

@end

NS_ASSUME_NONNULL_BEGIN

@interface DylibManager : NSObject

/// 创建单例对象
+ (instancetype)manager;

/// log信息接收代理
@property(nonatomic, weak) id<LogDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
