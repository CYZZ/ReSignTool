//
//  ViewController.m
//  ReSignTool
//
//  Created by Mac on 2018/9/29.
//  Copyright © 2018年 Mac. All rights reserved.
//

#import "ViewController.h"
#import "NSTextField+Copypast.h"
#import "NSTextField+Dragging.h"

#import <objc/runtime.h>

static NSString *kTYPEFramework = @"task Framework";
static NSString *kZip = @"task zip";
static NSString *kApp = @"task app";
static NSString *kPlugin = @"task appex";
static NSString *kEntitlements = @"task create entitlements.plist";
static NSString *kDelete = @"task delete _CodeSignature";
static NSString *kCopy = @"task copy embedded.mobileprovision";

	/// runtime的key
static const char *typeKey = "typeKey";

@interface ViewController ()
@property (weak) IBOutlet NSTextField *ipaPathTextField;
@property (weak) IBOutlet NSTextField *provisionTextField;
@property (weak) IBOutlet NSTextField *entitlementsTextField;
@property (weak) IBOutlet NSComboBox *certNameComboBox;
@property (weak) IBOutlet NSTextField *originalBundleIDTextField;
@property (weak) IBOutlet NSTextField *replaceBundleIDTextField;
@property (unsafe_unretained) IBOutlet NSTextView *outputTextView;
@property (weak) IBOutlet NSScrollView *logScrollView;
@property (weak) IBOutlet NSTextField *outputipaNameTextField;
@property (weak) IBOutlet NSButton *replaceBundleIDButton;

@property(nonatomic, strong) NSMutableArray *frameworksArray;
@property(nonatomic, strong) NSMutableArray *pluginsArray;

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[self loadCerts];
	
	[self log:@"初始化完成"];
	
		// Do any additional setup after loading the view.
}
- (IBAction)creactEntitlement:(NSButton *)sender {
	[self genuerateEntitlements];
}
- (IBAction)testButtonClick:(NSButton *)sender {
	NSStoryboard *main = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
	NSViewController *VC = [main instantiateControllerWithIdentifier:@"secondViewController"];
	NSLog(@"VC = %@",VC);
	
	[self presentViewControllerAsSheet:VC];
		//	[self presentViewControllerAsModalWindow:VC];
		//	[self preseviewcon]
		//	[self presentViewController:VC animator:self];
	
}

	// 生成plist文件
- (BOOL)genuerateEntitlements
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[self provisionFile]]) {
		NSString *securityCmd = [NSString stringWithFormat:@"security cms -D -i %@ > entitlements_full.plist", [self provisionFile]];
		NSString *plistCmd =@"/usr/libexec/PlistBuddy -x -c 'Print:Entitlements' entitlements_full.plist > entitlements.plist";
			//		NSString *deleteFullCmd = @"rm -rf entitlements_full.plist";
		NSString *command = [NSString stringWithFormat:@"%@;%@;", securityCmd, plistCmd];
		
		[self processTask:@"/bin/bash" arguments:@[@"-c", command] currentDir:[self provisionPath] taskType:kEntitlements];
		[self log:@"genuerate entitlements.plist"];
			// 自动填充
		self.entitlementsTextField.stringValue = [[self provisionPath] stringByAppendingPathComponent:@"entitlements.plist"];
		return YES;
	}
	
	return NO;
}

- (IBAction)readBundleIDbuttonClick:(NSButton *)sender {
	NSString *infoPlistPath = [[self appFile] stringByAppendingPathComponent:@"info.plist"];
	NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
	NSString *bundleID = plistDic[@"CFBundleIdentifier"];
	self.originalBundleIDTextField.stringValue = bundleID;
}
- (IBAction)repalceBundleIDbuttonClick:(NSButton *)sender {
		//	sender.state = NO;
	if (sender.state == 0) {
		self.replaceBundleIDTextField.enabled = NO;
	} else {
		self.replaceBundleIDTextField.enabled = YES;
	}
	NSLog(@"sender.state = %ld",sender.state);
		//	[self doAppBundleIDChange];
}
	// 进行签名
- (IBAction)resignButtonClick:(NSButton *)sender {
		//	[self showContextHelp:@"查看帮助"];
	
	[self doAppBundleIDChange];
	[self deleteCodeSignature];
	[self copyProvision];
	[self codesignPlugins];
	//	[self codesignFrameworks];
		//	[self codesignApp];
	
}
- (IBAction)verifyButtonClick:(NSButton *)sender {
	NSString *appPath = [self appFile];
	
	[self processTask:@"/usr/bin/codesign" arguments:@[@"-vv",appPath] currentDir:appPath taskType:@"验证签名文件app"];
}


