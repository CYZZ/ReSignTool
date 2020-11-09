//
//  Insert_dylib.m
//  insert_remove_dylib
//
//  Created by app2 on 2017/9/15.
//  Copyright © 2017年 app2. All rights reserved.
//

#import "Insert_dylib.h"
#import <mach-o/loader.h>
#import <mach-o/fat.h>

#import "DylibManager.h"


#define DYLIB_CURRENT_VER 0x10000
#define DYLIB_COMPATIBILITY_VERSION 0x10000

@implementation Insert_dylib

+(void)Insert_dylib:(NSString *)dylib_path targetFile:(NSString *)target_path{

    [Insert_dylib Insert_dylib:dylib_path targetFile:target_path insertStyle:LC_LOAD_DYLIB];
}

+(void)Insert_dylib:(NSString *)dylib_path targetFile:(NSString *)target_path insertStyle:(uint32_t)insertStyle{
    
    NSFileManager *file_manager = [NSFileManager defaultManager];
    if (![file_manager fileExistsAtPath:target_path isDirectory:NO]) {
//        fprintf(stderr, "error:target file not exist!!\n");
		[self startLog:@"\nerror:target file not exist!!"];
        //直接返回
        return;
    }
    
    if ([dylib_path hasPrefix:@"@executable_path/"] || [dylib_path hasPrefix:@"@rpath/"] || [dylib_path hasPrefix:@"@loader_path/"]) {
        
    }else{
        dylib_path = [NSString stringWithFormat:@"@executable_path/%@",dylib_path];
    }
    
    char target_binary[1024] = {0};
    char buffer[4096] = {0};
    
    strlcpy(target_binary, [target_path UTF8String], sizeof(target_binary));
    //读取target文件(r+:以读/写方式打开文件，该文件必须存在。)
    FILE *target_fp = fopen(target_binary, "r+");
    
    if (target_fp == NULL) {
//        fprintf(stderr, "open file error!!!");
		[self startLog:@"\nopen file error!!!f"];
        return;
    }
    fread(&buffer, sizeof(buffer), 1, target_fp);
    
    struct fat_header *fh = (struct fat_header *)buffer;
    
    switch (fh->magic) {
        case FAT_CIGAM:
        case FAT_MAGIC:
        {
            struct fat_arch* arch = (struct fat_arch*)&fh[1];
            int i;
            for (i=0; i<CFSwapInt32(fh->nfat_arch); i++) {
                fprintf(stderr, "Injecting to arch %i\n",CFSwapInt32(arch->cpusubtype));
				[self startLog:[NSString stringWithFormat:@"Injecting to arch %i\n",CFSwapInt32(arch->cpusubtype)]];
                if (CFSwapInt32(arch->cputype) == CPU_TYPE_ARM64) {
                    [self inject_64:target_fp startAddress:CFSwapInt32(arch->offset) injectPath:dylib_path insertStyle:insertStyle];
                }else{
                    [self inject_32:target_fp startAddress:CFSwapInt32(arch->offset) injectPath:dylib_path insertStyle:insertStyle];
                }
                arch++;
            }
        }
            break;
        case MH_CIGAM_64:
        case MH_MAGIC_64: {
            fprintf(stderr, "Thin 64bit binary!\n");
			[self startLog:@"\nInjecting to Thin 64bit binary!"];
            [self inject_64:target_fp startAddress:0 injectPath:dylib_path insertStyle:insertStyle];
        }
            break;
        case MH_CIGAM:
        case MH_MAGIC: {
            fprintf(stderr, "Thin 32bit binary!\n");
			[self startLog:@"\nInjecting to Thin 32bit binary!"];
            [self inject_32:target_fp startAddress:0 injectPath:dylib_path insertStyle:insertStyle];
        }
            break;
        default:
            break;
    }
    fclose(target_fp);
}

/***************************************************/



/***************************************************/

