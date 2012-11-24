//
//  WRMainWindowController.m
//  windower
//
//  Created by Mauricio Hanika on 23.11.12.
//  Copyright (c) 2012 Mauricio Hanika. All rights reserved.
//

#import "WRMainWindowController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <Carbon/Carbon.h>

@interface WRMainWindowController ()

@end


@implementation WRMainWindowController
{
  NSDictionary *_selectedWindow;
  NSMutableArray *_trackingWindows;
  NSMutableArray *_trackingApplications;
  
  IBOutlet NSArrayController *_arrayController;
  IBOutlet NSPopUpButton *_popUpButton;
  
  BOOL _spaceBarPressed;
}

@synthesize windows = _windows;
@synthesize selectedWindow = _selectedWindow;
@synthesize x = _x;
@synthesize y = _y;
@synthesize trackingWindows = _trackingWindows;

- (void) dealloc
{
  [_arrayController release];
  [_popUpButton release];
  [_selectedWindow release];
  [_trackingWindows release];
  [_trackingApplications release];
  
  [super dealloc];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
  if ((self = [super initWithWindowNibName:windowNibName]) == nil)
    return nil;
  
  _trackingWindows = [[NSMutableArray alloc] init];
  _trackingApplications = [[NSMutableArray alloc] init];
  
  EventHotKeyRef gHotKeyRef;
  EventHotKeyID gHotKeyID;
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  
  InstallApplicationEventHandler(hotKeyHandler, 1, &eventType, self, NULL);
  
  gHotKeyID.id = 1;
  gHotKeyID.signature = 'htk1';
  RegisterEventHotKey(49, cmdKey+shiftKey, gHotKeyID, GetApplicationEventTarget(), 0, &gHotKeyRef);
  
  [NSEvent addGlobalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^(NSEvent *evt) {
    if (_spaceBarPressed)
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
  
  return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
  CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
  
  NSMutableArray *windowNames = [NSMutableArray array];
  CFIndex count = CFArrayGetCount(windows);
  for (int i = 0; i < count; i++)
  {
    NSDictionary *window = (NSDictionary *)CFArrayGetValueAtIndex(windows, i);
    
    if ([[window objectForKey:@"kCGWindowAlpha"] floatValue] > 0.f && [window objectForKey:@"kCGWindowName"] != nil && ! [[window objectForKey:@"kCGWindowName"] isEqualToString:@""])
      [windowNames addObject:@{ @"name": [window objectForKey:@"kCGWindowName"], @"value": window }];
  }
  
  self.selectedWindow = self.windows.count > 0 ? self.windows[0][@"value"] : nil;
  self.windows = [NSArray arrayWithArray:windowNames];
  [_arrayController setContent:self.windows];
  
  [self addObserver:self forKeyPath:@"selectedWindow" options:NSKeyValueObservingOptionNew context:NULL];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"selectedWindow"])
  {
    NSLog(@"%@", self.selectedWindow);
    self.x = [self.selectedWindow[@"kCGWindowBounds"][@"X"] floatValue];
    self.y = [self.selectedWindow[@"kCGWindowBounds"][@"Y"] floatValue];
  }
}

- (void) clickedSetButton:(id)sender
{
  NSDictionary *selectedWindow = self.selectedWindow;
  pid_t pid = [[selectedWindow objectForKey:@"kCGWindowOwnerPID"] intValue];
  
  NSLog(@"%d", pid);
  if (pid != getpid())
  {
    AXObserverRef observer;
    AXObserverCreate(pid, windowMovedCallback, &observer);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), kCFRunLoopDefaultMode);

    AXUIElementRef app = AXUIElementCreateApplication(pid);
    AXObserverAddNotification(observer, app, (CFStringRef)NSAccessibilityWindowMovedNotification, self);
  }
}

- (void) timerCheckKeyPressed:(NSTimer *)theTimer
{
  if (! ([NSEvent modifierFlags]&NSShiftKeyMask) || ! ([NSEvent modifierFlags]&NSCommandKeyMask))
  {
    _spaceBarPressed = NO;
    [theTimer invalidate];
    return;
  }
  
  bool isSpaceBarPressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, (CGKeyCode)49);
  if (! isSpaceBarPressed)
  {
    _spaceBarPressed = NO;
    [theTimer invalidate];
  }
  else
  {
    _spaceBarPressed = YES;
  }
}

void windowMovedCallback(AXObserverRef observer, AXUIElementRef uiElement, CFStringRef notification, void* refcon)
{
  if ([[(WRMainWindowController *)refcon trackingWindows] containsObject:(id)uiElement])
  {
    NSLog(@"%@", (NSString *)notification);
    for (id el in [(WRMainWindowController *)refcon trackingWindows])
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

OSStatus hotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userInfo)
{
  [NSTimer scheduledTimerWithTimeInterval:.1f target:userInfo selector:@selector(timerCheckKeyPressed:) userInfo:nil repeats:YES];
  return noErr;
}



@end
