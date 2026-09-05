#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import "bridge.h"

@class ClipboardApp;
static EventHotKeyRef registeredHotkey;

@interface ClipboardApp : NSObject <NSApplicationDelegate, NSTextFieldDelegate>
@property (strong) NSPasteboard *pasteboard;
@property NSInteger changeCount;
@property (strong) NSStatusItem *statusItem;
@property (strong) NSMenu *statusMenu;
@property (strong) NSPanel *panel;
@property (strong) NSTextField *searchField;
@property (strong) NSView *rows;
@property (strong) NSRunningApplication *previousApp;
- (void)showPanel;
@end

static OSStatus hotkeyCallback(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
  ClipboardApp *app = (__bridge ClipboardApp *)userData;
  dispatch_async(dispatch_get_main_queue(), ^{ [app showPanel]; });
  return noErr;
}

@implementation ClipboardApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  self.pasteboard = NSPasteboard.generalPasteboard;
  self.changeCount = self.pasteboard.changeCount;
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidActivateApplicationNotification
      object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
    NSRunningApplication *active = note.userInfo[NSWorkspaceApplicationKey];
    if (active.processIdentifier != NSProcessInfo.processInfo.processIdentifier) self.previousApp = active;
  }];

  self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
  self.statusItem.visible = YES;
  NSStatusBarButton *button = self.statusItem.button;
  NSImage *icon = [NSImage imageWithSystemSymbolName:@"doc.on.clipboard" accessibilityDescription:@"Clipboard History"];
  icon.template = YES;
  button.image = icon;
  button.imagePosition = NSImageOnly;
  button.imageScaling = NSImageScaleProportionallyDown;
  button.toolTip = @"Clipboard History (⌘⇧V)";
  self.statusMenu = [[NSMenu alloc] initWithTitle:@"Clipboard History"];
  NSMenuItem *showItem = [[NSMenuItem alloc] initWithTitle:@"显示剪贴板历史" action:@selector(showPanel) keyEquivalent:@""];
  showItem.target = self;
  [self.statusMenu addItem:showItem];
  [self.statusMenu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出 Clipboard History" action:@selector(terminate:) keyEquivalent:@"q"];
  quitItem.target = NSApp;
  [self.statusMenu addItem:quitItem];
  self.statusItem.menu = self.statusMenu;

  [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(checkPasteboard:) userInfo:nil repeats:YES];
  [self installHotkey];
}

- (void)installHotkey {
  EventTypeSpec eventType = {kEventClassKeyboard, kEventHotKeyPressed};
  InstallApplicationEventHandler(hotkeyCallback, 1, &eventType, (__bridge void *)self, NULL);
  EventHotKeyID hotkeyID = {'CLPH', 1};
  OSStatus status = RegisterEventHotKey(kVK_ANSI_V, cmdKey | shiftKey, hotkeyID,
      GetApplicationEventTarget(), 0, &registeredHotkey);
  if (status != noErr) {
    NSLog(@"Could not register ⌘⇧V hotkey: %d", (int)status);
  }
}

- (void)checkPasteboard:(NSTimer *)timer {
  NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
  if (frontmost.processIdentifier != NSProcessInfo.processInfo.processIdentifier) self.previousApp = frontmost;
  if (self.pasteboard.changeCount == self.changeCount) return;
  self.changeCount = self.pasteboard.changeCount;
  NSString *text = [self.pasteboard stringForType:NSPasteboardTypeString];
  if (text.length > 0) GoClipboardChanged((char *)text.UTF8String);
}

- (void)togglePanel:(id)sender {
  if (self.panel.isVisible) [self.panel orderOut:nil]; else [self showPanel];
}

- (void)showPanel {
  if (!self.panel) [self buildPanel];
  self.searchField.stringValue = @"";
  [self refreshRows];
  [self.panel center];
  [self.panel makeKeyAndOrderFront:nil];
  [self.panel makeFirstResponder:self.searchField];
}

