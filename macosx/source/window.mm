#include <AppKit/AppKit.h>


@interface MainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation MainWindowDelegate


- (void)windowDidResize:(NSNotification *)notification  {
    NSWindow* window = (NSWindow*)notification.object;
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSLog(@"Window: become key");
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    NSLog(@"Window: become main");
}

- (void)windowDidResignKey:(NSNotification *)notification {
    NSLog(@"Window: resign key");
}

- (void)windowDidResignMain:(NSNotification *)notification {
    NSLog(@"Window: resign main");
}

// This will close/terminate the application when the main window is closed.
- (void)windowWillClose:(NSNotification *)notification {
    NSLog(@"Window: terminate");
    [NSApp terminate:nil];
}


// Empty implementations here so that the window doesn't complain (play the system
// beep error sound) when the events aren't handled or passed on to its view.
// i.e. A traditional Cocoa app expects to pass events on to its view(s).
- (void)keyDown :(NSEvent *)event { NSLog(@"keyDown"); }
- (void)keyUp   :(NSEvent *)event { NSLog(@"keyUp  "); }

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)canBecomeKeyWindow    { return YES; }
- (BOOL)canBecomeMainWindow   { return YES; }

@end


BOOL InitializeWindow()
{
    // [NSApplication sharedApplication];
    // [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    // [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    // [NSApp activateIgnoringOtherApps:YES];
    //
    // appDelegate = [[FSAppDelegate alloc] init];
    // [NSApp setDelegate:appDelegate];
    // [NSApp finishLaunching];
    return YES;
}


NSWindow* CreateWindow(int width, int height)
{
    // ---- INITIALIZE ----
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    [NSApp activateIgnoringOtherApps:YES];


    NSUInteger window_style = NSWindowStyleMaskTitled    |
                              NSWindowStyleMaskClosable  |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskMiniaturizable;

    NSRect screen_area = [[NSScreen mainScreen] frame];
    NSRect view_area   = NSMakeRect(0, 0, width, height);
    NSRect window_area = NSMakeRect(NSMidX(screen_area) - NSMidX(view_area),
                                    NSMidY(screen_area) - NSMidY(view_area),
                                    view_area.size.width,
                                    view_area.size.height);

    NSWindow* window = [[NSWindow alloc] initWithContentRect: window_area
                                                   styleMask: window_style
                                                     backing: NSBackingStoreBuffered
                                                       defer: NO];


    // id menubar = [[NSMenu new] autorelease];
    // id appMenuItem = [[NSMenuItem new] autorelease];
    // [menubar addItem:appMenuItem];
    // [NSApp setMainMenu:menubar];
    //
    // // Then we add the quit item to the menu. Fortunately the action is simple since terminate: is
    // // already implemented in NSApplication and the NSApplication is always in the responder chain.
    // id appMenu = [[NSMenu new] autorelease];
    // id appName = [[NSProcessInfo processInfo] processName];
    // id quitTitle = [@"Quit " stringByAppendingString:appName];
    // id quitMenuItem = [[[NSMenuItem alloc] initWithTitle:quitTitle
    //                                               action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
    // [appMenu addItem:quitMenuItem];
    // [appMenuItem setSubmenu:appMenu];
    //
    // NSWindowController* windowController = [[NSWindowController alloc] initWithWindow:window];
    // [windowController autorelease];

    //View
    // NSView* view = [[[NSView alloc] initWithFrame:view_area] autorelease];
    // [window setContentView: view];

    //Window Delegate
    MainWindowDelegate*  main_window_delegate = [[MainWindowDelegate alloc] init];
    [window setDelegate: main_window_delegate];


    [window setTitle: @"Temp"];
    [window setAcceptsMouseMovedEvents:YES];
    [window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
    [window setBackgroundColor: NSColor.blackColor];

    [window makeKeyAndOrderFront: nil];
    window.contentView.wantsLayer = YES;

    [NSApp finishLaunching];

    return window;
}

