#import <AppKit/AppKit.h>

#include "browser_activation.h"
#include "macos_browser_integration.h"

#include <QPointer>
#include <QString>

@interface GenyDLDownloadService : NSObject
@property (copy, nonatomic) BOOL (^submit)(NSString*);
@end

@implementation GenyDLDownloadService
- (void)downloadLink:(NSPasteboard*)pasteboard
            userData:(NSString*)userData
               error:(NSString**)error
{
    NSString* input = [pasteboard stringForType:NSPasteboardTypeURL];
    if (!input) input = [pasteboard stringForType:NSPasteboardTypeString];
    if (!input || !self.submit || !self.submit(input)) {
        if (error) *error = @"GenyDL only accepts direct HTTP(S) download links.";
    }
}
@end

void activateMacGenyDL()
{
    [NSApp activateIgnoringOtherApps:YES];
}

void registerMacBrowserService(BrowserActivation* receiver)
{
    if (!receiver) return;
    // Keep the Services provider alive for the lifetime of the application.
    static GenyDLDownloadService* provider = nil;
    if (!provider) provider = [[GenyDLDownloadService alloc] init];
    QPointer<BrowserActivation> target(receiver);
    provider.submit = ^BOOL(NSString* input) {
        return target && target->submitUrl(QString::fromNSString(input));
    };
    [NSApp setServicesProvider:provider];
    NSUpdateDynamicServices();
}