- (void)buildPanel {
  self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 580, 460)
      styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskNonactivatingPanel)
      backing:NSBackingStoreBuffered defer:NO];
  self.panel.title = @"剪贴板历史";
  self.panel.level = NSFloatingWindowLevel;
  self.panel.hidesOnDeactivate = NO;
  self.panel.becomesKeyOnlyIfNeeded = YES;

  NSView *content = self.panel.contentView;
  self.searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 416, 540, 28)];
  self.searchField.placeholderString = @"搜索历史记录…";
  self.searchField.delegate = self;
  [content addSubview:self.searchField];

  NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 540, 384)];
  scroll.hasVerticalScroller = YES;
  self.rows = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 384)];
  scroll.documentView = self.rows;
  [content addSubview:scroll];
}

- (void)controlTextDidChange:(NSNotification *)note { [self refreshRows]; }

- (void)refreshRows {
  for (NSView *view in self.rows.subviews) [view removeFromSuperview];
  char *raw = GoHistoryJSON();
  NSData *data = [NSData dataWithBytes:raw length:strlen(raw)];
  free(raw);
  NSArray<NSString *> *items = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSString *query = self.searchField.stringValue.lowercaseString;
  NSMutableArray<NSDictionary *> *matches = [NSMutableArray array];
  for (NSInteger i = 0; i < items.count && matches.count < 30; i++) {
    NSString *item = items[i];
    if (query.length && [item.lowercaseString rangeOfString:query].location == NSNotFound) continue;
    [matches addObject:@{@"text": item, @"index": @(i)}];
  }
  NSInteger height = MAX(384, matches.count * 34 + 8);
  self.rows.frame = NSMakeRect(0, 0, 520, height);
  for (NSInteger rowIndex = 0; rowIndex < matches.count; rowIndex++) {
    NSDictionary *match = matches[rowIndex];
    NSString *item = match[@"text"];
    NSString *oneLine = [[item componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] componentsJoinedByString:@" ↵ "];
    if (oneLine.length > 110) oneLine = [[oneLine substringToIndex:110] stringByAppendingString:@"…"];
    NSButton *row = [NSButton buttonWithTitle:oneLine target:self action:@selector(selectItem:)];
    row.tag = [match[@"index"] integerValue];
    row.bezelStyle = NSBezelStyleTexturedRounded;
    row.alignment = NSTextAlignmentLeft;
    row.frame = NSMakeRect(0, height - (rowIndex + 1) * 34 - 4, 520, 28);
    row.autoresizingMask = NSViewWidthSizable;
    [self.rows addSubview:row];
  }
  if (matches.count == 0) {
    NSTextField *empty = [NSTextField labelWithString:@"尚无匹配的文本记录"];
    empty.frame = NSMakeRect(0, height - 32, 520, 28);
    [self.rows addSubview:empty];
  }
}

- (void)selectItem:(NSButton *)sender {
  GoSelectHistory((int)sender.tag);
  [self.panel orderOut:nil];
  NSRunningApplication *target = self.previousApp;
  NSLog(@"Clipboard paste requested: target=%@ pid=%d, accessibility=%d", target.localizedName,
      (int)target.processIdentifier, AXIsProcessTrusted());
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!target || target.processIdentifier == NSProcessInfo.processInfo.processIdentifier) {
      NSLog(@"Clipboard paste skipped: no usable target application");
      return;
    }
    NSLog(@"Clipboard posting Command-V to %@ (%d)", target.localizedName, (int)target.processIdentifier);
    CGEventRef down = CGEventCreateKeyboardEvent(NULL, 9, true); // V
    CGEventSetFlags(down, kCGEventFlagMaskCommand);
    CGEventPostToPid(target.processIdentifier, down);
    CFRelease(down);
    CGEventRef up = CGEventCreateKeyboardEvent(NULL, 9, false);
    CGEventSetFlags(up, kCGEventFlagMaskCommand);
    CGEventPostToPid(target.processIdentifier, up);
    CFRelease(up);
  });
}
@end

void WriteClipboard(const char *text) {
  NSPasteboard *board = NSPasteboard.generalPasteboard;
  [board clearContents];
  [board setString:[NSString stringWithUTF8String:text] forType:NSPasteboardTypeString];
}

void RunClipboardApp(void) {
  @autoreleasepool {
    NSApplication *app = NSApplication.sharedApplication;
    ClipboardApp *delegate = [ClipboardApp new];
    app.delegate = delegate;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [app run];
  }
}
