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
@end
