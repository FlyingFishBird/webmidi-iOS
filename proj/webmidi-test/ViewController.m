//
//  ViewController.m
//  webmidi-test
//
//  Created by xiaoyezi on 2017/9/29.
//  Copyright © 2017年 com. All rights reserved.
//

#import "ViewController.h"
#import <webmidi/webmidi.h>

@interface ViewController ()<UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource> {
    __weak IBOutlet UITextField *_urlTextField;
    __weak IBOutlet UITableView *_urlTableView;
    NSMutableArray *_urlList;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化常用的几个地址列表
    _urlList = [[NSMutableArray alloc] initWithCapacity:2];
    [_urlList addObject:@"https://ppea.research.xiaoyezi.com"];
    [_urlList addObject:@"https://kass.dev.loscomet.com:64513/test.html"];
    [_urlList addObject:@"https://baidu.com"];
    [_urlList addObject:@"xyz:exit"];

    _urlTextField.delegate = self;
}

- (void)enterMIDIWebView:(NSString *)url {
    SimpleMIDIWebViewController *vc = [SimpleMIDIWebViewController new];
    [self presentViewController:vc
                       animated:YES
                     completion:^{
                         [vc loadUrl:url];
                     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text && textField.text.length > 0) {
        [self enterMIDIWebView:textField.text];
        return YES;
    }
    return NO;
}

#pragma mark - table data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _urlList.count;
}

- (NSUInteger)arrIdxFromRow:(NSIndexPath *)ipath {
    return _urlList.count - ipath.row - 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseID"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"reuseID"];
    }
    NSUInteger idx = [self arrIdxFromRow:indexPath];
    NSString *url  = [_urlList objectAtIndex:idx];

    cell.textLabel.text = url;
    //    cell.detailTextLabel.text = cellData.name;
    //    cell.textLabel.textColor = cellData.color;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger idx = [self arrIdxFromRow:indexPath];
    NSString *url  = [_urlList objectAtIndex:idx];

    [self enterMIDIWebView:url];
}

@end
