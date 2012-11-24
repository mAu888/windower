//
//  WRAppDelegate.m
//  windower
//
//  Created by Mauricio Hanika on 23.11.12.
//  Copyright (c) 2012 Mauricio Hanika. All rights reserved.
//

#import "WRAppDelegate.h"
#import "WRMainWindowController.h"

#import <Carbon/Carbon.h>

////////////
// Handles

OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userInfo)
{
  [NSTimer scheduledTimerWithTimeInterval:.1f target:userInfo selector:@selector(timerCheckKeyPressed:) userInfo:nil repeats:YES];
  
  return noErr;
}

void windowMovedCallback(AXObserverRef observer, AXUIElementRef uiElement, CFStringRef notification, void* refcon)
{
  if ([[(WRAppDelegate *)refcon trackingWindows] containsObject:(id)uiElement])
  {
    NSLog(@"%@", (NSString *)notification);
    for (id el in [(WRAppDelegate *)refcon trackingWindows])
    {
      if (el != (id)uiElement)
      {
        CFTypeRef _pos = NULL;
        AXUIElementCopyAttributeValue(uiElement, (CFStringRef)NSAccessibilityPositionAttribute, &_pos);
        AXUIElementSetAttributeValue((AXUIElementRef)el, (CFStringRef)NSAccessibilityPositionAttribute, _pos);
      }
    }
  }
}


////////////////////////
// Interface-extension

@interface WRAppDelegate ()

- (void) registerGlobalHotKeyEvent;
- (void) registerGlobalMouseClickEvent;
- (void) timerCheckKeyPressed:(NSTimer *)timer;

@end


///////////////////
// Implementation

@implementation WRAppDelegate
{
  WRMainWindowController *_mainWindowController;
  
  NSMutableArray *_trackingApplications;
  NSMutableArray *_trackingWindows;
  
  BOOL _hotKeyActive;
}

@synthesize trackingWindows = _trackingWindows;

- (void)dealloc
{
  [_mainWindowController release];
  
  [_trackingApplications release];
  [_trackingWindows release];
  
  [super dealloc];
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Create ui stuff
  _mainWindowController = [[WRMainWindowController alloc] initWithWindowNibName:@"WRMainWindow"];
  [_mainWindowController showWindow:self];

  _trackingApplications = [[NSMutableArray alloc] init];
  _trackingWindows = [[NSMutableArray alloc] init];
  
  [self registerGlobalHotKeyEvent];
  [self registerGlobalMouseClickEvent];
}

#pragma mark - Private methods

- (void) registerGlobalHotKeyEvent
{
  EventHotKeyRef hotKey;
  EventHotKeyID hotKeyID;
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  
  InstallApplicationEventHandler(hotKeyHandler, 1, &eventType, self, NULL);
  
  hotKeyID.id = 1;
  hotKeyID.signature = 'htk1';
  RegisterEventHotKey(49, cmdKey+shiftKey, hotKeyID, GetApplicationEventTarget(), 0, &hotKey);
}

- (void) registerGlobalMouseClickEvent
{
  [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^(NSEvent *event) {
    if (_hotKeyActive)
    {
      NSLog(@"Left mouse down at %@", NSStringFromPoint([NSEvent mouseLocation]));
      
      AXUIElementRef sysWide = AXUIElementCreateSystemWide();
      AXUIElementRef focusedApp;
      AXUIElementRef focusedWindow;
      pid_t pid;
      
      AXUIElementCopyAttributeValue(sysWide, kAXFocusedApplicationAttribute, (CFTypeRef*)&focusedApp);
      AXUIElementCopyAttributeValue(focusedApp, (CFStringRef)NSAccessibilityFocusedWindowAttribute, (CFTypeRef*)&focusedWindow);
      AXUIElementGetPid(focusedApp, &pid);
      NSNumber *pidNum = @(pid);
      
      if (! [_trackingApplications containsObject:pidNum])
      {
        if (pid != getpid())
        {
          AXObserverRef observer;
          AXObserverCreate(pid, windowMovedCallback, &observer);
          CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), kCFRunLoopDefaultMode);
          
          AXUIElementRef app = AXUIElementCreateApplication(pid);
          AXObserverAddNotification(observer, app, (CFStringRef)NSAccessibilityWindowMovedNotification, self);
        }
      }
      
      [_trackingApplications addObject:pidNum];
      
      CFTypeRef size;
      AXUIElementCopyAttributeValue(focusedWindow, (CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)&size);
      
      NSPoint p;
      AXValueGetValue(size, kAXValueCGPointType, &p);
      NSLog(@"ok ... is %@", NSStringFromPoint(p));
      
      if (! [_trackingWindows containsObject:(id)focusedWindow])
      {
        [_trackingWindows addObject:(id)focusedWindow];
      }
    }
  }];
}

- (void) timerCheckKeyPressed:(NSTimer *)timer
{
  // Verify shift, command and space pressed
  if (! ([NSEvent modifierFlags]&NSShiftKeyMask) || ! ([NSEvent modifierFlags]&NSCommandKeyMask) || ! CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, (CGKeyCode)49))
  {
    _hotKeyActive = NO;
    [timer invalidate];
  }
  else
  {
    _hotKeyActive = YES;
  }
}

@end
