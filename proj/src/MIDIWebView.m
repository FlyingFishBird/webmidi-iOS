//
//  MIDIWebView.m
//  webmidi
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import "MIDIWebView.h"
#import "WebMIDIDriver.h"
#import "MIDIWebViewDelegate.h"

static NSString* const _delegateNames[] = {
    @"onready", @"send", @"clear"
};

@implementation MIDIWebView

+ (WKWebViewConfiguration* _Nullable)createConfigWithMIDIDriver:(WebMIDIDriver* _Nonnull)drv
                                              sysexConfirmation:(BOOL (^_Nonnull)(NSString* _Nonnull url))sysexConfirmation {
    // Create a delegate for handling informal URL schemes.
    NSString* polyfillPath = [[NSBundle mainBundle] pathForResource:@"WebMIDIAPIPolyfill" ofType:@"js"];
    if (polyfillPath == nil) {
        return nil;
    }

    NSString* polyfillScript = [NSString stringWithContentsOfFile:polyfillPath encoding:NSUTF8StringEncoding error:nil];
    WKUserScript* script =
        [[WKUserScript alloc] initWithSource:polyfillScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];

    MIDIWebViewDelegate* delegate =
        [[MIDIWebViewDelegate alloc] initWithMidiDriverAndSysexConfirmation:drv sysexConfirmation:sysexConfirmation];
    // Inject Web MIDI API bridge JavaScript
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    [userContentController addUserScript:script];
    for (int i = 0; i < sizeof(_delegateNames) / sizeof(_delegateNames[0]); ++i) {
        [userContentController addScriptMessageHandler:delegate name:_delegateNames[i]];
    }

    WKWebViewConfiguration* conf = [[WKWebViewConfiguration alloc] init];
    conf.userContentController   = userContentController;

    return conf;
}

- (void)dealloc {
    for (int i = 0; i < sizeof(_delegateNames) / sizeof(_delegateNames[0]); ++i) {
        [[self configuration].userContentController removeScriptMessageHandlerForName:_delegateNames[i]];
    }
}

@end
