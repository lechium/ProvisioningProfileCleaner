//
//  XCProfileCleaner.m
//  XCProfileCleaner
//
//  Created by Kevin Bradley on 8/7/14.
//    Copyright (c) 2014 nito. All rights reserved.
//

#import "XCProfileCleaner.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>
#import "XCPCModel.h"

#import "KBProfileHelper.h"
static XCProfileCleaner *sharedPlugin;

@interface XCProfileCleaner()

@property (nonatomic, strong) NSBundle *bundle;
@end

@implementation XCProfileCleaner

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        // Create menu items, initialize UI, etc.

        // Sample Menu Item:
        NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
        if (menuItem) {
            [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
            NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Clean provisioning profiles..." action:@selector(cleanProfiles) keyEquivalent:@"c"];
            [actionMenuItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask];
            [actionMenuItem setTarget:self];
            [[menuItem submenu] addItem:actionMenuItem];
        }
        
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            
            //turn off the swizzling for now, everything inside there is experimental.
          // [self doSwizzlingScience];
        });
    }
    return self;
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

- (void)processProfile:(NSString *)theFile
{
    Class pbxProjClass = objc_getClass("PBXProject");
    Class macroClass = objc_getClass("DVTMacroDefinitionConditionSet");
    NSArray *devCerts = [KBProfileHelper devCertsFull];
    NSDictionary *openedProfile = [KBProfileHelper provisioningDictionaryFromFilePath:theFile];
    NSString *openProfileName = openedProfile[@"Name"];
    NSString *projectFile = [XCPCModel currentProjectFile];
    
    BOOL currentProfileValid = FALSE;
    BOOL incomingProfileValid = FALSE;
    BOOL codesignIDChanged = TRUE;
    NSLog(@"##### PROJECTFILE: %@", projectFile);
    
    NSString *projectName = [XCPCModel currentProjectName];
    
    id project = [pbxProjClass projectWithFile:projectFile];
    NSString *productName = [project name];
    id conditionSet = [macroClass conditionSetFromStringRepresentation:@"[sdk=iphoneos*]" getBaseMacroName:nil error:nil];
    id cmdTarget = [project targetNamed: productName];
    id debugTargetContext = [cmdTarget cachedPropertyInfoContextForConfigurationNamed:@"Debug"];
    id rlsTargetContext = [cmdTarget cachedPropertyInfoContextForConfigurationNamed:@"Release"];
    NSString *provProfile = [debugTargetContext expandedValueForPropertyNamed:@"PROVISIONING_PROFILE"];
    NSString *codeSignID = [debugTargetContext expandedValueForPropertyNamed:@"CODE_SIGN_IDENTITY"];
    BOOL definitelyNotDistributionProfile = FALSE;
 
  
    if ([devCerts containsObject:codeSignID])
    {
        NSLog(@"current project codesign value is valid: %@", codeSignID);
        currentProfileValid = TRUE;
    }
    
    NSDictionary *currentProvProfile = [KBProfileHelper provisioningDictionaryFromFilePath:[KBProfileHelper pathFromUUID:provProfile]];
  
    if ([openedProfile[@"DeveloperCertificates"]count] > 1)
    {
        //can at least identify that the incoming profile isnt a distro profile. the last issue is there is no reference to individual names / ID's in
        //provisioning profile plist :(
        definitelyNotDistributionProfile = TRUE;
        NSLog(@"#### incoming profile is DEFINITELY a developer profile");
        NSString *iphoneDevCert = [KBProfileHelper iphoneDeveloperString];
        NSLog(@"#### would probably be safe to assume we should change to this cert if its not the current one; %@", iphoneDevCert);
        if ([iphoneDevCert isEqualToString:codeSignID])
        {
            NSLog(@"#### ids already match!");
        }
    }
    NSString *certID = [openedProfile[@"TeamIdentifier"] lastObject];
    NSString *teamName = openedProfile[@"TeamName"];
    NSString *incomingProfile = openedProfile[@"UUID"];
    NSString *fullID = [NSString stringWithFormat:@"%@ (%@)", teamName, certID];
    NSLog(@"fullID: %@", fullID);
   
    if ([devCerts containsObject:fullID])
    {
        NSLog(@"We have a valid codesign ID for this new cert!");
        incomingProfileValid = TRUE;
    }
    //NSLog(@"devCerts: %@", devCerts);
    
    if ([codeSignID isEqualToString:fullID])
    {
        NSLog(@"code sign ID should not change");
        codesignIDChanged = FALSE;
    }

    NSString *profileName = currentProvProfile[@"Name"];
    
    if ([openProfileName isEqualToString:profileName])
    {
        NSLog(@"#### Frontmost Project: %@ uses the profile: %@", projectName, profileName);
        
        if (incomingProfileValid == TRUE)
        {
            NSLog(@"updating project to new profile!");
            [debugTargetContext setValue:incomingProfile forPropertyName:@"PROVISIONING_PROFILE"];
            
            if (codesignIDChanged == TRUE)
            {
                [debugTargetContext setValue:fullID forPropertyName:@"CODE_SIGN_IDENTITY"];
                [debugTargetContext setValue:fullID forPropertyName:@"CODE_SIGN_IDENTITY" conditionSet:conditionSet];
            }
            
            return;
            
        }
        
    }
    
    if (currentProfileValid == FALSE)
    {
        [debugTargetContext setValue:incomingProfile forPropertyName:@"PROVISIONING_PROFILE"];
        
        if (codesignIDChanged == TRUE)
        {
            [debugTargetContext setValue:fullID forPropertyName:@"CODE_SIGN_IDENTITY"];
            [debugTargetContext setValue:fullID forPropertyName:@"CODE_SIGN_IDENTITY" conditionSet:conditionSet];
        }
    }
    
    

}