+(void)inject_64:(FILE *)fp startAddress:(unsigned int)top injectPath:(NSString *)dylib_path insertStyle:(uint32_t) insertStyle{
    //将指针指向64架构的开始位置
    fseek(fp, top, SEEK_SET);
    
    struct mach_header_64 mach;
    
    fread(&mach, sizeof(struct mach_header_64), 1, fp);
    struct load_command exist_cmd;
    struct dylib_command orig_dyld;
    
    char orig_dyld_name[1024];
    //遍历所有的load command 段，查看是否已经注入相同的动态库，如果已经注入相同的库，就不注入了
    for (int i=0; i<mach.ncmds; i++) {
        
        fread(&exist_cmd, sizeof(struct load_command), 1, fp);
        
        if (exist_cmd.cmd == insertStyle) {
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
			if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//				fprintf(stderr, "64bit：You have injected \"%s\"\n\n",orig_dyld_name);
				[self startLog:[NSString stringWithFormat: @"\n64bit：You have injected \"%s\"",orig_dyld_name]];
				return;
			}
//            将文件指针移到下一个load command
            fseek(fp,-1024, SEEK_CUR);
            fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
            continue;
        }
        fseek(fp, exist_cmd.cmdsize-sizeof(struct load_command), SEEK_CUR);
    }
	
    //将所有的段都读完了，没有发现重复的，将指针指向load command 开始的地方
    fseek(fp, -(unsigned long)mach.sizeofcmds, SEEK_CUR);
    
    NSData *data = [dylib_path dataUsingEncoding:NSUTF8StringEncoding];
    
    //计算注入的load command 段的大小(cmd大小是 long 对齐的)
    unsigned long new_cmd_size = sizeof(struct dylib_command) + [data length];
    new_cmd_size = new_cmd_size + (sizeof(long)-new_cmd_size%sizeof(long));
    
    
    mach.ncmds = mach.ncmds + 0x1;
    
    uint32_t sizeofcmds = mach.sizeofcmds;
    
    mach.sizeofcmds += new_cmd_size;
    
    fseek(fp, -sizeof(struct mach_header_64), SEEK_CUR);
    
    fwrite(&mach, sizeof(struct mach_header_64), 1, fp);
    
    fseek(fp, sizeofcmds, SEEK_CUR);
    
    //给新的cmd初始化（置'\0'）
    unsigned char *_tc = malloc(new_cmd_size);
    memset(_tc, 0, new_cmd_size);
    fwrite(_tc, new_cmd_size, 1, fp);
    fseek(fp, -((long)new_cmd_size), SEEK_CUR);
    
    
    
    struct dylib_command dyld;
    
    fread(&dyld, sizeof(struct dylib_command), 1, fp);
    
    //给新的cmd赋值
    dyld.cmd = insertStyle;
    dyld.cmdsize = (uint32_t)new_cmd_size;
    dyld.dylib.compatibility_version = DYLIB_COMPATIBILITY_VERSION;
    dyld.dylib.current_version = DYLIB_CURRENT_VER;
    dyld.dylib.timestamp = 2;
    dyld.dylib.name.offset = sizeof(struct dylib_command);
    
    fseek(fp, -sizeof(struct dylib_command), SEEK_CUR);
    
    fwrite(&dyld, sizeof(struct dylib_command), 1, fp);
    
    fwrite([data bytes], [data length], 1, fp);
	[self startLog:@"inject 64CPU Sucess"];
}

/***************************************************/



/***************************************************/
+(void)inject_32:(FILE *)fp startAddress:(unsigned int)top injectPath:(NSString *)dylib_path insertStyle:(uint32_t) insertStyle{
    fseek(fp, top, SEEK_SET);
    struct mach_header mach;
    fread(&mach, sizeof(struct mach_header), 1, fp);
    
    struct load_command exist_cmd;
    struct dylib_command orig_dyld;
    
    char orig_dyld_name[1024];
    //遍历所有的load command 段，查看是否已经注入相同的动态库，如果已经注入相同的库，就不注入了
    for (int i=0; i<mach.ncmds; i++) {
        
        fread(&exist_cmd, sizeof(struct load_command), 1, fp);        
        if (exist_cmd.cmd == insertStyle) {
            fseek(fp, -sizeof(struct load_command), SEEK_CUR);
            fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
            fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
            fread(orig_dyld_name, 1024, 1, fp);
            if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//                fprintf(stderr, "32bit：You have injected \"%s\"\n\n",orig_dyld_name);
				[self startLog:[NSString stringWithFormat:@"\n32bit：You have injected \"%s\"",orig_dyld_name]];
                return;
            }
            //将文件指针移到下一个load command
            fseek(fp,-1024, SEEK_CUR);
            fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
            continue;
        }
        fseek(fp, exist_cmd.cmdsize-sizeof(struct load_command), SEEK_CUR);
    }
    //将所有的段都读完了，没有发现重复的，将指针指向load command 开始的地方
    fseek(fp, -(unsigned long)mach.sizeofcmds, SEEK_CUR);
    
    NSData *data = [dylib_path dataUsingEncoding:NSUTF8StringEncoding];

    uint32_t dylib_size = (uint32_t)[data length] + sizeof(struct dylib_command);
    dylib_size = dylib_size + (sizeof(long) - (dylib_size%sizeof(long)));
    mach.ncmds += 0x1;
    uint32_t sizeofcmds = mach.sizeofcmds;
    mach.sizeofcmds += dylib_size;
    
    fseek(fp, -sizeof(struct mach_header), SEEK_CUR);
    
    fwrite(&mach, sizeof(struct mach_header), 1, fp);
    
    fseek(fp, sizeofcmds, SEEK_CUR);
    
    //给新的cmd初始化（置'\0'）
    unsigned char *_tc = malloc(dylib_size);
    memset(_tc, 0, dylib_size);
    fwrite(_tc, dylib_size, 1, fp);
    fseek(fp, -((long)dylib_size), SEEK_CUR);
    
    struct dylib_command dyld;
    
    fread(&dyld, sizeof(struct dylib_command), 1, fp);
    
    //给新的cmd赋值
    dyld.cmd = insertStyle;
    dyld.cmdsize = (uint32_t)dylib_size;
    dyld.dylib.compatibility_version = DYLIB_COMPATIBILITY_VERSION;
    dyld.dylib.current_version = DYLIB_CURRENT_VER;
    dyld.dylib.timestamp = 2;
    dyld.dylib.name.offset = sizeof(struct dylib_command);
    
    fseek(fp, -sizeof(struct dylib_command), SEEK_CUR);
    
    fwrite(&dyld, sizeof(struct dylib_command), 1, fp);
    
    fwrite([data bytes], [data length], 1, fp);
	[self startLog:@"injuect 32CPU Success"];
}


