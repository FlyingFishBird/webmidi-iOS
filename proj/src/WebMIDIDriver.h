//
//  WebMIDIDriver.h
//  webmidi
//  提供访问 MIDI 设备的能力
//
//  Created by 张宇飞 on 2017/9/28.
//  Copyright © 2017年 com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WebMIDIDriver : NSObject

@property(nonatomic, readonly) NSMutableArray* _Nonnull dests;
@property(nonatomic, readonly) NSMutableArray* _Nonnull sources;
@property(nonatomic, readonly) BOOL valid;

+ (instancetype _Nonnull)sharedDriver;
/**
 收到 midi 数据
 */
@property(nonatomic, copy) void (^_Nullable onDataReceived)
    (__weak WebMIDIDriver* _Nonnull drv, NSUInteger source, NSData* data, UInt64 timestamp);

/**
 midi 输入源添加
 */
@property(nonatomic, copy) void (^_Nullable onSourceAdded)(__weak WebMIDIDriver* _Nonnull drv, NSUInteger source);

/**
 midi 输出目标设备已添加
 */
@property(nonatomic, copy) void (^_Nullable onDestAdded)(__weak WebMIDIDriver* _Nonnull drv, NSUInteger dest);

/**
 midi 输入源被移除
 */
@property(nonatomic, copy) void (^_Nullable onSourceRemoved)(__weak WebMIDIDriver* _Nonnull drv, NSUInteger source);

/**
 midi 输出目标设备被移除
 */
@property(nonatomic, copy) void (^_Nullable onDestRemoved)(__weak WebMIDIDriver* _Nonnull drv, NSUInteger dest);

/**
 发送midi消息

 @param dest 目标设备
 @param data midi 数据
 @param len midi 数据长度
 @param dtms 延迟的毫秒数
 @return noErr 表示成功
 */
- (OSStatus)send:(NSUInteger)dest data:(UInt8* _Nonnull)data length:(NSUInteger)len deltaMs:(NSTimeInterval)dtms;

/**
 清除目标设备的缓冲队列

 @param dest 要清除的目标设备
 @return noErr 表示成功
 */
- (OSStatus)clear:(NSUInteger)dest;

/**
 获取某个设备的信息

 @param endpoint dest 或者是 source 设备的id
 @param isSource 是否是输入设备
 @return nil 获取失败
 @return {
    @"id"          : @"xxx", 唯一ID
    @"name"        : @"xxx", 名字
    @"version"     : @"xxx", 驱动版本
    @"manufacture" : @"xxx", 设备生产商
 }
 */
- (NSDictionary* _Nullable)getInfoOfEndpoint:(NSUInteger)endpoint isSource:(BOOL)isSource;


/**
 将所有的delegate设置为nil
 */
- (void)cleanAllDelegates;

@end
