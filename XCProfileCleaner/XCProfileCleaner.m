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
#import "XCPCWindowController.h"

@interface NSString (additions)

- (NSString *)standardBundleID;

@end

@implementation NSString (additions)

- (NSString *)standardBundleID
{
    NSRange stringRange = [self rangeOfString:@"."];
    NSInteger offsetLocation = (stringRange.location+1);
    
    return [self substringFromIndex:offsetLocation];
}

@end

static XCProfileCleaner *sharedPlugin;

@interface XCProfileCleaner()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) XCPCWindowController* windowController;
@property (nonatomic, strong) NSMutableArray *alertDetails;
@end

@implementation XCProfileCleaner

+ (void)initialize
{
    NSDictionary *appDefaults = @{kPCAlertOnProjectChanges: [NSNumber numberWithBool:TRUE], kPCScanOpenedProfiles: [NSNumber numberWithBool:TRUE], kPCScanOpenedProjects: [NSNumber numberWithBool:TRUE] };
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

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

- (void)XCPDelayedSetup
{
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *ppMenuItem = [[NSMenuItem alloc] init];
        [ppMenuItem setTitle:@"Provisioning Profiles"];
        
        NSMenu *fullMenu = [[NSMenu alloc] initWithTitle:@""];
        NSMenuItem *actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"Clean provisioning profiles..." action:@selector(cleanProfiles) keyEquivalent:@"c"];
        [actionMenuItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask];
        [actionMenuItem setTarget:self];
        [fullMenu addItem:actionMenuItem];
        NSMenuItem *prefItem = [[NSMenuItem alloc] initWithTitle:@"Show Preferences..." action:@selector(showPrefs:) keyEquivalent:@""];
        [prefItem setTarget:self];
        [fullMenu addItem:prefItem];
        
        [ppMenuItem setSubmenu:fullMenu];
        [[menuItem submenu] addItem:ppMenuItem];
        
    }
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        
        //turn off the swizzling for now, everything inside there is experimental.
        [self doSwizzlingScience];
    });
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        
        if (self.windowController == nil) {
            XCPCWindowController* wc = [[XCPCWindowController alloc] initWithWindowNibName:@"XCPCWindowController"];
            self.windowController = wc;
            
        }
        self.alertDetails = [NSMutableArray new];
        self.scannedProjects = [NSMutableArray new];
        // Create menu items, initialize UI, etc.

        
        //experimental right now
        
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceScanned:) name:@"IDESourceControlDidScanWorkspaceNotification" object:nil];
        
       
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(XCPDelayedSetup) userInfo:nil repeats:FALSE];
        
    }
    return self;
}

- (void)showPrefs:(id)sender
{
    [self.windowController.window makeKeyAndOrderFront:nil];
}

- (void)workspaceScanned:(NSNotification *)n
{
    if ([UD boolForKey:kPCScanOpenedProjects] == TRUE)
    {
        NSString *scannedWorkspace = [[[[[n object] workspace] representingFilePath] fileURL] path];
        NSLog(@"#### scanned workspace: %@", scannedWorkspace);
        id project = [objc_getClass("PBXProject") projectWithFile:scannedWorkspace];
        NSString *productName = [project name];
        
        
        
        if ([[self scannedProjects] containsObject:productName])
        {
            NSLog(@"#### already scanned %@", productName);
            return;
        }
        
        if (productName != nil) {
            [[self scannedProjects] addObject:productName];
        }
        NSLog(@"#### evaluating project named: %@", productName);
        id mainTarget = [project targetNamed: productName];
        
        BOOL iphoneRequired = [[mainTarget productSettingForKey:@"LSRequiresIPhoneOS"] boolValue];
        
        if (iphoneRequired == TRUE)
        {
            [self validateProductTargetConfig:@"Debug" onTarget:mainTarget];
            [self validateProductTargetConfig:@"Release" onTarget:mainTarget];
        }
        
        [self showUpdateAlert];
    }

}