- (BOOL)newOurApplication:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    NSLog(@"newOurApplication:openFiles:");
    BOOL orig = [self newOurApplication:sender openFiles:filenames]; // call original method;
    NSString *filename = [filenames lastObject];
    NSLog(@"filename: %@", filename);
    if ([[[filename pathExtension] lowercaseString] isEqualToString:@"mobileprovision"])
    {
       //do extra stuff
          NSLog(@"do extra stuff: %@", filename);
        [sharedPlugin processProfile:filenames.lastObject];
        
   // } else {
        
     //   orig = [self newOurApplication:sender openFiles:filenames];
    }
    
    return orig;
}

- (void)doSwizzlingScience
{
    
    Class xcAppClass = objc_getClass("IDEApplicationController");
    NSError *theError = nil;
    
    BOOL swizzleScience = FALSE;
    
    
    Method ourFilesOpenReplacement = class_getInstanceMethod([self class], @selector(newOurApplication:openFiles:));
    class_addMethod(xcAppClass, @selector(newOurApplication:openFiles:), method_getImplementation(ourFilesOpenReplacement), method_getTypeEncoding(ourFilesOpenReplacement));
    
    swizzleScience = [xcAppClass jr_swizzleMethod:@selector(application:openFiles:) withMethod:@selector(newOurApplication:openFiles:) error:&theError];
    
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDEApplicationController ourApplication:openFiles: replaced!");
    } else {
        
        NSLog(@"IDEApplicationController ourApplication:openFiles: failed to replace with error(: %@", theError);
    }
    
  
    
}
- (void)showProfileSuccessAlert
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Profile clean completed!" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"Your provisioning profile folder has been cleaned, it is recommended to quit Xcode before you continue.\n Would you like to see the detail log?"];
    NSModalResponse modalReturn = [alert runModal];
    switch (modalReturn) {
            
        case NSAlertDefaultReturn:
            
            [[NSWorkspace sharedWorkspace] openFile:[KBProfileHelper mobileDeviceLog]];
            break;
            
        case NSAlertAlternateReturn:
            
            break;
    }
}

// Sample Action, for menu item:
- (void)cleanProfiles
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Provisioning profile cleanup" defaultButton:@"Clean" alternateButton:@"Cancel" otherButton:@"More Info" informativeTextWithFormat:@"Cleaning your profile folder will remove any invalid or old duplicate profiles, would you like to continue?"];
    
    KBProfileHelper *profileHelper = [[KBProfileHelper alloc] init];
    
    NSModalResponse modalReturn = [alert runModal];
    
    switch (modalReturn) {
        
        case NSAlertDefaultReturn:
            
            [profileHelper processProfilesWithOpen:FALSE];
            [self showProfileSuccessAlert];
            break;
            
        case NSAlertAlternateReturn:
            
            profileHelper = nil;
            break;
            
        case NSAlertOtherReturn:
            
            profileHelper = nil;
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/lechium/ProvisioningProfileCleaner/master/README.md"]];
            break;
        
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
