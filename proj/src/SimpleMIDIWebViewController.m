//
//  SimpleMIDIWebViewController.m
//  webmidi
//
//  Created by 张宇飞 on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import <UIKit/UIApplication.h>
#import "SimpleMIDIWebViewController.h"
#import "WebMIDIDriver.h"
#import "MIDIWebView.h"

#define ESPROGRESS_NAME @"estimatedProgress"

static NSString* _Nonnull const CUSTOM_MSG_EXIT = @"exit";
NSString* _Nonnull const SimpleMIDIWebViewControllerCustomMsgUrl = @"xyz:";

@interface SimpleMIDIWebViewController ()<WKNavigationDelegate, UIGestureRecognizerDelegate> {
    MIDIWebView* _webview;
    NSString* _lastUrl;
    CALayer* _progressBar;
    BOOL _preIdleTimerState;
}

@end

@implementation SimpleMIDIWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _preIdleTimerState = [UIApplication sharedApplication].isIdleTimerDisabled;
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    // load midi driver
    WKWebViewConfiguration* conf = [MIDIWebView createConfigWithMIDIDriver:[WebMIDIDriver sharedDriver]
                                                         sysexConfirmation:^BOOL(NSString* _Nonnull url) {
                                                             return YES;
                                                         }];

    _webview = [[MIDIWebView alloc] initWithFrame:self.view.bounds configuration:conf];
    [self.view addSubview:_webview];

    [_webview addObserver:self forKeyPath:ESPROGRESS_NAME options:NSKeyValueObservingOptionNew context:nil];

    // NOTE(zhangyufei): 默认禁止边缘弹性效果。这样在复杂交互的UI上有较好体验
    _webview.scrollView.bounces = NO;

    _webview.navigationDelegate = self;

    [self reloadLastUrl];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _webview.frame = self.view.bounds;
}

- (void)dealloc {
    [_webview removeObserver:self forKeyPath:ESPROGRESS_NAME];
    [_webview stopLoading];
    [[WebMIDIDriver sharedDriver] cleanAllDelegates];

    if (self.onViewControllerDestroy) {
        self.onViewControllerDestroy(self);
    }
}

// 隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    return YES;
}

// 禁止自动旋转
- (BOOL)shouldAutorotate {
    return YES;
}

// 设置只支持横屏
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

#pragma mark - public interfaces

- (void)backToPreViewController {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [UIApplication sharedApplication].idleTimerDisabled = _preIdleTimerState;
}

- (void)loadUrl:(NSString* _Nonnull)url {
    _lastUrl = url;
    if (!_webview) return;

    [self reloadLastUrl];
}

- (void)reloadLastUrl {
    if (!_lastUrl) return;
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:_lastUrl] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0];

    [_webview loadRequest:request];
}

#pragma mark - WKNavigationDelegate

#if DEBUG
- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse*)navigationResponse
                      decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView*)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                                                NSURLCredential* _Nullable credential))completionHandler {
    NSURLCredential* cred = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, cred);
}

#endif  // DEBUG

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString* url = navigationAction.request.URL.absoluteString;
    if (!url) return;

    if ([url rangeOfString:SimpleMIDIWebViewControllerCustomMsgUrl].location != 0) {
        _lastUrl = url;
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    decisionHandler(WKNavigationActionPolicyCancel);
    NSString* customMsg = [url substringFromIndex:SimpleMIDIWebViewControllerCustomMsgUrl.length];
    if ([customMsg isEqualToString:CUSTOM_MSG_EXIT]) {
        [self backToPreViewController];
    } else if (self.onCustomMsg) {
        self.onCustomMsg(self, customMsg);
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.onUrlLoadedFailed && _lastUrl) {
        self.onUrlLoadedFailed(self, _lastUrl, error);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (self.onUrlBeginToLoad && _lastUrl) {
        self.onUrlBeginToLoad(self, _lastUrl);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.onUrlLoaded && _lastUrl) {
        self.onUrlLoaded(self, _lastUrl);
    }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id>*)change
                       context:(void*)context {
    if ([keyPath isEqualToString:ESPROGRESS_NAME]) {
        CGFloat progress = [[change objectForKey:@"new"] floatValue];
        if (self.onUrlLoadingProgressChanged && _lastUrl) {
            self.onUrlLoadingProgressChanged(self, _lastUrl, progress);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
