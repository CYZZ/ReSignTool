//
//  NSTextField+Copypast.h
//  PackingTool
//
//  Created by Kaymin on 2017/7/25.
//  Copyright © 2017年 TSSDK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextField (Copypast) <NSDraggingDestination>

- (BOOL)performKeyEquivalent:(NSEvent *)event;

@end
