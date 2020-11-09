//
//  Insert_dylib.h
//  insert_remove_dylib
//
//  Created by app2 on 2017/9/15.
//  Copyright © 2017年 app2. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Insert_dylib : NSObject
+(void)Insert_dylib:(NSString *)dylib_path targetFile:(NSString *)target_path;
+(void)Insert_dylib:(NSString *)dylib_path targetFile:(NSString *)target_path insertStyle:(uint32_t) insertStyle;

/// 检查所有已注入的动态库
+(void)checkAllDylibAt:(NSString *)target_path;
@end