- (IBAction)packButtonClick:(id)sender {
	NSString *ipaPath = [self ipaPath];
		//	NSString *payload = [[self ipaPath] stringByAppendingPathComponent:@"Payload"];
	NSString *payload = @"Payload";
		//	NSFileManager *filemanager = [NSFileManager defaultManager];
		//	if ([filemanager fileExistsAtPath:payload]) {
	NSString *payloadPath = [ipaPath stringByAppendingPathComponent:payload];
	[self processTask:@"/bin/rm" arguments:@[@"-rf",@".DS_Store"] currentDir:payloadPath taskType:kDelete];
	[self processTask:@"/usr/bin/zip" arguments:@[@"-r",self.outputipaNameTextField.stringValue,payload] currentDir:ipaPath taskType:kZip];
		//		[self processTask:@"/usr/bin/zip" arguments:@[@"-qry",self.outputTextView.string,@"."] currentDir:payload taskType:kZip];
		//	}
		//	[self doAppBundleIDChange];
}

	/// 删除签名文件
- (BOOL)deleteCodeSignature{
	NSString *signPath = [[self appFile] stringByAppendingPathComponent:@"_CodeSignature"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:signPath]) {
		[self processTask:@"/bin/rm" arguments:@[@"-rf",signPath] currentDir:[self ipaPath] taskType:kDelete];
		return YES;
	}
	return NO;
}

	/// 复制描述文件(embedded.mobileprovision)
- (BOOL)copyProvision{
	NSString *appPath = [self appFile];
	NSString *embeddedFile = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
	[self log:@"copy embeddedFile"];
	[self processTask:@"/bin/cp" arguments:@[[self provisionFile], embeddedFile] currentDir:[self ipaPath] taskType:kCopy];
	return YES;
}


	/// 加载Apple证书
- (void)loadCerts
{
		// 命令行：security find-identity -v -p codesigning
	NSPipe *outputPipe = [NSPipe pipe];
	
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/usr/bin/security";
	task.arguments = @[@"find-identity",@"-v",@"-p",@"codesigning"];
	task.currentDirectoryPath = [[NSBundle mainBundle] bundlePath];
	task.standardOutput = outputPipe;
	[task launch];
	
	NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
	NSString *outputStr = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
		//	NSLog(@"outputStr = %@",outputStr);
	NSArray *components = [outputStr componentsSeparatedByString:@"\""];
		//	NSLog(@"components = %@",components);
	
	NSMutableArray<NSString*> *cerArr = [NSMutableArray array];
	for (int i = 0; i <= components.count-1; i += 2) {
		if (components.count-1 < i+1) {
			
		} else {
			NSString *cerName = components[i+1];
			[cerArr addObject:cerName];
		}
	}
	[self.certNameComboBox addItemsWithObjectValues:cerArr];
	
	NSLog(@"certs = %@", cerArr);
}

- (BOOL)doAppBundleIDChange{
	NSString *infoPlistPath = [[self appFile] stringByAppendingPathComponent:@"info.plist"];
	NSMutableDictionary *plistDic = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
		//	NSString *bundleID = plsitDic[@"CFBundleIdentifier"];
		//	self.originalBundleIDTextField.stringValue = bundleID;
	if (self.replaceBundleIDButton.state == 1 && self.replaceBundleIDTextField.stringValue.length > 0) {
		plistDic[@"CFBundleIdentifier"] = self.replaceBundleIDTextField.stringValue;
		NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plistDic format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
		return [xmlData writeToFile:infoPlistPath atomically:YES];
	}
		//	return  [plistDic writeToFile:infoPlistPath atomically:YES];
	
	return YES;
}

/// 对plugin进行签名
- (BOOL)codesignPlugins {
	NSString *appPath = [self appFile];
	NSString *PluginPath = [appPath stringByAppendingPathComponent:@"PlugIns"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir = NO;
	BOOL exists = [fileManager fileExistsAtPath:PluginPath isDirectory:&isDir];
	
	
	if (exists && isDir == YES) {
		NSMutableArray *subDirMu = [NSMutableArray array];
		NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:appPath];
		NSString *file;
		while ((file = [dirEnum nextObject])) {
			if ([[file pathExtension] isEqualToString:@"appex"]) {
				[subDirMu addObject:file];
			}
		}
		self.pluginsArray = subDirMu;
		[self begincodesignPlugin];
	} else {
		[self codesignFrameworks];
	}
	return YES;
}

