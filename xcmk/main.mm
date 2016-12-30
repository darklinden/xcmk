//
//  main.m
//  xcmk
//
//  Created by HanShaokun on 19/9/15.
//  Copyright © 2015 darklinden. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ErrorSuccess    0
#define ErrorExit       -1

NSString *_prjPath = nil;

NSString *_schRegx = nil;
NSString* _schName = nil;

NSString* _sigName = nil;
NSString* _prfPath = nil;
NSString *_prfName = nil;

NSString* runCmd(NSString* cmd, NSArray* arguments, NSString* path = nil) {
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:cmd];
    [task setArguments:arguments];
    if (path && path.length) {
        [task setCurrentDirectoryPath:path];
    }
    
    NSPipe* pout = [NSPipe pipe];
    [task setStandardOutput:pout];
    
    [task launch];

    NSMutableString* result = [NSMutableString string];

    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
        NSData *data = [file availableData]; // this will read to EOF, so call only once
        NSString *tmp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        printf("%s\n", tmp.UTF8String);

        [result appendString:tmp];
    }];

    [task waitUntilExit];

    return result;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        if (argc < 2) {
            printf("\nxcmk\n -prj project path\n -sch scheme regex\n -sig CodeSign name\n -prf Provision Profile path\n\n");
            return ErrorExit;
        }
        
        NSFileManager* fmgr = [NSFileManager defaultManager];
        
        //get globa info
        NSString* infoPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xcmk.plist"];
        if ([fmgr fileExistsAtPath:infoPath]) {
            NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:infoPath];
            
            NSString *tagRegx = dict[@"sch"];
            if (tagRegx && tagRegx.length) {
                _schRegx = tagRegx;
            }
            
            NSString *sigName = dict[@"sig"];
            if (sigName && sigName.length) {
                _sigName = sigName;
            }
            
            NSString *prfPath = dict[@"prf"];
            if (prfPath && prfPath.length) {
                _prfPath = prfPath;
            }
        }
        
        //get params
        NSMutableArray *keys = [NSMutableArray array];
        NSMutableArray *values = [NSMutableArray array];
        bool start = false;
        
        for (int i = 0; i < argc; i++) {
            NSString* tmp = [NSString stringWithFormat:@"%s", argv[i]];
            
            if ([tmp hasPrefix:@"-"]) {
                [keys addObject:[tmp substringFromIndex:1]];
                start = true;
            }
            else {
                if (start) {
                    [values addObject:tmp];
                }
            }
        }
        
        if (keys.count != values.count) {
            printf("xcmk \n");
            
            return ErrorExit;
        }
        
        NSDictionary *dict = [NSDictionary dictionaryWithObjects:values forKeys:keys];
        
        NSString *projPath = [dict objectForKey:@"prj"];
        if (projPath && projPath.length) {
            if ([projPath.pathExtension.lowercaseString isEqualToString:@"xcodeproj"]) {
                projPath = [projPath stringByDeletingLastPathComponent];
            }
            _prjPath = projPath;
        }
        
        NSString *schRegx = [dict objectForKey:@"sch"];
        if (schRegx && schRegx.length) {
            _schRegx = schRegx;
        }
        
        NSString *sigName = dict[@"sig"];
        if (sigName && sigName.length) {
            _sigName = sigName;
        }
        
        NSString *prfPath = dict[@"prf"];
        if (prfPath && prfPath.length) {
            _prfPath = prfPath;
        }
        
        //check proj path
        BOOL pathExist = false;
        if (_prjPath && _prjPath.length) {
            BOOL isDirectory = false;
            if ([fmgr fileExistsAtPath:_prjPath isDirectory:&isDirectory]) {
                if (isDirectory) {
                    pathExist = true;
                }
            }
        }
        
        if (!pathExist) {
            printf("*** error: Project Path is incorrect! [%s] ***\n", _prjPath.UTF8String);
            return ErrorExit;
        }
        
        //check tag
        if (!(_schRegx && _schRegx.length)) {
            printf("*** error: Project Target is incorrect! [%s] ***\n", _schRegx.UTF8String);
            return ErrorExit;
        }
        
        NSString* tagetResult = runCmd(@"/usr/bin/xcodebuild", @[@"-list"], _prjPath);
        
        NSArray* array = [tagetResult componentsSeparatedByString:@"\n"];
        BOOL isTag = false;
        for (int i = 0; i < array.count; i++) {
            NSString* str = array[i];
            NSString* single = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([single isEqualToString:@"Schemes:"]) {
                isTag = true;
            }
            else if (isTag) {
                NSRegularExpression *regexv = [NSRegularExpression regularExpressionWithPattern:_schRegx options:NSRegularExpressionCaseInsensitive error:nil];
                
                NSUInteger matchesCount = [regexv numberOfMatchesInString:single
                                                                  options:NSMatchingReportProgress
                                                                    range:NSMakeRange(0, single.length)];
                
                if (matchesCount) {
                    _schName = single;
                    break;
                }
            }
        }
        
        if (!(_schName && _schName.length)) {
            printf("*** error: Get Project Scheme Failed! [%s] ***\n", _schRegx.UTF8String);
            return ErrorExit;
        }
        else {
            printf("Select Scheme [%s]\n", _schName.UTF8String);
        }
        
        //check sig
        if (!(_sigName && _sigName.length)) {
            printf("*** error: Get Project CodeSign Failed! [%s] ***\n", _sigName.UTF8String);
            return ErrorExit;
        }
        else {
            printf("CodeSign With [%s]\n", _sigName.UTF8String);
        }

        //check profile path
        pathExist = false;
        if (_prfPath && _prfPath.length) {
            BOOL isDirectory = false;
            if ([fmgr fileExistsAtPath:_prfPath isDirectory:&isDirectory]) {
                if (!isDirectory) {
                    pathExist = true;
                }
            }
        }

        if (!pathExist) {
            printf("*** error: Provision Profile Path is incorrect! [%s] ***\n", _prfPath.UTF8String);
            return ErrorExit;
        }

        // get prf name
        NSString *prfPlist = runCmd(@"/usr/bin/security", @[@"cms", @"-D", @"-i", _prfPath], _prjPath);
        NSData *plistData = [prfPlist dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        NSPropertyListFormat format;
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:plistData
                                                                        options:NSPropertyListImmutable
                                                                         format:&format
                                                                          error:&error];
        if (!plist) {
            NSLog(@"Error: %@", error);
        }
        else {
//            printf("%s", plist.description.UTF8String);
            _prfName = plist[@"Name"];
            if (!_prfName) {
                printf("*** error: Provision Profile Name is incorrect! [%s] ***\n", _prfPath.UTF8String);
                return ErrorExit;
            }
        }


        NSString *arcPath = [[_prjPath stringByAppendingPathComponent:@"build"] stringByAppendingPathComponent:@"arch.xcarchive"];

