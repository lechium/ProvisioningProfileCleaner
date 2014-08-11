//
//  KBProfileHelper.h
//  ProvisioningProfileCleaner
//
//  Created by Kevin Bradley on 8/7/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KBProfileHelper : NSObject
{
    NSArray *invalidProfiles;
    NSArray *expiredProfiles;
    NSArray *duplicateProfiles;
}
- (int)processProfiles;
- (int)processProfilesWithOpen:(BOOL)openBool;
+ (NSString *)mobileDeviceLog;
+ (NSMutableDictionary *)provisioningDictionaryFromFilePath:(NSString *)profilePath;
+ (NSArray *)devCertsFull;
+ (NSString *)provisioningProfilesPath;
+ (NSString *)pathFromUUID:(NSString *)uuid;
+ (NSString *)iphoneDeveloperString;
//- (NSDictionary *)validProfileForID:(NSString *)appID;
- (NSDictionary *)validProfileForID:(NSString *)appID withTarget:(NSString *)target;
- (NSArray *)validProfilesForID:(NSString *)appID;
@end
