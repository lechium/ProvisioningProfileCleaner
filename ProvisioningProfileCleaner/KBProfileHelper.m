//
//  KBProfileHelper.m
//  ProvisioningProfileCleaner
//
//  Created by Kevin Bradley on 8/7/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "KBProfileHelper.h"

#define MAN [NSFileManager defaultManager]

#define DLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);

@interface NSMutableString (profileHelper)

- (void)clearString;

@end

@implementation NSMutableString (profileHelper)

- (void)clearString
{
    [self deleteCharactersInRange:NSMakeRange(0, self.length)];
}

@end
@interface NSString (profileHelper)
- (id)dictionaryFromString;
@end

@implementation NSString (profileHelper)

- (id)dictionaryFromString
{
	NSString *error = nil;
	NSPropertyListFormat format;
	NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	id theDict = [NSPropertyListSerialization propertyListFromData:theData
												  mutabilityOption:NSPropertyListMutableContainersAndLeaves
															format:&format
												  errorDescription:&error];
	return theDict;
}

@end

@interface NSArray (profileHelper)

- (NSArray *)subarrayWithName:(NSString *)theName;

@end

@implementation NSArray (profileHelper)

- (NSArray *)subarrayWithName:(NSString *)theName
{
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(Name == %@)", theName];
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"CreationDate" ascending:TRUE];
    NSArray *filteredArray = [self filteredArrayUsingPredicate:filterPredicate];
    return [filteredArray sortedArrayUsingDescriptors:@[sortDesc]];
}

@end


@implementation KBProfileHelper

