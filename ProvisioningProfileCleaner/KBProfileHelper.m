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

//was used when different files were maintained for each log, easy way to clear out contents of mutable string

@interface NSMutableString (profileHelper)

- (void)clearString;

@end

@implementation NSMutableString (profileHelper)

- (void)clearString {
    [self deleteCharactersInRange:NSMakeRange(0, self.length)];
}

@end
@interface NSString (profileHelper)
- (id)dictionaryFromString;
@end

@implementation NSString (profileHelper)

//convert basic XML plist string from the profile and convert it into a mutable nsdictionary

- (id)dictionaryFromString {
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


//filter subarray based on what contacts have that particular name sorted ascending by creation date. used to easily sort the top most object as far as date created when doing profile comparisons

- (NSArray *)subarrayWithName:(NSString *)theName {
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(Name == %@)", theName];
    NSSortDescriptor *sortDesc = [[NSSortDescriptor alloc] initWithKey:@"CreationDate" ascending:TRUE];
    NSArray *filteredArray = [self filteredArrayUsingPredicate:filterPredicate];
    return [filteredArray sortedArrayUsingDescriptors:@[sortDesc]];
}

@end


@implementation KBProfileHelper

//super small / lightweight easy replacement for using an NSTask to get data back out of a cli utilility

+ (NSArray *)returnForProcess:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
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

- (int)processProfiles {
    return [self processProfilesWithOpen:TRUE];
}

//actually process the expiredProfiles / duplicateProfiles / invalid profiles here, these are set in validProfiles (kind of a hack, but it works)

- (int)processProfilesWithOpen:(BOOL)openBool {
    //not really used for anything other than logging purposes, in the old version of this i would copy the valid profiles to a different folder.
    NSArray *validProfiles = [self validProfilePaths];
    DLog(@"Valid Profiles: %@", validProfiles);
    NSMutableString *logString = [NSMutableString new];
    //write all the logs to here
    NSString *ourLog = [KBProfileHelper mobileDeviceLog];
    
    //process expired profiles
    
    if (expiredProfiles.count > 0) {
        // NSString *expiredLog = [[self expiredProvisioningProfiles] stringByAppendingPathComponent:@"Expired.log"];
        [logString appendString:@"The following provisioning profiles have expired:\n---------------------------------------------------\n\n"];
        for (NSDictionary *expiredDict in expiredProfiles) {
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
        [logString appendString:@"\n\n"];
        [logString writeToFile:ourLog atomically:true encoding:NSUTF8StringEncoding error:nil];
        // [logString clearString];
    }
    
    //process duplicate profiles
    
    if (duplicateProfiles.count > 0) {
        //   NSString *duplicateLog = [[self duplicateProvisioningProfiles] stringByAppendingPathComponent:@"Duplicates.log"];
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
        [logString appendString:@"\n\n"];
        [logString writeToFile:ourLog atomically:true encoding:NSUTF8StringEncoding error:nil];
        //[logString clearString];
    }
    
    //process invalid profiles
    
    if (invalidProfiles.count > 0) {
        // NSString *invalidLog = [[self invalidProvisioningProfiles] stringByAppendingPathComponent:@"Invalid.log"];
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
            NSArray *validCerts = invalidDict[@"CodeSignArray"];
            NSString *profileInfo = [NSString stringWithFormat:@"Profile %@ is invalid (there is no matching valid certificate!)\nit expires on %@ with team: %@ (%@) profile name: %@ \nappID: %@ appIDName: %@ missing expected certs: %@\n\n", fileName, expireDate,teamName,teamId, name, appID, appIDName, validCerts];
            [logString appendString:profileInfo];
            
        }
        [logString writeToFile:ourLog atomically:true encoding:NSUTF8StringEncoding error:nil];
    }
    
    if (openBool == TRUE){
        NSString *openPath = [NSString stringWithFormat:@"/usr/bin/open '%@'", [self provisioningProfilesPath]];
        system([openPath UTF8String]);
    }
    return 0;
}

+ (NSString *)iphoneDeveloperString {
    NSArray *devCertsArray = [self devCertsFull];
    for (NSString *devCert in devCertsArray) {
        if ([devCert rangeOfString:@"iPhone Developer:"].location != NSNotFound) {
            return devCert;
        }
    }
    return nil;
}

+ (NSArray *)devCertsFull {
    NSMutableArray *outputArray = [[NSMutableArray alloc ]init];
    NSArray *securityReturn = [KBProfileHelper returnForProcess:@"security find-identity -p codesigning -v"];
    for (NSString *profileLine in securityReturn) {
        if (profileLine.length > 0) {
            NSArray *clips = [profileLine componentsSeparatedByString:@"\""];
            if ([clips count] > 1) {
                NSString *clipIt = [[profileLine componentsSeparatedByString:@"\""] objectAtIndex:1];
                [outputArray addObject:clipIt];
            }
        }
    }
    return outputArray;
}

- (NSArray *)devCerts {
    NSMutableArray *outputArray = [[NSMutableArray alloc ]init];
    NSArray *securityReturn = [KBProfileHelper returnForProcess:@"security find-identity -p codesigning -v"];
    for (NSString *profileLine in securityReturn) {
        if (profileLine.length > 0) {
            NSArray *clips = [profileLine componentsSeparatedByString:@"\""];
            if ([clips count] > 1) {
                NSString *clipIt = [[profileLine componentsSeparatedByString:@"\""] objectAtIndex:1];
                NSArray *certArray = [clipIt componentsSeparatedByString:@"("];
                NSString *certID = [[certArray lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@") "]];
                //  DLog(@"certId: -%@-", certID);
                NSString *devName = [[certArray objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (certID != nil && devName != nil){
                    // NSDictionary *certDict = @{@"certID": certID, @"devName": devName};
                    [outputArray addObject:certID];
                    //  DLog(@"%@", clipIt);
                    
                }
            }
        }
    }
    return outputArray;
}

- (NSString *)duplicateProvisioningProfiles {
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Duplicate Profiles"];
    if (![MAN fileExistsAtPath:theDir]) {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)expiredProvisioningProfiles {
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Expired Profiles"];
    if (![MAN fileExistsAtPath:theDir]) {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)invalidProvisioningProfiles {
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Invalid Profiles"];
    if (![MAN fileExistsAtPath:theDir]) {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)validProfilePath {
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/ValidProvProfiles"];
    if (![MAN fileExistsAtPath:theDir]) {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

- (NSString *)pwd {
    NSString *theDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/ProvisioningProfileDicts"];
    if (![MAN fileExistsAtPath:theDir]) {
        [MAN createDirectoryAtPath:theDir withIntermediateDirectories:true attributes:nil error:nil];
    }
    return theDir;
}

+ (NSString *)mobileDeviceLog {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Cleanup.log"];
}

+ (NSString *)provisioningProfilesPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Provisioning Profiles"];
}

- (NSString *)provisioningProfilesPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Provisioning Profiles"];
}

/**
 
 go through DeveloperCertificates NSArray key in the mobileprovision file and loops through them one by one
 inside of this loop we run an additional loop through all of our valid cert profiles in our keychain, if we find
 the range of our string in the raw data of the cert we return that as the valid id, no need to process any data after
 that point.
 
 */

+ (NSString *)validIDFromCerts:(NSArray *)devCerts {
    NSArray *validDevCerts = [KBProfileHelper devCertsFull];
    for (NSData *devCert in devCerts) {
        for (NSString *currentValidCert in validDevCerts) {
            NSData *distroData = [currentValidCert dataUsingEncoding:NSUTF8StringEncoding];
            NSRange searchRange = NSMakeRange(0, devCert.length);
            NSRange dataRange = [devCert rangeOfData:distroData options:0 range:searchRange];
            if (dataRange.location != NSNotFound) {
                //DLog(@"found profile: %@", currentValidCert);
                return currentValidCert;
            }
        }
    }
    return nil;
}

/**
 
 go through DeveloperCertificates NSArray key in the mobileprovision file to determine what valid ID's it contains, this will mainly
 be used for logging purposes if we don't find a valid cert
 
 */

+ (NSArray *)certIDsFromCerts:(NSArray *)devCerts {
    NSMutableArray *certIDs = [NSMutableArray new];
    for (NSData *devCert in devCerts) {
        //the origin offset of iPhone Developer: / iPhone Distribution / 3rd Party Mac Developer Application: appears to be the same in ever raw cert
        //we grab way too much data on purpose since we have no idea how long the names appended will be.
        NSData *userData = [devCert subdataWithRange:NSMakeRange(0x00109, 100)];
        NSString *stringData = [[NSString alloc] initWithData:userData encoding:NSASCIIStringEncoding];
        //grab all the way up to ), split, grab first object, readd ) could probably do a range of string thing here too.. this works tho.
        NSString *devName = [[[stringData componentsSeparatedByString:@")"] firstObject] stringByAppendingString:@")"];
        //dont add any repeats
        if (![certIDs containsObject:devName]) {
            [certIDs addObject:devName];
        }
    }
    return certIDs;
}

//#define ESSENTIAL_PREDICATE @"(SELF CONTAINS[c] Essential) OR (Tag contains[c] 'essential') OR (Priority == 'required') or (Package == 'com.science')"

+ (NSDictionary *)validProfileForID:(NSString *)appID withTarget:(NSString *)target {
    NSArray *validProfiles = [self validProfilesSlim];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(applicationIdentifier contains[c] '%@') or (applicationIdentifier contains[c] '*')", appID];
    
    NSPredicate *targetPredicate = [NSPredicate predicateWithFormat:@"(Target == %@)", target];
    NSPredicate *thePred = [NSCompoundPredicate andPredicateWithSubpredicates:@[filterPredicate, targetPredicate]];
    NSArray *filterOne = [validProfiles filteredArrayUsingPredicate:thePred];
    //NSArray *filterTwo = [filterOne filteredArrayUsingPredicate:targetPredicate];
    return [filterOne firstObject];
}

+ (NSArray *)validProfilesForID:(NSString *)appID {
    NSMutableArray *bothProfiles = [NSMutableArray new];
    NSArray *validProfiles = [self validProfilesSlim];
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"(applicationIdentifier contains[c] '%@') or (applicationIdentifier contains[c] '*')", appID];
    NSPredicate *targetPredicate = [NSPredicate predicateWithFormat:@"(Target == %@)", @"Debug"];
    NSPredicate *thePred = [NSCompoundPredicate andPredicateWithSubpredicates:@[filterPredicate, targetPredicate]];
    NSArray *profileFilter = [validProfiles filteredArrayUsingPredicate:thePred];
    [bothProfiles addObject:[profileFilter firstObject]];
    targetPredicate = [NSPredicate predicateWithFormat:@"(Target == %@)", @"Release"];
    thePred = [NSCompoundPredicate andPredicateWithSubpredicates:@[filterPredicate, targetPredicate]];
    profileFilter = [validProfiles filteredArrayUsingPredicate:thePred];
    [bothProfiles addObject:[profileFilter firstObject]];
    return bothProfiles;
    
}


+ (NSArray *)validProfilesSlim {
    NSMutableArray *profileArray = [NSMutableArray new];
    NSMutableArray *profileNames = [NSMutableArray new];
    
    NSString *profileDir = [self provisioningProfilesPath];
    NSArray *fileArray = [MAN contentsOfDirectoryAtPath:profileDir error:nil];
    for (NSString *theObject in fileArray) {
        if ([[[theObject pathExtension] lowercaseString] isEqualToString:@"mobileprovision"] ||
            [[[theObject pathExtension] lowercaseString] isEqualToString:@"provisionprofile"]) {
            NSString *fullPath = [profileDir stringByAppendingPathComponent:theObject];
            NSMutableDictionary *provisionDict = [KBProfileHelper provisioningDictionaryFromFilePath:
                                                  [profileDir stringByAppendingPathComponent:theObject]];
            
            NSString *csid = provisionDict[@"CODE_SIGN_IDENTITY"];
            NSDate *expireDate = provisionDict[@"ExpirationDate"];
            NSDate *createdDate = provisionDict[@"CreationDate"];
            NSString *name = provisionDict[@"Name"];
            [provisionDict setObject:fullPath forKey:@"Path"];
            BOOL expired = FALSE;
            
            if ([expireDate isGreaterThan:[NSDate date]]) {
                //     DLog(@"not expired: %@", expireDate);
            } else {
                //its expired, who cares about any of the other details. add it to the expired list.
                DLog(@"expired: %@\n", expireDate);
                expired = TRUE;
            }
            
            //check to see if our valid non expired certificates in our keychain are referenced by the profile, or if its expired
            
            if (csid == nil || expired == TRUE) {
                
                //trimmed
                
            } else { //we got this far the profile is not expired and can be compared against other potential duplicates
                
                if ([profileNames containsObject:name]) //we have this profile already, is ours newer or is the one already in our collection newer?
                {
                    NSDictionary *otherDict = [[profileArray subarrayWithName:name] objectAtIndex:0];
                    NSDate *previousCreationDate = otherDict[@"CreationDate"];
                    if ([previousCreationDate isGreaterThan:createdDate]) {
                        DLog(@"found repeat name, but we're older: %@ vs: %@\n", createdDate, previousCreationDate);
                        
                    } else {
                        
                        DLog(@"found a newer profile: %@ replace the old one: %@\n", createdDate, previousCreationDate);
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
    return profileArray;
}

//this is where all the arrays are created of who is valid, invalid, duplicate etc...

- (NSArray *)validProfiles {
    NSMutableArray *profileArray = [NSMutableArray new];
    NSMutableArray *profileNames = [NSMutableArray new];
    NSMutableArray *_invalids = [NSMutableArray new];
    NSMutableArray *_expired = [NSMutableArray new];
    NSMutableArray *_duplicates = [NSMutableArray new];
    // NSArray *devCert = [self devCerts];
    NSString *profileDir = [self provisioningProfilesPath];
    NSArray *fileArray = [MAN contentsOfDirectoryAtPath:profileDir error:nil];
    for (NSString *theObject in fileArray) {
        if ([[[theObject pathExtension] lowercaseString] isEqualToString:@"mobileprovision"] ||
            [[[theObject pathExtension] lowercaseString] isEqualToString:@"provisionprofile"]) {
            NSString *fullPath = [profileDir stringByAppendingPathComponent:theObject];
            NSMutableDictionary *provisionDict = [KBProfileHelper provisioningDictionaryFromFilePath:
                                                  [profileDir stringByAppendingPathComponent:theObject]];
            
            NSString *csid = provisionDict[@"CODE_SIGN_IDENTITY"];
            // NSString *teamId = [provisionDict[@"TeamIdentifier"] lastObject];
            NSDate *expireDate = provisionDict[@"ExpirationDate"];
            NSDate *createdDate = provisionDict[@"CreationDate"];
            NSString *name = provisionDict[@"Name"];
            [provisionDict setObject:fullPath forKey:@"Path"];
            BOOL expired = FALSE;
            DLog(@"processing profile named: %@ filename: %@", name, theObject);
            if ([expireDate isGreaterThan:[NSDate date]]) {
                //     DLog(@"not expired: %@", expireDate);
                
            } else {
                
                //its expired, who cares about any of the other details. add it to the expired list.
                
                DLog(@"expired: %@\n", expireDate);
                [_expired addObject:provisionDict];
                expired = TRUE;
            }
            
            //check to see if our valid non expired certificates in our keychain are referenced by the profile, or if its expired
            
            if (csid == nil || expired == TRUE) {
                if (![_expired containsObject:provisionDict]) {
                    [_invalids addObject:provisionDict];
                }
                if (csid == nil) {
                    
                    DLog(@"No valid codesigning identities found!!");
                    
                } else {
                    
                    DLog(@"invalid or expired cert: %@\n", theObject );
                    
                }
            } else { //we got this far the profile is not expired and can be compared against other potential duplicates
                
                if ([profileNames containsObject:name]) //we have this profile already, is ours newer or is the one already in our collection newer?
                {
                    NSDictionary *otherDict = [[profileArray subarrayWithName:name] objectAtIndex:0];
                    NSDate *previousCreationDate = otherDict[@"CreationDate"];
                    if ([previousCreationDate isGreaterThan:createdDate]) {
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

+ (NSString *)pathFromUUID:(NSString *)uuid {
    NSString *thePath = [[[self provisioningProfilesPath] stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:@"mobileprovision"];
    if (![MAN fileExistsAtPath:thePath]) {
        thePath = [[[self provisioningProfilesPath] stringByAppendingPathComponent:uuid] stringByAppendingPathExtension:@"provisionprofile"];
        if (![MAN fileExistsAtPath:thePath]) {
            NSLog(@"provisioning profile not found: %@", thePath);
            return nil;
        }
    }
    return thePath;
}

//sort of obsolete, used to take the valid profiles and copy them out for the original POC

- (NSArray *)validProfilePaths {
    NSMutableArray *pathArray = [NSMutableArray new];
    NSArray *profiles = [self validProfiles];
    for (NSDictionary *profile in profiles)
    {
        NSString *filePath = [[self class] pathFromUUID:profile[@"UUID"]];
        if (filePath != nil) {
            [pathArray addObject:filePath];
        }
    }
    return pathArray;
}


//take that profile and chop off the top and bottom "junk" data to get at the <?xml -> </plist> portion that we need.

+ (NSMutableDictionary *)provisioningDictionaryFromFilePath:(NSString *)profilePath {
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
    
    
    NSString *appID = [dict[@"Entitlements"] objectForKey:@"application-identifier"];
    
    if (appID == nil) {
        appID = [dict[@"Entitlements"] objectForKey:@"com.apple.application-identifier"];
    }
    [dict setObject:appID forKey:@"applicationIdentifier"];
    
    //since we will always need this data, best to grab it here and make it part of the dictionary for easy re-use / validity check.
    
    NSString *ourID = [self validIDFromCerts:dict[@"DeveloperCertificates"]];
    
    if (ourID != nil) {
        [dict setValue:ourID forKey:@"CODE_SIGN_IDENTITY"];
        //in THEORY should set the profile target to Debug or Release depending on if it finds "Developer:" string.
        if ([ourID rangeOfString:@"Developer:"].location != NSNotFound) {
            [dict setValue:@"Debug" forKey:@"Target"];
        } else {
            [dict setValue:@"Release" forKey:@"Target"];
        }
    }
    
    //grab all the valid certs, for later logging / debugging for why a profile might be invalid
    
    NSArray *validCertIds = [self certIDsFromCerts:dict[@"DeveloperCertificates"]];
    [dict setValue:validCertIds forKey:@"CodeSignArray"];
    
    // shouldnt need this frivolous data any longer, we know which ID (if any) we have and have all the valid ones too
    
    [dict removeObjectForKey:@"DeveloperCertificates"];
    
    //write to file for debug / posterity
    // [dict writeToFile:[[[self pwd] stringByAppendingPathComponent:dict[@"Name"]] stringByAppendingPathExtension:@"plist"] atomically:TRUE];
    return dict;
}

@end
