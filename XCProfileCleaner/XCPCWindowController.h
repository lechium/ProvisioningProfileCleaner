//
//  XTWindowController.h
//  XCProfileCleaner
//
//  Created by Kevin Bradley on 7/14/14.
//  Copyright (c) 2014 nito. All rights reserved.
//

#import <Cocoa/Cocoa.h>



@interface XCPCWindowController : NSWindowController <NSWindowDelegate>
{
    IBOutlet NSButton *scanProfilesCheckbox;
    IBOutlet NSButton *scanProjectsCheckbox;
    IBOutlet NSButton *alertMeCheckbox;
}

@property (nonatomic, assign) id delegate;
@end
