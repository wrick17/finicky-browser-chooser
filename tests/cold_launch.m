// Checks that a link delivered before applicationDidFinishLaunching: reaches the chooser. Shows no UI and opens nothing.
// Run: clang -fobjc-arc -arch arm64 -mmacosx-version-min=13.0 -framework Cocoa -Isrc -o /tmp/cold_launch tests/cold_launch.m src/Chooser.m && /tmp/cold_launch
#define main chooser_app_main
#include "../src/main.m"
#undef main

@interface RecordingChooser : ChooserController
@property (nonatomic, strong) NSMutableArray<NSString *> *hosts;
@end

@implementation RecordingChooser
- (void)askForHost:(NSString *)host completion:(void (^)(NSInteger choice))completion {
    [self.hosts addObject:host];
}
@end

int main(void) {
    @autoreleasepool {
        AppDelegate *delegate = [[AppDelegate alloc] init];
        if (!delegate.chooser) {
            printf("FAIL: no chooser before launch finishes\n");
            return 1;
        }
        RecordingChooser *chooser = [[RecordingChooser alloc] initWithChoices:ChoiceNames()];
        chooser.hosts = [NSMutableArray array];
        delegate.chooser = chooser;

        [delegate application:NSApp openURLs:@[ [NSURL URLWithString:@"https://first.example.test/callback?code=sample"] ]];
        [delegate applicationDidFinishLaunching:[NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification object:nil]];

        if (delegate.chooser != chooser || ![chooser.hosts isEqualToArray:@[ @"first.example.test" ]] || delegate.pending != 1) {
            printf("FAIL: early link lost (pending=%ld, asked=%lu)\n", (long)delegate.pending, (unsigned long)chooser.hosts.count);
            return 1;
        }
        printf("PASS: early link reached the chooser (pending=1, asked for first.example.test)\n");
    }
    return 0;
}
