//
//  ViewController.m
//  MsgDemo
//
//  Created by chenxingbin on 2018/7/10.
//  Copyright © 2018年 chenxingbin. All rights reserved.
//

#import "ViewController.h"
#import "XBMsgThrottle.h"

@interface ViewController ()<UIScrollViewDelegate>
@property (nonatomic,strong) XBThrottleItem *item;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
    //对scrollViewDidScroll：进行回调限制 每一秒回调一次
    self.item = [XBMsgThrottle throttleTarget:self selector:@selector(scrollViewDidScroll:) durationInterval:1  mode:XBThrottleModePerBegin];
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
    
    
    UIButton *removeBtn = UIButton.new;
    removeBtn.frame = CGRectMake(0, 100, 100, 100);
    removeBtn.backgroundColor = UIColor.blueColor;
    [scrollView addSubview:removeBtn];
    [removeBtn addTarget:self action:@selector(removeBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [removeBtn setTitle:@"移除" forState:UIControlStateNormal];
    
    
}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    NSLog(@"scrollViewDidScroll");
}

-(void)removeBtnClick{
    [XBMsgThrottle.sharedThrottle removeItem:self.item];
}


@end
