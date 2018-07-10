//
//  ViewController.m
//  XBMsgThrottle
//
//  Created by chenxingbin on 2018/7/9.
//  Copyright © 2018年 chenxingbin. All rights reserved.
//

#import "ViewController.h"
#import "XBMsgThrottle.h"

@interface ViewController ()<UIScrollViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
    
    //对scrollViewDidScroll：进行回调限制 每一秒回调一次
    [self limitSelector:@selector(scrollViewDidScroll:) durationInterval:1 mode:XBThrottleModePerBegin];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)createUI{
    UIScrollView *scrollView = UIScrollView.new;
    scrollView.frame = self.view.bounds;
    scrollView.contentSize = scrollView.frame.size;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];
    scrollView.backgroundColor = UIColor.redColor;
    scrollView.delegate = self;
    
    
    UIView *testView = UIView.new;
    testView.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 200);
    testView.backgroundColor = UIColor.yellowColor;
    [scrollView addSubview:testView];
}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    NSLog(@"scrollViewDidScroll");
}


@end
