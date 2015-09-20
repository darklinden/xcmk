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

NSString *_tagRegx = nil;
NSString* _tagName = nil;

NSString* _sigName = nil;
NSString* _prfPath = nil;

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
    [task waitUntilExit];
    
    NSFileHandle* read = [pout fileHandleForReading];
    NSData* dataRead = [read readDataToEndOfFile];
    return [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        if (argc < 2) {
            printf("");
        }
        
        NSFileManager* fmgr = [NSFileManager defaultManager];
        
        //get globa info
        NSString* infoPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xcmk.plist"];
        if ([fmgr fileExistsAtPath:infoPath]) {
            NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:infoPath];
            
            NSString *tagRegx = dict[@"tag"];
            if (tagRegx && tagRegx.length) {
                _tagRegx = tagRegx;
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
        
        NSString *tagRegx = [dict objectForKey:@"tag"];
        if (tagRegx && tagRegx.length) {
            _tagRegx = tagRegx;
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
        if (!(_tagRegx && _tagRegx.length)) {
            printf("*** error: Project Target is incorrect! [%s] ***\n", _tagRegx.UTF8String);
            return ErrorExit;
        }
        
        NSString* tagetResult = runCmd(@"/usr/bin/xcodebuild", @[@"-list"], _prjPath);
        
        NSArray* array = [tagetResult componentsSeparatedByString:@"\n"];
        BOOL isTag = false;
        for (int i = 0; i < array.count; i++) {
            NSString* str = array[i];
            NSString* single = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([single isEqualToString:@"Targets:"]) {
                isTag = true;
            }
            else if ([single isEqualToString:@"Build Configurations:"]) {
                isTag = false;
            }
            else if (isTag) {
                NSRegularExpression *regexv = [NSRegularExpression regularExpressionWithPattern:_tagRegx options:NSRegularExpressionCaseInsensitive error:nil];
                
                NSUInteger matchesCount = [regexv numberOfMatchesInString:single
                                                                  options:NSMatchingReportProgress
                                                                    range:NSMakeRange(0, single.length)];
                
                if (matchesCount) {
                    _tagName = single;
                    break;
                }
            }
        }
        
        if (!(_tagName && _tagName.length)) {
            printf("*** error: Get Project Target Failed! [%s] ***\n", _tagRegx.UTF8String);
            return ErrorExit;
        }
        else {
            printf("Select Target [%s]\n", _tagName.UTF8String);
        }
        
        //check sig
        if (!(_sigName && _sigName.length)) {
            printf("*** error: Get Project CodeSign Failed! [%s] ***\n", _sigName.UTF8String);
            return ErrorExit;
        }
        else {
            printf("CodeSign With [%s]\n", _sigName.UTF8String);
        }
        
        NSString* arguments = [NSString stringWithFormat:@"-target \"%@\" -configuration Release clean build \"CODE_SIGN_IDENTITY=%@\" DEPLOYMENT_POSTPROCESSING=YES", _tagName, _sigName];
        
        printf("building... \n");
        
        NSString* buildResult = runCmd(@"/usr/bin/xcodebuild", @[arguments], _prjPath);
        
        if ([buildResult rangeOfString:@"** BUILD SUCCEEDED **"].location == NSNotFound) {
            printf("build failed:\n %s\n", buildResult.UTF8String);
            return ErrorExit;
        }
        else {
            printf("build success, exporting ipa... \n");
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
        
        //export ipa
        NSString* app = [[[_prjPath stringByAppendingPathComponent:@"build/Release-iphoneos"] stringByAppendingPathComponent:_tagName]stringByAppendingPathExtension:@"app"];
        NSString* ipa = [[[_prjPath stringByAppendingPathComponent:@"build/Release-iphoneos"] stringByAppendingPathComponent:_tagName]stringByAppendingPathExtension:@"ipa"];
        NSMutableArray* arrayArguments = [NSMutableArray array];
        [arrayArguments addObject:@"-sdk"];
        [arrayArguments addObject:@"iphoneos"];
        [arrayArguments addObject:@"PackageApplication"];
//        [arrayArguments addObject:@"-v"];
        [arrayArguments addObject:[NSString stringWithFormat:@"%@", app]];
        [arrayArguments addObject:[NSString stringWithFormat:@"%@", ipa]];
        [arrayArguments addObject:@"--embed"];
        [arrayArguments addObject:[NSString stringWithFormat:@"%@", _prfPath]];
        [arrayArguments addObject:@"--sign"];
        [arrayArguments addObject:[NSString stringWithFormat:@"%@", _sigName]];
        
        NSString* exportResult = runCmd(@"/usr/bin/xcrun", arrayArguments, _prjPath);
        if ([exportResult rangeOfString:@"error"].location == NSNotFound) {
            printf("ipa May Exported At [%s]\n", ipa.UTF8String);
        }
        else {
            printf("Export Failed:\n%s\n", exportResult.UTF8String);
        }
    }
    return 0;
}
