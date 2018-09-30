//
//  NSTextField+Dragging.m
//  PackingTool
//
//  Created by Kaymin on 2017/8/2.
//  Copyright © 2017年 TSSDK. All rights reserved.
//

#import "NSTextField+Dragging.h"

@implementation NSTextField (Dragging)

- (void)awakeFromNib {
	[self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	
	NSPasteboard *pasteboard = [sender draggingPasteboard];
	NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
	self.stringValue = files.firstObject;
	return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	
	if (!self.isEnabled) {
		return NSDragOperationNone;
	}
	
//	NSDragOperation dragOperation = [sender draggingSourceOperationMask];
//	NSPasteboard *pasteboard = [sender draggingPasteboard];
	
	return NSDragOperationEvery;
}

@end
