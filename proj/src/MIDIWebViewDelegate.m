//
//  WebMIDIViewDelegate.m
//  webmidi
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import <mach/mach_time.h>
#import "MIDIWebViewDelegate.h"
#import "WebMIDIDriver.h"

static void invokeJSCallback_onNotReady(WKWebView* webView) {
    [webView evaluateJavaScript:@"_callback_onNotReady();" completionHandler:nil];
}

@implementation MIDIWebViewDelegate {
    BOOL _sysexEnabled;
    __weak WebMIDIDriver* _midiDrv;
    BOOL (^_confirmSysExAvailability)(NSString* url);
}

- (id _Nonnull)initWithMidiDriverAndSysexConfirmation:(WebMIDIDriver* _Nonnull)drv
                                    sysexConfirmation:(BOOL (^_Nonnull)(NSString* _Nonnull url))sysexConfirmation {
    if (self = [super init]) {
        _sysexEnabled             = NO;
        _midiDrv                  = drv;
        _confirmSysExAvailability = sysexConfirmation;
    }
    return self;
}

#pragma mark - WKScriptMessageHandler's interfaces

- (void)userContentController:(WKUserContentController*)userContentController didReceiveScriptMessage:(WKScriptMessage*)message {
    if ([message.name isEqualToString:@"onready"] == YES) {
        __block uint64_t timestampOrigin = 0;

        mach_timebase_info_data_t base;
        mach_timebase_info(&base);

        NSDictionary* dict = message.body;

        NSDictionary* MIDIoptions = dict[@"options"];
        NSString* url             = dict[@"url"];

        _sysexEnabled  = NO;
        id sysexOption = MIDIoptions[@"sysex"];
        if ([sysexOption isKindOfClass:[NSNumber class]] && [sysexOption boolValue] == YES) {
            if (_confirmSysExAvailability) {
                if (_confirmSysExAvailability(url) == NO) {
                    invokeJSCallback_onNotReady(message.webView);
                    return;
                } else {
                    _sysexEnabled = YES;
                }
            } else {
                invokeJSCallback_onNotReady(message.webView);
                return;
            }
        }

        if (_midiDrv.valid == NO) {
            invokeJSCallback_onNotReady(message.webView);
            return;
        }

        // 监听 midi 消息
        _midiDrv.onDataReceived =
            ^(WebMIDIDriver* __weak _Nonnull drv, NSUInteger source, NSData* data, UInt64 timestamp) {
                NSMutableArray* array = [NSMutableArray arrayWithCapacity:data.length];
                BOOL sysexIncluded = NO;
                for (int i = 0; i < data.length; i++) {
                    unsigned char byte = ((unsigned char*)data.bytes)[i];
                    [array addObject:[NSNumber numberWithUnsignedChar:byte]];

                    if (byte == 0xf0) {
                        sysexIncluded = YES;
                    }
                }

                if (_sysexEnabled == NO && sysexIncluded == YES) {
                    // should throw InvalidAccessError exception here
                    return;
                }

                NSData* dataJSON      = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
                NSString* dataJSONStr = [[NSString alloc] initWithData:dataJSON encoding:NSUTF8StringEncoding];

                double dt = (double)(timestamp - timestampOrigin) * base.numer / base.denom / 1000000.0;

                NSString* s = [NSString stringWithFormat:@"_callback_receiveMIDIMessage(%lu, %f, %@);", (unsigned long)source, dt, dataJSONStr];
                [message.webView evaluateJavaScript:s completionHandler:nil];
            };

        // 监听输出端口的添加
        _midiDrv.onDestAdded   = ^(WebMIDIDriver* __weak _Nonnull drv, NSUInteger dest) {
            NSDictionary* info = [drv getInfoOfEndpoint:dest isSource:NO];
            NSData* JSON       = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
            NSString* JSONStr  = [[NSString alloc] initWithData:JSON encoding:NSUTF8StringEncoding];

            [message.webView evaluateJavaScript:[NSString stringWithFormat:@"_callback_addDestination(%lu, %@);", (unsigned long)dest, JSONStr]
                              completionHandler:nil];
        };

        // 监听输入设备的添加
        _midiDrv.onSourceAdded = ^(WebMIDIDriver* __weak _Nonnull drv, NSUInteger source) {
            NSDictionary* info = [drv getInfoOfEndpoint:source isSource:YES];
            NSData* JSON       = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
            NSString* JSONStr  = [[NSString alloc] initWithData:JSON encoding:NSUTF8StringEncoding];

            [message.webView evaluateJavaScript:[NSString stringWithFormat:@"_callback_addSource(%lu, %@);", (unsigned long)source, JSONStr]
                              completionHandler:nil];
        };

        // 监听输出设备的移除
        _midiDrv.onDestRemoved = ^(WebMIDIDriver* __weak _Nonnull drv, NSUInteger dest) {
            [message.webView evaluateJavaScript:[NSString stringWithFormat:@"_callback_removeDestination(%lu);", (unsigned long)dest]
                              completionHandler:nil];
        };

        // 监听输入设备的移除
        _midiDrv.onSourceRemoved = ^(WebMIDIDriver* __weak _Nonnull drv, NSUInteger source) {
            [message.webView evaluateJavaScript:[NSString stringWithFormat:@"_callback_removeSource(%lu);", (unsigned long)source] completionHandler:nil];
        };

        // Send all MIDI ports information when the setup request is received.
        NSMutableArray* srcInfos  = [NSMutableArray arrayWithCapacity:_midiDrv.sources.count];
        NSMutableArray* destInfos = [NSMutableArray arrayWithCapacity:_midiDrv.dests.count];

        for (NSUInteger i = 0; i < _midiDrv.sources.count; ++i) {
            NSDictionary* info = [_midiDrv getInfoOfEndpoint:i isSource:YES];
            [srcInfos addObject:info];
        }

        for (NSUInteger i = 0; i < _midiDrv.dests.count; ++i) {
            NSDictionary* info = [_midiDrv getInfoOfEndpoint:i isSource:NO];
            [destInfos addObject:info];
        }

        NSData* srcsJSON = [NSJSONSerialization dataWithJSONObject:srcInfos options:0 error:nil];
        if (srcsJSON == nil) {
            invokeJSCallback_onNotReady(message.webView);
            return;
        }
        NSString* srcsJSONStr = [[NSString alloc] initWithData:srcsJSON encoding:NSUTF8StringEncoding];

        NSData* destsJSON = [NSJSONSerialization dataWithJSONObject:destInfos options:0 error:nil];
        if (destsJSON == nil) {
            invokeJSCallback_onNotReady(message.webView);
            return;
        }
        NSString* destsJSONStr = [[NSString alloc] initWithData:destsJSON encoding:NSUTF8StringEncoding];

        timestampOrigin = mach_absolute_time();
        [message.webView evaluateJavaScript:[NSString stringWithFormat:@"_callback_onReady(%@, %@);", srcsJSONStr, destsJSONStr]
                          completionHandler:nil];

        return;
    } else if ([message.name isEqualToString:@"send"] == YES) {
        NSDictionary* dict = message.body;

        NSArray* array      = dict[@"data"];
        NSMutableData* data = [NSMutableData dataWithCapacity:[array count]];
        BOOL sysexIncluded = NO;
        for (NSNumber* number in array) {
            uint8_t byte = [number unsignedIntegerValue];
            [data appendBytes:&byte length:1];

            if (byte == 0xf0) {
                sysexIncluded = YES;
            }
        }

        if (_sysexEnabled == NO && sysexIncluded == YES) {
            return;
        }

        NSUInteger dest = [dict[@"outputPortIndex"] unsignedIntegerValue];
        [_midiDrv send:dest data:(UInt8*)data.bytes length:data.length deltaMs:[dict[@"deltaTime"] doubleValue]];

        return;
    } else if ([message.name isEqualToString:@"clear"] == YES) {
        NSDictionary* dict = message.body;
        [_midiDrv clear:(UInt32)[dict[@"outputPortIndex"] unsignedIntegerValue]];
    }
}

@end
