//
//  DylibViewController.m
//  ReSignTool
//
//  Created by chiyz on 2020/11/4.
//  Copyright © 2020 Mac. All rights reserved.
//

#import "DylibViewController.h"
#import "DylibManager.h"
#import "Insert_dylib.h"
#import "Remove_dylib.h"

#import <mach-o/loader.h>
#import <mach-o/fat.h>

@interface DylibViewController ()<LogDelegate>

@property (weak) IBOutlet NSTextField *machoTextField;
@property (weak) IBOutlet NSTextField *dylibTextField;
@property (weak) IBOutlet NSScrollView *logScrollView;
@property (unsafe_unretained) IBOutlet NSTextView *logTextView;

@property (weak) IBOutlet NSButton *isWeakButton;
@property (weak) IBOutlet NSButton *checkAllButton;
@property (weak) IBOutlet NSButton *checkExistButton;
@property (weak) IBOutlet NSButton *insetButton;
@property (weak) IBOutlet NSButton *removeButton;

@end

@implementation DylibViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
	[DylibManager manager].delegate = self; // 设置log的代理是自己
}


- (IBAction)isWeakClick:(NSButton *)sender {
	
}

- (IBAction)checkAllClick:(id)sender {
	[Insert_dylib checkAllDylibAt:self.machoTextField.stringValue];

	
}

- (IBAction)checkExistClick:(id)sender {
//		[Insert_dylib Insert_dylib:@"" targetFile:self.machoTextField.stringValue];
}

- (IBAction)insertClick:(id)sender {
	if (self.dylibTextField.stringValue.length == 0) {
		[self starLogWith:@"\nError Missing dylib Parameter!!!"];
		return;
	}
	if (self.isWeakButton.state == NSControlStateValueOn) {
		// 使用weak注入
		[Insert_dylib Insert_dylib:self.dylibTextField.stringValue targetFile:self.machoTextField.stringValue insertStyle:LC_LOAD_WEAK_DYLIB];
	} else {
		[Insert_dylib Insert_dylib:self.dylibTextField.stringValue targetFile:self.machoTextField.stringValue];
	}
}

- (IBAction)removeClick:(id)sender {
	
	[Remove_dylib Remove_dylib:self.dylibTextField.stringValue targetFile:self.machoTextField.stringValue];
}


- (void)starLogWith:(NSString *)str {
	
	[self.logTextView insertText:str];
	[self.logTextView insertText:@"\n"];
}

- (void)dealloc
{
	NSLog(@"func=%s",__FUNCTION__);
	
}

@end
