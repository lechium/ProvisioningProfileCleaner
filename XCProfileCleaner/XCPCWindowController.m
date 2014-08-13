//
//  XTWindowController.m
//  XCProfileCleaner
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import "XCPCWindowController.h"
#import "XCPCModel.h"
@interface XCPCWindowController ()

@end

@implementation XCPCWindowController


- (void)windowWillClose:(NSNotification *)notification
{
 //save prefs
}

- (void)awakeFromNib
{
    scanProfilesCheckbox.toolTip = @"When enabled XCProfileCleaner will scan any new provisioning profiles that are opened and see if any of the currently opened projects need to be updated \
or whether or not they are invalid and need to be updated";
    scanProjectsCheckbox.toolTip = @"When enabled XCProfileCleaner will scan any Xcode projects that open to see if they are currently up to date with a valid cert and provisioning profile \
if not it will search for a valid profile and update the project automatically";
    alertMeCheckbox.toolTip = @"Alert me when either of the two options above make project changes";
    
}


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    //nada
}

@end
