//
//  main.m
//  ProvisioningProfileCleaner
//
//  Created by Kevin Bradley on 8/7/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KBProfileHelper.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // insert code here...
       // NSLog(@"Hello, World!");
        KBProfileHelper *helper = [[KBProfileHelper alloc] init];
        return [helper processProfiles];
    }
    return 0;
}

