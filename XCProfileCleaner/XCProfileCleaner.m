//
//  XCProfileCleaner.m
//  XCProfileCleaner
//
//  Created by Kevin Bradley on 8/7/14.
//    Copyright (c) 2014 nito. All rights reserved.
//

#import "XCProfileCleaner.h"
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
    }
    return self;
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