/// 开始逐个进行签名
- (BOOL)begincodesignPlugin{
	NSString *appPath = [self appFile];
	
	NSString *fileName = self.pluginsArray.lastObject;
	
	// 如果没有动态库直接对app进行签名
	if (self.pluginsArray.count == 0) {
		[self codesignFrameworks];
		return NO;
	}
	
	if (fileName.length > 0) {
		
		[self log:[NSString stringWithFormat:@"Copy embedded to plugin --%@",fileName]];
		NSString *embeddedFile = [fileName stringByAppendingPathComponent:@"embedded.mobileprovision"];
		[self log:@"copy embeddedFile"];
		[self processTask:@"/bin/cp" arguments:@[[self provisionFile], embeddedFile] currentDir:appPath taskType:kCopy];
		
		NSString *taskTye = [@"codesigned  -" stringByAppendingString:fileName];
		[self log:[NSString stringWithFormat:@"codesigning--%@",fileName]];
		
		[self processTask:@"/usr/bin/codesign"
				arguments:@[@"-f",
							@"-s",
							[NSString stringWithFormat:@"%@", [self certName]],
							@"--entitlements",
							[self entitlementFile],
							fileName]
			   currentDir:appPath
				 taskType:taskTye];
		[self.pluginsArray removeLastObject]; // 签名完之后就移除
		
		return YES;
	} else {
		return NO;
	}
	
   
}


	/// 签名framework
- (BOOL)codesignFrameworks{
	
	NSString *appPath = [self appFile];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
//	NSArray *contents = [fileManager subpathsOfDirectoryAtPath:appPath error:nil];
//
//	NSString *match = @"*.framework";
//	NSString *match2 = @"*.dylib"; // 有些swift项目会有类似libSwiftUIKit.dylib框架
//
//	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF like %@ || SELF like %@",match,match2];
//	contents = [contents filteredArrayUsingPredicate:predicate];
	
	NSMutableArray *subDirMu = [NSMutableArray array];
	NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:appPath];
	NSString *file;
	while ((file = [dirEnum nextObject])) {
		if ([[file pathExtension] isEqualToString:@"framework"] || [[file pathExtension] isEqualToString:@"dylib"]) {
			[subDirMu addObject:file];
		}
	}
	NSArray *contents = [subDirMu copy];
	
		// 对文件进行排序，确保按照内部往外签名 倒叙
	contents = [contents sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
		NSInteger len0 = [(NSString *)obj1 length];
		NSInteger len1 = [(NSString *)obj2 length];
		return len0 < len1? NSOrderedAscending : NSOrderedDescending;
	}];
	
	self.frameworksArray  = [NSMutableArray arrayWithArray:contents];
	
		//	for (NSString *filename in contents) {
		//		NSLog(@"cosign:%@", filename);
		//		[self log:[NSString stringWithFormat:@"cosign%@",filename]];
		//
		//		[self processTask:@"/usr/bin/codesign"
		//				arguments:@[@"-f",
		//							@"-s",
		//							[NSString stringWithFormat:@"%@", [self certName]],
		//							@"--entitlements",
		//							[self entitlementFile],
		//							filename]
		//			   currentDir:appPath
		//				 taskType:kTYPEFramework];
		//
		//	}
		// 需要一个个进行签名
	[self begincodesignFramework];
	
	return YES;
}

	/// 开始逐个进行签名
- (BOOL)begincodesignFramework{
	NSString *appPath = [self appFile];
	
	NSString *fileName = self.frameworksArray.lastObject;
	
		// 如果没有动态库直接对app进行签名
	if (self.frameworksArray.count == 0) {
		[self codesignApp];
		return NO;
	}
	
	if (fileName.length > 0) {
		NSString *taskTye = [@"codesigned  -" stringByAppendingString:fileName];
		[self log:[NSString stringWithFormat:@"codesigning--%@",fileName]];
		
		[self processTask:@"/usr/bin/codesign"
				arguments:@[@"-f",
							@"-s",
							[NSString stringWithFormat:@"%@", [self certName]],
							@"--entitlements",
							[self entitlementFile],
							fileName]
			   currentDir:appPath
				 taskType:taskTye];
		[self.frameworksArray removeLastObject]; // 签名完之后就移除
		
		return YES;
	} else {
		return NO;
	}
	
	
}

	/// 签名APP
- (BOOL)codesignApp{
	NSString *appPath = [self appFile];
	NSString *plistFile = [self entitlementFile];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (![fileManager fileExistsAtPath:plistFile]) {
		[self genuerateEntitlements];
	}
	[self log:[@"codesigning-- " stringByAppendingString:appPath]];
	[self processTask:@"/usr/bin/codesign"
			arguments:@[@"-f",
						@"-s",
						[self certName],
						@"--entitlements",
						plistFile,
						appPath]
		   currentDir:[self ipaPath]
			 taskType:kApp];
	return YES;
}

