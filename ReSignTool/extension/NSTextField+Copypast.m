//
//  NSTextField+Copypast.m
//  PackingTool
//
//  Created by Kaymin on 2017/7/25.
//  Copyright © 2017年 TSSDK. All rights reserved.
//

#import "NSTextField+Copypast.h"

@implementation NSTextField (Copypast)

- (BOOL)performKeyEquivalent:(NSEvent *)event {
	if (([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) {
		// The command key is the ONLY modifier key being pressed.
		if ([[event charactersIgnoringModifiers] isEqualToString:@"x"]) {
			return [NSApp sendAction:@selector(cut:) to:[[self window] firstResponder] from:self];
		} else if ([[event charactersIgnoringModifiers] isEqualToString:@"c"]) {
			return [NSApp sendAction:@selector(copy:) to:[[self window] firstResponder] from:self];
		} else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"]) {
			return [NSApp sendAction:@selector(paste:) to:[[self window] firstResponder] from:self];
		} else if ([[event charactersIgnoringModifiers] isEqualToString:@"a"]) {
			return [NSApp sendAction:@selector(selectAll:) to:[[self window] firstResponder] from:self];
		}
	}
	return [super performKeyEquivalent:event];
}

@end