- (void)validateProductTargetConfig:(NSString *)targetConfig onTarget:(id)mainTarget
{
    NSArray *devCerts = [KBProfileHelper devCertsFull];
    BOOL iphoneRequired = [[mainTarget productSettingForKey:@"LSRequiresIPhoneOS"] boolValue];
    id targetContext = [mainTarget cachedPropertyInfoContextForConfigurationNamed:targetConfig];
    NSString *productID = [mainTarget productSettingForKey:@"CFBundleIdentifier"];
    
    NSString *provProfile = [targetContext expandedValueForPropertyNamed:@"PROVISIONING_PROFILE"];
    NSString *codeSignID = [targetContext expandedValueForPropertyNamed:@"CODE_SIGN_IDENTITY"];
    
    if (provProfile != nil || iphoneRequired == TRUE) // we dont care otherwise, no mac support yet
    {
        /* if codesignID length is 0 then it probably means they have "Automatic" set for the developer choice, we don't want to disrupt that and am
         not 100% sure how to even check that setting "properly". */
        
        if ([devCerts containsObject:codeSignID] || codeSignID.length == 0)
        {
            NSLog(@"#### current project codesign value is valid or automatically selected: %@", codeSignID);
            
        } else {
            
            NSLog(@"#### %@ is not a valid code sign ID for project: %@ Certificate expiration is possible explanation", codeSignID, [mainTarget name]);
            
        }
        
        NSString *provProfilePath = [KBProfileHelper pathFromUUID:provProfile];
        if (![[NSFileManager defaultManager] fileExistsAtPath:provProfilePath])
        {
            NSLog(@"### provisioning profile %@ is missing!!!", provProfilePath);
            //  return;
        }
        
        NSDictionary *currentProvProfile = [KBProfileHelper provisioningDictionaryFromFilePath:[KBProfileHelper pathFromUUID:provProfile]];
        NSString *myCodesignID = currentProvProfile[@"CODE_SIGN_IDENTITY"];
        if (myCodesignID == nil)
        {
            NSLog(@"### current provisioning profile: %@ is invalid", currentProvProfile);
            
            NSDictionary *validProfile = [KBProfileHelper validProfileForID:productID withTarget:targetConfig];
            if (validProfile != nil)
            {
                NSLog(@"### found a valid profile, should change to it: %@", validProfile[@"Name"]);
                
                id conditionSet = [ objc_getClass("DVTMacroDefinitionConditionSet") conditionSetFromStringRepresentation:@"[sdk=iphoneos*]" getBaseMacroName:nil error:nil];
                [targetContext setValue:validProfile[@"UUID"] forPropertyName:@"PROVISIONING_PROFILE"];
                [targetContext setValue:validProfile[@"CODE_SIGN_IDENTITY"] forPropertyName:@"CODE_SIGN_IDENTITY"];
                [targetContext setValue:validProfile[@"CODE_SIGN_IDENTITY"] forPropertyName:@"CODE_SIGN_IDENTITY" conditionSet:conditionSet];
                
                NSDictionary *updatedProfile = @{@"projectName": [mainTarget name], @"profileName": validProfile[@"Name"], @"reason": @"Replacing invalid cert/profile", @"target": targetConfig};
                
                [self.alertDetails addObject:updatedProfile];
                
                
            }
        }
        
        
        
    }
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

/*
 
 all the magic happens here when it comes to the plugin processing profiles as they get opened by Xcode.
 
 */

//IDESourceControlDidScanWorkspaceNotification

- (void)processProfile:(NSString *)theFile
{
    NSLog(@"#### XCProfileCleaner Processing Profile: %@", theFile);
    
    Class pbxProjClass = objc_getClass("PBXProject");
    Class macroClass = objc_getClass("DVTMacroDefinitionConditionSet");
    NSArray *devCerts = [KBProfileHelper devCertsFull];
    NSDictionary *openedProfile = [KBProfileHelper provisioningDictionaryFromFilePath:theFile];
    NSString *openProfileName = openedProfile[@"Name"];
    NSString *target = openedProfile[@"Target"];
    NSString *incomingAppID = [[openedProfile[@"Entitlements"] objectForKey:@"application-identifier"] standardBundleID];
    
    //modify debug/release target settings depending on whether the profile is a Distribution or Dev profile.
    
    if (target == nil) target = @"Debug";
    
    NSArray *openedProjects = [pbxProjClass openProjects]; //eventually cycle through all open projects
    
    //remeber to make sure if it isnt currently codesigning, not to add it to projects that dont currently have it toggled on!!
    
    //the above note isn't important at the current moment since we are only supporting iOS profiles with the initial version.
    
    for (id project in openedProjects)
    {
        BOOL currentProfileValid = FALSE;
        BOOL incomingProfileValid = FALSE;
        BOOL codesignIDChanged = TRUE;
        
        NSString *productName = [project name];
        
        NSLog(@"#### evaluating project named: %@", productName);
        
        id conditionSet = [macroClass conditionSetFromStringRepresentation:@"[sdk=iphoneos*]" getBaseMacroName:nil error:nil];
        id cmdTarget = [project targetNamed: productName];
        NSString *productID = [cmdTarget productSettingForKey:@"CFBundleIdentifier"];
        BOOL iphoneRequired = [[cmdTarget productSettingForKey:@"LSRequiresIPhoneOS"] boolValue];
        id targetContext = [cmdTarget cachedPropertyInfoContextForConfigurationNamed:target];
        NSString *provProfile = [targetContext expandedValueForPropertyNamed:@"PROVISIONING_PROFILE"];
        NSString *codeSignID = [targetContext expandedValueForPropertyNamed:@"CODE_SIGN_IDENTITY"];
        
        /* if codesignID length is 0 then it probably means they have "Automatic" set for the developer choice, we don't want to disrupt that and am
        not 100% sure how to even check that setting "properly". */
        
        if ([devCerts containsObject:codeSignID] || codeSignID.length == 0)
        {
            NSLog(@"#### current project codesign value is valid or automatically selected: %@", codeSignID);
            currentProfileValid = TRUE;
            
        } else {
            
            NSLog(@"#### %@ is not a valid code sign ID. Certificate expiration is possible explanation", codeSignID);
            currentProfileValid = FALSE;
        }
        
        /*
         
         validate the productID with the one in the provisioning profile to make sure its even applicable to this current project
         
         do this by matching the incoming ID (stripped to a standard product ID) against our current projects CFBundleIdentifier
         
         */
        if (([incomingAppID isEqualToString:productID] || [incomingAppID isEqualToString:@"*"]) && iphoneRequired)
        {
            NSLog(@"#### the incoming profile is for iOS and ID is a wildcard OR ID matches our current application: %@", incomingAppID);
   
            
            //get the details of our current provisioning profile that this project is using to determine if its valid and to get the actual profile name.
            
            NSDictionary *currentProvProfile = [KBProfileHelper provisioningDictionaryFromFilePath:[KBProfileHelper pathFromUUID:provProfile]];
            
            NSString *openID = openedProfile[@"CODE_SIGN_IDENTITY"]; //we append the value when we create the provisioning dictionary IF we find a matching valid certificate in keychain.
            
            if (openID != nil) //we have a valid profile because this key exists in the dictionary!
            {
                if ([openID isEqualToString:codeSignID])
                {
                    NSLog(@"#### ids already match!");
                    codesignIDChanged = FALSE;
                }
                
                NSLog(@"### We have a valid codesign ID for this new cert!");
                incomingProfileValid = TRUE;
                
            } else {
                
                NSLog(@"### incoming profile is invalid you don't have any of the following certs: %@", openedProfile[@"CodeSignArray"]);
                incomingProfileValid = FALSE;
                return;
                
            }
            
            /*
             
             provisioning profiles are organized in the ~/Library/MobileDevice/Provisioning Profiles folder the are organized by their UUID, Xcode 
             stores this UUID in target/projects property PROVISIONING_PROFILE key, if we want to update it thats how we do it. with the UUID.
             
             
             */
            
            NSString *incomingProfile = openedProfile[@"UUID"];
            
            NSString *profileName = currentProvProfile[@"Name"];
            
            //compare our current provisioing profile in this project with the name of the incoming one, if they match its a newer version and we make sure Xcode updates/propagates this change.
 
            //FIXME: should probably do a sanity compare to make sure this profile is a) newer b) has more UDID's
            
            if ([openProfileName isEqualToString:profileName])
            {
                NSLog(@"#### Project: %@ already uses the profile: %@! pointing towards the new one.", productName, profileName);
                
                if (incomingProfileValid == TRUE)
                {
                    NSLog(@"#### updating project to new profile!");
                    [targetContext setValue:incomingProfile forPropertyName:@"PROVISIONING_PROFILE"];
                    
                    if (codesignIDChanged == TRUE)
                    {
                        [targetContext setValue:openID forPropertyName:@"CODE_SIGN_IDENTITY"];
                        [targetContext setValue:openID forPropertyName:@"CODE_SIGN_IDENTITY" conditionSet:conditionSet];
                    }
                    
                    
                    NSDictionary *updatedProfile = @{@"projectName": productName, @"profileName": openProfileName, @"reason": @"Newer profile", @"target": target};
                    
                    [self.alertDetails addObject:updatedProfile];
                    
                    return;
                    
                }
                
            }
            
            /* 
               if we have gotten this far its because the projects current and incoming profile dont match, but still want to check to see if the current one is valid
               if it is not then we are being "smart" and updating this project to use a valid profile.
            
              the reasoning here is we have passed all the rigorous validation checks (is it a wildcard/matching app ID, does it have a valid cert, and (for now) is it 
              iOS based. 
             
        
             */
             
            if (currentProfileValid == FALSE)
            {
                NSLog(@"the current profile selected for this project is currently invalid: %@ Expected ID: %@", provProfile, codeSignID);
                
                [targetContext setValue:incomingProfile forPropertyName:@"PROVISIONING_PROFILE"];
                
                if (codesignIDChanged == TRUE)
                {
                    [targetContext setValue:openID forPropertyName:@"CODE_SIGN_IDENTITY"];
                    [targetContext setValue:openID forPropertyName:@"CODE_SIGN_IDENTITY" conditionSet:conditionSet];
                }
                
                NSDictionary *updatedProfile = @{@"projectName": productName, @"profileName": openProfileName, @"reason": @"Expired/Invalid profile replaced", @"target": target};
                
                [self.alertDetails addObject:updatedProfile];
                
            }
            
            
        } else {
            
            NSLog(@"#### %@ is not iOS based, XCProfileCleaner is currently iOS only",productName );
            
        }
    }
    
    [self showUpdateAlert];
    
    

}

- (NSString *)alertDetailString
{
    NSMutableString *newString = [NSMutableString new];
    for (NSDictionary *detail in self.alertDetails)
    {
        NSString *detailString = [NSString stringWithFormat:@"Project '%@' target '%@' was updated to profile: '%@' for reason: %@\n\n", detail[@"projectName"], detail[@"target"], detail[@"profileName"], detail[@"reason"]];
        [newString appendString:detailString];
    }
    
    [newString appendString:@"\nThese settings can be changed in Product->Provisioning Profiles->Show Preferences"];
    
    return newString;
}

- (void)showUpdateAlert
{
    if ([UD boolForKey:kPCAlertOnProjectChanges] == TRUE)
    {
        
        if (self.alertDetails.count > 0)
        {
            NSAlert *theAlert = [NSAlert alertWithMessageText:@"Projects Updated" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", [self alertDetailString]];
            [theAlert setShowsSuppressionButton:TRUE];
            [theAlert runModal];
            NSInteger showButton = [[theAlert suppressionButton] state];
            if (showButton == 1)
            {
                [UD setBool:false forKey:kPCAlertOnProjectChanges];
            }
        }
    }
    
    [self.alertDetails removeAllObjects];
}

/*
 
 Extra note:
 
 Limiting to iOS only right now removes the extra sanity check of whether or not the project even uses code signing to begin with. and since code signing is required
 to officially run anything on an iOS device, we don't need to check to see if they use code signing as is, they don't have a choice!
 
 so to add Mac support (it /should/ be rather trivial)
 
 1. add "provisionprofile" to extensions checked in the openFiles: replacement
 2. add an extra check to make sure you aren't adding codesign to a project that doesn't currently have it on / want to have it on
 3. pretty sure the check for whether your a Debug/Release profile gets trickier to
 
 on that note, adding mac support isnt a high priority. never really agreed with the whole concept of adding a walled garden where one wasn't necessary.
 
 
 */

- (BOOL)newOurApplication:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    BOOL orig = [self newOurApplication:sender openFiles:filenames]; // call original method;
    for (NSString *theFile in filenames)
    {
        if ([[[theFile pathExtension] lowercaseString] isEqualToString:@"mobileprovision"])
        {
            if([UD boolForKey:kPCScanOpenedProfiles] == TRUE)
            {
                [sharedPlugin processProfile:theFile];
            }
        }
    }
    return orig;
}



- (void)_setIssues:(id)arg1 forFilePath:(id)arg2 {}

- (void)_ourSetIssues:(id)arg1 forFilePath:(id)arg2 {

    NSLog(@"issuesClass: %@", NSStringFromClass([arg1 class]));
    NSLog(@"setIssues: %@ forFilePath: %@", arg1, arg2);
    [self _ourSetIssues:arg1 forFilePath:arg2];
    
}

- (void)_addIssues:(id)arg1 { }

- (void)_ourAddIssues:(id)arg1 {

    NSLog(@"issuesClass: %@", NSStringFromClass([arg1 class]));
    NSLog(@"_ourAddIssues: %@", arg1);
    [self _ourAddIssues:arg1];
    
}


/*
 
 ws = window.document.workspace
 ip = ws.issueManager
 issueProviders = [ip valueForKey:"issueProviders"]
 dp = [issueProviders objectAtIndex:5]
 ig = ip.issueGroups
 */



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
        NSLog(@"IDEApplicationController application:openFiles: replaced!");
    } else {
        
        NSLog(@"IDEApplicationController application:openFiles: failed to replace with error(: %@", theError);
    }
    
    //just messin around with adding issues.
    
    /*
    
    Class diagnosticIssueProvider = objc_getClass("IDEDiagnosticIssueProvider");
    Class ifg = objc_getClass("IDEIssueFileGroup");
    
    Method ourSetIssuesReplacement = class_getInstanceMethod([self class], @selector(_ourSetIssues:forFilePath:));
    class_addMethod(diagnosticIssueProvider, @selector(_ourSetIssues:forFilePath:), method_getImplementation(ourSetIssuesReplacement), method_getTypeEncoding(ourSetIssuesReplacement));
    
    swizzleScience = [diagnosticIssueProvider jr_swizzleMethod:@selector(_setIssues:forFilePath:) withMethod:@selector(_ourSetIssues:forFilePath:) error:&theError];
    
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDEDiagnosticIssueProvider _setIssues:forFilePath: replaced!");
    } else {
        
        NSLog(@"IDEDiagnosticIssueProvider _setIssues:forFilePath: failed to replace with error(: %@", theError);
    }
    
    Method addIssuesReplacement = class_getInstanceMethod([self class], @selector(_ourAddIssues:));
    class_addMethod(ifg, @selector(_ourAddIssues:), method_getImplementation(addIssuesReplacement), method_getTypeEncoding(addIssuesReplacement));
    
    swizzleScience = [ifg jr_swizzleMethod:@selector(_addIssues:) withMethod:@selector(_ourAddIssues:) error:&theError];
    
    if (swizzleScience == TRUE)
    {
        NSLog(@"IDEIssueFileGroup _addIssues: replaced!");
    } else {
        
        NSLog(@"IDEIssueFileGroup _addIssues: failed to replace with error(: %@", theError);
    }
  
    */
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
