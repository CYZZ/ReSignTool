//
//  AppDelegate.m
//  ReSignTool
//
//  Created by Mac on 2018/9/29.
//  Copyright © 2018年 Mac. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	// 最后一个窗口关闭之后直接退出应用
	return YES;
}


@end