+ (void)checkAllDylibAt:(NSString *)target_path {
	
	NSFileManager *file_manager = [NSFileManager defaultManager];
	if (![file_manager fileExistsAtPath:target_path]) {
//		fprintf(stderr, "error:target file not exist!!\n");
		[self startLog:@"\nerror:target file not exist!!"];
		//直接返回
		return;
	}

	
	char target_binary[1024] = {0};
	char buffer[4096] = {0};
	
	strlcpy(target_binary, [target_path UTF8String], sizeof(target_binary));
	//读取target文件(r+:以读/写方式打开文件，该文件必须存在。)
	FILE *target_fp = fopen(target_binary, "r+");
	
	if (target_fp == NULL) {
//		fprintf(stderr, "open file error!!!");
		[self startLog:@"\nopen file error!!!"];
		return;
	}
	fread(&buffer, sizeof(buffer), 1, target_fp);
	
	struct fat_header *fh = (struct fat_header *)buffer;
	
	switch (fh->magic) {
		case FAT_CIGAM:
		case FAT_MAGIC:
		{
			struct fat_arch* arch = (struct fat_arch*)&fh[1];
			int i;
			for (i=0; i<CFSwapInt32(fh->nfat_arch); i++) {
//				fprintf(stderr, "Injecting to arch %i\n",CFSwapInt32(arch->cpusubtype));
				if (CFSwapInt32(arch->cputype) == CPU_TYPE_ARM64) {
//					[self inject_64:target_fp startAddress:CFSwapInt32(arch->offset) injectPath:dylib_path insertStyle:insertStyle];
					[self startLog:@"\nThin 64bit FAT_binary!"];
					[self check_64:target_fp startAddress:CFSwapInt32(arch->offset)];
				}else{
//					[self inject_32:target_fp startAddress:CFSwapInt32(arch->offset) injectPath:dylib_path insertStyle:insertStyle];
					[self startLog:@"\nThin 32bit FAT_binary!"];
					[self check_32:target_fp startAddress:CFSwapInt32(arch->offset)];
				}
				arch++;
			}
		}
			break;
		case MH_CIGAM_64:
		case MH_MAGIC_64:
		{
//			fprintf(stderr, "Thin 64bit binary!\n");
		[self startLog:@"\nThin 64bit binary!"];
//			[self inject_64:target_fp startAddress:0 injectPath:dylib_path insertStyle:insertStyle];
		[self check_64:target_fp startAddress:0];
		}
			break;
		case MH_CIGAM:
		case MH_MAGIC:
		{
//			fprintf(stderr, "Thin 32bit binary!\n");
		[self startLog:@"\nThin 32bit binary!"];
//			[self inject_32:target_fp startAddress:0 injectPath:dylib_path insertStyle:insertStyle];
		[self check_32:target_fp startAddress:0];
		}
			break;
		default:
			break;
	}
	fclose(target_fp);
	
}

