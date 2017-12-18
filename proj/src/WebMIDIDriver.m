//
//  WebMIDIDriver.m
//  webmidi
//
//  Created by 张宇飞 on 2017/9/28.
//  Copyright © 2017年 com. All rights reserved.
//

#import "WebMIDIDriver.h"
#import "WebMIDIDataParser.h"
#import <mach/mach_time.h>
#import <CoreMIDI/CoreMIDI.h>

#if TARGET_OS_IOS
#import <UIKit/UIApplication.h>
#import <CoreMIDI/MIDINetworkSession.h>
#endif

#define LOG_ERR_RET(c, str, rval)                                                                                                       \
    do {                                                                                                                                \
        if (c) {                                                                                                                        \
            NSLog(@"WebMIDIDriver error (%@): %ld: %@", str, (long)c, [NSError errorWithDomain:NSMachErrorDomain code:c userInfo:nil]); \
            return rval;                                                                                                                \
        }                                                                                                                               \
    } while (false)

static WebMIDIDriver* _sharedDrv = nil;

@interface WebMIDIDriver () <WebMIDIDataParserDelegate> {
    MIDIClientRef _client;
    MIDIPortRef _oport;
    MIDIPortRef _iport;

    NSMutableArray* _parsers;
    mach_timebase_info_data_t _startTime;
}

- (void)notifyProc:(const MIDINotification*)noti;

@end

#pragma mark - C tools

static void midiNotifyProc(const MIDINotification* notification, void* drvRef) {
    WebMIDIDriver* drv = (__bridge WebMIDIDriver*)drvRef;
    [drv notifyProc:notification];
}

static void midiReadProc(const MIDIPacketList* pktlist, void* drvRef, void* parserRef) {
    WebMIDIDataParser* parser = (__bridge WebMIDIDataParser*)parserRef;

    MIDIPacket* packet = (MIDIPacket*)&(pktlist->packet[0]);
    UInt32 packetCount = pktlist->numPackets;
    for (NSInteger i = 0; i < packetCount; i++) {
        [parser setData:packet->data length:packet->length timestamp:packet->timeStamp];
        packet = MIDIPacketNext(packet);
    }
}

static NSUInteger removeEndpoint(NSMutableArray* arr, MIDIEndpointRef endpoint) {
    NSUInteger idx = [arr indexOfObject:@(endpoint)];
    if (idx != NSNotFound) {
        [arr removeObjectAtIndex:idx];
    }
    return idx;
}

@implementation WebMIDIDriver

#pragma mark - tools
static BOOL isNetworkSession(MIDIEndpointRef ref) {
    MIDIEntityRef entity = 0;
    MIDIEndpointGetEntity(ref, &entity);

    BOOL hasMidiRtpKey = NO;
    CFPropertyListRef properties = nil;
    OSStatus s = MIDIObjectGetProperties(entity, &properties, true);
    if (!s) {
        NSDictionary* dictionary = (__bridge NSDictionary*)properties;
        hasMidiRtpKey = [dictionary valueForKey:@"apple.midirtp.session"] != nil;
        CFRelease(properties);
    }

    return hasMidiRtpKey;
}

+ (BOOL)isValidEndpoint:(MIDIEndpointRef)endpoint {
#ifndef DEBUG
#if TARGET_OS_IOS
    // 检测是否是网络连接
    BOOL isEnableNetwork = [[MIDINetworkSession defaultSession] isEnabled];
    BOOL isNetwork = isNetworkSession(endpoint);
    if (isNetwork && !isEnableNetwork) return NO;
#endif  // TARGET_OS_IOS
#endif  // DEBUG

    // 检测是否在线
    SInt32 offline;
    if (noErr == MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline)) {
        return offline == 0;
    }

    return NO;
}

#pragma mark - private interfaces

