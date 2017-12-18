//
//  WebMIDIDataParser.h
//  webmidi
//  用于解析midi 数据。代码修改自 Takashi Mizuhiki 在 Takashi Mizuhiki
//  项目中 MIDIParser 的实现
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WebMIDIDataParser;

@protocol WebMIDIDataParserDelegate

@required
- (void)onData:(WebMIDIDataParser *_Nonnull)parser data:(const UInt8* _Nonnull)data length:(NSUInteger)len timestamp:(UInt64)timestamp;
@end

@interface WebMIDIDataParser : NSObject

@property (nonatomic, weak, nullable) id <WebMIDIDataParserDelegate> delegate;

- (void)setData:(UInt8* _Nonnull)data length:(NSUInteger)len timestamp:(UInt64)timestamp;
- (void)reset;

@end
