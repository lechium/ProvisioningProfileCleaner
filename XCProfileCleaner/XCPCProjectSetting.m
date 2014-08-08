//
//  GMProjectSetting
//  XToDo
//
//  Created by shuice on 2014-03-08.
//  Copyright (c) 2014. All rights reserved.
//

#import "XCPCProjectSetting.h"
#import "XCPCModel.h"

@implementation XCPCProjectSetting

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.includeDirs ? self.includeDirs : @[]  forKey:@"includeDirs"];
    [aCoder encodeObject:self.excludeDirs ? self.excludeDirs : @[]  forKey:@"excludeDirs"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.includeDirs = [aDecoder decodeObjectForKey:@"includeDirs"];
        self.excludeDirs = [aDecoder decodeObjectForKey:@"excludeDirs"];
    }
    return self;
}

+ (XCPCProjectSetting *) defaultProjectSetting
{
    XCPCProjectSetting *projectSetting = [[XCPCProjectSetting alloc] init];
    projectSetting.includeDirs = @[[XCPCModel rootPathMacro]];
    projectSetting.excludeDirs = @[[XCPCModel addPathSlash:[[XCPCModel rootPathMacro] stringByAppendingPathComponent:@"Pods"]]];
    return projectSetting;
}

- (NSString *)firstIncludeDir
{
    NSString *firstDir = [self.includeDirs count] ? [self.includeDirs objectAtIndex:0] : @"";
    if ([firstDir length] == 0)
    {
        firstDir = [XCPCModel rootPathMacro];
    }
    return firstDir;
}

@end
