#import "Chooser.h"

@interface ChooserRequest : NSObject
@property (nonatomic, copy) NSString *host;
@property (nonatomic, strong) NSScreen *screen;
@property (nonatomic, copy) void (^completion)(NSInteger choice);
@end

@implementation ChooserRequest
@end

@interface ChooserPanel : NSPanel
@property (nonatomic, weak) ChooserController *controller;
@end

@interface ChooserController ()
- (void)moveSelection:(NSInteger)delta;
- (void)finishWithChoice:(NSInteger)choice;
@end

@implementation ChooserPanel
- (BOOL)canBecomeKeyWindow { return YES; }

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 123: case 126: [self.controller moveSelection:-1]; return; // left, up
        case 124: case 125: [self.controller moveSelection:1]; return;  // right, down
    }
    [super keyDown:event];
}

- (void)cancelOperation:(id)sender {
    [self.controller finishWithChoice:-1];
}
@end

@implementation ChooserController {
    NSArray<NSString *> *choices;
    NSMutableArray<ChooserRequest *> *queue;
    ChooserRequest *current;
    ChooserPanel *panel;
    NSMutableArray<NSButton *> *buttons;
    NSInteger selected;
}

- (instancetype)initWithChoices:(NSArray<NSString *> *)initialChoices {
    self = [super init];
    if (self) {
        choices = [initialChoices copy];
        queue = [NSMutableArray array];
        buttons = [NSMutableArray array];
    }
    return self;
}

- (void)askForHost:(NSString *)host completion:(void (^)(NSInteger choice))completion {
    ChooserRequest *request = [[ChooserRequest alloc] init];
    request.host = host;
    // Capture the display with keyboard focus now, not when an earlier panel finishes.
    request.screen = NSScreen.mainScreen;
    request.completion = completion;
    [queue addObject:request];
    if (!panel) [self presentNext];
}

- (NSView *)contentViewForHost:(NSString *)host {
    NSTextField *label = [NSTextField labelWithString:[NSString stringWithFormat:@"Open %@ in:", host]];
    label.font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:NSFontWeightSemibold];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [label.widthAnchor constraintLessThanOrEqualToConstant:360].active = YES;

    NSStackView *row = [[NSStackView alloc] init];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8;
    [buttons removeAllObjects];
    for (NSUInteger i = 0; i < choices.count; i++) {
        NSButton *button = [NSButton buttonWithTitle:choices[i] target:self action:@selector(choose:)];
        button.tag = (NSInteger)i;
        [buttons addObject:button];
        [row addArrangedSubview:button];
    }
    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
    cancel.keyEquivalent = @"\e";
    [row addArrangedSubview:cancel];
    [row setCustomSpacing:24 afterView:buttons.lastObject];

    NSStackView *stack = [NSStackView stackViewWithViews:@[label, row]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    // Pin the stack on all sides so the panel sizes to it with equal side margins.
    NSView *content = [[NSView alloc] init];
    [content addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:18],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-18],
    ]];
    return content;
}

- (void)presentNext {
    if (queue.count == 0) return;
    current = queue.firstObject;
    [queue removeObjectAtIndex:0];

    panel = [[ChooserPanel alloc] initWithContentRect:NSZeroRect
                                            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskNonactivatingPanel
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    panel.controller = self;
    panel.delegate = self;
    panel.title = @"Finicky";
    panel.releasedWhenClosed = NO;
    panel.hidesOnDeactivate = NO;
    panel.floatingPanel = YES;
    panel.level = NSFloatingWindowLevel;
    // Join whichever Space is active, including another app's fullscreen Space, without activating this app.
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorTransient |
        NSWindowCollectionBehaviorCanJoinAllApplications;

    NSView *content = [self contentViewForHost:current.host];
    panel.contentView = content;
    selected = 0;
    [self updateSelection];
    [panel setContentSize:content.fittingSize];

    NSRect frame = panel.frame;
    NSRect area = (current.screen ?: NSScreen.mainScreen).frame;
    frame.origin.x = NSMidX(area) - frame.size.width / 2;
    frame.origin.y = NSMidY(area) - frame.size.height / 2 + area.size.height / 6;
    [panel setFrame:frame display:NO];

    // Key without activating: activating this app could switch Spaces.
    [panel makeKeyAndOrderFront:nil];
}

- (void)updateSelection {
    for (NSButton *button in buttons) {
        button.keyEquivalent = button.tag == selected ? @"\r" : @"";
    }
}

- (void)moveSelection:(NSInteger)delta {
    NSInteger count = (NSInteger)buttons.count;
    selected = ((selected + delta) % count + count) % count;
    [self updateSelection];
}

- (void)choose:(NSButton *)sender { [self finishWithChoice:sender.tag]; }
- (void)cancel:(id)sender { [self finishWithChoice:-1]; }

- (void)finishWithChoice:(NSInteger)choice {
    if (!panel) return;
    ChooserRequest *done = current;
    panel.delegate = nil;
    [panel orderOut:nil];
    panel = nil;
    current = nil;
    done.completion(choice);
    [self presentNext];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self finishWithChoice:-1];
    return NO;
}
@end