- (id)init {
    if (self = [super init]) {
        _dests   = [[NSMutableArray alloc] init];
        _sources = [[NSMutableArray alloc] init];
        _parsers = [[NSMutableArray alloc] init];

        mach_timebase_info(&_startTime);

        _valid = [self initClientAndPorts];
        if (_valid) {
            [self scanExistEndpoints];
#if TARGET_OS_IOS
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onForeground)
                                                         name:UIApplicationWillEnterForegroundNotification
                                                       object:nil];
#endif
        }
    }
    return self;
}

- (void)dealloc {
#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
}

- (BOOL)initClientAndPorts {
    OSStatus ret = MIDIClientCreate(CFSTR("web midi driver client"), midiNotifyProc, (__bridge void*)(self), &_client);
    LOG_ERR_RET(ret, @"create midi client failed", NO);

    ret = MIDIOutputPortCreate(_client, CFSTR("web midi driver output port"), &_oport);
    LOG_ERR_RET(ret, @"create midi output port failed", NO);

    ret = MIDIInputPortCreate(_client, CFSTR("web midi driver output port"), midiReadProc, (__bridge void*)self, &_iport);
    LOG_ERR_RET(ret, @"create midi input port failed", NO);

    return YES;
}

- (void)midiNotifyAdd:(const MIDIObjectAddRemoveNotification*)noti {
    if (noti->childType == kMIDIObjectType_Destination)
        [self addDest:(MIDIEndpointRef)noti->child checkExist:YES];
    else if (noti->childType == kMIDIObjectType_Source) {
        [self addSource:(MIDIEndpointRef)noti->child checkExist:YES];
    }
}

- (void)midiNotifyRemove:(const MIDIObjectAddRemoveNotification*)noti {
    if (noti->childType == kMIDIObjectType_Destination)
        [self removeDest:(MIDIEndpointRef)noti->child];
    else if (noti->childType == kMIDIObjectType_Source)
        [self removeSource:(MIDIEndpointRef)noti->child];
}

- (void)midiNotifyPropertyChanged:(const MIDIObjectPropertyChangeNotification*)noti {
    // 只处理休眠设备(例如我们的蓝牙设备会在切换后台的时候进入休眠)
    SInt32 offline;
    if (CFStringCompare(noti->propertyName, kMIDIPropertyOffline, 0) == kCFCompareEqualTo) {
        MIDIObjectGetIntegerProperty(noti->object, kMIDIPropertyOffline, &offline);
    } else {
        return;
    }

    // 对于休眠，就当作拔下处理。休眠结束就当作连接
    if (noti->objectType == kMIDIObjectType_Source) {
        if (offline) {
            [self removeSource:(MIDIEndpointRef)noti->object];
        } else {
            [self addSource:(MIDIEndpointRef)noti->object checkExist:YES];
        }
    } else if (noti->objectType == kMIDIObjectType_Destination) {
        if (offline) {
            [self removeDest:(MIDIEndpointRef)noti->object];
        } else {
            [self addDest:(MIDIEndpointRef)noti->object checkExist:YES];
        }
    }
}

- (void)notifyProc:(const MIDINotification*)noti {
    switch (noti->messageID) {
    case kMIDIMsgObjectAdded:
        [self midiNotifyAdd:(const MIDIObjectAddRemoveNotification*)noti];
        break;
    case kMIDIMsgObjectRemoved:
        [self midiNotifyRemove:(const MIDIObjectAddRemoveNotification*)noti];
        break;
    case kMIDIMsgPropertyChanged:
        [self midiNotifyPropertyChanged:(const MIDIObjectPropertyChangeNotification*)noti];
        break;
    case kMIDIMsgSetupChanged:
    case kMIDIMsgThruConnectionsChanged:
    case kMIDIMsgSerialPortOwnerChanged:
    case kMIDIMsgIOError:
        break;
    }
}

- (void)onForeground {
    [self scanExistEndpoints];
}

