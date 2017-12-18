//
//  WebMIDIDataParser.m
//  webmidi
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import "WebMIDIDataParser.h"

#pragma mark - C tools

/**
 获取一个 midi 数据的长度

 @param statu midi 数据的标志位
 @return 数据长度
 */
static NSUInteger getMIDIDataLength(UInt8 statu) {
    switch (statu & 0xF0) {
    case 0x80:
    case 0x90:
    case 0xA0:
    case 0xB0:
    case 0xE0:
        return 3;

    case 0xC0:
    case 0xD0:
        return 2;

    case 0xF0:
        switch (statu) {
        case 0xF1:
        case 0xF3:
            return 2;
        case 0xF2:
            return 3;
        default:
            return 1;
        }
        break;

    default:
        return 0;
    }
}

@interface WebMIDIDataParser () {
    UInt8 _parsedData[3];
    NSUInteger _totalBytes;
    NSUInteger _filledBytes;

    NSMutableData* _sysex;
}

@end

@implementation WebMIDIDataParser

#pragma mark - private interfaces

- (id)init {
    if (self = [super init]) {
        [self reset];
    }
    return self;
}

#pragma mark - public interfaces

- (void)setData:(UInt8* _Nonnull)data length:(NSUInteger)len timestamp:(UInt64)timestamp {
    const uint8_t* p   = data;
    const uint8_t* end = data + len;

    while (p < end) {
        if (*p & 0x80) {
            // status byte (MSB is 1)
            if (*p >= 0xF8) {
                // realtime message
                [self.delegate onData:self data:p length:1 timestamp:timestamp];
            } else if (_sysex) {
                // detected a status byte in SysEx
                if (*p == 0xF7) {
                    // End of SysEx
                    [_sysex appendBytes:p length:1];
                    [self.delegate onData:self data:_sysex.bytes length:_sysex.length timestamp:timestamp];
                    _sysex = nil;
                } else {
                    // A unrightful status byte was found in the SysEx message.
                    // Finish parsing the message forcedly.
                    UInt8 f7 = 0xf7;
                    [_sysex appendBytes:&f7 length:1];

                    [self.delegate onData:self data:_sysex.bytes length:_sysex.length timestamp:timestamp];
                    _sysex = nil;

                    // Continue to parse the unrightful status byte.
                    continue;
                }
            } else {
                if (*p == 0xF0) {
                    // Start parsing a SysEx.
                    _sysex = [NSMutableData data];
                    [_sysex appendBytes:p length:1];
                    _totalBytes  = NSUIntegerMax;
                    _filledBytes = 0;
                } else {
                    _parsedData[0] = *p;
                    _totalBytes    = getMIDIDataLength(*p);
                    _filledBytes   = 1;
                }
            }
        } else {
            // Data byte (MSB is 0)
            if (_sysex) {
                // A SysEx message is being parsed. Append the byte into the SysEx.
                [_sysex appendBytes:p length:1];
            } else if (_totalBytes == 0) {
                // A data byte has been detected without a status byte. It might be a running status.
                if (_parsedData[0]) {
                    _totalBytes  = getMIDIDataLength(_parsedData[0]);
                    _filledBytes = 1;

                    // Continue to parse next byte.
                    continue;
                }

                // Found a data byte but a valid status byte has not been detected.
                // The data byte will be ignored.
            } else {
                _parsedData[_filledBytes] = *p;
                _filledBytes++;

                if (_totalBytes == _filledBytes) {
                    [self.delegate onData:self data:_parsedData length:_totalBytes timestamp:timestamp];
                    _totalBytes  = 0;
                    _filledBytes = 0;
                }
            }
        }
        p++;
    }
}

- (void)reset {
    memset(_parsedData, 0, sizeof(_parsedData));
    _totalBytes  = 0;
    _filledBytes = 0;
    _sysex       = nil;
}

@end
