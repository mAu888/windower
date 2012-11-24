//
//  WRMainWindowController.h
//  windower
//
//  Created by Mauricio Hanika on 23.11.12.
//  Copyright (c) 2012 Mauricio Hanika. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WRMainWindowController : NSWindowController

@property (nonatomic, retain) NSArray *windows;
@property (nonatomic, retain) NSDictionary *selectedWindow;
@property (nonatomic, assign) float x;
@property (nonatomic, assign) float y;
@property (nonatomic, readonly) NSArray *trackingWindows;

- (IBAction) clickedSetButton:(id)sender;

@end
