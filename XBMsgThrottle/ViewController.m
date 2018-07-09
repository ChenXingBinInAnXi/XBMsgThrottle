//
//  ViewController.m
//  XBMsgThrottle
//
//  Created by chenxingbin on 2018/7/9.
//  Copyright © 2018年 chenxingbin. All rights reserved.
//

#import "ViewController.h"
#import "XBMsgThrottle.h"

@interface ViewController ()
@property (nonatomic,strong) XBThrottleItem *item;
@property (nonatomic,strong) XBThrottleItem *item2;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    

    

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)btnClick{
    NSLog(@"btnClick");
    [XBMsgThrottle.sharedThrottle removeItem:self.item];
    [XBMsgThrottle.sharedThrottle removeItem:self.item2];
}

-(void)btn2Click{
    
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//    NSLog(@"touchesBegan");
//    [[ViewController class] clsT1];
//    [[ViewController class] clsT1];
    
    [self test1];
    [self test2];
}

+(void)clsT1{
    NSLog(@"clsT1");
}
+(void)clsT2{
    NSLog(@"clsT2");
}


-(void)test1{
    NSLog(@"test1");
}

-(void)test2{
    NSLog(@"test2");
}

@end