- (void)scanExistEndpoints {
    MIDIEndpointRef endpoint;

    // 清除掉已经掉线的设备
    NSMutableArray* deadDests = [[NSMutableArray alloc] init];
    NSMutableArray* deadSrcs  = [[NSMutableArray alloc] init];

    for (NSNumber* dest in _dests) {
        if (![WebMIDIDriver isValidEndpoint:[dest unsignedIntValue]]) {
            [deadDests addObject:dest];
        }
    }
    for (NSNumber* src in _sources) {
        if (![WebMIDIDriver isValidEndpoint:[src unsignedIntValue]]) {
            [deadSrcs addObject:src];
        }
    }
    for (NSNumber* dest in deadDests) {
        [self removeDest:[dest unsignedIntValue]];
    }
    for (NSNumber* src in deadSrcs) {
        [self removeSource:[src unsignedIntValue]];
    }

    // 扫描新的设备, 删除已经不存在的设备
    const ItemCount ndest = MIDIGetNumberOfDestinations();
    deadDests = [[NSMutableArray alloc] initWithArray:_dests];
    for (ItemCount index = 0; index < ndest; ++index) {
        endpoint = MIDIGetDestination(index);
        if (removeEndpoint(deadDests, endpoint) != NSNotFound) {
            continue;
        }
        [self addDest:endpoint checkExist:NO];
    }

    const ItemCount nsrc = MIDIGetNumberOfSources();
    deadSrcs = [[NSMutableArray alloc] initWithArray:_sources];
    for (ItemCount index = 0; index < nsrc; ++index) {
        endpoint = MIDIGetSource(index);
        if (removeEndpoint(deadSrcs, endpoint) != NSNotFound) {
            continue;
        }
        [self addSource:endpoint checkExist:NO];
    }

    for (NSNumber* dest in deadDests) {
        [self removeDest:[dest unsignedIntValue]];
    }

    for (NSNumber* src in deadSrcs) {
        [self removeSource:[src unsignedIntValue]];
    }
}

- (void)addSource:(MIDIEndpointRef)endpoint checkExist:(BOOL)checkExist {
    if (checkExist && ([_sources indexOfObject:@(endpoint)] != NSNotFound)) {
        return;
    }
    if (![WebMIDIDriver isValidEndpoint:endpoint]) {
        return;
    }

    WebMIDIDataParser* parser = [[WebMIDIDataParser alloc] init];
    NSUInteger idx = _sources.count;
    [_sources addObject:@(endpoint)];
    [_parsers addObject:parser];
    parser.delegate = self;

    OSStatus s = MIDIPortConnectSource(_iport, endpoint, (__bridge void*)parser);
    if (s != noErr) {
        [_sources removeObjectAtIndex:idx];
        [_parsers removeObjectAtIndex:idx];
        return;
    }

    if (_onSourceAdded) {
        _onSourceAdded(self, idx);
    }
}

- (void)addDest:(MIDIEndpointRef)endpoint checkExist:(BOOL)checkExist {
    if (checkExist && ([_dests indexOfObject:@(endpoint)] != NSNotFound)) {
        return;
    }
    if (![WebMIDIDriver isValidEndpoint:endpoint]) {
        return;
    }
    NSUInteger idx = _dests.count;
    [_dests addObject:@(endpoint)];

    if (_onDestAdded) {
        _onDestAdded(self, idx);
    }
}

- (void)removeDest:(MIDIEndpointRef)endpoint {
    NSUInteger idx = removeEndpoint(_dests, endpoint);
    if (idx != NSNotFound) {
        if (_onDestRemoved) {
            _onDestRemoved(self, idx);
        }
    }
}

- (void)removeSource:(MIDIEndpointRef)endpoint {
    NSUInteger idx = removeEndpoint(_sources, endpoint);
    if (idx != NSNotFound) {
        MIDIPortDisconnectSource(_iport, endpoint);
        [_parsers removeObjectAtIndex:idx];

        if (_onSourceRemoved) {
            _onSourceRemoved(self, idx);
        }
    }
}

