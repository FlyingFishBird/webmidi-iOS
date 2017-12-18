//
//  MIDIWebView.h
//  webmidi
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@class WebMIDIDriver;

@interface MIDIWebView : WKWebView

+ (WKWebViewConfiguration* _Nullable)createConfigWithMIDIDriver:(WebMIDIDriver* _Nonnull)drv
                                              sysexConfirmation:(BOOL (^_Nonnull)(NSString* _Nonnull url))sysexConfirmation;

@end