+ (void)check_64:(FILE *)fp startAddress:(unsigned int)top {

	//将指针指向64架构的开始位置
	fseek(fp, top, SEEK_SET);
	
	struct mach_header_64 mach;
	
	fread(&mach, sizeof(struct mach_header_64), 1, fp);
	struct load_command exist_cmd;
	struct dylib_command orig_dyld;
	
	char orig_dyld_name[1024];
	//遍历所有的load command 段，查看所有动态库
	for (int i=0; i<mach.ncmds; i++) {
		
		fread(&exist_cmd, sizeof(struct load_command), 1, fp);
		
		if (exist_cmd.cmd == LC_LOAD_DYLIB) { // 默认的引用方式
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
//			if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//				fprintf(stderr, "jhhhh 64bit：You have injected \"%s\"\n\n",orig_dyld_name);
//				return;
//			}
			[self startLog:[NSString stringWithFormat:@"CPU_TYPE_ARM64-libName=%s---LC_LOAD_DYLIB",orig_dyld_name]];
			
//            将文件指针移到下一个load command
			fseek(fp,-1024, SEEK_CUR);
			fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
			continue;
		}
		if (exist_cmd.cmd == LC_LOAD_WEAK_DYLIB) { // weak的引用方式
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
//			if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//				fprintf(stderr, "weak 64bit：You have injected \"%s\"\n\n",orig_dyld_name);
//				return;
//			}
			[self startLog:[NSString stringWithFormat:@"CPU_TYPE_ARM64-libName=%s---LC_LOAD_WEAK_DYLIB",orig_dyld_name]];
//            将文件指针移到下一个load command
			fseek(fp,-1024, SEEK_CUR);
			fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
			continue;
		}
		
		if (exist_cmd.cmd == LC_RPATH) { // weak的引用方式
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
//			if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//				fprintf(stderr, "weak 64bit：You have injected \"%s\"\n\n",orig_dyld_name);
//				return;
//			}
			[self startLog:[NSString stringWithFormat:@"CPU_TYPE_ARM64-libName=%s---LC_RPATH",orig_dyld_name]];
//            将文件指针移到下一个load command
			fseek(fp,-1024, SEEK_CUR);
			fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
			continue;
		}
		fseek(fp, exist_cmd.cmdsize-sizeof(struct load_command), SEEK_CUR);
	}
	//将所有的段都读完了，没有发现重复的，将指针指向load command 开始的地方
	fseek(fp, -(unsigned long)mach.sizeofcmds, SEEK_CUR);
	
}

+ (void)check_32:(FILE *)fp startAddress:(unsigned int)top {
	
	fseek(fp, top, SEEK_SET);
	struct mach_header mach;
	fread(&mach, sizeof(struct mach_header), 1, fp);
	
	struct load_command exist_cmd;
	struct dylib_command orig_dyld;
	
	char orig_dyld_name[1024];
	//遍历所有的load command 段，查看是否已经注入相同的动态库，如果已经注入相同的库，就不注入了
	for (int i=0; i<mach.ncmds; i++) {
		
		fread(&exist_cmd, sizeof(struct load_command), 1, fp);
		if (exist_cmd.cmd == LC_LOAD_WEAK_DYLIB) {
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
//            if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//                fprintf(stderr, "32bit：You have injected \"%s\"\n\n",orig_dyld_name);
//                return;
//            }
			[self startLog:[NSString stringWithFormat:@"CPU_TYPE_ARM32-libName=%s---LC_LOAD_WEAK_DYLIB",orig_dyld_name]];
			//将文件指针移到下一个load command
			fseek(fp,-1024, SEEK_CUR);
			fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
			continue;
		}
		if (exist_cmd.cmd == LC_LOAD_DYLIB) {
			fseek(fp, -sizeof(struct load_command), SEEK_CUR);
			fread(&orig_dyld, sizeof(struct dylib_command), 1, fp);
			fseek(fp, orig_dyld.dylib.name.offset - sizeof(struct dylib_command), SEEK_CUR);
			fread(orig_dyld_name, 1024, 1, fp);
//            if (!strcmp(orig_dyld_name, [dylib_path UTF8String])) {
//                fprintf(stderr, "32bit：You have injected \"%s\"\n\n",orig_dyld_name);
//                return;
//            }
			[self startLog:[NSString stringWithFormat:@"CPU_TYPE_ARM32-libName=%s---LC_LOAD_DYLIB",orig_dyld_name]];
			//将文件指针移到下一个load command
			fseek(fp,-1024, SEEK_CUR);
			fseek(fp, orig_dyld.cmdsize-sizeof(struct dylib_command), SEEK_CUR);
			continue;
		}
		fseek(fp, exist_cmd.cmdsize-sizeof(struct load_command), SEEK_CUR);
	}
	//将所有的段都读完了，将指针指向load command 开始的地方
	fseek(fp, -(unsigned long)mach.sizeofcmds, SEEK_CUR);
}


+ (void)startLog:(NSString *)logStr {
	if ([DylibManager manager].delegate && [[DylibManager manager].delegate respondsToSelector:@selector(starLogWith:)]) {
		
		[[DylibManager manager].delegate starLogWith:logStr];
		
	}
}




@end