#if 0
        // arvhice
        [fmgr createDirectoryAtPath:[_prjPath stringByAppendingPathComponent:@"build"] withIntermediateDirectories:YES attributes:nil error:nil];
        [fmgr removeItemAtPath:arcPath error:nil];
        
//        NSString* arguments = [NSString stringWithFormat:@"-target \"%@\" -configuration Release clean build \"CODE_SIGN_IDENTITY=%@\" DEPLOYMENT_POSTPROCESSING=YES", _schName, _sigName];

        printf("building... \n");
        
        NSString* buildResult = runCmd(@"/usr/bin/xcodebuild", @[@"-scheme", _schName, @"clean", @"archive", @"-archivePath", arcPath], _prjPath);
        
        if ([buildResult rangeOfString:@"** ARCHIVE SUCCEEDED **"].location == NSNotFound) {
            printf("build failed:\n %s\n", buildResult.UTF8String);
            return ErrorExit;
        }
        else {
            printf("build success, exporting ipa... \n");
        }

#endif

        //export ipa
        NSString *ipaPath = [[_prjPath stringByAppendingPathComponent:@"build"] stringByAppendingPathComponent:@"build.ipa"];
        [fmgr removeItemAtPath:ipaPath error:nil];

        NSMutableArray* arrayArguments = [NSMutableArray array];
        [arrayArguments addObject:@"-exportArchive"];
        [arrayArguments addObject:@"-exportFormat"];
        [arrayArguments addObject:@"ipa"];

        [arrayArguments addObject:@"-archivePath"];
        [arrayArguments addObject:arcPath];

        [arrayArguments addObject:@"-exportPath"];
        [arrayArguments addObject:ipaPath];

        [arrayArguments addObject:@"-exportProvisioningProfile"];
        [arrayArguments addObject:_prfName];
        
        NSString* exportResult = runCmd(@"/usr/bin/xcodebuild", arrayArguments, _prjPath);
        if ([exportResult rangeOfString:@"** EXPORT FAILED **"].location == NSNotFound) {
            printf("ipa May Exported At [%s]\n", ipaPath.UTF8String);
        }
        else {
            printf("Export Failed:\n%s\n", exportResult.UTF8String);
        }
    }
    return 0;
}