+ (NSArray *)returnForProcess:(NSString *)call
{
    if (call==nil)
        return 0;
    char line[200];
    
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp)
    {
        while (fgets(line, sizeof line, fp))
        {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    pclose(fp);
    return lines;
}

/*
 
 TeamName,
 ExpirationDate,
 TimeToLive,
 AppIDName,
 CreationDate,
 DeveloperCertificates,
 ProvisionedDevices,
 Name,
 ApplicationIdentifierPrefix,
 Version,
 UUID,
 TeamIdentifier,
 Entitlements {
    application-identifier,
    get-task-allow,
 }
 
 
 */


- (int)processProfiles
{
    NSArray *validProfiles = [self validProfilePaths];
    DLog(@"Valid Profiles: %@", validProfiles);
    NSMutableString *logString = [NSMutableString new];
    if (expiredProfiles.count > 0)
    {
        NSString *expiredLog = [[self expiredProvisioningProfiles] stringByAppendingPathComponent:@"Expired.log"];
        [logString appendString:@"The following provisioning profiles have expired:\n---------------------------------------------------\n\n"];
        for (NSDictionary *expiredDict in expiredProfiles)
        {
            NSString *fullpath = expiredDict[@"Path"];
            NSString *baseName = [fullpath lastPathComponent];
            NSString *newPath = [[self expiredProvisioningProfiles] stringByAppendingPathComponent:baseName];
            [MAN moveItemAtPath:fullpath toPath:newPath error:nil];
            NSString *teamName = expiredDict[@"TeamName"];
            NSString *teamId = [expiredDict[@"TeamIdentifier"] lastObject];
            NSDate *expireDate = expiredDict[@"ExpirationDate"];
            NSString *name = expiredDict[@"Name"];
            NSString *appIDName = expiredDict[@"AppIDName"];
            NSString *appID = [expiredDict[@"Entitlements"] objectForKey:@"application-identifier"];
            NSString *fileName = [expiredDict[@"Path"] lastPathComponent];
            NSString *profileInfo = [NSString stringWithFormat:@"Profile %@ expired on %@\nwith team: %@ (%@) profile name: %@\nappID: %@ appIDName: %@\n\n", fileName, expireDate,teamName,teamId, name, appID, appIDName];
            [logString appendString:profileInfo];
            
        }
        [logString writeToFile:expiredLog atomically:true encoding:NSUTF8StringEncoding error:nil];
        [logString clearString];
    }
    
    if (duplicateProfiles.count > 0)
    {
        NSString *duplicateLog = [[self duplicateProvisioningProfiles] stringByAppendingPathComponent:@"Duplicates.log"];
        [logString appendString:@"The following provisioning profiles have newer duplicates:\n---------------------------------------------------\n\n"];
        for (NSDictionary *duplicateDict in duplicateProfiles)
        {
            NSString *fullpath = duplicateDict[@"Path"];
            NSString *baseName = [fullpath lastPathComponent];
            NSString *newPath = [[self duplicateProvisioningProfiles] stringByAppendingPathComponent:baseName];
            [MAN moveItemAtPath:fullpath toPath:newPath error:nil];
            NSString *teamName = duplicateDict[@"TeamName"];
            NSString *teamId = [duplicateDict[@"TeamIdentifier"] lastObject];
            NSDate *expireDate = duplicateDict[@"ExpirationDate"];
            NSString *name = duplicateDict[@"Name"];
            NSString *appIDName = duplicateDict[@"AppIDName"];
            NSString *appID = [duplicateDict[@"Entitlements"] objectForKey:@"application-identifier"];
            NSString *fileName = [duplicateDict[@"Path"] lastPathComponent];
            NSString *profileInfo = [NSString stringWithFormat:@"Profile %@ has duplicates!\nit expires on %@ with team: %@ (%@)\nprofile name: %@ \nappID: %@ appIDName: %@\n\n", fileName, expireDate,teamName,teamId, name, appID, appIDName];
            [logString appendString:profileInfo];
            
        }
        [logString writeToFile:duplicateLog atomically:true encoding:NSUTF8StringEncoding error:nil];
        [logString clearString];
    }
    
    if (invalidProfiles.count > 0)
    {
        NSString *invalidLog = [[self invalidProvisioningProfiles] stringByAppendingPathComponent:@"Invalid.log"];
        [logString appendString:@"The following provisioning profiles are invalid:\n---------------------------------------------------\n\n"];
        for (NSDictionary *invalidDict in invalidProfiles)
        {
            NSString *fullpath = invalidDict[@"Path"];
            NSString *baseName = [fullpath lastPathComponent];
            NSString *newPath = [[self invalidProvisioningProfiles] stringByAppendingPathComponent:baseName];
            [MAN moveItemAtPath:fullpath toPath:newPath error:nil];
            NSString *teamName = invalidDict[@"TeamName"];
            NSString *teamId = [invalidDict[@"TeamIdentifier"] lastObject];
            NSDate *expireDate = invalidDict[@"ExpirationDate"];
            NSString *name = invalidDict[@"Name"];
            NSString *appIDName = invalidDict[@"AppIDName"];
            NSString *appID = [invalidDict[@"Entitlements"] objectForKey:@"application-identifier"];
            NSString *fileName = [invalidDict[@"Path"] lastPathComponent];
            NSString *profileInfo = [NSString stringWithFormat:@"Profile %@ is invalid (there is no matching valid certificate!)\nit expires on %@ with team: %@ (%@) profile name: %@ \nappID: %@ appIDName: %@\n\n", fileName, expireDate,teamName,teamId, name, appID, appIDName];
            [logString appendString:profileInfo];
            
        }
        [logString writeToFile:invalidLog atomically:true encoding:NSUTF8StringEncoding error:nil];
        
    }
    
    NSString *openPath = [NSString stringWithFormat:@"/usr/bin/open '%@'", [self provisioningProfilesPath]];
    system([openPath UTF8String]);
    return 0;
}

- (NSArray *)devCerts
{
    NSMutableArray *outputArray = [[NSMutableArray alloc ]init];
    NSArray *securityReturn = [KBProfileHelper returnForProcess:@"security find-identity -p codesigning -v"];
    for (NSString *profileLine in securityReturn)
    {
        if (profileLine.length > 0)
        {
            NSArray *clips = [profileLine componentsSeparatedByString:@"\""];
            if ([clips count] > 1)
            {
                NSString *clipIt = [[profileLine componentsSeparatedByString:@"\""] objectAtIndex:1];
                NSArray *certArray = [clipIt componentsSeparatedByString:@"("];
                NSString *certID = [[certArray lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@") "]];
                //  DLog(@"certId: -%@-", certID);
                NSString *devName = [[certArray objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (certID != nil && devName != nil);
               // NSDictionary *certDict = @{@"certID": certID, @"devName": devName};
                [outputArray addObject:certID];
                //  DLog(@"%@", clipIt);
                
            }
        }
        
    }
    return outputArray;
}

- (NSString *)duplicateProvisioningProfiles
{
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Duplicate Profiles"];
    if (![MAN fileExistsAtPath:theDir])
    {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)expiredProvisioningProfiles
{
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Expired Profiles"];
    if (![MAN fileExistsAtPath:theDir])
    {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)invalidProvisioningProfiles
{
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Invalid Profiles"];
    if (![MAN fileExistsAtPath:theDir])
    {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)validProfilePath
{
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/ValidProvProfiles"];
    if (![MAN fileExistsAtPath:theDir])
    {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)pwd
{
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/ProvisioningProfileDicts"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:theDir])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}


- (NSString *)provisioningProfilesPath
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Provisioning Profiles"];
}

- (NSArray *)validProfiles
{
    NSMutableArray *profileArray = [NSMutableArray new];
    NSMutableArray *profileNames = [NSMutableArray new];
    NSMutableArray *_invalids = [NSMutableArray new];
    NSMutableArray *_expired = [NSMutableArray new];
    NSMutableArray *_duplicates = [NSMutableArray new];
    NSArray *devCert = [self devCerts];
    NSString *profileDir = [self provisioningProfilesPath];
    NSArray *fileArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:profileDir error:nil];
    for (NSString *theObject in fileArray)
    {
        if ([[[theObject pathExtension] lowercaseString] isEqualToString:@"mobileprovision"])
        {
            NSString *fullPath = [profileDir stringByAppendingPathComponent:theObject];
            NSMutableDictionary *provisionDict = [self provisioningDictionaryFromFilePath:
                                           [profileDir stringByAppendingPathComponent:theObject]];
            [provisionDict removeObjectForKey:@"DeveloperCertificates"];
            NSString *teamId = [provisionDict[@"TeamIdentifier"] lastObject];
            NSDate *expireDate = provisionDict[@"ExpirationDate"];
            NSDate *createdDate = provisionDict[@"CreationDate"];
            NSString *name = provisionDict[@"Name"];
            [provisionDict setObject:fullPath forKey:@"Path"];
            BOOL expired = FALSE;
            
            if ([expireDate isGreaterThan:[NSDate date]])
            {
           //     DLog(@"not expired: %@", expireDate);
                
            } else {
                
                DLog(@"expired: %@\n", expireDate);
                [_expired addObject:provisionDict];
                expired = TRUE;
            }
            
            
            if (![devCert containsObject:teamId] || expired == TRUE)
            {
                if (![_expired containsObject:provisionDict])
                {
                    [_invalids addObject:provisionDict];
                }
                DLog(@"invalid or expired cert: %@\n", theObject );
                
            } else {
                
                if ([profileNames containsObject:name])
                {
                    NSDictionary *otherDict = [[profileArray subarrayWithName:name] objectAtIndex:0];
                    NSDate *previousCreationDate = otherDict[@"CreationDate"];
                    if ([previousCreationDate isGreaterThan:createdDate])
                    {
                        DLog(@"found repeat name, but we're older: %@ vs: %@\n", createdDate, previousCreationDate);
                        [_duplicates addObject:provisionDict];
                        
                    } else {
                        
                        DLog(@"found a newer profile: %@ replace the old one: %@\n", createdDate, previousCreationDate);
                        [_duplicates addObject:otherDict];
                        [profileArray removeObject:otherDict];
                        [profileArray addObject:provisionDict];
                    }
                    
                } else {
                    
                    //we dont have this name on record and it should be a valid profile!
                    
                    [profileArray addObject:provisionDict];
                    [profileNames addObject:name];
                    
                }
                
                
            }
        }
    }
    
    invalidProfiles = _invalids;
    expiredProfiles = _expired;
    duplicateProfiles = _duplicates;
    
    
    return profileArray;
}

- (NSArray *)validProfilePaths
{
    NSMutableArray *pathArray = [NSMutableArray new];
    NSArray *profiles = [self validProfiles];
    for (NSDictionary *profile in profiles)
    {
        NSString *filePath = [[[self provisioningProfilesPath] stringByAppendingPathComponent:profile[@"UUID"]] stringByAppendingPathExtension:@"mobileprovision"];
        [pathArray addObject:filePath];
    }
    return pathArray;
}

- (NSMutableDictionary *)provisioningDictionaryFromFilePath:(NSString *)profilePath
{
    NSString *fileContents = [NSString stringWithContentsOfFile:profilePath encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0)
        fileContents = [NSString stringWithContentsOfFile:profilePath]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
    
    fileLength = [fileContents length];
    if (fileLength == 0)
        return nil;
    
    //find NSRange location of <?xml to pass by all the "garbage" data before our plist
    
    NSUInteger startingLocation = [fileContents rangeOfString:@"<?xml"].location;
    
    //find NSRange of the end of the plist (there is "junk" cert data after our plist info as well
    NSRange endingRange = [fileContents rangeOfString:@"</plist>"];
    
    //adjust the location of endingRange to include </plist> into our newly trimmed string.
    NSUInteger endingLocation = endingRange.location + endingRange.length;
    
    //offset the ending location to trim out the "garbage" before <?xml
    NSUInteger endingLocationAdjusted = endingLocation - startingLocation;
    
    //create the final range of the string data from <?xml to </plist>
    
    NSRange plistRange = NSMakeRange(startingLocation, endingLocationAdjusted);
    
    //actually create our string!
    NSString *plistString = [fileContents substringWithRange:plistRange];
    
    //yay categories!! convert the dictionary raw string into an actual NSDictionary
    NSMutableDictionary *dict = [plistString dictionaryFromString];
    
    
    //write to file for debug / posterity
   // [dict writeToFile:[[[self pwd] stringByAppendingPathComponent:dict[@"Name"]] stringByAppendingPathExtension:@"plist"] atomically:TRUE];
    
    return dict;
}


@end
