//
//  WRAppDelegate.m
//  windower
//
//  Created by Mauricio Hanika on 23.11.12.
//  Copyright (c) 2012 Mauricio Hanika. All rights reserved.
//

#import "WRAppDelegate.h"
#import "WRMainWindowController.h"

@implementation WRAppDelegate
{
  WRMainWindowController *_mainWindowController;
}

- (void)dealloc
{
  [_mainWindowController release];
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Insert code here to initialize your application
  _mainWindowController = [[WRMainWindowController alloc] initWithWindowNibName:@"WRMainWindow"];
  [_mainWindowController showWindow:self];
}

@end