- (void)log:(NSString *)line{
	
	NSMutableString *string = [NSMutableString stringWithString:self.outputTextView.string];
	if (string.length > 0) {
		[string appendString:@"\n"];
	}
	[string appendString:line];
	self.outputTextView.string = string;
	NSPoint point = NSMakePoint(0, self.logScrollView.contentSize.height);
	[self.logScrollView scrollPoint:point]; // 默认数据更新之后滚动到底部
}


#pragma mark - 各个文件名和路径
- (NSString *)certName
{
	return self.certNameComboBox.stringValue;
}
	/// 原bundleID
- (NSString *)originalBundleIDName{
	return self.originalBundleIDTextField.stringValue;
}
	/// 需要替换的bundleID
- (NSString *)replaceBundleIDName{
	return self.replaceBundleIDTextField.stringValue;
}

	/// 描述文件mobileprovision路径
- (NSString *)provisionPath{
	return [self.provisionTextField.stringValue stringByDeletingLastPathComponent];
}

- (NSString *)provisionFile{
	return self.provisionTextField.stringValue;
}

	/// entitlement.plist文件路径
- (NSString *)entitlementPath
{
	return [self.entitlementsTextField.stringValue stringByDeletingLastPathComponent];
}
	/// entitlement.plist文件
- (NSString *)entitlementFile{
	return self.entitlementsTextField.stringValue;
}

	/// .app文件
- (NSString *)appFile{
	
	NSString *ipaPath = [self ipaPath];
	NSString *payload = [ipaPath stringByAppendingPathComponent:@"Payload"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
		//	NSError *error;
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:payload error:nil];
		//	NSLog(@"是否存在文件=%d",[fileManager fileExistsAtPath:[self ipaPath]]);
		//	NSLog(@"全部文件=%@",[fileManager contentsOfDirectoryAtPath:ipaPath error:&error]);
		//	NSLog(@"全部子文件=%@",[fileManager subpathsOfDirectoryAtPath:ipaPath error:nil]);
		//	NSLog(@"error = %@",error);
	for (NSString *path in contents) {
		if ([path hasSuffix:@".app"]) {
			return [payload stringByAppendingPathComponent:path];
		}
	}
	NSLog(@"未找到.app文件");
	return nil;
	
}


	/// ipa文件所在的文件夹
- (NSString *)ipaPath{
	return [self.ipaPathTextField.stringValue stringByDeletingLastPathComponent];
}

- (NSString *)ipaFile{
	return self.ipaPathTextField.stringValue;
}

- (void)processTask:(NSString *)launchPath arguments:(NSArray *)arguments currentDir:(NSString *)currentDir taskType:(NSString *)type {
	NSPipe *outputPipe = [NSPipe pipe];
	
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = launchPath;
	task.arguments = arguments;
	task.currentDirectoryPath = currentDir;
	task.standardOutput = outputPipe;
	
	task.standardError = outputPipe;
	
	NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
		// 使用runtime进行赋值
	objc_setAssociatedObject(outputHandle, typeKey, type, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(taskOutputNotification:)
												 name:NSFileHandleReadCompletionNotification
											   object:outputHandle];
	
	[task launch];
	[outputHandle readInBackgroundAndNotify];
}

- (void)taskOutputNotification:(NSNotification *)notification
{
	NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
	NSString *outputStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSFileHandle *fileHandle = notification.object;
	
	if (outputStr && outputStr.length > 0) {
		[self log:outputStr];
		printf("%s",[outputStr cStringUsingEncoding:NSUTF8StringEncoding]);
			//		NSFileHandle *fileHandle = notification.object;
		[fileHandle readInBackgroundAndNotify];
		
	} else {
		NSString *type = objc_getAssociatedObject(fileHandle, typeKey);
		[self log:[NSString stringWithFormat: @"%@  completed",type]];
		
		// 逐个签名插件
		if ([[type pathExtension] isEqualToString:@"appex"]) {
			if (self.pluginsArray.count > 0) {
				[self begincodesignPlugin];
			} else {
				[self codesignFrameworks];
			}
		}
		
			// 等上一个framework签名完成之后继续签名下一个文件
		if ([[type pathExtension] isEqualToString:@"framework"] || [[type pathExtension] isEqualToString:@"dylib"] ) {
			if (self.frameworksArray.count > 0) {
				[self begincodesignFramework];
			} else {
				[self codesignApp];
			}
		}
		
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSFileHandleReadCompletionNotification
													  object:notification.object];
	}
}



- (void)setRepresentedObject:(id)representedObject {
	[super setRepresentedObject:representedObject];
	
		// Update the view, if already loaded.
}

	// Show a critical alert
- (void)showAlertOfKind:(NSAlertStyle)style WithTitle:(NSString *)title AndMessage:(NSString *)message {
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:title];
	[alert setInformativeText:message];
	[alert setAlertStyle:style];
	[alert runModal];
}

@end