- (BOOL)getEndpointFromIdx:(NSUInteger)idx isSource:(BOOL)isSource endpoint:(MIDIEndpointRef*)endpoint {
    if (isSource) {
        if (idx >= _sources.count) return NO;
        *endpoint = [[_sources objectAtIndex:idx] unsignedIntValue];
    } else {
        if (idx >= _dests.count) return NO;
        *endpoint = [[_dests objectAtIndex:idx] unsignedIntValue];
    }
    return YES;
}

#pragma mark - public interfaces
+ (instancetype)sharedDriver {
    @synchronized(self) {
        if (!_sharedDrv) {
            _sharedDrv = [self new];
        }
    }
    return _sharedDrv;
}

- (OSStatus)send:(NSUInteger)dest data:(UInt8* _Nonnull)data length:(NSUInteger)len deltaMs:(NSTimeInterval)dtms {
    if (dtms < 0 || len == 0) return -1;
    MIDIEndpointRef ep;
    if (![self getEndpointFromIdx:dest isSource:NO endpoint:&ep]) {
        return -1;
    }

    MIDITimeStamp timestamp = mach_absolute_time() + dtms * 1000000 * _startTime.denom / _startTime.numer;
    Byte buf[sizeof(MIDIPacketList) + len];
    MIDIPacketList* pktlist = (MIDIPacketList*)buf;
    MIDIPacket* packet      = MIDIPacketListInit(pktlist);
    packet = MIDIPacketListAdd(pktlist, sizeof(buf), packet, timestamp, len, data);
    if (packet == NULL) return -2;

    return MIDISend(_oport, ep, pktlist);
}

- (OSStatus)clear:(NSUInteger)dest {
    MIDIEndpointRef ep;
    if (![self getEndpointFromIdx:dest isSource:NO endpoint:&ep]) {
        return -1;
    }
    return MIDIFlushOutput(ep);
}

- (NSDictionary* _Nullable)getInfoOfEndpoint:(NSUInteger)endpoint isSource:(BOOL)isSource {
    MIDIEndpointRef ep;
    if (![self getEndpointFromIdx:endpoint isSource:isSource endpoint:&ep]) {
        return nil;
    }

    SInt32 uniqueId;
    OSStatus status = MIDIObjectGetIntegerProperty(ep, kMIDIPropertyUniqueID, &uniqueId);
    if (status != noErr) {
        uniqueId = 0;
    }

    CFStringRef manufacturer;
    status = MIDIObjectGetStringProperty(ep, kMIDIPropertyManufacturer, &manufacturer);
    if (status != noErr) {
        manufacturer = nil;
    }

    CFStringRef name;
    status = MIDIObjectGetStringProperty(ep, kMIDIPropertyName, &name);
    if (status != noErr) {
        name = nil;
    }

    SInt32 version;
    status = MIDIObjectGetIntegerProperty(ep, kMIDIPropertyDriverVersion, &version);
    if (status != noErr) {
        version = 0;
    }

    return @{
        @"id": @(uniqueId),
        @"version": @(version),
        @"manufacturer": ((__bridge_transfer NSString*)manufacturer ?: @""),
        @"name": ((__bridge_transfer NSString*)name ?: @""),
    };
}

- (void)cleanAllDelegates {
    self.onDestAdded = nil;
    self.onDestRemoved = nil;
    self.onDataReceived = nil;
    self.onSourceAdded = nil;
    self.onSourceRemoved = nil;
}

#pragma mark - WebMIDIDataParserDelegate
- (void)onData:(WebMIDIDataParser *)parser data:(const UInt8* _Nonnull)data length:(NSUInteger)len timestamp:(UInt64)timestamp {
    if (len == 1 && ((data[0] == 0xf8) || (data[0] == 0xfe))) return;

    NSData* udata = [[NSData alloc] initWithBytes:(const void*)data length:len];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onDataReceived) {
            NSUInteger idx = [_parsers indexOfObject:parser];
            if (idx != NSNotFound) {
                self.onDataReceived(self, idx, udata, timestamp);
            }
        }
    });
}

@end
