//
//  SimpleMIDIWebViewController.h
//  webmidi
//  一个全屏的横屏显示的web view
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SimpleMIDIWebViewController : UIViewController

// 自定义消息url。用这个字符串连接其它的字符串请求的话，将视为自定义消息
extern NSString* _Nonnull const SimpleMIDIWebViewControllerCustomMsgUrl;

@property(nonatomic, copy) void (^_Nullable onViewControllerDestroy)
(SimpleMIDIWebViewController* _Nonnull vc);

@property(nonatomic, copy) void (^_Nullable onUrlBeginToLoad)
(SimpleMIDIWebViewController* _Nonnull vc, NSString* _Nonnull url);

@property(nonatomic, copy) void (^_Nullable onUrlLoaded)
(SimpleMIDIWebViewController* _Nonnull vc, NSString* _Nonnull url);

@property(nonatomic, copy) void (^_Nullable onCustomMsg)
(SimpleMIDIWebViewController* _Nonnull vc, NSString* _Nullable msg);

@property(nonatomic, copy) void (^_Nullable onUrlLoadedFailed)
(SimpleMIDIWebViewController* _Nonnull vc, NSString* _Nonnull url, NSError* _Nonnull error);

@property(nonatomic, copy) void (^_Nullable onUrlLoadingProgressChanged)
(SimpleMIDIWebViewController* _Nonnull vc, NSString* _Nonnull url, CGFloat progress);

- (void)backToPreViewController;
- (void)loadUrl:(NSString* _Nonnull)url;
- (void)reloadLastUrl;

@end
