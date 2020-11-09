//
//  DylibManager.m
//  ReSignTool
//
//  Created by chiyz on 2020/11/4.
//  Copyright © 2020 Mac. All rights reserved.
//

#import "DylibManager.h"

@implementation DylibManager

+ (instancetype)manager {
	static DylibManager *_instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		//不能再使用alloc方法
		// 因为已经重写了allocWithZone方法，所以这里要调用父类的分配控件的方法
		_instance = [[super allocWithZone:NULL] init];
	});
	return  _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
	return [DylibManager manager];
}




@end
