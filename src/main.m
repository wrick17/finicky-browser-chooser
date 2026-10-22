#import <Cocoa/Cocoa.h>
#import "Chooser.h"

static NSArray<NSString *> *ChoiceNames(void) { return @[ @"Island", @"Helium" ]; }
static NSArray<NSString *> *ChoiceBundleIDs(void) { return @[ @"io.island.Island", @"net.imput.helium" ]; }

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic) BOOL testMode;
@property (nonatomic, strong) ChooserController *chooser;
@property (nonatomic) NSInteger pending;
@end

@implementation AppDelegate

// Create the chooser here: AppKit can deliver the launching link before applicationDidFinishLaunching:.
- (instancetype)init {
    self = [super init];
    if (self) _chooser = [[ChooserController alloc] initWithChoices:ChoiceNames()];
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (self.testMode) {
        [self runTest];
    } else {
        // Launched without a link (for example from Finder): nothing to do.
        [self quitWhenIdle];
    }
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    if (self.testMode) return;
    for (NSURL *url in urls) {
        NSString *scheme = url.scheme.lowercaseString;
        if (!([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) || url.host.length == 0) {
            NSLog(@"Ignoring a link that is not http or https");
            continue;
        }
        [self ask:url];
    }
}

- (void)ask:(NSURL *)url {
    self.pending++;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(quitIfIdle) object:nil];
    // Show only the host: the path and query can carry sign-in tokens.
    [self.chooser askForHost:url.host completion:^(NSInteger choice) {
        if (choice < 0) {
            [self finishOne];
        } else {
            [self open:url withChoice:(NSUInteger)choice];
        }
    }];
}

- (void)open:(NSURL *)url withChoice:(NSUInteger)choice {
    NSString *name = ChoiceNames()[choice];
    NSURL *appURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:ChoiceBundleIDs()[choice]];
    if (!appURL) {
        NSLog(@"%@ is not installed", name);
        NSBeep();
        [self finishOne];
        return;
    }
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    [NSWorkspace.sharedWorkspace openURLs:@[ url ]
                     withApplicationAtURL:appURL
                            configuration:configuration
                        completionHandler:^(NSRunningApplication *app, NSError *error) {
        if (error) {
            // The error description can include the link, so log only its code.
            NSLog(@"Could not open the link in %@ (%@ %ld)", name, error.domain, (long)error.code);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ [self finishOne]; });
    }];
}

- (void)finishOne {
    self.pending--;
    [self quitWhenIdle];
}

- (void)quitWhenIdle {
    if (self.pending == 0) [self performSelector:@selector(quitIfIdle) withObject:nil afterDelay:2];
}

- (void)quitIfIdle {
    if (self.pending == 0) [NSApp terminate:nil];
}

// Shows two queued panels with sample hosts and prints each answer. Opens no links.
- (void)runTest {
    __block NSInteger remaining = 2;
    for (NSString *host in @[ @"first.example.test", @"second.example.test" ]) {
        [self.chooser askForHost:host completion:^(NSInteger choice) {
            NSString *answer = choice < 0 ? @"cancelled" : ChoiceNames()[(NSUInteger)choice];
            printf("chooser-test: %s -> %s\n", host.UTF8String, answer.UTF8String);
            fflush(stdout);
            if (--remaining == 0) exit(0);
        }];
    }
}
@end

// NSApplication holds its delegate weakly, so keep it alive here.
static AppDelegate *appDelegate;

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        appDelegate = [[AppDelegate alloc] init];
        // Only an explicit command-line run enters test mode; Launch Services never passes this flag.
        appDelegate.testMode = argc == 2 && strcmp(argv[1], "--chooser-test") == 0;
        app.delegate = appDelegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
