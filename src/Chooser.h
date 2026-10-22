#import <Cocoa/Cocoa.h>

// Shows one chooser panel at a time. The completion gets the chosen index, or -1 when cancelled.
@interface ChooserController : NSObject <NSWindowDelegate>
- (instancetype)initWithChoices:(NSArray<NSString *> *)choices;
- (void)askForHost:(NSString *)host completion:(void (^)(NSInteger choice))completion;
// Builds the panel content. Exposed so the layout can be checked without showing a window.
- (NSView *)contentViewForHost:(NSString *)host;
@end
